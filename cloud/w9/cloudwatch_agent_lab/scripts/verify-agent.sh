#!/bin/bash
# =============================================================================
# verify-agent.sh — Kiểm tra toàn diện trạng thái CloudWatch Agent
# =============================================================================

set -uo pipefail

# ── Màu sắc ──────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS="${GREEN}[PASS]${NC}"
FAIL="${RED}[FAIL]${NC}"
WARN="${YELLOW}[WARN]${NC}"
INFO="${BLUE}[INFO]${NC}"

ERRORS=0

check() {
    local desc="$1"
    local cmd="$2"

    if eval "$cmd" &>/dev/null; then
        echo -e "${PASS} $desc"
    else
        echo -e "${FAIL} $desc"
        ERRORS=$((ERRORS + 1))
    fi
}

echo ""
echo "============================================================"
echo "   🔍 CloudWatch Agent — Verification Check                "
echo "============================================================"
echo ""

# ── 1. Kiểm tra Agent Installed ──────────────────────────────────────────────
echo -e "${INFO} [1/5] Kiểm tra cài đặt agent..."
check "Binary agent tồn tại" \
    "test -f /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent"
check "Control script tồn tại" \
    "test -f /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl"

# ── 2. Kiểm tra Service Status ───────────────────────────────────────────────
echo ""
echo -e "${INFO} [2/5] Kiểm tra service status..."
check "Service enabled" \
    "systemctl is-enabled amazon-cloudwatch-agent"
check "Service running" \
    "systemctl is-active amazon-cloudwatch-agent"

# ── 3. Kiểm tra Config ───────────────────────────────────────────────────────
echo ""
echo -e "${INFO} [3/5] Kiểm tra configuration..."
CONFIG_PATH="/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json"
CONFIG_PATH_ALT="/opt/aws/amazon-cloudwatch-agent/bin/config.json"

if [ -f "$CONFIG_PATH" ] || [ -f "$CONFIG_PATH_ALT" ]; then
    echo -e "${PASS} Config file tồn tại"
else
    echo -e "${FAIL} Config file không tìm thấy"
    ERRORS=$((ERRORS + 1))
fi

# ── 4. Kiểm tra Agent Status (JSON) ──────────────────────────────────────────
echo ""
echo -e "${INFO} [4/5] Agent status report..."
STATUS_JSON=$(sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -m ec2 -a status 2>/dev/null || echo '{"status":"error"}')

echo "$STATUS_JSON" | python3 -m json.tool 2>/dev/null || echo "$STATUS_JSON"

AGENT_STATUS=$(echo "$STATUS_JSON" | grep -o '"status": *"[^"]*"' | grep -o '"[^"]*"$' | tr -d '"' 2>/dev/null || echo "unknown")

if [ "$AGENT_STATUS" = "running" ]; then
    echo -e "${PASS} Agent status: running"
else
    echo -e "${FAIL} Agent status: ${AGENT_STATUS}"
    ERRORS=$((ERRORS + 1))
fi

# ── 5. Kiểm tra IAM Role ─────────────────────────────────────────────────────
echo ""
echo -e "${INFO} [5/5] Kiểm tra IAM Role..."
IAM_ROLE=$(curl -sf --max-time 5 \
    "http://169.254.169.254/latest/meta-data/iam/security-credentials/" \
    2>/dev/null || echo "")

if [ -n "$IAM_ROLE" ]; then
    echo -e "${PASS} IAM Role attached: ${IAM_ROLE}"
else
    echo -e "${WARN} Không phát hiện IAM Role. Hãy gắn role có CloudWatchAgentServerPolicy."
fi

# ── Kết quả tổng hợp ─────────────────────────────────────────────────────────
echo ""
echo "============================================================"
if [ "$ERRORS" -eq 0 ]; then
    echo -e "${GREEN}✅ Tất cả kiểm tra PASSED — Agent hoạt động bình thường!${NC}"
    echo ""
    echo "📊 Xem metrics tại: CloudWatch → Metrics → All metrics → CWAgent"
    echo "📜 Xem logs tại:    CloudWatch → Log groups → /ec2/app-logs"
else
    echo -e "${RED}❌ ${ERRORS} kiểm tra FAILED — Xem docs/troubleshooting.md để khắc phục.${NC}"
fi
echo "============================================================"
echo ""

exit $ERRORS
