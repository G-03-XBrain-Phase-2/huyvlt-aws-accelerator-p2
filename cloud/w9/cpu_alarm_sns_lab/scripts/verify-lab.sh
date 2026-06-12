#!/bin/bash
# =============================================================================
# verify-lab.sh — Xác minh toàn bộ setup của CPU Alarm → SNS Lab
# Chạy trên máy local (cần AWS CLI configured)
# =============================================================================

set -uo pipefail

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
PASS="${GREEN}[PASS]${NC}"; FAIL="${RED}[FAIL]${NC}"; WARN="${YELLOW}[WARN]${NC}"; INFO="${BLUE}[INFO]${NC}"

ALARM_NAME="High-CPU-Alert"
TOPIC_NAME="cpu-alert-topic"
REGION="${AWS_DEFAULT_REGION:-ap-southeast-1}"
ERRORS=0

while [[ $# -gt 0 ]]; do
    case $1 in
        --alarm-name) ALARM_NAME="$2"; shift 2 ;;
        --topic-name) TOPIC_NAME="$2"; shift 2 ;;
        --region)     REGION="$2";     shift 2 ;;
        *) shift ;;
    esac
done

echo ""
echo "============================================================"
echo "   🔍 Lab Verification — CPU Alarm → SNS Email             "
echo "============================================================"
echo ""

# ── 1. Kiểm tra SNS Topic ────────────────────────────────────────────────────
echo -e "${INFO} [1/5] Kiểm tra SNS Topic '${TOPIC_NAME}'..."

TOPIC_ARN=$(aws sns list-topics --region "$REGION" \
    --query "Topics[?contains(TopicArn, '${TOPIC_NAME}')].TopicArn | [0]" \
    --output text 2>/dev/null || echo "None")

if [ "$TOPIC_ARN" != "None" ] && [ -n "$TOPIC_ARN" ]; then
    echo -e "${PASS} SNS Topic tồn tại: ${TOPIC_ARN}"
else
    echo -e "${FAIL} SNS Topic '${TOPIC_NAME}' không tồn tại"
    ERRORS=$((ERRORS + 1))
fi

# ── 2. Kiểm tra Email Subscription đã Confirmed ──────────────────────────────
echo ""
echo -e "${INFO} [2/5] Kiểm tra Email Subscription..."

if [ -n "$TOPIC_ARN" ] && [ "$TOPIC_ARN" != "None" ]; then
    CONFIRMED=$(aws sns list-subscriptions-by-topic \
        --topic-arn "$TOPIC_ARN" \
        --region "$REGION" \
        --query "Subscriptions[?Protocol=='email' && SubscriptionArn!='PendingConfirmation'].SubscriptionArn" \
        --output text 2>/dev/null || echo "")

    PENDING=$(aws sns list-subscriptions-by-topic \
        --topic-arn "$TOPIC_ARN" \
        --region "$REGION" \
        --query "Subscriptions[?SubscriptionArn=='PendingConfirmation'].Endpoint" \
        --output text 2>/dev/null || echo "")

    if [ -n "$CONFIRMED" ]; then
        echo -e "${PASS} Email Subscription đã được xác nhận"
    elif [ -n "$PENDING" ]; then
        echo -e "${WARN} Email subscription PENDING: ${PENDING}"
        echo -e "        ⚠️  Hãy check email và click 'Confirm subscription'!"
        ERRORS=$((ERRORS + 1))
    else
        echo -e "${FAIL} Không có Email Subscription nào"
        ERRORS=$((ERRORS + 1))
    fi
fi

# ── 3. Kiểm tra CloudWatch Alarm ─────────────────────────────────────────────
echo ""
echo -e "${INFO} [3/5] Kiểm tra CloudWatch Alarm '${ALARM_NAME}'..."

ALARM_INFO=$(aws cloudwatch describe-alarms \
    --alarm-names "${ALARM_NAME}" \
    --region "$REGION" \
    --query "MetricAlarms[0].{State:StateValue,Threshold:Threshold,Period:Period,Namespace:Namespace,Metric:MetricName}" \
    --output json 2>/dev/null || echo "null")

if [ "$ALARM_INFO" != "null" ] && [ "$ALARM_INFO" != "[]" ]; then
    STATE=$(echo "$ALARM_INFO" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('State','?'))" 2>/dev/null || echo "?")
    THRESHOLD=$(echo "$ALARM_INFO" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('Threshold','?'))" 2>/dev/null || echo "?")
    PERIOD=$(echo "$ALARM_INFO" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('Period','?'))" 2>/dev/null || echo "?")

    echo -e "${PASS} Alarm tồn tại:"
    echo "        State:     ${STATE}"
    echo "        Threshold: ${THRESHOLD}%"
    echo "        Period:    ${PERIOD}s"
else
    echo -e "${FAIL} Alarm '${ALARM_NAME}' không tìm thấy"
    ERRORS=$((ERRORS + 1))
fi

# ── 4. Kiểm tra Alarm Actions (có SNS không?) ─────────────────────────────────
echo ""
echo -e "${INFO} [4/5] Kiểm tra Alarm Actions → SNS..."

ALARM_ACTIONS=$(aws cloudwatch describe-alarms \
    --alarm-names "${ALARM_NAME}" \
    --region "$REGION" \
    --query "MetricAlarms[0].AlarmActions" \
    --output text 2>/dev/null || echo "")

if echo "$ALARM_ACTIONS" | grep -q "sns"; then
    echo -e "${PASS} Alarm có SNS action: ${ALARM_ACTIONS}"
else
    echo -e "${FAIL} Alarm không có SNS action!"
    ERRORS=$((ERRORS + 1))
fi

# ── 5. Kiểm tra Alarm State hiện tại ─────────────────────────────────────────
echo ""
echo -e "${INFO} [5/5] Alarm State Summary..."

aws cloudwatch describe-alarms \
    --alarm-names "${ALARM_NAME}" \
    --region "$REGION" \
    --query "MetricAlarms[0].{AlarmName:AlarmName,State:StateValue,Reason:StateReason,UpdatedAt:StateUpdatedTimestamp}" \
    --output table 2>/dev/null || true

# ── Kết quả ───────────────────────────────────────────────────────────────────
echo ""
echo "============================================================"
if [ "$ERRORS" -eq 0 ]; then
    echo -e "${GREEN}✅ Tất cả kiểm tra PASSED — Lab setup hoàn chỉnh!${NC}"
    echo ""
    echo "  🧪 Test trigger alarm:"
    echo "     bash stress-cpu.sh        (chạy trên EC2)"
    echo ""
    echo "  📊 Xem trên Console:"
    echo "     https://console.aws.amazon.com/cloudwatch/home?region=${REGION}#alarmsV2:"
else
    echo -e "${RED}❌ ${ERRORS} kiểm tra FAILED${NC}"
    echo ""
    echo "  Xem docs/sns-troubleshooting.md để khắc phục"
fi
echo "============================================================"
echo ""

exit $ERRORS
