# 📖 Hướng Dẫn Vận Hành & Nghiệm Thu: Lab 2 (Secrets Rotation + Supply Chain Security)

Thư mục này chứa toàn bộ tài nguyên cấu hình bảo mật dữ liệu và chuỗi cung ứng phần mềm (Supply Chain Security) cho **Lab 2 (Buổi chiều)** bao gồm:
1. **Secrets Rotation:** Đồng bộ tự động Secret từ AWS/SecretStore thông qua External Secrets Operator (ESO) với thời gian < 60s và không restart pod.
2. **Supply Chain Security:** Quét CVE trong CI/CD (Trivy), ký số image (Cosign) và xác thực chữ ký đầu vào cụm (Sigstore Policy Controller).

---

## 🏗️ 1. Cấu Trúc Tài Nguyên Lab 2
*   [eso/](file:///c:/Project%20Web/huyvlt-aws-accelerator-p2/cloud/w10/lab2/eso/): Định nghĩa SecretStore (fake-store) và ExternalSecret (db-secret-eso).
*   [policies/](file:///c:/Project%20Web/huyvlt-aws-accelerator-p2/cloud/w10/lab2/policies/): Định nghĩa ClusterImagePolicy để xác thực chữ ký số của image.
*   [signing/](file:///c:/Project%20Web/huyvlt-aws-accelerator-p2/cloud/w10/lab2/signing/): Chứa khóa công khai `cosign.pub` dùng để xác thực.
*   [runbooks/](file:///c:/Project%20Web/huyvlt-aws-accelerator-p2/cloud/w10/lab2/runbooks/): Sổ tay vận hành cho Secrets Rotation, Supply Chain Security và quy trình viết exception ADR cho CVE.

---

## 🛠️ 2. Các Bước Kích Hoạt & Đồng Bộ Cụm

Đảm bảo bạn đã đẩy các chỉnh sửa mới nhất lên repo của bạn:
```powershell
git push origin main
```
Sau đó kiểm tra trạng thái các ứng dụng trên ArgoCD:
```bash
kubectl get applications -n argocd
```
*   **Mục tiêu:** Ứng dụng `external-secrets-operator`, `external-secrets-config`, `policy-controller`, và `cosign-policies` đều ở trạng thái **`Synced`** và **`Healthy`**.

---

## 🧪 3. Hướng Dẫn Kiểm Thử & Nghiệm Thu

### 🔑 Phần 3.1: Nghiệm thu Secrets Rotation (Lab 2.1)

#### Bước A: Thực hiện xoay vòng Secret
Mở file [secret-store.yaml](file:///c:/Project%20Web/huyvlt-aws-accelerator-p2/cloud/w10/lab2/eso/secret-store.yaml) và thay đổi giá trị mật khẩu trong cấu hình fake store:
```yaml
# Thay đổi giá trị value từ "initial-db-password-123" thành giá trị bất kỳ:
value: "new-rotated-password-999"
```
Commit và push lên GitHub để ArgoCD tự động áp dụng, hoặc áp dụng trực tiếp:
```bash
kubectl apply -f cloud/w10/lab2/eso/secret-store.yaml
```

#### Bước B: Xác minh kết quả
1.  **Kiểm tra K8s Secret tự động cập nhật (< 60s):**
    ```powershell
    $val = (kubectl get secret db-secret -n demo -o jsonpath='{.data.password}'); [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($val))
    # Kỳ vọng kết quả in ra: new-rotated-password-999 (đồng bộ trong < 15 giây)
    ```
2.  **Kiểm tra Pod không bị Restart:**
    ```bash
    kubectl get pods -n demo -l app=api
    # Kiểm tra cột AGE (phải giữ nguyên thời gian cũ, ví dụ 80m+) và RESTARTS (phải là 0)
    ```
3.  **Kiểm tra giá trị cập nhật bên trong Pod (Volume Mount):**
    ```powershell
    $podName = (kubectl get pods -n demo -o jsonpath="{.items[0].metadata.name}"); kubectl exec -n demo $podName -- cat /etc/secrets/password
    # Kỳ vọng kết quả in ra mật khẩu mới: new-rotated-password-999
    ```

---

### 🛡️ Phần 3.2: Nghiệm thu Supply Chain Security (Lab 2.2)

#### Bước A: Bật xác thực chữ ký cho namespace `demo`
```bash
kubectl label namespace demo policy.sigstore.dev/include=true --overwrite
```

#### Bước B: Thử nghiệm kịch bản VI PHẠM (Chặn Image chưa ký)
Sử dụng file mẫu [pod-unsigned.yaml](file:///c:/Project%20Web/huyvlt-aws-accelerator-p2/cloud/w10/lab1/scratch/pod-unsigned.yaml):
```bash
kubectl apply -f cloud/w10/lab1/scratch/pod-unsigned.yaml
```
*   **Kỳ vọng lỗi:** Yêu cầu tạo Pod bị API Server từ chối ngay lập tức:
    > *Error from server (BadRequest): ... admission webhook "policy.sigstore.dev" denied the request: validation failed: invalid value: ... must be an image digest*

#### Bước C: Thử nghiệm kịch bản HỢP LỆ (Cho phép Image đã ký)
1.  **Lưu ý quan trọng về Private Registry:** Do GitHub Packages của bạn là private, webhook Sigstore cần quyền truy cập để đọc chữ ký. Hãy chuyển visibility của container package `w10-api` sang **Public** trên trang GitHub Settings của bạn, hoặc cấu hình `imagePullSecrets` cho Pod.
2.  Deploy Pod sử dụng hình ảnh đã được ký thông qua mã digest (SHA256):
    ```bash
    kubectl apply -f cloud/w10/lab1/scratch/pod-signed.yaml
    ```
    *   **Kỳ vọng:** Pod được tạo thành công không bị chặn bởi Admission Webhook.
