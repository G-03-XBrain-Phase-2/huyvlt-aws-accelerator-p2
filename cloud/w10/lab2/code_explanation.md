# 📖 Giải Thích Chi Tiết Mã Nguồn & Nguyên Lý Hoạt Động: Lab 2 (ESO + Supply Chain Security)

Tài liệu này giải thích chi tiết từng khối mã nguồn YAML trong cấu hình External Secrets Operator, GitHub Actions CI/CD và ClusterImagePolicy được sử dụng trong bài Lab 2.

---

## 🔑 1. Giải thích cấu hình Secrets Rotation (ESO)

### A. SecretStore (Mock/Fake AWS Provider)
Tệp tin: [secret-store.yaml](file:///c:/Project%20Web/huyvlt-aws-accelerator-p2/cloud/w10/lab2/eso/secret-store.yaml)
```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: fake-store
  namespace: demo
spec:
  provider:
    fake:                     # Khai báo sử dụng Mock provider cho minikube
      data:
        - key: database/password
          value: "new-rotated-password-999" # Mật khẩu giả lập lưu trên AWS Secrets Manager
```
*   **Giải thích:** `SecretStore` đóng vai trò kết nối tới nhà cung cấp quản lý secret. Trên môi trường Minikube cục bộ, ta sử dụng provider `fake` để giả lập cơ sở dữ liệu khóa-giá trị của AWS Secrets Manager mà không cần kết nối internet hay tài khoản AWS thực tế.

---

### B. Bản đồ đồng bộ (ExternalSecret)
Tệp tin: [external-secret.yaml](file:///c:/Project%20Web/huyvlt-aws-accelerator-p2/cloud/w10/lab2/eso/external-secret.yaml)
```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: db-secret-eso
  namespace: demo
spec:
  refreshInterval: "15s"       # Tần suất quét thay đổi từ nguồn (15 giây)
  secretStoreRef:
    name: fake-store
    kind: SecretStore
  target:
    name: db-secret            # Tên K8s Secret được tự động sinh ra trong cụm
    creationPolicy: Owner
    deletionPolicy: Retain     # Giữ lại Secret trên cụm kể cả khi ExternalSecret bị xóa
  data:
    - secretKey: password      # Tên key trong K8s Secret đầu ra
      remoteRef:
        key: database/password # Khóa cần lấy từ SecretStore nguồn
        conversionStrategy: Default
        decodingStrategy: None
        metadataPolicy: None
```
*   **Giải thích:** `ExternalSecret` hướng dẫn ESO Controller quét nguồn `fake-store` mỗi `15s`. Nếu phát hiện giá trị mật khẩu thay đổi, nó sẽ tự động đồng bộ và cập nhật giá trị base64 vào K8s Secret có tên `db-secret`.

---

### C. Cơ chế Volume Mount (Không restart pod)
Trong file cấu hình Rollout của ứng dụng:
```yaml
        volumeMounts:
        - name: db-secret-volume
          mountPath: /etc/secrets
          readOnly: true
      volumes:
      - name: db-secret-volume
        secret:
          secretName: db-secret
```
*   **Giải thích:** Pod gắn K8s Secret `db-secret` thành một thư mục `/etc/secrets` trên ổ đĩa ảo. Khi ESO cập nhật giá trị của `db-secret`, tiến trình Kubelet của Kubernetes sẽ tự động cập nhật nội dung của file `/etc/secrets/password` mà không kích hoạt restart pod ➔ Giúp ứng dụng lấy được mật khẩu mới với Downtime bằng 0.

---

## 🛡️ 2. Giải thích pipeline CI/CD & Security (Trivy + Cosign)

Tệp tin cấu hình pipeline: [.github/workflows/build-push-w10.yml](file:///c:/Project%20Web/huyvlt-aws-accelerator-p2/.github/workflows/build-push-w10.yml)

### A. Quét lỗ hổng an ninh với Trivy
```yaml
      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@0.20.0
        with:
          image-ref: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:temp-scan
          format: 'table'
          exit-code: '1'       # Trả về mã lỗi 1 để dừng pipeline ngay lập tức nếu có lỗi
          ignore-unfixed: true # Bỏ qua các lỗi chưa có bản vá sửa lỗi (Unfixed CVEs)
          vuln-type: 'os,library'
          severity: 'HIGH,CRITICAL' # Chỉ quét các lỗi nặng trở lên
```
*   **Giải thích:** Pipeline tiến hành build nháp image cục bộ (`temp-scan`), sau đó Trivy tiến hành quét. Nếu phát hiện bất kỳ CVE bảo mật nào có độ nghiêm trọng là `HIGH` hoặc `CRITICAL` mà đã có bản vá sửa lỗi (`ignore-unfixed: true`), pipeline sẽ bị dừng ngay lập tức tại bước này và không đẩy image lên registry.

---

### B. Ký số bảo mật bằng Cosign
```yaml
      - name: Sign the published Docker image
        env:
          COSIGN_PRIVATE_KEY: ${{ secrets.COSIGN_PRIVATE_KEY }} # Private key lưu trong GitHub Action Secret
          COSIGN_PASSWORD: ${{ secrets.COSIGN_PASSWORD }}
        run: |
          if [ -n "$COSIGN_PRIVATE_KEY" ]; then
            # Sử dụng Cosign ký số image dựa trên Private key
            echo "$COSIGN_PRIVATE_KEY" | cosign sign --key - --yes "${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ steps.semver.outputs.version }}"
          else
            echo "Warning: COSIGN_PRIVATE_KEY secret is not set, skipping signing"
          fi
```
*   **Giải thích:** Sau khi image được đẩy thành công lên GitHub Container Registry, pipeline dùng khóa riêng tư `COSIGN_PRIVATE_KEY` ký xác nhận. Chữ ký số này được tải lên registry nằm cạnh image gốc làm căn cứ đối chiếu.

---

## 🛡️ 3. Giải thích Chính sách Xác thực Chữ ký (ClusterImagePolicy)

Tệp tin: [cluster-image-policy.yaml](file:///c:/Project%20Web/huyvlt-aws-accelerator-p2/cloud/w10/lab2/policies/cluster-image-policy.yaml)
```yaml
apiVersion: policy.sigstore.dev/v1beta1
kind: ClusterImagePolicy
metadata:
  name: api-image-policy
spec:
  images:
    - glob: "ghcr.io/*/w10-api*" # Phạm vi áp dụng: Mọi image có đường dẫn khớp glob này
  mode: enforce                 # Chế độ bắt buộc chặn vi phạm (enforce)
  authorities:
    - name: authority-0
      key:
        data: |                 # Khóa công khai dùng để giải mã chữ ký số đối chứng
          -----BEGIN PUBLIC KEY-----
          MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAE1nuEAn5c04888CUSXq0hyUQRECEj
          JtWDg7jqsHU9d3g/zmDvaME3rMxepz8OIV4EjLyeGEbF0hHZgGN476WFmg==
          -----END PUBLIC KEY-----
```
*   **Giải thích:** `ClusterImagePolicy` định nghĩa chính sách bảo vệ hạ tầng cụm. Mọi Pod trong namespace có gán nhãn kích hoạt, khi pull image khớp với glob `ghcr.io/*/w10-api*` sẽ bị gác cổng Admission Webhook chặn lại để kiểm duyệt:
    *   Sử dụng Public Key định nghĩa ở phần `authorities.key.data` để xác minh chữ ký của image.
    *   Nếu chữ ký hợp lệ ➔ Chấp nhận deploy.
    *   Nếu chữ ký không hợp lệ, không khớp khóa công khai hoặc không có chữ ký ➔ Từ chối deploy lập tức.
