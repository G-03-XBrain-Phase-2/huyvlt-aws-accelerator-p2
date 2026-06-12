# 🔐 Tại Sao Phải Bảo Vệ Root Account?

## Root Account là gì?

AWS Root Account là tài khoản **có quyền tuyệt đối** — không thể bị giới hạn bởi IAM Policy, SCP, hay Permission Boundary. Nó có thể:

- Xoá toàn bộ tài khoản AWS
- Truy cập mọi dữ liệu trong account
- Thay đổi billing/payment information
- Cancel AWS Support plans
- Xoá MFA, đổi root email/password
- Bỏ qua mọi IAM restriction

---

## Tại Sao Không Nên Dùng Root?

### 1. Nguy cơ bảo mật cực cao
Nếu root credentials bị lộ → kẻ tấn công có quyền kiểm soát **toàn bộ** AWS account.

### 2. Không thể audit chi tiết
Khi root làm gì, CloudTrail ghi lại nhưng không có cách nào biết **ai** đang dùng root (vì chỉ có 1 root).

### 3. Vi phạm Principle of Least Privilege
Root có thể làm mọi thứ — luôn dùng IAM Users/Roles với quyền tối thiểu cần thiết.

### 4. Yêu cầu của CIS Benchmark & AWS Well-Architected
- **CIS AWS Benchmark 1.7:** Alert on root account usage
- **AWS Well-Architected Security Pillar:** Protect root credentials, enable MFA

---

## Khi Nào Phải Dùng Root?

Chỉ những tác vụ **bắt buộc** dùng root:

| Tác vụ | Có thể dùng IAM? |
|--------|-----------------|
| Thay đổi root email/password | ❌ Chỉ root |
| Kích hoạt IAM access cho Billing | ❌ Chỉ root |
| Submit GovCloud account request | ❌ Chỉ root |
| Khôi phục IAM admin khi bị lock | ❌ Chỉ root |
| Mọi tác vụ khác | ✅ Dùng IAM |

---

## AWS Security Best Practices cho Root

| Best Practice | Trạng thái |
|--------------|-----------|
| Bật MFA cho root | 🔴 Bắt buộc |
| Không tạo Root Access Keys | 🔴 Bắt buộc |
| Alert khi root login | 🟡 Lab này! |
| Lưu root credentials an toàn | 🔴 Bắt buộc |
| Không dùng root cho daily tasks | 🔴 Bắt buộc |

---

## Cách Kiểm Tra Root Security Status

```bash
# Kiểm tra Credential Report
aws iam generate-credential-report
aws iam get-credential-report \
    --query 'Content' \
    --output text | base64 -d | grep '<root_account>'

# Kiểm tra MFA đã bật chưa
aws iam get-account-summary \
    --query 'SummaryMap.AccountMFAEnabled'
# Output: 1 = đã bật, 0 = chưa bật

# Kiểm tra có Root Access Key không
aws iam list-access-keys
# Output lý tưởng: AccessKeyMetadata = [] (trống)
```
