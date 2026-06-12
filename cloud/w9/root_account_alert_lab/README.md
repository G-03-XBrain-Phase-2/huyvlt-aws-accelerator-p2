# 🔐 Lab: Alert on AWS Root Account Login

> **Session 05 — Mastering AWS System Monitoring | TechX Training**

> ⚠️ **Security Best Practice:** _The root account should almost never be used. Alert immediately if it is!_

Bài lab này thiết lập hệ thống cảnh báo **real-time** khi có ai đó đăng nhập vào tài khoản AWS Root — một trong những security best practices quan trọng nhất của AWS.

---

## 🎯 Mục Tiêu Lab

Sau khi hoàn thành, bạn sẽ có thể:

- [x] Bật CloudTrail và gửi logs tới CloudWatch Logs
- [x] Tạo Metric Filter lọc sự kiện đăng nhập Root
- [x] Tạo CloudWatch Alarm trigger ngay khi có **1 lần** Root login
- [x] Gửi cảnh báo tới Security Team qua Email + SMS (SNS)
- [x] (Optional) Trigger Lambda để tự động vô hiệu hoá root credentials

---

## 🏗️ Kiến Trúc Tổng Quan

```
┌─────────────────────────────────────────────────────────────────┐
│                      AWS Management Console                      │
│                                                                  │
│   👤 Root User Login ──────────────────────────────────────►   │
│   (ConsoleLogin event)                                           │
└──────────────────────────┬───────────────────────────────────────┘
                           │
                           ▼
         ┌─────────────────────────────┐
         │        AWS CloudTrail        │  Bước 1
         │  (Ghi lại mọi API call &     │
         │   Console login events)      │
         └──────────────┬──────────────┘
                        │ Gửi logs
                        ▼
         ┌─────────────────────────────┐
         │   CloudWatch Logs Group     │
         │   /aws/cloudtrail/trail     │
         │                             │
         │  ┌──────────────────────┐   │
         │  │   Metric Filter      │   │  Bước 2
         │  │  { $.userIdentity.   │   │
         │  │    type = "Root" &&  │   │
         │  │    $.eventType !=    │   │
         │  │    "AwsServiceEvent"}│   │
         │  │                      │   │
         │  │  → RootLoginCount    │   │
         │  └──────────┬───────────┘   │
         └─────────────┼───────────────┘
                       │ Custom Metric
                       ▼
         ┌─────────────────────────────┐
         │    CloudWatch Alarm         │  Bước 3
         │                             │
         │  RootLoginCount >= 1        │
         │  in any 5-minute period     │
         │  → ALARM immediately        │
         └──────────────┬──────────────┘
                        │ Trigger
                        ▼
         ┌─────────────────────────────┐
         │        Amazon SNS           │  Bước 4
         │                             │
         │  ┌─────────────────────┐    │
         │  │ Email Subscription  │    │
         │  │ → security@team.com │    │
         │  └─────────────────────┘    │
         │  ┌─────────────────────┐    │
         │  │ SMS Subscription    │    │
         │  │ → +84xxxxxxxxx      │    │
         │  └─────────────────────┘    │
         │  ┌─────────────────────┐    │
         │  │ Lambda (Optional)   │    │
         │  │ Auto-disable root   │    │
         │  └─────────────────────┘    │
         └─────────────────────────────┘
```

---

## 📋 Prerequisites

| Yêu cầu | Chi tiết |
|---------|---------|
| IAM Permission | `cloudtrail:*`, `logs:*`, `cloudwatch:*`, `sns:*` |
| AWS Region | Chọn 1 region chính (vd: `ap-southeast-1`) |
| Email/Phone | Để nhận cảnh báo qua SNS |
| CloudTrail chưa bật | Nếu đã có Trail, có thể dùng lại |

> 🔑 **Lưu ý bảo mật:** Bài lab này chỉ cần thiết lập **1 lần** và để chạy mãi mãi như một security control.

---

## 🚀 Các Bước Thực Hiện

### Bước 1: Enable CloudTrail & Gửi Logs tới CloudWatch

**Qua AWS Console:**
1. Vào **CloudTrail** → **Trails** → **Create trail**
2. Trail name: `security-audit-trail`
3. Storage location: Tạo S3 bucket mới hoặc chọn bucket có sẵn
4. Bật **CloudWatch Logs**:
   - Log group name: `/aws/cloudtrail/security-trail`
   - IAM Role: để AWS tạo role mới tự động
5. Click **Create trail**

**Qua AWS CLI:**
```bash
bash scripts/setup-cloudtrail.sh
```

> 📝 CloudTrail cần **IAM Role** để có quyền ghi vào CloudWatch Logs group.

---

### Bước 2: Tạo CloudWatch Metric Filter

Filter Pattern để phát hiện Root login:
```
{ $.userIdentity.type = "Root" && $.eventType != "AwsServiceEvent" }
```

| Tham số | Giá trị |
|--------|---------|
| Filter Pattern | `{ $.userIdentity.type = "Root" && $.eventType != "AwsServiceEvent" }` |
| Metric Name | `RootAccountLoginCount` |
| Namespace | `Security` |
| Metric Value | `1` |
| Default Value | `0` |

**Qua AWS CLI:**
```bash
bash scripts/create-metric-filter.sh \
    --log-group /aws/cloudtrail/security-trail
```

---

### Bước 3: Tạo CloudWatch Alarm

Alarm phải trigger **ngay khi có 1 lần** Root login:

| Tham số | Giá trị |
|--------|---------|
| Metric | `Security/RootAccountLoginCount` |
| Threshold | `>= 1` |
| Period | `300s` (5 phút) |
| Evaluation Periods | `1` |
| Datapoints to Alarm | `1 out of 1` |
| Treat Missing Data | `notBreaching` |

```bash
bash scripts/create-alarm.sh \
    --sns-topic-arn <ARN>
```

---

### Bước 4: Notify via SNS (Email + SMS)

```bash
# Tạo SNS Topic + Email + SMS
bash scripts/create-sns.sh \
    --email security@yourteam.com \
    --phone +84xxxxxxxxx
```

**Optional — Lambda auto-disable root:**
```bash
# Deploy Lambda function để tự động vô hiệu hoá root credentials
bash scripts/deploy-lambda.sh
```

---

## 🧪 Test & Xác Minh

### Test 1: Test Metric Filter (không cần login root)

```bash
# Giả lập event Root login để test filter
bash scripts/test-metric-filter.sh
```

### Test 2: Trigger Alarm thủ công

```bash
# Gửi manual metric để trigger alarm ngay lập tức
aws cloudwatch put-metric-data \
    --namespace Security \
    --metric-name RootAccountLoginCount \
    --value 1 \
    --region ap-southeast-1

# Đợi ~2 phút → kiểm tra email
```

### Test 3: Verify toàn bộ setup

```bash
bash scripts/verify-lab.sh
```

---

## 📁 Cấu Trúc Thư Mục

```
root_account_alert_lab/
├── README.md
├── configs/
│   ├── metric-filter-pattern.json    # Filter pattern + metric config
│   └── alarm-config.json             # CloudWatch alarm parameters
├── scripts/
│   ├── setup-cloudtrail.sh           # Bước 1: CloudTrail + CloudWatch Logs
│   ├── create-metric-filter.sh       # Bước 2: Metric Filter
│   ├── create-alarm.sh               # Bước 3: CloudWatch Alarm
│   ├── create-sns.sh                 # Bước 4: SNS Email + SMS
│   ├── test-metric-filter.sh         # Test filter bằng fake event
│   └── verify-lab.sh                 # Kiểm tra toàn bộ setup
├── lambda/
│   ├── auto-disable-root/
│   │   ├── handler.py                # Lambda tự động disable root
│   │   └── requirements.txt
│   └── deploy.sh                     # Deploy Lambda + gắn SNS trigger
├── terraform/
│   ├── main.tf                       # Toàn bộ infrastructure as code
│   ├── variables.tf
│   └── outputs.tf
└── docs/
    ├── why-protect-root.md           # Lý do bảo vệ root account
    └── security-checklist.md         # AWS Security checklist tham khảo
```

---

## 🔧 Troubleshooting Nhanh

| Vấn đề | Nguyên nhân | Giải pháp |
|--------|------------|-----------|
| CloudTrail không gửi logs | IAM Role thiếu quyền | Xem `docs/why-protect-root.md` mục IAM |
| Metric Filter không match | Sai filter pattern | Test với `scripts/test-metric-filter.sh` |
| Alarm không trigger | Metric chưa có data | Dùng `put-metric-data` để test |
| Không nhận SMS | Số điện thoại sai format | Dùng format E.164: `+84xxxxxxxxx` |

---

## 📚 Tài Liệu Tham Khảo

- [AWS Security Best Practices — Root Account](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html#lock-away-credentials)
- [CloudTrail Log Event Reference](https://docs.aws.amazon.com/awscloudtrail/latest/userguide/cloudtrail-event-reference.html)
- [CloudWatch Metric Filters](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/FilterAndPatternSyntax.html)
- [CIS AWS Benchmark — Control 1.7](https://www.cisecurity.org/benchmark/amazon_web_services)
