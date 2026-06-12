#!/bin/bash
# =============================================================================
# setup-cloudtrail.sh — Bước 1: Tạo CloudTrail Trail + gửi logs tới CloudWatch
# Session 05: Alert on AWS Root Account Login
# =============================================================================

set -euo pipefail

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log_info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_success() { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

# ── Giá trị mặc định ─────────────────────────────────────────────────────────
TRAIL_NAME="security-audit-trail"
LOG_GROUP="/aws/cloudtrail/security-trail"
REGION="${AWS_DEFAULT_REGION:-ap-southeast-1}"
BUCKET_NAME=""

usage() {
    echo "Usage: $0 [--trail-name <name>] [--log-group <name>] [--bucket <name>] [--region <region>]"
    echo ""
    echo "Options:"
    echo "  --trail-name  Tên CloudTrail (default: security-audit-trail)"
    echo "  --log-group   CloudWatch Log Group (default: /aws/cloudtrail/security-trail)"
    echo "  --bucket      S3 bucket name (default: tự tạo với account ID)"
    echo "  --region      AWS Region (default: ap-southeast-1)"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --trail-name)  TRAIL_NAME="$2"; shift 2 ;;
        --log-group)   LOG_GROUP="$2";  shift 2 ;;
        --bucket)      BUCKET_NAME="$2"; shift 2 ;;
        --region)      REGION="$2";     shift 2 ;;
        -h|--help)     usage ;;
        *) shift ;;
    esac
done

# Lấy Account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Tự tạo bucket name nếu chưa có
if [ -z "$BUCKET_NAME" ]; then
    BUCKET_NAME="cloudtrail-logs-${ACCOUNT_ID}-${REGION}"
fi

echo ""
echo "============================================================"
echo "   🔐 CloudTrail Setup — Root Account Alert Lab            "
echo "============================================================"
echo ""
echo "  Trail Name:  ${TRAIL_NAME}"
echo "  S3 Bucket:   ${BUCKET_NAME}"
echo "  Log Group:   ${LOG_GROUP}"
echo "  Region:      ${REGION}"
echo ""

# ── Kiểm tra Trail đã tồn tại chưa ──────────────────────────────────────────
EXISTING=$(aws cloudtrail describe-trails \
    --query "trailList[?Name=='${TRAIL_NAME}'].Name" \
    --output text 2>/dev/null || echo "")

if [ -n "$EXISTING" ]; then
    log_warn "Trail '${TRAIL_NAME}' đã tồn tại. Bỏ qua tạo mới."
    log_info "Kiểm tra CloudWatch Logs integration..."
else
    # ── Bước 1a: Tạo S3 Bucket ───────────────────────────────────────────────
    log_info "Tạo S3 bucket: ${BUCKET_NAME}"

    # Tạo bucket (us-east-1 không cần LocationConstraint)
    if [ "$REGION" = "us-east-1" ]; then
        aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$REGION" 2>/dev/null || true
    else
        aws s3api create-bucket \
            --bucket "$BUCKET_NAME" \
            --region "$REGION" \
            --create-bucket-configuration "LocationConstraint=${REGION}" 2>/dev/null || true
    fi

    # Block public access
    aws s3api put-public-access-block \
        --bucket "$BUCKET_NAME" \
        --public-access-block-configuration \
            "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

    # Gắn bucket policy cho CloudTrail
    BUCKET_POLICY=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AWSCloudTrailAclCheck",
      "Effect": "Allow",
      "Principal": {"Service": "cloudtrail.amazonaws.com"},
      "Action": "s3:GetBucketAcl",
      "Resource": "arn:aws:s3:::${BUCKET_NAME}"
    },
    {
      "Sid": "AWSCloudTrailWrite",
      "Effect": "Allow",
      "Principal": {"Service": "cloudtrail.amazonaws.com"},
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::${BUCKET_NAME}/AWSLogs/${ACCOUNT_ID}/*",
      "Condition": {
        "StringEquals": {"s3:x-amz-acl": "bucket-owner-full-control"}
      }
    }
  ]
}
EOF
)
    aws s3api put-bucket-policy --bucket "$BUCKET_NAME" --policy "$BUCKET_POLICY"
    log_success "S3 bucket đã sẵn sàng: ${BUCKET_NAME}"

    # ── Bước 1b: Tạo CloudWatch Log Group ───────────────────────────────────
    log_info "Tạo CloudWatch Log Group: ${LOG_GROUP}"
    aws logs create-log-group --log-group-name "$LOG_GROUP" --region "$REGION" 2>/dev/null || true
    aws logs put-retention-policy \
        --log-group-name "$LOG_GROUP" \
        --retention-in-days 90 \
        --region "$REGION"
    log_success "Log Group đã tạo với retention 90 ngày"

    # ── Bước 1c: Tạo IAM Role cho CloudTrail → CloudWatch ────────────────────
    log_info "Tạo IAM Role cho CloudTrail..."

    ROLE_NAME="CloudTrail-CloudWatch-Role"
    TRUST_POLICY=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"Service": "cloudtrail.amazonaws.com"},
    "Action": "sts:AssumeRole"
  }]
}
EOF
)

    aws iam create-role \
        --role-name "$ROLE_NAME" \
        --assume-role-policy-document "$TRUST_POLICY" \
        --output json > /dev/null 2>/dev/null || true

    ROLE_POLICY=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": ["logs:CreateLogStream", "logs:PutLogEvents"],
    "Resource": "arn:aws:logs:${REGION}:${ACCOUNT_ID}:log-group:${LOG_GROUP}:*"
  }]
}
EOF
)
    aws iam put-role-policy \
        --role-name "$ROLE_NAME" \
        --policy-name "CloudTrailToCloudWatchLogs" \
        --policy-document "$ROLE_POLICY" 2>/dev/null || true

    ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"
    log_success "IAM Role: ${ROLE_ARN}"

    # Đợi role propagate
    sleep 10

    # ── Bước 1d: Tạo CloudTrail Trail ───────────────────────────────────────
    log_info "Tạo CloudTrail Trail: ${TRAIL_NAME}"

    LOG_GROUP_ARN="arn:aws:logs:${REGION}:${ACCOUNT_ID}:log-group:${LOG_GROUP}:*"

    aws cloudtrail create-trail \
        --name "$TRAIL_NAME" \
        --s3-bucket-name "$BUCKET_NAME" \
        --include-global-service-events \
        --is-multi-region-trail \
        --enable-log-file-validation \
        --cloud-watch-logs-log-group-arn "$LOG_GROUP_ARN" \
        --cloud-watch-logs-role-arn "$ROLE_ARN" \
        --region "$REGION"

    # Bật logging
    aws cloudtrail start-logging --name "$TRAIL_NAME" --region "$REGION"
    log_success "CloudTrail đang ghi logs!"
fi

# Lưu log group name để dùng tiếp
echo "$LOG_GROUP" > /tmp/cloudtrail-log-group.txt

echo ""
echo "============================================================"
log_success "✅ Bước 1 hoàn tất!"
echo ""
echo "  CloudTrail Trail: ${TRAIL_NAME}"
echo "  CloudWatch Logs:  ${LOG_GROUP}"
echo ""
echo "  ▶ Bước tiếp theo:"
echo "    bash create-metric-filter.sh --log-group ${LOG_GROUP}"
echo "============================================================"
echo ""
