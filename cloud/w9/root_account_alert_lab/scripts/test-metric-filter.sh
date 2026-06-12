#!/bin/bash
# =============================================================================
# test-metric-filter.sh — Test metric filter bằng cách gửi fake log event
# KHÔNG cần thực sự đăng nhập root!
# Session 05: Alert on AWS Root Account Login
# =============================================================================

set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log_info() { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_ok()   { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC}  $*"; }

LOG_GROUP="${1:-/aws/cloudtrail/security-trail}"
REGION="${AWS_DEFAULT_REGION:-ap-southeast-1}"
LOG_STREAM="test-root-login-$(date +%s)"

echo ""
echo "============================================================"
echo "   🧪 Test Metric Filter — Root Login Simulator            "
echo "============================================================"
echo ""
echo "  Log Group:  ${LOG_GROUP}"
echo "  Method:     Gửi fake CloudTrail event vào Log Group"
echo ""

# ── Tạo log stream tạm thời ──────────────────────────────────────────────────
log_info "Tạo Log Stream tạm: ${LOG_STREAM}"
aws logs create-log-stream \
    --log-group-name "$LOG_GROUP" \
    --log-stream-name "$LOG_STREAM" \
    --region "$REGION"

# ── Tạo fake Root Login event (giống CloudTrail real event) ──────────────────
TIMESTAMP=$(date +%s%3N)  # Unix timestamp milliseconds

FAKE_ROOT_LOGIN_EVENT=$(cat <<'EOF'
{
  "eventVersion": "1.08",
  "userIdentity": {
    "type": "Root",
    "principalId": "123456789012",
    "arn": "arn:aws:iam::123456789012:root",
    "accountId": "123456789012"
  },
  "eventTime": "2026-06-12T05:30:00Z",
  "eventSource": "signin.amazonaws.com",
  "eventName": "ConsoleLogin",
  "awsRegion": "us-east-1",
  "sourceIPAddress": "1.2.3.4",
  "userAgent": "Mozilla/5.0",
  "requestParameters": null,
  "responseElements": {
    "ConsoleLogin": "Success"
  },
  "eventType": "AwsConsoleSignIn",
  "eventID": "test-event-$(date +%s)",
  "readOnly": false,
  "managementEvent": true
}
EOF
)

# Ghi vào CloudWatch Logs
log_info "Gửi fake Root Login event vào CloudWatch Logs..."

aws logs put-log-events \
    --log-group-name "$LOG_GROUP" \
    --log-stream-name "$LOG_STREAM" \
    --log-events "timestamp=${TIMESTAMP},message=${FAKE_ROOT_LOGIN_EVENT}" \
    --region "$REGION" > /dev/null

log_ok "Fake event đã gửi!"

# ── Phương án 2: put-metric-data trực tiếp (đảm bảo alarm trigger) ───────────
log_info "Gửi metric trực tiếp để đảm bảo alarm trigger..."

aws cloudwatch put-metric-data \
    --namespace "Security" \
    --metric-name "RootAccountLoginCount" \
    --value 1 \
    --unit Count \
    --region "$REGION"

log_ok "Metric data đã gửi! (Security/RootAccountLoginCount = 1)"

echo ""
echo "============================================================"
log_ok "✅ Test event đã gửi!"
echo ""
echo "  ⏱  Đợi 1-2 phút cho CloudWatch xử lý..."
echo ""
echo "  📊 Theo dõi alarm state:"
echo "    watch -n 30 'aws cloudwatch describe-alarms \\"
echo "        --alarm-names RootAccountLogin-Alert \\"
echo "        --query \"MetricAlarms[0].{State:StateValue,Reason:StateReason}\" \\"
echo "        --output table'"
echo ""
echo "  📧 Kiểm tra email để xác nhận cảnh báo đã được gửi."
echo "============================================================"
echo ""
