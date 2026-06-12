#!/bin/bash
# =============================================================================
# create-alarm.sh — Tạo CloudWatch Alarm: CPU > 80% trong 5 phút
# Session 03: CPU Alarm → Email Alert via SNS
# =============================================================================

set -euo pipefail

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log_info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_success() { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

# ── Giá trị mặc định ─────────────────────────────────────────────────────────
ALARM_NAME="High-CPU-Alert"
INSTANCE_ID=""
SNS_TOPIC_ARN=""
THRESHOLD=80
PERIOD=300          # 5 phút = 300 giây
EVAL_PERIODS=1
REGION="${AWS_DEFAULT_REGION:-ap-southeast-1}"
ADD_OK_ACTION=true

usage() {
    echo "Usage: $0 --instance-id <i-xxx> --sns-topic-arn <arn:aws:sns:...>"
    echo ""
    echo "Options:"
    echo "  --instance-id     EC2 Instance ID (bắt buộc)"
    echo "  --sns-topic-arn   SNS Topic ARN (bắt buộc)"
    echo "  --alarm-name      Tên alarm (default: High-CPU-Alert)"
    echo "  --threshold       Ngưỡng CPU % (default: 80)"
    echo "  --period          Chu kỳ tính giây (default: 300)"
    echo "  --region          AWS Region (default: ap-southeast-1)"
    echo "  --no-ok-action    Không gửi email khi CPU trở về bình thường"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --instance-id)    INSTANCE_ID="$2";    shift 2 ;;
        --sns-topic-arn)  SNS_TOPIC_ARN="$2";  shift 2 ;;
        --alarm-name)     ALARM_NAME="$2";     shift 2 ;;
        --threshold)      THRESHOLD="$2";      shift 2 ;;
        --period)         PERIOD="$2";         shift 2 ;;
        --region)         REGION="$2";         shift 2 ;;
        --no-ok-action)   ADD_OK_ACTION=false;  shift ;;
        -h|--help)        usage ;;
        *) log_error "Unknown argument: $1" ;;
    esac
done

# Nếu chưa có SNS ARN, thử đọc từ file tạm
if [ -z "$SNS_TOPIC_ARN" ] && [ -f /tmp/sns-topic-arn.txt ]; then
    SNS_TOPIC_ARN=$(cat /tmp/sns-topic-arn.txt)
    log_info "Đọc SNS Topic ARN từ /tmp/sns-topic-arn.txt: ${SNS_TOPIC_ARN}"
fi

[ -z "$INSTANCE_ID" ]   && log_error "Thiếu --instance-id. Chạy: $0 --help"
[ -z "$SNS_TOPIC_ARN" ] && log_error "Thiếu --sns-topic-arn. Chạy create-sns.sh trước."

echo ""
echo "============================================================"
echo "   🚨 CloudWatch Alarm Setup — CPU Alert Lab               "
echo "============================================================"
echo ""
echo "  Alarm Name:    ${ALARM_NAME}"
echo "  Instance ID:   ${INSTANCE_ID}"
echo "  Threshold:     CPU > ${THRESHOLD}%"
echo "  Period:        ${PERIOD}s ($(( PERIOD / 60 )) phút)"
echo "  Evaluation:    ${EVAL_PERIODS} out of ${EVAL_PERIODS} datapoints"
echo "  SNS Topic:     ${SNS_TOPIC_ARN}"
echo ""

# ── Build OK actions array ────────────────────────────────────────────────────
if [ "$ADD_OK_ACTION" = true ]; then
    OK_ACTIONS="--ok-actions ${SNS_TOPIC_ARN}"
    log_info "✅ OK state notification: BẬT (nhận email khi CPU trở về bình thường)"
else
    OK_ACTIONS=""
    log_warn "OK state notification: TẮT"
fi

# ── Bước 2+3+4: Tạo CloudWatch Alarm ─────────────────────────────────────────
log_info "Tạo CloudWatch Alarm '${ALARM_NAME}'..."

aws cloudwatch put-metric-alarm \
    --alarm-name "${ALARM_NAME}" \
    --alarm-description "Cảnh báo khi CPU > ${THRESHOLD}% trong $(( PERIOD / 60 )) phút liên tiếp" \
    --metric-name CPUUtilization \
    --namespace AWS/EC2 \
    --statistic Average \
    --period "${PERIOD}" \
    --evaluation-periods "${EVAL_PERIODS}" \
    --datapoints-to-alarm "${EVAL_PERIODS}" \
    --threshold "${THRESHOLD}" \
    --comparison-operator GreaterThanThreshold \
    --treat-missing-data notBreaching \
    --dimensions "Name=InstanceId,Value=${INSTANCE_ID}" \
    --alarm-actions "${SNS_TOPIC_ARN}" \
    ${OK_ACTIONS} \
    --region "${REGION}"

log_success "Alarm đã tạo thành công!"

# ── Kiểm tra trạng thái hiện tại ─────────────────────────────────────────────
log_info "Kiểm tra trạng thái alarm..."
sleep 2

STATE=$(aws cloudwatch describe-alarms \
    --alarm-names "${ALARM_NAME}" \
    --region "${REGION}" \
    --query "MetricAlarms[0].StateValue" \
    --output text)

echo ""
echo "============================================================"
log_success "🎉 Alarm đã được tạo!"
echo ""
echo "  State hiện tại: ${STATE}"
echo ""
echo "  🔍 Xem alarm trên Console:"
echo "  https://console.aws.amazon.com/cloudwatch/home?region=${REGION}#alarmsV2:alarm/${ALARM_NAME}"
echo ""
echo "  🧪 Test ngay: bash stress-cpu.sh (chạy trên EC2)"
echo "  🔎 Verify:    bash verify-lab.sh --alarm-name ${ALARM_NAME}"
echo "============================================================"
echo ""
