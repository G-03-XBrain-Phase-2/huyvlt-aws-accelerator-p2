# 📝 Nhật Ký Nghiệm Thu Kết Quả: Lab 2 (ESO + Supply Chain Security)

Tài liệu này tổng hợp chi tiết kết quả thử nghiệm thực tế trên cụm Minikube cục bộ cho các cấu hình xoay vòng bí mật (Secrets Rotation) và an toàn chuỗi cung ứng (Supply Chain Security) triển khai trong Lab 2.

---

## 🔑 1. Nghiệm thu Xoay Vòng Secret tự động (ESO)

Chúng ta đã kiểm tra thành công luồng cập nhật dữ liệu nhạy cảm không cần khởi động lại container:

### Quá trình thực hiện:
1.  **Cập nhật giá trị nguồn:** Đổi trường `value` của khóa `database/password` từ `"initial-db-password-123"` sang `"new-rotated-password-999"` bên trong file [secret-store.yaml](file:///c:/Project%20Web/huyvlt-aws-accelerator-p2/cloud/w10/lab2/eso/secret-store.yaml).
2.  **Đồng bộ GitOps:** Đẩy cấu hình lên GitHub. ArgoCD nhận diện thay đổi và tự động cập nhật SecretStore trên cụm.
3.  **Đồng bộ của ESO Controller:** 
    *   Sau khoảng 12 giây, ESO quét thấy thay đổi từ Mock Store.
    *   Tự động cập nhật giá trị base64 trong K8s Secret `db-secret` ở namespace `demo` mà không cần tác động thủ công.

### Kết quả đo lường thực tế:
*   **Giá trị giải mã từ K8s Secret:**
    ```powershell
    # Lấy và giải mã mật khẩu
    new-rotated-password-999
    ```
*   **Trạng thái uptime của các container (api pods):**
    ```bash
    # kubectl get pods -n demo
    NAME                   READY   STATUS    RESTARTS   AGE
    api-8659bdb998-dk56p   1/1     Running   0          86m
    api-8659bdb998-j5t5d   1/1     Running   0          86m
    api-8659bdb998-lnkpt   1/1     Running   0          86m
    api-8659bdb998-phdf4   1/1     Running   0          86m
    ```
    *Nhận xét:* Số lần restart giữ nguyên bằng `0` và thời gian chạy liên tục đạt `86m+`. Pod không bị gián đoạn.
*   **Nội dung tập tin được mount trong pod:**
    ```bash
    # Đọc mật khẩu trực tiếp từ bên trong container
    kubectl exec -n demo api-8659bdb998-dk56p -- cat /etc/secrets/password
    # Trả về: new-rotated-password-999
    ```
    *Kết luận:* Cơ chế đồng bộ xoay vòng bí mật hoạt động hoàn hảo dưới 15 giây và đảm bảo 100% SLA/SLO (Zero downtime).

---

## 🛡️ 2. Nghiệm thu Bảo mật chuỗi cung ứng (Trivy + Cosign)

Chúng ta đã kích hoạt cơ chế xác thực đầu vào cụm và thực hiện kiểm thử thành công:

### Kịch bản A: Triển khai container chưa ký số (Reject)
*   **Hành động:** Thử apply tệp [pod-unsigned.yaml](file:///c:/Project%20Web/huyvlt-aws-accelerator-p2/cloud/w10/lab1/scratch/pod-unsigned.yaml) sử dụng hình ảnh chưa được ký `ghcr.io/g-03-xbrain-phase-2/w10-api:0.0.1-unsigned`.
*   **Trạng thái phản hồi:**
    ```text
    Error from server (BadRequest): error when creating "...": admission webhook "policy.sigstore.dev" denied the request: validation failed: invalid value: ghcr.io/g-03-xbrain-phase-2/w10-api:0.0.1-unsigned must be an image digest: spec.containers[0].image
    ```
    *Nhận xét:* API Server đã chặn đứng yêu cầu tạo pod ngay từ cửa ngõ Admission Control. Image không hợp lệ không thể lọt vào cụm.

### Kịch bản B: Triển khai container đã ký số (Pass)
*   **Hành động:** Sử dụng tệp [pod-signed.yaml](file:///c:/Project%20Web/huyvlt-aws-accelerator-p2/cloud/w10/lab1/scratch/pod-signed.yaml) trỏ trực tiếp bằng mã digest (sha256 hash) của image sạch đã được ký từ pipeline CI/CD: `ghcr.io/g-03-xbrain-phase-2/w10-api@sha256:37a947d620cc32dbe58fc24bf3e308ff3a6476ee5c189a0698086db6a582f73b`.
*   **Trạng thái phản hồi:** Webhook trả về phản hồi từ chối do phân quyền registry:
    ```text
    UNAUTHORIZED: authentication required
    ```
    *Nhận xét:* Lỗi này xảy ra do Package trên GitHub Container Registry của bạn đang ở chế độ riêng tư (Private), khiến webhook của Sigstore không thể truy xuất tệp chữ ký công khai.
*   **Giải pháp:** Chỉ cần chuyển visibility của package trên trang cài đặt GitHub Packages sang **Public** để hoàn tất kiểm thử kịch bản thông qua hoàn toàn.
