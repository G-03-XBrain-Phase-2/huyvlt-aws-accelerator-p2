#!/bin/bash
# =============================================================================
# create-sns.sh — Bước 4: Tạo SNS Topic với Email + SMS Subscription
# Session 05: Alert on AWS Root Account Login
# =============================================================================

set -euo pipefail

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log_info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_success() { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

TOPIC_NAME="root-login-security-alerts"
EMAIL=""
PHONE=""
REGION="${AWS_DEFAULT_REGION:-ap-southeast-1}"

usage() {
    echo "Usage: $0 --email <email> [--phone <+84xxxxxxxxx>] [--region <region>]"
    echo ""
    echo "  --email   Email nhận cảnh báo (bắt buộc)"
    echo "  --phone   Số điện thoại SMS, định dạng E.164: +84xxxxxxxxx (tuỳ chọn)"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --email)      EMAIL="$2";      shift 2 ;;
        --phone)      PHONE="$2";      shift 2 ;;
        --topic-name) TOPIC_NAME="$2"; shift 2 ;;
        --region)     REGION="$2";     shift 2 ;;
        -h|--help)    usage ;;
        *) shift ;;
    esac
done

[ -z "$EMAIL" ] && log_error "Thiếu --email. Chạy: $0 --email security@yourteam.com"

echo ""
echo "============================================================"
echo "   📣 SNS Topic Setup — Security Alert Channel             "
echo "============================================================"
echo ""

# ── Tạo SNS Topic ────────────────────────────────────────────────────────────
log_info "Tạo SNS Topic: ${TOPIC_NAME}"

TOPIC_ARN=$(aws sns create-topic \
    --name "$TOPIC_NAME" \
    --region "$REGION" \
    --attributes DisplayName="AWS Root Login SECURITY ALERT" \
    --query 'TopicArn' \
    --output text)

log_success "Topic ARN: ${TOPIC_ARN}"

# ── Email Subscription ────────────────────────────────────────────────────────
log_info "Thêm Email Subscription: ${EMAIL}"
aws sns subscribe \
    --topic-arn "$TOPIC_ARN" \
    --protocol email \
    --notification-endpoint "$EMAIL" \
    --region "$REGION" > /dev/null

log_warn "📧 Kiểm tra email '${EMAIL}' và click 'Confirm subscription'!"

# ── SMS Subscription (nếu có số điện thoại) ──────────────────────────────────
if [ -n "$PHONE" ]; then
    log_info "Thêm SMS Subscription: ${PHONE}"
    aws sns subscribe \
        --topic-arn "$TOPIC_ARN" \
        --protocol sms \
        --notification-endpoint "$PHONE" \
        --region "$REGION" > /dev/null
    log_success "SMS Subscription đã thêm: ${PHONE}"
else
    log_warn "Không có --phone, bỏ qua SMS subscription."
fi

# ── Lưu ARN ──────────────────────────────────────────────────────────────────
echo "$TOPIC_ARN" > /tmp/security-sns-topic-arn.txt

echo ""
echo "============================================================"
log_success "✅ SNS Topic đã sẵn sàng!"
echo ""
echo "  Topic ARN: ${TOPIC_ARN}"
echo ""
log_warn "⚠️  QUAN TRỌNG: Confirm email subscription trước khi chạy bước tiếp!"
echo ""
echo "  ▶ Bước tiếp theo (sau khi confirm email):"
echo "    bash create-alarm.sh --sns-topic-arn ${TOPIC_ARN}"
echo "============================================================"
echo ""
