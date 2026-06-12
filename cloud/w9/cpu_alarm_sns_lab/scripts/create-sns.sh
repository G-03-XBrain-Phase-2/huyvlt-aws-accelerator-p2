#!/bin/bash
# =============================================================================
# create-sns.sh — Tạo SNS Topic (Standard) và Email Subscription
# Session 03: CPU Alarm → Email Alert via SNS
# =============================================================================

set -euo pipefail

# ── Màu sắc ──────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log_info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_success() { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

# ── Giá trị mặc định ─────────────────────────────────────────────────────────
TOPIC_NAME="cpu-alert-topic"
EMAIL=""
REGION="${AWS_DEFAULT_REGION:-ap-southeast-1}"

# ── Parse arguments ───────────────────────────────────────────────────────────
usage() {
    echo "Usage: $0 --email <your@email.com> [--topic-name <name>] [--region <region>]"
    echo ""
    echo "Options:"
    echo "  --email       Email nhận cảnh báo (bắt buộc)"
    echo "  --topic-name  Tên SNS Topic (default: cpu-alert-topic)"
    echo "  --region      AWS Region (default: ap-southeast-1)"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --email)       EMAIL="$2";      shift 2 ;;
        --topic-name)  TOPIC_NAME="$2"; shift 2 ;;
        --region)      REGION="$2";     shift 2 ;;
        -h|--help)     usage ;;
        *) log_error "Unknown argument: $1" ;;
    esac
done

[ -z "$EMAIL" ] && log_error "Thiếu --email. Chạy: $0 --email your@email.com"

echo ""
echo "============================================================"
echo "   📧 SNS Topic Setup — CPU Alarm Lab                      "
echo "============================================================"
echo ""

# ── Bước 1: Tạo SNS Topic ─────────────────────────────────────────────────────
log_info "Bước 1: Tạo SNS Topic '${TOPIC_NAME}' (Standard)..."

TOPIC_ARN=$(aws sns create-topic \
    --name "$TOPIC_NAME" \
    --region "$REGION" \
    --query 'TopicArn' \
    --output text)

log_success "SNS Topic đã tạo:"
echo "         ARN: ${TOPIC_ARN}"

# ── Bước 2: Thêm Email Subscription ──────────────────────────────────────────
log_info "Bước 2: Thêm Email Subscription cho: ${EMAIL}"

SUBSCRIPTION_ARN=$(aws sns subscribe \
    --topic-arn "$TOPIC_ARN" \
    --protocol email \
    --notification-endpoint "$EMAIL" \
    --region "$REGION" \
    --query 'SubscriptionArn' \
    --output text)

log_success "Subscription đã tạo: ${SUBSCRIPTION_ARN}"

# ── Bước 3: Lưu ARN để dùng cho script tiếp theo ─────────────────────────────
echo "$TOPIC_ARN" > /tmp/sns-topic-arn.txt
log_info "Topic ARN đã lưu vào /tmp/sns-topic-arn.txt"

# ── Kết quả ───────────────────────────────────────────────────────────────────
echo ""
echo "============================================================"
log_success "✅ SNS Topic đã được tạo thành công!"
echo ""
echo "  📌 Topic ARN:  ${TOPIC_ARN}"
echo "  📧 Email:      ${EMAIL}"
echo ""
log_warn "⚠️  QUAN TRỌNG: Kiểm tra email '${EMAIL}' và click"
log_warn "   'Confirm subscription' để kích hoạt subscription!"
echo ""
echo "  Sau khi confirm, chạy tiếp:"
echo "  bash create-alarm.sh \\"
echo "      --instance-id <EC2_INSTANCE_ID> \\"
echo "      --sns-topic-arn ${TOPIC_ARN}"
echo "============================================================"
echo ""
