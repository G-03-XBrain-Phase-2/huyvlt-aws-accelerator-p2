# 🏆 Challenge "Ship Smartly" - Canary Deployment & Observability Pipeline

Tài liệu này hướng dẫn chi tiết cách triển khai, vận hành và kiểm thử giải pháp cho bài tập lớn **Challenge W9 "Ship Smartly"**. Giải pháp này thiết lập một quy trình phân phối ứng dụng an toàn khép kín thông qua mô hình **GitOps (ArgoCD)**, phát hành dạng **Canary (Argo Rollouts)** kết hợp đo lường thời gian thực **(Prometheus SLO)**, tự động hủy bỏ khi có sự cố **(Auto-Abort)** và gửi email cảnh báo **(Alertmanager & Maildev)**.

---

## 🏗️ 1. Thiết Kế Hệ Thống & Các Thành Phần Cốt Lõi

Để đảm bảo tính tối giản và tập trung đúng vào tiêu chí đánh giá của Challenge, giải pháp loại bỏ hoàn toàn tầng Frontend (Nginx) dư thừa, chỉ tập trung thiết lập hạ tầng cho dịch vụ API Backend:

### A. Sơ đồ luồng hoạt động (Architecture Flow)
```
Git Repository (main) 
  └──> ArgoCD Root App (App-of-Apps)
        ├──> App: Argo Rollouts Controller
        ├──> App: Kube-Prometheus-Stack (Prometheus & Alertmanager)
        └──> App: Backend API & Observability Manifests
              ├──> Namespace: argocd-test (Chạy workloads)
              ├──> Service & ServiceMonitor (Prometheus thu thập metrics)
              ├──> Argo Rollout & AnalysisTemplate (Canary & tự động đo lường)
              ├──> PrometheusRule (Quy tắc cảnh báo SLO Availability < 95%)
              └──> Maildev (SMTP Server giả lập để nhận email alert)
```

### B. Chỉ số SLI/SLO & Công thức PromQL
Hệ thống sử dụng metric `flask_http_request_total` (được thư viện `prometheus-flask-exporter` xuất ra từ Flask API) để đo lường chất lượng dịch vụ:
* **Chỉ số SLI (Availability Rate):** Tỉ lệ HTTP request thành công (không phải mã lỗi 5xx) trên tổng số HTTP request nhận được trong cửa sổ 1 phút.
* **Mục tiêu SLO:** Đảm bảo tỉ lệ thành công **tối thiểu 95%** (`>= 0.95`).
* **Công thức PromQL:**
  ```promql
  (sum(rate(flask_http_request_total{namespace="argocd-test", status!~"5.."}[1m])) or vector(1))
  /
  (sum(rate(flask_http_request_total{namespace="argocd-test"}[1m])) or vector(1))
  ```
  * *Giải thích:* Lấy tổng tốc độ các request thành công chia cho tổng số request nhận được. Phép toán `or vector(1)` đảm bảo khi không có traffic chạy qua hệ thống, tỉ lệ thành công mặc định trả về `1` (100%), tránh lỗi chia cho 0 (`NaN`) làm sai lệch quá trình tự động phân tích Canary.

### C. Cơ Chế Canary Tự Động (AnalysisTemplate)
Thay vì phê duyệt thủ công, quá trình thăng cấp (promotion) của Canary được Argo Rollouts giao phó cho `AnalysisTemplate` (`api-success-rate`):
* **Chu kỳ kiểm tra:** Chạy truy vấn Prometheus liên tục mỗi **15 giây**.
* **Điều kiện thành công:** Giá trị PromQL trả về phải `>= 0.95` (SLO 95%).
* **Giới hạn lỗi (`failureLimit: 5`):** Nếu phát hiện tỉ lệ thành công rơi xuống dưới 95% tích lũy đủ 5 lần, `AnalysisRun` sẽ đổi trạng thái sang `Failed`.
* **Phản ứng hủy bỏ (Auto-Abort):** Argo Rollouts phát hiện Analysis Run thất bại, lập tức hủy bỏ quá trình Canary, lập tức scale-down phiên bản mới về 0 pod và scale-up phiên bản ổn định trước đó lên 100% để bảo vệ người dùng dưới 3 phút.

### D. Định Tuyến Cảnh Báo (Alertmanager & Maildev)
* **PrometheusRule (`ApiAvailabilitySloBurn`):** Nếu tỉ lệ thành công giảm dưới 95% trong 5 giây liên tiếp, cảnh báo chuyển sang trạng thái `Firing`.
* **Alertmanager Routing:** Được cấu hình chuyển tiếp email thông qua SMTP của Maildev chạy trong cụm:
  * **SMTP Host:** `maildev.argocd-test.svc.cluster.local:1025`
  * **Email gửi đi:** `alertmanager@prometheus.local`

---

## 🛠️ 2. Hướng Dẫn Các Bước Triển Khai Step-by-Step

### Bước 1: Khởi động Minikube với tài nguyên tối ưu
Khởi động cụm Kubernetes local bằng Minikube với cấu hình đủ mạnh để chạy trơn tru Prometheus Stack, ArgoCD và Argo Rollouts:
```bash
minikube start -p w9 --cpus=4 --memory=6g --driver=docker
kubectl config use-context w9
```

### Bước 2: Build các Docker Images cho API Backend
Build Docker image cho API từ thư mục `backend/` và nạp trực tiếp vào cụm Minikube:
```bash
# Build image v1 gốc
docker build -t argocd-test-backend:v1 cloud/w9/backend/

# Tạo tag v2 (chạy tốt) và v3 (giả lập lỗi) từ cùng một codebase
docker tag argocd-test-backend:v1 argocd-test-backend:v2
docker tag argocd-test-backend:v1 argocd-test-backend:v3

# Nạp images vào Minikube w9
minikube image load argocd-test-backend:v1 -p w9
minikube image load argocd-test-backend:v2 -p w9
minikube image load argocd-test-backend:v3 -p w9
```

### Bước 3: Cài đặt ArgoCD lên Cụm
1. Tạo namespace cho ArgoCD:
   ```bash
   kubectl create ns argocd
   ```
2. Cài đặt ArgoCD bằng phương thức server-side apply:
   ```bash
   kubectl apply --server-side -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
   ```
3. Chờ cho đến khi ArgoCD Server sẵn sàng:
   ```bash
   kubectl -n argocd rollout status deploy/argocd-server
   ```

### Bước 4: Lấy mật khẩu Admin & Port-Forward ArgoCD UI
1. Lấy mật khẩu tài khoản `admin`:
   ```powershell
   # PowerShell (Windows)
   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }; echo ""
   ```
2. Port-forward ArgoCD Server:
   ```bash
   kubectl -n argocd port-forward svc/argocd-server 8080:443
   ```
   *Truy cập giao diện quản lý tại:* [https://localhost:8080](https://localhost:8080)

### Bước 5: Đẩy code lên GitHub & Kích hoạt GitOps Pipeline
Khai báo Root Application (mô hình App-of-Apps) duy nhất một lần để ArgoCD tự động quét và cài đặt toàn bộ hệ thống:
```bash
kubectl apply -f cloud/w9/gitops/root-app.yaml
```
*Trạng thái mong đợi:* Trên giao diện ArgoCD UI xuất hiện `root-app-argocd-test`, tự động đồng bộ và cài đặt 3 ứng dụng con: `argo-rollouts`, `kube-prometheus-stack`, và `argocd-test-be`.

---

## 🧪 3. Các Kịch Bản Kiểm Thử & Xác Minh SLO

### Kịch Bản 1: Giả lập Traffic liên tục (Load Testing)
Để Prometheus và Analysis Run có dữ liệu đo đạc liên tục, chạy một Pod gửi request liên tục tới dịch vụ backend API:
```bash
kubectl -n argocd-test run load --image=busybox --restart=Never -- sh -c "while true; do wget -qO- backend:8080/; sleep 0.1; done"
```
*(Yêu cầu bắt buộc phải chạy Pod này trong suốt quá trình test Canary).*

### Kịch Bản 2: Thiết lập Port-Forwarding tiện ích ngoài máy
Mở thêm 2 cửa sổ terminal để port-forward Prometheus và hòm thư Maildev ra ngoài máy cá nhân:
```bash
# Terminal 1: Prometheus Web UI (Xem đồ thị metric và Alert trạng thái)
kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090:9090

# Terminal 2: Maildev Web UI (Hòm thư email nhận cảnh báo)
kubectl -n argocd-test port-forward svc/maildev 1080:1080
```
* Prometheus: [http://localhost:9090](http://localhost:9090)
* Maildev UI: [http://localhost:1080](http://localhost:1080)

### Kịch Bản 3: Canary Happy Path (Nâng cấp tự động v1 ➜ v2 tốt)
1. Sửa file `cloud/w9/k8s/backend/backend-deployment.yaml`:
   * Đổi `image: argocd-test-backend:v2`
   * Đổi biến `VERSION` sang `v2`
   * Giữ nguyên `ERROR_RATE: "0"` (không lỗi)
2. Commit và push lên GitHub để kích hoạt GitOps:
   ```bash
   git add cloud/w9/k8s/backend/backend-deployment.yaml
   git commit -m "deploy: upgrade backend to v2"
   git push origin main
   ```
3. **Quan sát:**
   * Argo Rollouts sẽ chia traffic: gửi **25%** sang v2. Một AnalysisRun mới được khởi tạo và chạy ngầm.
   * Sau 1 phút phân tích thành công (success-rate 100%), traffic tăng lên **50%** và phân tích tiếp 1 phút.
   * Kết thúc phân tích tốt, hệ thống tự động thăng cấp lên **100%** traffic sang v2 mà không gặp bất kỳ lỗi nào.

### Kịch Bản 4: Canary Auto-Abort & Rollback (Nâng cấp v2 ➜ v3 lỗi)
1. Sửa file `cloud/w9/k8s/backend/backend-deployment.yaml` để cập nhật bản lỗi:
   * Đổi `image: argocd-test-backend:v3`
   * Đổi biến `VERSION` sang `v3`
   * Cập nhật **`ERROR_RATE: "0.5"`** (giả lập v3 bị lỗi 500 với tỉ lệ 50%)
2. Commit và push lên GitHub:
   ```bash
   git add cloud/w9/k8s/backend/backend-deployment.yaml
   git commit -m "deploy: upgrade backend to v3 (failing version)"
   git push origin main
   ```
3. **Quan sát:**
   * Cụm bắt đầu Canary v3 (chiếm 25% traffic). Vì pod v3 lỗi 50%, tỉ lệ request thành công tổng thể giảm xuống **~87%** (nhỏ hơn ngưỡng SLO 95%).
   * AnalysisRun chạy kiểm tra mỗi 15 giây phát hiện vi phạm. Tích lũy đủ **5 lần** đo thất bại liên tiếp, `AnalysisRun` chuyển trạng thái sang `Failed`.
   * Argo Rollouts kích hoạt **Auto-Abort**: Lập tức thu hồi v3, khôi phục bản stable `v2` lên 100% traffic để bảo vệ người dùng cuối.

### Kịch Bản 5: Kiểm tra Email Cảnh Báo SLO trong Maildev
1. Mở trình duyệt vào Maildev Web UI: [http://localhost:1080](http://localhost:1080).
2. Khi Canary v3 gặp lỗi, Prometheus Rule `ApiAvailabilitySloBurn` sẽ chuyển sang trạng thái `Firing` sau 5 giây.
3. Alertmanager phát hiện alert Firing, lập tức gửi email cảnh báo thông báo SLO bị vi phạm về hòm thư Maildev với tiêu đề dạng:
   **`[FIRING:1] ApiAvailabilitySloBurn (monitoring/kube-prometheus-stack-prometheus critical api)`**

### Kịch Bản 6: Thực Hiện Rollback GitOps Đúng Chuẩn (< 5 phút)
Khi quá trình Auto-Abort hoàn thành, cụm Kubernetes đã an toàn chạy bản stable `v2`. Tuy nhiên, cấu hình trên Git vẫn đang chỉ định bản lỗi `v3` (gây ra tình trạng Drift).

Để đồng bộ cấu hình trên Git khớp với cụm Kubernetes, bạn **không được** dùng `kubectl rollout undo` mà phải revert commit trên Git trong vòng dưới 5 phút:
```bash
# Checkout tệp cấu hình trở lại trạng thái của commit trước đó (v2)
git checkout HEAD~1 -- cloud/w9/k8s/backend/backend-deployment.yaml
git commit -m "rollback(backend): revert to stable v2 configuration"
git push origin main
```
ArgoCD tự động phát hiện commit mới, đồng bộ sạch sẽ trạng thái, đưa hệ thống trở lại trạng thái xanh hoàn toàn không còn lệch cấu hình.
