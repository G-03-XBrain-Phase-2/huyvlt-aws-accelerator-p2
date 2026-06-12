# 🔍 Lab: Installing the CloudWatch Agent on EC2

> **Session 02 — Mastering AWS System Monitoring | TechX Training**

Bài lab này hướng dẫn cài đặt và cấu hình **Amazon CloudWatch Agent** trên EC2 để thu thập metrics hệ thống (RAM, Disk, Custom Metrics) và logs ứng dụng, sau đó đẩy về CloudWatch Dashboard.

---

## 🎯 Mục Tiêu Lab

Sau khi hoàn thành bài lab, bạn sẽ có thể:

- [x] Cài đặt CloudWatch Agent trên EC2 (Amazon Linux 2 & Ubuntu)
- [x] Chạy Configuration Wizard để tạo file cấu hình
- [x] Gắn IAM Role `CloudWatchAgentServerPolicy` vào EC2
- [x] Thu thập custom metrics: RAM usage, Disk I/O
- [x] Đẩy application logs lên CloudWatch Logs
- [x] Xác minh trạng thái Agent và xem metrics trên Console

---

## 🏗️ Kiến Trúc Tổng Quan

```
┌──────────────────────────────────────────────┐
│                 EC2 Instance                  │
│                                              │
│  ┌────────────────────────────────────────┐  │
│  │        CloudWatch Agent                │  │
│  │  ┌──────────────┐  ┌───────────────┐  │  │
│  │  │ Metrics      │  │  Logs         │  │  │
│  │  │ - CPU        │  │  - /var/log/  │  │  │
│  │  │ - RAM *      │  │  - app.log    │  │  │
│  │  │ - Disk *     │  │  - syslog     │  │  │
│  │  │ - Network    │  │               │  │  │
│  │  └──────┬───────┘  └──────┬────────┘  │  │
│  └─────────┼────────────────┼────────────┘  │
│            │ IAM Role        │               │
│            │ CloudWatchAgent │               │
│            │ ServerPolicy    │               │
└────────────┼────────────────┼───────────────┘
             │                │
             ▼                ▼
    ┌─────────────────────────────┐
    │      Amazon CloudWatch      │
    │  ┌──────────┐ ┌──────────┐ │
    │  │ Metrics  │ │   Logs   │ │
    │  │ (Custom) │ │  Groups  │ │
    │  └──────────┘ └──────────┘ │
    │  ┌──────────────────────┐  │
    │  │     Dashboard        │  │
    │  └──────────────────────┘  │
    └─────────────────────────────┘

* Không có sẵn nếu chỉ dùng default EC2 metrics
```

---

## 📋 Prerequisites

| Yêu cầu | Chi tiết |
|---------|---------|
| EC2 Instance | Amazon Linux 2 hoặc Ubuntu 20.04+ |
| IAM Role | Phải gắn policy `CloudWatchAgentServerPolicy` |
| Outbound Internet | Port 443 tới `monitoring.amazonaws.com` |
| AWS CLI | (Tuỳ chọn) Để tạo IAM Role qua CLI |

---

## 🚀 Các Bước Thực Hiện

### Bước 1: Gắn IAM Role cho EC2

> ⚠️ **Prerequisite bắt buộc:** EC2 phải có IAM Role với `CloudWatchAgentServerPolicy` trước khi cài Agent.

#### Tạo IAM Role qua AWS Console:
1. Vào **IAM** → **Roles** → **Create role**
2. Trusted entity: **AWS service** → **EC2**
3. Tìm và attach policy: **`CloudWatchAgentServerPolicy`**
4. Đặt tên role: `EC2-CloudWatch-Role`
5. Gắn role vào EC2: **EC2 Console** → Instance → **Actions** → **Security** → **Modify IAM role**

#### Hoặc tạo qua CLI (xem `scripts/create-iam-role.sh`):
```bash
bash scripts/create-iam-role.sh
```

---

### Bước 2: Cài Đặt Agent Package

SSH vào EC2 instance và chạy lệnh tương ứng với OS:

**Amazon Linux 2 / Amazon Linux 2023:**
```bash
sudo yum install amazon-cloudwatch-agent -y
```

**Ubuntu:**
```bash
sudo apt-get update
sudo apt-get install amazon-cloudwatch-agent -y
```

Kiểm tra cài đặt thành công:
```bash
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl --version
```

---

### Bước 3: Chạy Configuration Wizard

```bash
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-config-wizard
```

Wizard sẽ hỏi các câu hỏi và sinh ra file `/opt/aws/amazon-cloudwatch-agent/bin/config.json`. Bạn có thể tham khảo file cấu hình mẫu có sẵn:

```bash
# Sử dụng file config mẫu (khuyến nghị cho lab này)
sudo cp configs/cloudwatch-agent-config.json \
    /opt/aws/amazon-cloudwatch-agent/bin/config.json
```

---

### Bước 4: Khởi Động Agent

```bash
# Enable agent tự chạy khi khởi động lại EC2
sudo systemctl enable amazon-cloudwatch-agent

# Khởi động agent ngay lập tức
sudo systemctl start amazon-cloudwatch-agent
```

Hoặc dùng `amazon-cloudwatch-agent-ctl`:
```bash
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config \
    -m ec2 \
    -s \
    -c file:/opt/aws/amazon-cloudwatch-agent/bin/config.json
```

---

### Bước 5: Xác Minh & Kiểm Tra Trạng Thái

```bash
# Kiểm tra trạng thái agent
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -m ec2 -a status

# Kiểm tra systemd service
sudo systemctl status amazon-cloudwatch-agent

# Xem logs của agent
sudo tail -f /opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log
```

**Output mong đợi khi agent đang chạy:**
```json
{
  "status": "running",
  "starttime": "2026-06-12T05:00:00+0000",
  "configstatus": "configured",
  "cwoc_status": "running",
  "version": "1.300032.3"
}
```

---

## 🧪 Verification & Testing

### Test 1: Kiểm tra Metrics trên CloudWatch Console

1. Vào **CloudWatch** → **Metrics** → **All metrics**
2. Tìm namespace **`CWAgent`**
3. Bạn sẽ thấy metrics mới: `mem_used_percent`, `disk_used_percent`, v.v.

### Test 2: Kiểm tra Log Groups

1. Vào **CloudWatch** → **Log groups**
2. Tìm log group: `/ec2/app-logs` (theo cấu hình mẫu)
3. Xem log events từ EC2

### Test 3: Sinh Traffic Metrics

```bash
# Tạo CPU load để test
stress --cpu 2 --timeout 60

# Xem disk I/O
dd if=/dev/zero of=/tmp/testfile bs=1M count=512

# Xem RAM usage
free -m
```

---

## 📁 Cấu Trúc Thư Mục

```
cloudwatch_agent_lab/
├── README.md                        # Tài liệu chính (file này)
├── configs/
│   ├── cloudwatch-agent-config.json # Config mẫu (metrics + logs)
│   └── cloudwatch-agent-minimal.json# Config tối giản (chỉ metrics)
├── scripts/
│   ├── install-agent.sh             # Script cài đặt tự động
│   ├── create-iam-role.sh           # Script tạo IAM Role qua AWS CLI
│   └── verify-agent.sh              # Script kiểm tra trạng thái
├── terraform/
│   ├── main.tf                      # EC2 + IAM Role infrastructure
│   ├── variables.tf
│   └── outputs.tf
└── docs/
    ├── troubleshooting.md           # Xử lý sự cố thường gặp
    └── custom-metrics.md            # Hướng dẫn custom metrics nâng cao
```

---

## 🔧 Troubleshooting Nhanh

| Vấn đề | Nguyên nhân | Giải pháp |
|--------|------------|-----------|
| Agent không start | IAM Role thiếu policy | Attach `CloudWatchAgentServerPolicy` |
| Không thấy metrics | Agent chưa configured | Chạy lại wizard hoặc apply config |
| Log không lên | Sai log path trong config | Kiểm tra `file_path` trong config.json |
| `status: stopped` | Agent bị tắt | `sudo systemctl start amazon-cloudwatch-agent` |

Xem thêm: [docs/troubleshooting.md](docs/troubleshooting.md)

---

## 📚 Tài Liệu Tham Khảo

- [AWS CloudWatch Agent Official Docs](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Install-CloudWatch-Agent.html)
- [CloudWatchAgentServerPolicy Reference](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/create-iam-roles-for-cloudwatch-agent.html)
- [Configuration File Reference](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-Agent-Configuration-File-Details.html)
