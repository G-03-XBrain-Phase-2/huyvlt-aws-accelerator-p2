#!/bin/bash
# =============================================================================
# create-iam-role.sh — Tạo IAM Role với CloudWatchAgentServerPolicy
# Yêu cầu: AWS CLI đã cấu hình với quyền IAM
# =============================================================================

set -euo pipefail

ROLE_NAME="${1:-EC2-CloudWatch-Role}"
INSTANCE_PROFILE_NAME="${ROLE_NAME}-Profile"

echo "🔐 Tạo IAM Role: ${ROLE_NAME}"

# ── 1. Tạo Trust Policy cho EC2 ──────────────────────────────────────────────
cat > /tmp/ec2-trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# ── 2. Tạo IAM Role ──────────────────────────────────────────────────────────
echo "Tạo IAM Role..."
aws iam create-role \
    --role-name "${ROLE_NAME}" \
    --assume-role-policy-document file:///tmp/ec2-trust-policy.json \
    --description "IAM Role for EC2 to push metrics/logs to CloudWatch" \
    --output json | jq -r '.Role.Arn'

# ── 3. Gắn Policy CloudWatchAgentServerPolicy ────────────────────────────────
echo "Gắn CloudWatchAgentServerPolicy..."
aws iam attach-role-policy \
    --role-name "${ROLE_NAME}" \
    --policy-arn "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"

# ── 4. Tạo Instance Profile ──────────────────────────────────────────────────
echo "Tạo Instance Profile..."
aws iam create-instance-profile \
    --instance-profile-name "${INSTANCE_PROFILE_NAME}"

aws iam add-role-to-instance-profile \
    --instance-profile-name "${INSTANCE_PROFILE_NAME}" \
    --role-name "${ROLE_NAME}"

echo ""
echo "✅ Hoàn tất!"
echo ""
echo "📌 Gắn Instance Profile vào EC2:"
echo "   aws ec2 associate-iam-instance-profile \\"
echo "       --instance-id <INSTANCE_ID> \\"
echo "       --iam-instance-profile Name=${INSTANCE_PROFILE_NAME}"
echo ""
echo "   Hoặc qua Console: EC2 → Instance → Actions → Security → Modify IAM role"

# Dọn dẹp file tạm
rm -f /tmp/ec2-trust-policy.json
