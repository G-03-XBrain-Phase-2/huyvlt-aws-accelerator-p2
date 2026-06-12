# 🔧 SNS Troubleshooting — CPU Alarm Lab

## Vấn đề thường gặp khi dùng SNS Email

---

### ❌ Vấn đề 1: Không nhận được email xác nhận subscription

**Triệu chứng:** Tạo subscription xong nhưng không thấy email từ AWS.

**Checklist:**
1. Kiểm tra thư mục **Spam / Junk Mail** — email từ `no-reply@sns.amazonaws.com` hay bị lọc
2. Kiểm tra địa chỉ email nhập đúng chưa
3. Đợi **tối đa 5 phút** — AWS SNS đôi khi gửi chậm

**Kiểm tra trạng thái subscription:**
```bash
aws sns list-subscriptions-by-topic \
    --topic-arn <TOPIC_ARN> \
    --query "Subscriptions[].{Email:Endpoint,Status:SubscriptionArn}" \
    --output table
```

Output:
- `PendingConfirmation` → Chưa confirm, hãy check email
- `arn:aws:sns:...` → Đã confirm thành công

**Gửi lại email xác nhận:**
```bash
# Xoá subscription cũ và tạo lại
aws sns unsubscribe --subscription-arn <SUBSCRIPTION_ARN>
aws sns subscribe --topic-arn <TOPIC_ARN> --protocol email --notification-endpoint <EMAIL>
```

---

### ❌ Vấn đề 2: Alarm trigger nhưng không nhận được email

**Nguyên nhân phổ biến:**

| Nguyên nhân | Kiểm tra |
|-------------|---------|
| Subscription chưa confirm | `SubscriptionArn == PendingConfirmation` |
| Alarm actions sai ARN | `aws cloudwatch describe-alarms --alarm-names "High-CPU-Alert"` |
| SNS Topic bị xoá | `aws sns list-topics` |
| Region không khớp | Alarm và SNS Topic phải cùng region |

**Debug toàn diện:**
```bash
# 1. Xem alarm có actions không
aws cloudwatch describe-alarms \
    --alarm-names "High-CPU-Alert" \
    --query "MetricAlarms[0].{Actions:AlarmActions,OKActions:OKActions}" \
    --output json

# 2. Gửi test message trực tiếp vào SNS (bypass alarm)
aws sns publish \
    --topic-arn <TOPIC_ARN> \
    --message "Test message từ AWS CLI" \
    --subject "CloudWatch Alarm Test"
```

→ Nếu nhận được email test nhưng không nhận từ alarm → Lỗi ở alarm config  
→ Nếu không nhận được cả test → Lỗi ở subscription

---

### ❌ Vấn đề 3: Alarm mãi ở `INSUFFICIENT_DATA`

**Nguyên nhân:**
- EC2 instance đang **stopped** (không gửi CPUUtilization metric)
- Mới tạo alarm, chưa qua 1 evaluation period (đợi 5 phút)
- Sai InstanceId trong Alarm dimensions

**Kiểm tra:**
```bash
# Xem metrics có đang được gửi không
aws cloudwatch get-metric-statistics \
    --namespace AWS/EC2 \
    --metric-name CPUUtilization \
    --dimensions "Name=InstanceId,Value=<INSTANCE_ID>" \
    --start-time $(date -u -d '10 minutes ago' '+%Y-%m-%dT%H:%M:%S') \
    --end-time $(date -u '+%Y-%m-%dT%H:%M:%S') \
    --period 60 \
    --statistics Average \
    --output table
```

---

### ❌ Vấn đề 4: Nhận quá nhiều email (alarm flapping)

**Triệu chứng:** CPU oscillate quanh ngưỡng 80%, cứ vài phút nhận 1 email.

**Giải pháp:** Tăng `evaluation_periods` và `datapoints_to_alarm`:
```bash
aws cloudwatch put-metric-alarm \
    --alarm-name "High-CPU-Alert" \
    --evaluation-periods 3 \
    --datapoints-to-alarm 2 \
    # ... các tham số khác giữ nguyên
```
→ Phải có **2 trong 3 periods** (= 2 trong 3 lần đo × 5 phút = 15 phút) mới trigger.

---

### ❌ Vấn đề 5: Email CPU Recovery không đến

**Kiểm tra OK actions:**
```bash
aws cloudwatch describe-alarms \
    --alarm-names "High-CPU-Alert" \
    --query "MetricAlarms[0].OKActions" \
    --output text
```

Nếu trống, thêm lại:
```bash
aws cloudwatch put-metric-alarm \
    --alarm-name "High-CPU-Alert" \
    --ok-actions "arn:aws:sns:<REGION>:<ACCOUNT>:cpu-alert-topic" \
    # ... các tham số khác giữ nguyên
```

---

## 🔍 Quick Debug One-liner

```bash
# Kiểm tra tất cả cùng lúc
ALARM="High-CPU-Alert"
aws cloudwatch describe-alarms --alarm-names "$ALARM" \
    --query "MetricAlarms[0].{
        State: StateValue,
        Threshold: Threshold,
        Period: Period,
        EvalPeriods: EvaluationPeriods,
        AlarmActions: AlarmActions,
        OKActions: OKActions,
        Reason: StateReason
    }" \
    --output yaml
```
