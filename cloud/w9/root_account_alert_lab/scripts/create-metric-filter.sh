#!/bin/bash
# =============================================================================
# create-metric-filter.sh — Bước 2: Tạo CloudWatch Metric Filter
# Pattern: { $.userIdentity.type = "Root" && $.eventType != "AwsServiceEvent" }
# Session 05: Alert on AWS Root Account Login
# =============================================================================

set -euo pipefail

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log_info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_success() { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

# ── Giá trị mặc định ─────────────────────────────────────────────────────────
LOG_GROUP="/aws/cloudtrail/security-trail"
FILTER_NAME="RootAccountLoginFilter"
METRIC_NAME="RootAccountLoginCount"
METRIC_NAMESPACE="Security"
REGION="${AWS_DEFAULT_REGION:-ap-southeast-1}"

# Filter pattern chính xác từ slide
FILTER_PATTERN='{ $.userIdentity.type = "Root" && $.eventType != "AwsServiceEvent" }'

usage() {
    echo "Usage: $0 [--log-group <name>] [--region <region>]"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --log-group) LOG_GROUP="$2"; shift 2 ;;
        --region)    REGION="$2";    shift 2 ;;
        -h|--help)   usage ;;
        *) shift ;;
    esac
done

# Đọc từ file tạm nếu có
if [ -f /tmp/cloudtrail-log-group.txt ]; then
    SAVED=$(cat /tmp/cloudtrail-log-group.txt)
    LOG_GROUP="${LOG_GROUP:-$SAVED}"
fi

echo ""
echo "============================================================"
echo "   🔍 Metric Filter Setup — Root Login Detection           "
echo "============================================================"
echo ""
echo "  Log Group:    ${LOG_GROUP}"
echo "  Filter Name:  ${FILTER_NAME}"
echo "  Metric:       ${METRIC_NAMESPACE}/${METRIC_NAME}"
echo ""
echo "  Filter Pattern:"
echo "  ${FILTER_PATTERN}"
echo ""

# ── Kiểm tra Log Group tồn tại ───────────────────────────────────────────────
log_info "Kiểm tra Log Group tồn tại..."
EXISTS=$(aws logs describe-log-groups \
    --log-group-name-prefix "$LOG_GROUP" \
    --region "$REGION" \
    --query "logGroups[?logGroupName=='${LOG_GROUP}'].logGroupName" \
    --output text)

if [ -z "$EXISTS" ]; then
    log_error "Log Group '${LOG_GROUP}' không tồn tại. Chạy setup-cloudtrail.sh trước."
fi
log_success "Log Group tồn tại: ${LOG_GROUP}"

# ── Tạo Metric Filter ─────────────────────────────────────────────────────────
log_info "Tạo Metric Filter '${FILTER_NAME}'..."

aws logs put-metric-filter \
    --log-group-name "$LOG_GROUP" \
    --filter-name "$FILTER_NAME" \
    --filter-pattern "$FILTER_PATTERN" \
    --metric-transformations \
        "metricName=${METRIC_NAME},metricNamespace=${METRIC_NAMESPACE},metricValue=1,defaultValue=0,unit=Count" \
    --region "$REGION"

log_success "Metric Filter đã tạo!"

# ── Xác minh ─────────────────────────────────────────────────────────────────
log_info "Xác minh filter..."
aws logs describe-metric-filters \
    --log-group-name "$LOG_GROUP" \
    --filter-name-prefix "$FILTER_NAME" \
    --region "$REGION" \
    --query "metricFilters[0].{FilterName:filterName,Pattern:filterPattern,Metric:metricTransformations[0].metricName,Namespace:metricTransformations[0].metricNamespace}" \
    --output table

# Lưu để dùng cho bước tiếp
echo "${METRIC_NAMESPACE}" > /tmp/metric-namespace.txt
echo "${METRIC_NAME}" > /tmp/metric-name.txt

echo ""
echo "============================================================"
log_success "✅ Bước 2 hoàn tất!"
echo ""
echo "  Custom Metric sẽ xuất hiện tại:"
echo "  CloudWatch → Metrics → ${METRIC_NAMESPACE} → ${METRIC_NAME}"
echo ""
echo "  ▶ Bước tiếp theo:"
echo "    bash create-sns.sh --email your@email.com"
echo "    bash create-alarm.sh --sns-topic-arn <ARN>"
echo "============================================================"
echo ""
