# Hướng dẫn Vận hành & Nghiệm thu: Lab 2.1 · External Secrets Operator (ESO)

Tài liệu này hướng dẫn cách thực hành, rotate secret và nghiệm thu hệ thống Secret Rotation tự động không gây gián đoạn (no restart pod).

---

## 💡 Cơ chế hoạt động
1. **External Secrets Operator (ESO)**: Theo dõi tài nguyên `ExternalSecret` và định kỳ (`refreshInterval: 15s`) đồng bộ dữ liệu từ nguồn `SecretStore` (Fake Provider để giả lập Secrets Manager) vào K8s Secret `db-secret`.
2. **No-Restart Mount Volume**: Ứng dụng Flask API được cấu hình mount K8s Secret dưới dạng **Volume** (thay vì nạp qua biến môi trường `env`). Kubelet sẽ tự động đồng bộ thay đổi của file `/etc/secrets/password` bên trong container mà không làm tắt/khởi động lại Pod.

---

## 🛠️ Quy trình nghiệm thu (Rotate Secret)

### Bước 1: Kiểm tra trạng thái ban đầu
1. Đảm bảo các app ArgoCD của ESO đã deploy thành công (`external-secrets-operator` và `external-secrets-config`).
2. Xem giá trị K8s Secret hiện tại:
   ```bash
   kubectl get secret db-secret -n demo -o jsonpath='{.data.password}' | base64 --decode
   # Kỳ vọng: initial-db-password-123
   ```
3. Truy cập endpoint `/secret` của API (hoặc exec vào pod để xem file):
   ```bash
   # Tìm tên pod api
   kubectl get pods -n demo -l app=api
   
   # Đọc file password từ bên trong container
   kubectl exec -n demo deploy/api -c api -- cat /etc/secrets/password
   # Kỳ vọng: initial-db-password-123
   ```
4. Kiểm tra thời gian sống (AGE) và số lần Restart của Pod:
   ```bash
   kubectl get pods -n demo -l app=api
   # Lưu ý giá trị cột AGE và RESTARTS (phải là 0)
   ```

---

### Bước 2: Thực hiện xoay vòng (Rotate) Secret
1. Mở file [secret-store.yaml](file:///c:/Project%20Web/huyvlt-aws-accelerator-p2/cloud/w10/eso/secret-store.yaml) và thay đổi giá trị mật khẩu:
   ```yaml
   # Thay đổi từ:
   # value: "initial-db-password-123"
   # thành:
   value: "new-rotated-password-999"
   ```
2. Thực hiện apply trực tiếp lên cụm để thấy kết quả ngay lập tức (hoặc commit/push git để ArgoCD sync):
   ```bash
   kubectl apply -f cloud/w10/eso/secret-store.yaml
   ```

---

### Bước 3: Kiểm chứng kết quả đồng bộ tự động
1. **Kiểm tra K8s Secret (Đồng bộ < 15 giây)**:
   Chạy liên tục lệnh này cho đến khi mật khẩu cập nhật sang giá trị mới:
   ```bash
   kubectl get secret db-secret -n demo -o jsonpath='{.data.password}' | base64 --decode
   # Kỳ vọng: new-rotated-password-999
   ```
2. **Kiểm tra dữ liệu trong Pod (Kubelet sync < 60 giây)**:
   Đợi khoảng 30-45 giây để Kubelet đồng bộ file vào volume của pod, sau đó kiểm tra:
   ```bash
   kubectl exec -n demo deploy/api -c api -- cat /etc/secrets/password
   # Kỳ vọng: new-rotated-password-999
   ```
3. **Kiểm tra Uptime (No Restart)**:
   Kiểm tra lại danh sách pod:
   ```bash
   kubectl get pods -n demo -l app=api
   # Kỳ vọng: AGE của pod vẫn giữ nguyên (không bị reset về vài giây), cột RESTARTS vẫn là 0.
   ```

**Chúc mừng! Bạn đã hoàn thành kiểm thử thành công cơ chế Secret Rotation tự động mà không gây downtime!**
