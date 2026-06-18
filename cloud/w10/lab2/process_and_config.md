# 📋 Báo Cáo Quá Trình Thực Hiện & Cấu Hình Bảo Mật: Lab 2 (ESO + Trivy + Cosign)

Tài liệu này tổng hợp chi tiết toàn bộ quá trình thực hiện bài Lab 2, các lỗi gặp phải trong quá trình cấu hình tích hợp nền tảng (Platform Integration) cùng giải pháp khắc phục, và các vị trí lưu cấu hình của hệ thống.

---

## 🕒 1. Nhật Ký Quá Trình Thực Hiện (Troubleshooting & Setup)

Quá trình triển khai tích hợp các dịch vụ bảo mật ở Lab 2 bao gồm các giai đoạn gỡ lỗi chính sau:

### Giai đoạn 1: Phân tách cấu trúc Lab 1 & Lab 2
*   **Vấn đề:** Các thư mục của Lab 2 (`eso/`, `policies/`, `signing/`, `runbooks/`) ban đầu được đặt trực tiếp ở thư mục gốc `cloud/w10/`, gây lẫn lộn với Lab 1 và khó khăn cho việc mở rộng các bài tập lớn tiếp theo.
*   **Khắc phục:** Di chuyển toàn bộ các thư mục trên vào thư mục con chuyên biệt `cloud/w10/lab2/`.

### Giai đoạn 2: Cập nhật đường dẫn ArgoCD Apps tương ứng
*   **Vấn đề:** Sau khi di chuyển thư mục, các ArgoCD Applications quản lý Platform bị trỏ vào đường dẫn cũ không còn tồn tại trên GitHub, gây ra lỗi:
    > *Failed to load target state: ... app path does not exist*
*   **Khắc phục:** 
    *   Cập nhật `source.path` trong các manifest [eso-config.yaml](file:///c:/Project%20Web/huyvlt-aws-accelerator-p2/cloud/w10/argocd/apps/eso-config.yaml) và [policies.yaml](file:///c:/Project%20Web/huyvlt-aws-accelerator-p2/cloud/w10/argocd/apps/policies.yaml) sang đường dẫn mới dưới `cloud/w10/lab2/`.
    *   Đẩy code lên GitHub và thực hiện lệnh `kubectl patch` để ép ArgoCD thực hiện "hard refresh" bỏ qua cache, giúp đồng bộ hóa các ứng dụng con lập tức.

### Giai đoạn 3: Khắc phục lỗi lệch cấu hình (ArgoCD Sync Drift)
*   **Vấn đề:** Sau khi đồng bộ, ArgoCD báo trạng thái `OutOfSync` cho `cosign-policies` và `external-secrets-config` mặc dù tài nguyên đã chạy. Nguyên nhân do API Server tự động bổ sung một số tham số mặc định (defaulting mutations) mà trong file Git gốc không khai báo.
*   **Khắc phục:** 
    *   Đối với **ClusterImagePolicy**: Thêm `mode: enforce` và gán tên `name: authority-0` cho Authority key trong file [cluster-image-policy.yaml](file:///c:/Project%20Web/huyvlt-aws-accelerator-p2/cloud/w10/lab2/policies/cluster-image-policy.yaml).
    *   Đối với **ExternalSecret**: Thêm cấu hình `deletionPolicy: Retain` và các thuộc tính `conversionStrategy`, `decodingStrategy`, `metadataPolicy` trong file [external-secret.yaml](file:///c:/Project%20Web/huyvlt-aws-accelerator-p2/cloud/w10/lab2/eso/external-secret.yaml).
    *   Sau khi đẩy các thay đổi khớp hoàn toàn này lên Git, ArgoCD đã chuyển trạng thái sang **`Synced`** và **`Healthy`** tuyệt đối.

---

## 👥 2. Vị Trí Cấu Hình Secrets Rotation (ESO)

Hệ thống quản lý vòng đời mật khẩu tự động được lưu trữ tại các tệp cấu hình:

1.  **Cài đặt ESO Operator:**
    *   *File cấu hình:* [eso.yaml](file:///c:/Project%20Web/huyvlt-aws-accelerator-p2/cloud/w10/argocd/apps/eso.yaml)
    *   *Nhiệm vụ:* Đăng ký cài đặt External Secrets Operator Helm Chart với tham số tự động cài CRDs (`installCRDs: true`) ở sync-wave `-5`.
2.  **SecretStore Kết nối AWS/Mock Store:**
    *   *File cấu hình:* [secret-store.yaml](file:///c:/Project%20Web/huyvlt-aws-accelerator-p2/cloud/w10/lab2/eso/secret-store.yaml)
    *   *Nhiệm vụ:* Sử dụng mock `fake` provider chứa khóa `database/password` phục vụ môi trường Minikube cục bộ.
3.  **Bản đồ đồng bộ dữ liệu (ExternalSecret):**
    *   *File cấu hình:* [external-secret.yaml](file:///c:/Project%20Web/huyvlt-aws-accelerator-p2/cloud/w10/lab2/eso/external-secret.yaml)
    *   *Nhiệm vụ:* Cấu hình chu kỳ quét thay đổi `refreshInterval: 15s`, kéo mật khẩu từ mock store đổ vào K8s Secret `db-secret` tại namespace `demo`.
4.  **Tích hợp vào Ứng dụng (Mount Volume):**
    *   *Dòng cấu hình:* [rollout.yaml:L49-L56](file:///c:/Project%20Web/huyvlt-aws-accelerator-p2/cloud/w10/lab1/app-api/rollout.yaml#L49-L56)
    *   *Nhiệm vụ:* Gắn Secret `db-secret` dưới dạng volume mount vào thư mục `/etc/secrets` để Kubelet tự động cập nhật tệp tin khi có thay đổi mà không làm khởi động lại Pod.

---

## 🛡️ 3. Vị Trí Cấu Hợp Supply Chain Security (Trivy + Cosign)

Hạ tầng an toàn chuỗi cung ứng và xác thực chữ ký số bao gồm:

1.  **Quét lỗ hổng Trivy & Ký số Cosign trong CI/CD:**
    *   *File cấu hình:* [.github/workflows/build-push-w10.yml](file:///c:/Project%20Web/huyvlt-aws-accelerator-p2/.github/workflows/build-push-w10.yml)
    *   *Vị trí quét Trivy:* Lớp `Run Trivy vulnerability scanner` (dòng 66-74), tự động chặn build push nếu có CVE `HIGH` hoặc `CRITICAL`.
    *   *Vị trí ký Cosign:* Lớp `Sign the published Docker image` (dòng 87-97), sử dụng Private Key được cấu hình trong GitHub Actions Secrets.
2.  **Khóa công khai để xác minh (Public Key):**
    *   *File lưu trữ:* [cosign.pub](file:///c:/Project%20Web/huyvlt-aws-accelerator-p2/cloud/w10/lab2/signing/cosign.pub)
    *   *Nhiệm vụ:* Lưu trữ public key dùng làm đối chứng xác thực chữ ký đầu vào.
3.  **Chính sách kiểm duyệt chữ ký trên cụm (ClusterImagePolicy):**
    *   *File cấu hình:* [cluster-image-policy.yaml](file:///c:/Project%20Web/huyvlt-aws-accelerator-p2/cloud/w10/lab2/policies/cluster-image-policy.yaml)
    *   *Nhiệm vụ:* Ràng buộc đối chứng mọi image tải về khớp với glob `ghcr.io/*/w10-api*` phải được ký bằng khóa công khai tương ứng.
4.  **Sổ tay xử lý ngoại lệ lỗi bảo mật (CVE Exception):**
    *   *File cấu hình:* [adr-exception.md](file:///c:/Project%20Web/huyvlt-aws-accelerator-p2/cloud/w10/lab2/runbooks/adr-exception.md)
    *   *Nhiệm vụ:* Định nghĩa quy trình sử dụng `.trivyignore` kèm thời hạn tối đa 30 ngày để xử lý các CVE chưa có bản vá (unfixed) mà không gây tắc nghẽn chuỗi cung ứng.
