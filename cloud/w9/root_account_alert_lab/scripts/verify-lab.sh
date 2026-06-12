#!/bin/bash
# =============================================================================
# verify-lab.sh — Kiểm tra toàn bộ 4 bước setup Root Account Alert Lab
# Session 05: Alert on AWS Root Account Login
# =============================================================================

set -uo pipefail

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
PASS="${GREEN}[PASS]${NC}"; FAIL="${RED}[FAIL]${NC}"; WARN="${YELLOW}[WARN]${NC}"; INFO="${BLUE}[INFO]${NC}"

TRAIL_NAME="security-audit-trail"
LOG_GROUP="/aws/cloudtrail/security-trail"
FILTER_NAME="RootAccountLoginFilter"
ALARM_NAME="RootAccountLogin-Alert"
TOPIC_NAME="root-login-security-alerts"
REGION="${AWS_DEFAULT_REGION:-ap-southeast-1}"
ERRORS=0

while [[ $# -gt 0 ]]; do
    case $1 in
        --region) REGION="$2"; shift 2 ;;
        *) shift ;;
    esac
done

echo ""
echo "============================================================"
echo "   🔍 Lab Verification — Root Account Login Alert          "
echo "============================================================"
echo ""

# ── Bước 1: CloudTrail ────────────────────────────────────────────────────────
echo -e "${INFO} [1/5] Kiểm tra CloudTrail Trail..."

TRAIL_STATUS=$(aws cloudtrail get-trail-status \
    --name "$TRAIL_NAME" \
    --region "$REGION" \
    --query "{Logging:IsLogging,LastDelivery:LatestDeliveryAttemptTime}" \
    --output json 2>/dev/null || echo '{"Logging":false}')

IS_LOGGING=$(echo "$TRAIL_STATUS" | python3 -c "import sys,json; print(json.load(sys.stdin).get('Logging',False))" 2>/dev/null || echo "False")

if [ "$IS_LOGGING" = "True" ]; then
    echo -e "${PASS} CloudTrail '${TRAIL_NAME}' đang ACTIVE và ghi logs"
else
    echo -e "${FAIL} CloudTrail '${TRAIL_NAME}' không tìm thấy hoặc chưa bật"
    ERRORS=$((ERRORS + 1))
fi

# ── Bước 1b: CloudWatch Logs integration ─────────────────────────────────────
CW_LOG=$(aws cloudtrail describe-trails \
    --query "trailList[?Name=='${TRAIL_NAME}'].CloudWatchLogsLogGroupArn" \
    --output text 2>/dev/null || echo "")

if [ -n "$CW_LOG" ] && [ "$CW_LOG" != "None" ]; then
    echo -e "${PASS} CloudTrail → CloudWatch Logs integration: BẬT"
    echo "         Log Group: ${CW_LOG}"
else
    echo -e "${FAIL} CloudTrail chưa gửi logs tới CloudWatch!"
    ERRORS=$((ERRORS + 1))
fi

# ── Bước 2: Metric Filter ─────────────────────────────────────────────────────
echo ""
echo -e "${INFO} [2/5] Kiểm tra CloudWatch Metric Filter..."

FILTER=$(aws logs describe-metric-filters \
    --log-group-name "$LOG_GROUP" \
    --filter-name-prefix "$FILTER_NAME" \
    --region "$REGION" \
    --query "metricFilters[0].{Name:filterName,Pattern:filterPattern,Metric:metricTransformations[0].metricName}" \
    --output json 2>/dev/null || echo "null")

if [ "$FILTER" != "null" ] && echo "$FILTER" | grep -q "Root"; then
    echo -e "${PASS} Metric Filter tồn tại và có pattern Root"
    METRIC=$(echo "$FILTER" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('Metric','?'))" 2>/dev/null || echo "?")
    echo "         Metric: ${METRIC}"
else
    echo -e "${FAIL} Metric Filter '${FILTER_NAME}' không tìm thấy hoặc sai pattern"
    ERRORS=$((ERRORS + 1))
fi

# ── Bước 3: CloudWatch Alarm ──────────────────────────────────────────────────
echo ""
echo -e "${INFO} [3/5] Kiểm tra CloudWatch Alarm..."

ALARM=$(aws cloudwatch describe-alarms \
    --alarm-names "$ALARM_NAME" \
    --region "$REGION" \
    --query "MetricAlarms[0].{State:StateValue,Threshold:Threshold,Namespace:Namespace,Metric:MetricName}" \
    --output json 2>/dev/null || echo "null")

if [ "$ALARM" != "null" ] && echo "$ALARM" | grep -q "Security"; then
    STATE=$(echo "$ALARM" | python3 -c "import sys,json; print(json.load(sys.stdin).get('State','?'))" 2>/dev/null || echo "?")
    THRESHOLD=$(echo "$ALARM" | python3 -c "import sys,json; print(json.load(sys.stdin).get('Threshold','?'))" 2>/dev/null || echo "?")
    echo -e "${PASS} Alarm '${ALARM_NAME}' tồn tại"
    echo "         State: ${STATE} | Threshold: >= ${THRESHOLD}"
else
    echo -e "${FAIL} Alarm '${ALARM_NAME}' không tìm thấy"
    ERRORS=$((ERRORS + 1))
fi

# ── Bước 4: SNS Topic ─────────────────────────────────────────────────────────
echo ""
echo -e "${INFO} [4/5] Kiểm tra SNS Topic..."

TOPIC_ARN=$(aws sns list-topics \
    --region "$REGION" \
    --query "Topics[?contains(TopicArn,'${TOPIC_NAME}')].TopicArn | [0]" \
    --output text 2>/dev/null || echo "None")

if [ "$TOPIC_ARN" != "None" ] && [ -n "$TOPIC_ARN" ]; then
    echo -e "${PASS} SNS Topic: ${TOPIC_ARN}"

    # Kiểm tra subscription
    CONFIRMED=$(aws sns list-subscriptions-by-topic \
        --topic-arn "$TOPIC_ARN" \
        --region "$REGION" \
        --query "Subscriptions[?SubscriptionArn!='PendingConfirmation'].{Protocol:Protocol,Endpoint:Endpoint}" \
        --output table 2>/dev/null)

    PENDING_COUNT=$(aws sns list-subscriptions-by-topic \
        --topic-arn "$TOPIC_ARN" \
        --region "$REGION" \
        --query "length(Subscriptions[?SubscriptionArn=='PendingConfirmation'])" \
        --output text 2>/dev/null || echo "0")

    if [ "$PENDING_COUNT" -gt "0" ] 2>/dev/null; then
        echo -e "${WARN} ${PENDING_COUNT} subscription đang PENDING CONFIRMATION"
        echo "         ⚠️  Check email và click 'Confirm subscription'!"
    fi
    echo "$CONFIRMED"
else
    echo -e "${FAIL} SNS Topic '${TOPIC_NAME}' không tìm thấy"
    ERRORS=$((ERRORS + 1))
fi

# ── Bước 5: End-to-end test ───────────────────────────────────────────────────
echo ""
echo -e "${INFO} [5/5] End-to-end connectivity (Alarm → SNS)..."

ALARM_ACTIONS=$(aws cloudwatch describe-alarms \
    --alarm-names "$ALARM_NAME" \
    --region "$REGION" \
    --query "MetricAlarms[0].AlarmActions" \
    --output text 2>/dev/null || echo "")

if echo "$ALARM_ACTIONS" | grep -q "sns"; then
    echo -e "${PASS} Alarm có SNS action kết nối đúng"
else
    echo -e "${FAIL} Alarm không có SNS action!"
    ERRORS=$((ERRORS + 1))
fi

# ── Kết quả ───────────────────────────────────────────────────────────────────
echo ""
echo "============================================================"
if [ "$ERRORS" -eq 0 ]; then
    echo -e "${GREEN}✅ Tất cả kiểm tra PASSED — Security monitoring đang hoạt động!${NC}"
    echo ""
    echo "  🧪 Test không cần root login:"
    echo "     bash test-metric-filter.sh"
else
    echo -e "${RED}❌ ${ERRORS} kiểm tra FAILED${NC}"
    echo ""
    echo "  Thứ tự chạy lại:"
    echo "    1. bash setup-cloudtrail.sh"
    echo "    2. bash create-metric-filter.sh"
    echo "    3. bash create-sns.sh --email your@email.com"
    echo "    4. bash create-alarm.sh"
fi
echo "============================================================"
echo ""

exit $ERRORS
