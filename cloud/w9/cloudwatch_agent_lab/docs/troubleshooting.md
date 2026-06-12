# 🔧 Troubleshooting — CloudWatch Agent

## Các vấn đề thường gặp và cách xử lý

---

### ❌ Vấn đề 1: Agent không khởi động

**Triệu chứng:**
```bash
$ sudo systemctl status amazon-cloudwatch-agent
● amazon-cloudwatch-agent.service - Amazon CloudWatch Agent
   Loaded: loaded
   Active: failed (Result: exit-code)
```

**Nguyên nhân & Giải pháp:**

| Nguyên nhân | Kiểm tra | Giải pháp |
|------------|---------|----------|
| Chưa có config file | `ls /opt/aws/amazon-cloudwatch-agent/bin/config.json` | Chạy wizard hoặc copy config mẫu |
| Config JSON sai format | `python3 -m json.tool config.json` | Sửa lại JSON cho đúng cú pháp |
| IAM Role thiếu policy | Xem mục IAM bên dưới | Attach `CloudWatchAgentServerPolicy` |

**Xem logs chi tiết:**
```bash
sudo journalctl -u amazon-cloudwatch-agent -n 100 --no-pager
sudo tail -100 /opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log
```

---

### ❌ Vấn đề 2: Không thấy metrics trong CloudWatch Console

**Triệu chứng:** Agent đang chạy nhưng không thấy namespace `CWAgent` trong Console.

**Checklist:**
1. Kiểm tra IAM Role có `CloudWatchAgentServerPolicy` không?
2. Đợi ít nhất **2-3 phút** sau khi agent start (metrics cần thời gian gửi lên)
3. Chọn đúng **region** trong CloudWatch Console
4. Kiểm tra outbound connectivity port 443

```bash
# Test kết nối tới CloudWatch endpoint
curl -I https://monitoring.ap-southeast-1.amazonaws.com

# Kiểm tra IAM Role
curl http://169.254.169.254/latest/meta-data/iam/security-credentials/
```

---

### ❌ Vấn đề 3: IAM Role không có quyền

**Triệu chứng** trong agent log:
```
E! cloudwatch: Error in PutMetricData, err: AccessDenied
```

**Giải pháp:**
```bash
# Kiểm tra role hiện tại của instance
aws sts get-caller-identity

# Verify policy được attach
aws iam list-attached-role-policies --role-name <ROLE_NAME>
```

Policy ARN cần có: `arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy`

---

### ❌ Vấn đề 4: Log files không được thu thập

**Triệu chứng:** Log Group xuất hiện trong Console nhưng không có log events.

**Checklist:**
```bash
# 1. Kiểm tra file log tồn tại
ls -la /var/log/app/

# 2. Kiểm tra quyền đọc
sudo cat /var/log/app/app.log

# 3. Kiểm tra config đúng path
cat /opt/aws/amazon-cloudwatch-agent/bin/config.json | \
    python3 -m json.tool | grep file_path

# 4. Restart agent sau khi sửa config
sudo systemctl restart amazon-cloudwatch-agent
```

---

### ❌ Vấn đề 5: `status: stopped` sau khi restart EC2

**Nguyên nhân:** Service chưa được enable (chỉ start thủ công).

**Giải pháp:**
```bash
# Enable service để tự chạy khi boot
sudo systemctl enable amazon-cloudwatch-agent

# Verify
sudo systemctl is-enabled amazon-cloudwatch-agent
# Output mong đợi: enabled
```

---

## 🔍 Debug Commands Tổng Hợp

```bash
# Xem trạng thái đầy đủ
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -m ec2 -a status

# Reload config không cần restart
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config -m ec2 -s \
    -c file:/opt/aws/amazon-cloudwatch-agent/bin/config.json

# Xem agent logs real-time
sudo tail -f /opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log

# Kiểm tra version
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl --version
```
