# 🚨 Lab: CPU Alarm → Email Alert via SNS

> **Session 03 — Mastering AWS System Monitoring | TechX Training**

**Scenario:** Gửi email cảnh báo tự động khi CPU của EC2 vượt quá **80%** trong **5 phút liên tiếp** thông qua Amazon SNS.

---

## 🎯 Mục Tiêu Lab

Sau khi hoàn thành bài lab, bạn sẽ có thể:

- [x] Tạo SNS Topic (Standard) và thêm Email Subscription
- [x] Tạo CloudWatch Alarm giám sát metric `CPUUtilization`
- [x] Cấu hình điều kiện cảnh báo: CPU > 80%, Period 5 phút
- [x] Kết nối Alarm với SNS để gửi email tự động
- [x] Test cảnh báo bằng cách stress CPU và xác minh email nhận được

---

## 🏗️ Kiến Trúc Tổng Quan

```
┌────────────────────────────────────────────────────────┐
│                    EC2 Instance                        │
│                                                        │
│   CPU Usage ──────────────────────────────────────►   │
│   (CPUUtilization metric gửi tự động 1 phút/lần)      │
└──────────────────────┬─────────────────────────────────┘
                       │
                       ▼
        ┌──────────────────────────────┐
        │     Amazon CloudWatch        │
        │                              │
        │  Alarm: "High-CPU-Alert"     │
        │  ┌───────────────────────┐   │
        │  │ Metric: CPUUtilization│   │
        │  │ Threshold: > 80%      │   │
        │  │ Period: 5 minutes     │   │
        │  │ Evaluation: 1/1 dp    │   │
        │  └───────────┬───────────┘   │
        │              │ ALARM state   │
        └──────────────┼───────────────┘
                       │
                       ▼
        ┌──────────────────────────────┐
        │       Amazon SNS             │
        │                              │
        │  Topic: "cpu-alert-topic"    │
        │  ┌────────────────────────┐  │
        │  │ Subscription: Email    │  │
        │  │ → your@email.com       │  │
        │  └────────────────────────┘  │
        └──────────────────────────────┘
                       │
                       ▼
           📧 Email Alert Delivered!
```

---

## 📋 Prerequisites

| Yêu cầu | Chi tiết |
|---------|---------|
| EC2 Instance | Đang chạy (bất kỳ OS) |
| IAM Permission | `cloudwatch:PutMetricAlarm`, `sns:CreateTopic`, `sns:Subscribe` |
| Email | Địa chỉ email hợp lệ để nhận cảnh báo |
| AWS Region | Thống nhất 1 region cho tất cả resources |

---

## 🚀 Các Bước Thực Hiện

### Bước 1: Tạo SNS Topic & Subscription

**Qua AWS Console:**
1. Vào **SNS** → **Topics** → **Create topic**
2. Type: **Standard**
3. Name: `cpu-alert-topic`
4. Click **Create topic**
5. Sau khi tạo xong → **Create subscription**:
   - Protocol: **Email**
   - Endpoint: `your@email.com`
6. Vào email → Click **"Confirm subscription"** trong email từ AWS

**Qua AWS CLI (xem `scripts/create-sns.sh`):**
```bash
bash scripts/create-sns.sh --email your@email.com
```

> ⚠️ **Bắt buộc:** Phải xác nhận subscription qua email trước khi alarm có thể gửi được!

---

### Bước 2: Tạo CloudWatch Alarm

**Qua AWS Console:**
1. Vào **CloudWatch** → **Alarms** → **Create alarm**
2. Click **Select metric**
3. Chọn: **EC2** → **Per-Instance Metrics** → **CPUUtilization**
4. Chọn Instance ID của EC2 cần monitor → **Select metric**

**Qua AWS CLI:**
```bash
# Lấy danh sách EC2 instances
aws ec2 describe-instances --query \
    'Reservations[].Instances[].[InstanceId,Tags[?Key==`Name`].Value|[0],State.Name]' \
    --output table
```

---

### Bước 3: Cấu Hình Alarm Conditions

| Tham số | Giá trị |
|--------|---------|
| Metric | `CPUUtilization` |
| Statistic | `Average` |
| Condition | **Greater than** `80` |
| Period | `300` seconds (5 phút) |
| Evaluation periods | `1` |
| Datapoints to alarm | `1 out of 1` |

**Qua Console:**
- Conditions: **Greater than** → `80`
- Period: `5 minutes`
- Datapoints to alarm: `1 out of 1`

---

### Bước 4: Set SNS Notification Action

**Qua Console:**
1. Section **Notification**:
   - Alarm state trigger: **In alarm**
   - Send notification to: chọn `cpu-alert-topic`
2. (Tuỳ chọn) Thêm notification cho **OK state** (recovery alert):
   - Click **Add notification**
   - Trigger: **OK**
   - SNS Topic: `cpu-alert-topic`
3. Đặt tên Alarm: `High-CPU-Alert`
4. Click **Create alarm**

**Qua AWS CLI (xem `scripts/create-alarm.sh`):**
```bash
bash scripts/create-alarm.sh \
    --instance-id i-xxxxxxxxxxxxxxxxx \
    --sns-topic-arn arn:aws:sns:ap-southeast-1:123456789:cpu-alert-topic
```

---

## 🧪 Test & Xác Minh

### Test 1: Stress CPU để trigger alarm

```bash
# SSH vào EC2, chạy lệnh stress
# Amazon Linux 2:
sudo amazon-linux-extras install epel -y
sudo yum install stress -y

# Ubuntu:
sudo apt-get install stress -y

# Stress CPU trong 10 phút (đủ để trigger alarm)
stress --cpu $(nproc) --timeout 600
```

### Test 2: Xem Alarm State thay đổi

```bash
# Theo dõi alarm state real-time
watch -n 30 'aws cloudwatch describe-alarms \
    --alarm-names "High-CPU-Alert" \
    --query "MetricAlarms[0].{State:StateValue,Reason:StateReason}" \
    --output table'
```

### Test 3: Kiểm tra email

Sau ~5 phút CPU > 80%, bạn sẽ nhận email với nội dung:
```
Subject: ALARM: "High-CPU-Alert" in Asia Pacific (Singapore)

You are receiving this email because your Amazon CloudWatch Alarm
"High-CPU-Alert" in the Asia Pacific (Singapore) region has entered
the ALARM state...

Threshold: CPUUtilization > 80.0 for 1 datapoints within 5 minutes
```

### Test 4: Dùng script verify tự động

```bash
bash scripts/verify-lab.sh --alarm-name High-CPU-Alert
```

---

## 📁 Cấu Trúc Thư Mục

```
cpu_alarm_sns_lab/
├── README.md                    # Tài liệu chính (file này)
├── configs/
│   └── alarm-config.json        # Cấu hình alarm dạng JSON (tham khảo)
├── scripts/
│   ├── create-sns.sh            # Tạo SNS Topic + Email Subscription
│   ├── create-alarm.sh          # Tạo CloudWatch Alarm
│   ├── stress-cpu.sh            # Stress test CPU để trigger alarm
│   └── verify-lab.sh            # Kiểm tra toàn bộ lab setup
├── terraform/
│   ├── main.tf                  # SNS Topic + CloudWatch Alarm + EC2
│   ├── variables.tf
│   └── outputs.tf
└── docs/
    ├── alarm-states.md          # Giải thích các trạng thái Alarm
    └── sns-troubleshooting.md   # Xử lý sự cố SNS email
```

---

## 🔧 Troubleshooting Nhanh

| Vấn đề | Nguyên nhân | Giải pháp |
|--------|------------|-----------|
| Không nhận được email | Chưa confirm subscription | Check email, click "Confirm subscription" |
| Alarm mãi ở `INSUFFICIENT_DATA` | EC2 chưa gửi metrics | Đợi 2-3 phút hoặc check instance đang chạy |
| Alarm không trigger dù CPU cao | Sai Instance ID | Kiểm tra lại InstanceId trong alarm config |
| Email vào spam | Sender là `no-reply@sns.amazonaws.com` | Whitelist địa chỉ này |

Xem thêm: [docs/sns-troubleshooting.md](docs/sns-troubleshooting.md)

---

## 📚 Tài Liệu Tham Khảo

- [AWS CloudWatch Alarms](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/AlarmThatSendsEmail.html)
- [Amazon SNS Email Subscription](https://docs.aws.amazon.com/sns/latest/dg/sns-email-notifications.html)
- [EC2 CPUUtilization Metric](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/viewing_metrics_with_cloudwatch.html)
