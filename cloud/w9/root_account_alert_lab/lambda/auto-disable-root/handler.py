"""
auto_disable_root/handler.py
Lambda Function: Tự động vô hiệu hoá Root credentials khi phát hiện Root login

Trigger: SNS → Lambda (khi CloudWatch Alarm → ALARM state)

Actions:
  1. Xoá Root Access Keys (nếu có)
  2. Gửi thông báo chi tiết qua SNS
  3. Ghi audit log vào CloudWatch Logs
  4. (Optional) Tạo AWS Config rule violation

Lưu ý: Root MFA không thể bị disable qua API — cần can thiệp thủ công.
"""

import json
import boto3
import logging
import os
from datetime import datetime, timezone

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# AWS Clients
iam_client = boto3.client('iam')
sns_client = boto3.client('sns')
logs_client = boto3.client('logs')

# Config từ environment variables
ALERT_TOPIC_ARN = os.environ.get('ALERT_TOPIC_ARN', '')
AUDIT_LOG_GROUP = os.environ.get('AUDIT_LOG_GROUP', '/security/root-login-audit')


def lambda_handler(event, context):
    """
    Main Lambda handler - triggered by SNS từ CloudWatch Alarm.
    """
    logger.info(f"Root Account Alert received: {json.dumps(event)}")

    timestamp = datetime.now(timezone.utc).isoformat()
    actions_taken = []
    findings = []

    try:
        # ── 1. Phân tích SNS message ──────────────────────────────────────────
        sns_message = json.loads(event['Records'][0]['Sns']['Message'])
        alarm_name = sns_message.get('AlarmName', 'Unknown')
        alarm_state = sns_message.get('NewStateValue', 'Unknown')
        alarm_reason = sns_message.get('NewStateReason', '')

        logger.info(f"Alarm: {alarm_name}, State: {alarm_state}")

        # Chỉ xử lý khi alarm CHUYỂN SANG ALARM state (không xử lý khi về OK)
        if alarm_state != 'ALARM':
            logger.info("State không phải ALARM, bỏ qua.")
            return {'statusCode': 200, 'body': 'Skipped — not ALARM state'}

        findings.append(f"🚨 CẢNH BÁO: Root account login được phát hiện lúc {timestamp}")
        findings.append(f"Alarm: {alarm_name}")
        findings.append(f"Lý do: {alarm_reason}")

        # ── 2. Kiểm tra Root Access Keys ──────────────────────────────────────
        logger.info("Kiểm tra Root Access Keys...")
        access_keys = _get_root_access_keys()

        if access_keys:
            findings.append(f"⚠️  Phát hiện {len(access_keys)} Root Access Key(s)!")
            for key in access_keys:
                key_id = key['AccessKeyId']
                key_status = key['Status']
                findings.append(f"   Key ID: {key_id}, Status: {key_status}")

                # Vô hiệu hoá key nếu đang Active
                if key_status == 'Active':
                    logger.warning(f"Vô hiệu hoá Root Access Key: {key_id}")
                    iam_client.update_access_key(
                        AccessKeyId=key_id,
                        Status='Inactive'
                    )
                    actions_taken.append(f"✅ Đã vô hiệu hoá Root Access Key: {key_id}")
                    logger.info(f"Key {key_id} đã bị disable!")
        else:
            findings.append("✅ Không có Root Access Key nào (tốt!)")

        # ── 3. Kiểm tra Root MFA ──────────────────────────────────────────────
        logger.info("Kiểm tra Root MFA status...")
        account_summary = iam_client.get_account_summary()['SummaryMap']

        mfa_enabled = account_summary.get('AccountMFAEnabled', 0)
        if mfa_enabled == 1:
            findings.append("✅ Root MFA: ĐÃ BẬT")
        else:
            findings.append("❌ Root MFA: CHƯA BẬT — Bật ngay tại IAM Console!")

        # ── 4. Gửi notification chi tiết ─────────────────────────────────────
        if ALERT_TOPIC_ARN:
            detailed_message = _build_alert_message(findings, actions_taken, timestamp)
            _send_notification(alarm_name, detailed_message)
            actions_taken.append("📧 Đã gửi thông báo chi tiết qua SNS")

        # ── 5. Ghi audit log ──────────────────────────────────────────────────
        _write_audit_log(findings, actions_taken, timestamp)

        result = {
            'timestamp': timestamp,
            'alarm_name': alarm_name,
            'findings': findings,
            'actions_taken': actions_taken
        }

        logger.info(f"Kết quả xử lý: {json.dumps(result, ensure_ascii=False)}")
        return {'statusCode': 200, 'body': json.dumps(result, ensure_ascii=False)}

    except Exception as e:
        logger.error(f"Lỗi xử lý: {str(e)}", exc_info=True)
        raise


def _get_root_access_keys():
    """Lấy danh sách Root Access Keys."""
    try:
        response = iam_client.list_access_keys()
        # Lưu ý: list_access_keys() không có UserName = root user
        return response.get('AccessKeyMetadata', [])
    except Exception as e:
        logger.error(f"Không lấy được access keys: {e}")
        return []


def _build_alert_message(findings, actions_taken, timestamp):
    """Xây dựng nội dung email cảnh báo chi tiết."""
    lines = [
        "=" * 60,
        "🚨 SECURITY INCIDENT: AWS ROOT ACCOUNT LOGIN DETECTED",
        "=" * 60,
        f"Time: {timestamp}",
        "",
        "FINDINGS:",
        *[f"  {f}" for f in findings],
        "",
        "AUTOMATED ACTIONS TAKEN:",
        *([f"  {a}" for a in actions_taken] if actions_taken else ["  Không có action tự động"]),
        "",
        "REQUIRED MANUAL ACTIONS:",
        "  1. Xác nhận việc root login có được phép không",
        "  2. Kiểm tra CloudTrail logs để biết root làm gì",
        "  3. Nếu không được phép: đổi root password ngay",
        "  4. Review và revoke mọi root access keys",
        "  5. Đảm bảo root MFA đang được bật",
        "",
        "CloudTrail Console:",
        "  https://console.aws.amazon.com/cloudtrail/home#/events",
        "=" * 60,
    ]
    return "\n".join(lines)


def _send_notification(alarm_name, message):
    """Gửi SNS notification."""
    try:
        sns_client.publish(
            TopicArn=ALERT_TOPIC_ARN,
            Subject=f"🚨 [ACTION REQUIRED] {alarm_name} — Root Login Auto-Response",
            Message=message
        )
        logger.info("SNS notification đã gửi")
    except Exception as e:
        logger.error(f"Không gửi được SNS: {e}")


def _write_audit_log(findings, actions_taken, timestamp):
    """Ghi audit log vào CloudWatch Logs."""
    try:
        audit_entry = {
            'timestamp': timestamp,
            'event_type': 'ROOT_LOGIN_DETECTED',
            'findings': findings,
            'actions_taken': actions_taken,
            'automated_response': True
        }

        # Tạo log stream theo ngày
        stream_name = f"root-login-{datetime.now().strftime('%Y/%m/%d')}"

        try:
            logs_client.create_log_stream(
                logGroupName=AUDIT_LOG_GROUP,
                logStreamName=stream_name
            )
        except logs_client.exceptions.ResourceAlreadyExistsException:
            pass  # Stream đã tồn tại, bình thường

        import time
        logs_client.put_log_events(
            logGroupName=AUDIT_LOG_GROUP,
            logStreamName=stream_name,
            logEvents=[{
                'timestamp': int(time.time() * 1000),
                'message': json.dumps(audit_entry, ensure_ascii=False)
            }]
        )
        logger.info(f"Audit log đã ghi vào {AUDIT_LOG_GROUP}/{stream_name}")

    except Exception as e:
        logger.warning(f"Không ghi được audit log: {e}")
