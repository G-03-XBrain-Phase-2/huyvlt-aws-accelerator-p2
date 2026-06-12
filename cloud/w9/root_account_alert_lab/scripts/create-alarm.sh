#!/bin/bash
# =============================================================================
# create-alarm.sh — Bước 3: Tạo CloudWatch Alarm cho RootAccountLoginCount
# Trigger ngay khi có >= 1 root login trong bất kỳ 5 phút nào
# Session 05: Alert on AWS Root Account Login
# =============================================================================

set -euo pipefail

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log_info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_success() { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

ALARM_NAME="RootAccountLogin-Alert"
SNS_TOPIC_ARN=""
METRIC_NAME="RootAccountLoginCount"
METRIC_NAMESPACE="Security"
REGION="${AWS_DEFAULT_REGION:-ap-southeast-1}"

usage() {
    echo "Usage: $0 --sns-topic-arn <arn:aws:sns:...> [--alarm-name <name>]"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --sns-topic-arn) SNS_TOPIC_ARN="$2"; shift 2 ;;
        --alarm-name)    ALARM_NAME="$2";    shift 2 ;;
        --region)        REGION="$2";        shift 2 ;;
        -h|--help)       usage ;;
        *) shift ;;
    esac
done

# Đọc ARN từ file tạm nếu có
if [ -z "$SNS_TOPIC_ARN" ] && [ -f /tmp/security-sns-topic-arn.txt ]; then
    SNS_TOPIC_ARN=$(cat /tmp/security-sns-topic-arn.txt)
    log_info "Đọc SNS ARN từ file tạm: ${SNS_TOPIC_ARN}"
fi

[ -z "$SNS_TOPIC_ARN" ] && log_error "Thiếu --sns-topic-arn. Chạy create-sns.sh trước."

echo ""
echo "============================================================"
echo "   🚨 CloudWatch Alarm — Root Login Alert                  "
echo "============================================================"
echo ""
echo "  Alarm:     ${ALARM_NAME}"
echo "  Metric:    ${METRIC_NAMESPACE}/${METRIC_NAME}"
echo "  Threshold: >= 1 (BẤT KỲ root login nào)"
echo "  Period:    300s (5 phút)"
echo "  SNS:       ${SNS_TOPIC_ARN}"
echo ""

# ── Tạo CloudWatch Alarm ──────────────────────────────────────────────────────
log_info "Tạo Alarm '${ALARM_NAME}'..."

aws cloudwatch put-metric-alarm \
    --alarm-name "${ALARM_NAME}" \
    --alarm-description "🚨 SECURITY ALERT: Root account đã được sử dụng! Kiểm tra ngay." \
    --namespace "${METRIC_NAMESPACE}" \
    --metric-name "${METRIC_NAME}" \
    --statistic Sum \
    --period 300 \
    --evaluation-periods 1 \
    --datapoints-to-alarm 1 \
    --threshold 1 \
    --comparison-operator GreaterThanOrEqualToThreshold \
    --treat-missing-data notBreaching \
    --alarm-actions "${SNS_TOPIC_ARN}" \
    --ok-actions "${SNS_TOPIC_ARN}" \
    --region "${REGION}"

log_success "Alarm đã tạo!"

# ── Kiểm tra state ────────────────────────────────────────────────────────────
sleep 2
STATE=$(aws cloudwatch describe-alarms \
    --alarm-names "${ALARM_NAME}" \
    --region "$REGION" \
    --query "MetricAlarms[0].StateValue" \
    --output text 2>/dev/null || echo "UNKNOWN")

echo ""
echo "============================================================"
log_success "✅ Bước 3 hoàn tất!"
echo ""
echo "  Alarm State:  ${STATE}"
echo "  (INSUFFICIENT_DATA là bình thường — alarm sẽ chuyển OK"
echo "   khi CloudTrail bắt đầu gửi data, hoặc ngay sau khi test)"
echo ""
echo "  🧪 Test ngay (không cần login root thật):"
echo "    bash test-metric-filter.sh"
echo "    # hoặc:"
echo "    aws cloudwatch put-metric-data \\"
echo "        --namespace Security \\"
echo "        --metric-name RootAccountLoginCount \\"
echo "        --value 1"
echo ""
echo "  🔍 Console:"
echo "    https://console.aws.amazon.com/cloudwatch/home?region=${REGION}#alarmsV2:alarm/${ALARM_NAME}"
echo "============================================================"
echo ""
