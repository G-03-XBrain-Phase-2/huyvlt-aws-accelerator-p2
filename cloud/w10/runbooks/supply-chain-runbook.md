# Hướng dẫn Vận hành & Nghiệm thu: Lab 2.2 · Supply Chain Security (Trivy + Cosign)

Tài liệu này hướng dẫn bạn cấu hình Cosign để ký và Sigstore Policy Controller để xác minh tính hợp lệ của image chạy trên cụm.

---

## 🛠️ Bước 1: Tạo cặp khóa Cosign (Local)
Nếu bạn chưa có sẵn Cosign CLI cục bộ, bạn có thể thực hiện theo một trong hai cách:

### Cách A: Cài đặt và sử dụng Cosign CLI trực tiếp
1. Cài đặt Cosign:
   ```bash
   winget install Sigstore.Cosign
   ```
2. Mở cửa sổ CMD/PowerShell mới và tạo cặp khóa:
   ```bash
   # Tạo khóa bên trong thư mục cloud/w10/signing/
   cd "c:\Project Web\huyvlt-aws-accelerator-p2"
   mkdir cloud/w10/signing
   cosign generate-key-pair --output-key-prefix cloud/w10/signing/cosign
   ```
   *Nhập mật khẩu (passphrase) bảo vệ khóa khi được hỏi (hoặc nhấn Enter để bỏ qua).*
   Quá trình này sinh ra 2 file:
   - `cloud/w10/signing/cosign.key` (Private Key - Tuyệt đối không commit lên Git)
   - `cloud/w10/signing/cosign.pub` (Public Key - Sẽ được commit lên Git)

### Cách B: Sử dụng Docker (Nếu đã sửa xong Docker Desktop)
```bash
docker run --rm -v "c:\Project Web\huyvlt-aws-accelerator-p2\cloud\w10\signing:/signing" sigstore/cosign:v2.2.4 generate-key-pair --output-key-prefix /signing/cosign
```

---

## 🛠️ Bước 2: Cấu hình GitHub Secrets và Policy Controller

1. **Cấu hình GitHub Secrets**:
   - Truy cập kho lưu trữ GitHub của bạn.
   - Đi tới **Settings** -> **Secrets and variables** -> **Actions** -> Click **New repository secret**.
   - Tạo các secret sau:
     - Tên: `COSIGN_PRIVATE_KEY` -> Nội dung: Copy toàn bộ nội dung file `cosign.key` vừa tạo.
     - Tên: `COSIGN_PASSWORD` -> Nội dung: Mật khẩu bạn nhập lúc tạo khóa (bỏ qua nếu không đặt mật khẩu).

2. **Cập nhật ClusterImagePolicy**:
   - Mở file [cluster-image-policy.yaml](file:///c:/Project%20Web/huyvlt-aws-accelerator-p2/cloud/w10/policies/cluster-image-policy.yaml).
   - Thay thế toàn bộ phần `[DÁN NỘI DUNG COSIGN.PUB CỦA BẠN VÀO ĐÂY]` bằng nội dung khóa công khai từ file `cosign.pub` của bạn.
   - Ví dụ cấu hình sau khi hoàn thành:
     ```yaml
     authorities:
       - key:
           data: |
             -----BEGIN PUBLIC KEY-----
             MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAE9m+9Y5o53F8aXq3...
             -----END PUBLIC KEY-----
     ```

3. **Push cấu hình lên GitHub**:
   Đảm bảo file `cosign.key` đã được gitignore (đã có quy tắc `*.key` / `*.exe`). Push code lên repo:
   ```bash
   git add cloud/w10/policies/cluster-image-policy.yaml cloud/w10/signing/cosign.pub
   git commit -m "chore(w10): add cosign public key and policy configuration"
   git push origin main
   ```

---

## 🧪 Quy trình nghiệm thu kiểm thử

Khi các ArgoCD apps (`policy-controller` và `cosign-policies`) chuyển sang trạng thái Synced/Healthy:

### Tình huống 1: Quét lỗ hổng Trivy (CI Đỏ khi có CVE HIGH/CRITICAL)
- Pipeline GitHub Actions của bạn sẽ tự động chạy Trivy trước khi build push.
- Nếu bạn cố tình đưa một package lỗi bảo mật nghiêm trọng (ví dụ image base quá cũ có nhiều CVE) vào Dockerfile, bước `Run Trivy vulnerability scanner` sẽ fail (exit-code 1), dừng toàn bộ pipeline và không cho phép push image lên registry.

### Tình huống 2: Admission Controller chặn Image chưa được ký (Reject)
1. Gắn nhãn kích hoạt xác thực cho namespace `demo`:
   ```bash
   kubectl label namespace demo policy.sigstore.dev/include=true --overwrite
   ```
2. Thử chạy một Pod sử dụng image chưa ký (ví dụ: `nginx:latest`):
   ```bash
   kubectl run test-unsigned --image=nginx:latest -n demo
   ```
   **Kỳ vọng**: Yêu cầu bị từ chối bởi Admission Webhook của Sigstore. Bạn sẽ nhận được thông báo lỗi tương tự:
   > *Error from server (BadRequest): admission webhook "policy.sigstore.dev" denied the request: validation failed: image ... does not match any signatures*

### Tình huống 3: Deploy Image đã được ký thành công (Pass)
1. Kích hoạt GitHub Actions pipeline tự động chạy để build, scan, push và ký image `w10-api` phiên bản mới.
2. Deploy ứng dụng api chính thức (đã có chữ ký):
   ```bash
   kubectl apply -f cloud/w10/lab1/app-api/rollout.yaml
   ```
   **Kỳ vọng**: Ứng dụng triển khai thành công, các Pod khởi chạy bình thường mà không bị Admission Controller chặn lại vì chữ ký số hợp lệ.
