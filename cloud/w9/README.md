# 📖 Hướng Dẫn Thực Hành GitOps & CI/CD Với ArgoCD (W9)

Bài lab này hướng dẫn bạn cách vận hành ứng dụng Kubernetes theo mô hình **GitOps-managed** sử dụng **ArgoCD**, tích hợp quy trình phát hành **Canary Deployment (Argo Rollouts)**, đo lường **SLO (Prometheus)** và gửi cảnh báo **SLO Burn (Alertmanager & Maildev)** trên cụm **Minikube**.

---

## 📁 Cấu Trúc Thư Mục Dự Án (Đã Tối Giản)

Để tập trung hoàn toàn vào mục tiêu của Challenge "Ship Smartly", dự án đã được tinh chỉnh loại bỏ tầng Frontend dư thừa, chỉ giữ lại API Backend được cấu hình toàn bộ qua GitOps:

```
cloud/w9/
├── 📁 .github/
│   └── 📁 workflows/
│       └── validate.yml             # Workflow kiểm tra schema YAML (CI)
├── 📁 backend/
│   ├── app.py                       # Flask API application với endpoint /metrics
│   └── Dockerfile                   # Dockerfile của backend
├── 📁 gitops/
│   ├── root-app.yaml                # Root Application (quản lý mô hình App-of-Apps)
│   └── 📁 apps/
│       ├── argo-rollouts.yaml       # Application quản lý controller Argo Rollouts
│       ├── be-app.yaml              # Application quản lý backend API & K8s resources
│       └── kube-prometheus-stack.yaml # Application quản lý Prometheus stack
├── 📁 k8s/
│   ├── 📁 backend/
│   │   ├── analysis-template.yaml   # AnalysisTemplate tự động đo lường success-rate Canary
│   │   ├── backend-config.yaml      # ConfigMap chứa cấu hình môi trường (Sync Wave 1)
│   │   ├── backend-deployment.yaml  # Argo Rollout cấu hình Canary (Sync Wave 2)
│   │   ├── backend-service.yaml     # Service expose cổng backend (Sync Wave 3)
│   │   ├── kustomization.yaml       # Cấu hình Kustomize cho backend
│   │   ├── maildev.yaml             # Maildev SMTP server & UI phục vụ nhận mail alert
│   │   ├── namespace.yaml           # Namespace argocd-test (Sync Wave 0)
│   │   ├── prometheus-rules.yaml    # Định nghĩa PrometheusRule SLO Alerting
│   │   └── servicemonitor.yaml      # ServiceMonitor để Prometheus Operator scrape metrics
│   └── kustomization.yaml           # Root kustomization referencing backend folder
└── README.md                        # Hướng dẫn này
```

---

## 🛠️ Hướng Dẫn Thực Hiện Chi Tiết

### 🚀 Bước 1: Khởi động Minikube & Chuẩn bị Môi trường
Khởi động cụm Kubernetes local bằng Minikube với cấu hình tài nguyên đủ lớn:
```bash
minikube start -p w9 --cpus=4 --memory=6g --driver=docker
kubectl config use-context w9
```

---

### 🚀 Bước 2: Cài đặt ArgoCD lên Cụm
1. Tạo namespace riêng cho ArgoCD:
   ```bash
   kubectl create ns argocd
   ```
2. Cài đặt ArgoCD sử dụng phương pháp server-side apply (tránh lỗi giới hạn annotation):
   ```bash
   kubectl apply --server-side -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
   ```
3. Chờ cho đến khi tất cả các Pod của ArgoCD ở trạng thái `Running`:
   ```bash
   kubectl -n argocd rollout status deploy/argocd-server
   ```

---

### 🚀 Bước 3: Lấy Mật khẩu Admin & Port-Forward ArgoCD UI
1. Lấy mật khẩu đăng nhập ban đầu của tài khoản `admin`:
   ```powershell
   # Dành cho Windows PowerShell:
   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }; echo ""
   ```
2. Thực hiện port-forward dịch vụ ArgoCD Server ra máy cá nhân:
   ```bash
   kubectl -n argocd port-forward svc/argocd-server 8080:443
   ```
3. Mở trình duyệt web truy cập địa chỉ: [https://localhost:8080](https://localhost:8080)
   * **Username:** `admin`
   * **Password:** Sử dụng mật khẩu vừa lấy được ở bước trên.

---

### 🚀 Bước 4: Chuẩn Bị Docker Images Cho API
Build các tag image cho các phiên bản kiểm thử Canary và load thẳng vào cụm Minikube:
```bash
# Đứng tại thư mục cloud/w9/backend
docker build -t argocd-test-backend:v1 .
docker tag argocd-test-backend:v1 argocd-test-backend:v2
docker tag argocd-test-backend:v1 argocd-test-backend:v3

# Nạp images vào profile w9
minikube image load argocd-test-backend:v1 -p w9
minikube image load argocd-test-backend:v2 -p w9
minikube image load argocd-test-backend:v3 -p w9
```

---

### 🚀 Bước 5: Triển khai Root Application (App-of-Apps)
Root Application được cấu hình để theo dõi thư mục `cloud/w9/gitops/apps` trên nhánh `main` của repository.

Chạy lệnh apply thủ công **duy nhất một lần** để ArgoCD tiếp quản hệ thống:
```bash
kubectl apply -f cloud/w9/gitops/root-app.yaml
```

**Kết quả mong đợi:**
* Trên UI ArgoCD, bạn sẽ thấy ứng dụng `root-app-argocd-test` xuất hiện.
* Tiếp theo, ứng dụng `root` sẽ tự động phát hiện các tệp trong `gitops/apps/` và tạo ra 3 ứng dụng con:
  * `argo-rollouts`
  * `kube-prometheus-stack`
  * `argocd-test-be`
* Trạng thái đồng bộ tự động sẽ deploy toàn bộ hạ tầng K8s cần thiết lên namespace `argocd-test`.

---

### 🚀 Bước 6: Kiểm tra cơ chế Tự phục hồi (Self-Healing)
1. Thử chạy lệnh scale thủ công bỏ qua Git:
   ```bash
   kubectl -n argocd-test scale rollout/backend --replicas=8
   ```
2. Chạy lệnh theo dõi trạng thái Rollout:
   ```bash
   kubectl -n argocd-test get rollout backend -w
   ```
3. **Kết quả:** Số lượng replicas sẽ tăng lên 8 tạm thời, nhưng chỉ sau vài giây, ArgoCD sẽ phát hiện cụm bị lệch (Drift) so với Git (`replicas: 4`) và kích hoạt **Self-Heal** để tự động kéo số lượng Pod trở lại 4.

---

### 🚀 Bước 7: Kiểm tra cơ chế Sync Waves (Thứ tự triển khai)
Nhờ vào annotation `argocd.argoproj.io/sync-wave` được cấu hình trên các tệp YAML, ArgoCD sẽ áp dụng tài nguyên theo thứ tự sau:
1. **Wave 0:** Tạo Namespace `argocd-test` (file `namespace.yaml`).
2. **Wave 1:** Tạo ConfigMap `backend-config` (file `backend-config.yaml`).
3. **Wave 2:** Tạo Rollout `backend` (đọc biến môi trường từ ConfigMap).
4. **Wave 3:** Tạo Service `backend` (expose cổng kết nối).

*Thứ tự này giúp đảm bảo Rollout chạy sau khi ConfigMap được tạo, tránh lỗi Pod khởi động thiếu cấu hình.*

---

# 🚀 Challenge "Ship Smartly" - Giải Pháp & Hướng Dẫn Thực Hành

Tài liệu này hướng dẫn chi tiết cách vận hành và kiểm thử các kịch bản của bài tập lớn **Challenge "Ship Smartly"**.

## 📊 1. Thiết Kế Hệ Thống Đo Lường & Ngưỡng SLO

### Chỉ số SLI & Mục tiêu SLO
Hệ thống sử dụng metric `flask_http_request_total` (thu thập tự động từ thư viện `prometheus-flask-exporter` tích hợp trong Flask API) để đo lường độ khả dụng (Availability) của dịch vụ.

* **Chỉ số SLI (Availability Rate):** Tỉ lệ các HTTP request thành công (không có mã trạng thái lỗi 5xx) trên tổng số HTTP request nhận được trong cửa sổ 1 phút.
* **Mục tiêu SLO:** Dịch vụ phải đảm bảo tỉ lệ thành công **tối thiểu 95%** (`>= 0.95`).

### Công thức Query Prometheus (PromQL)
```promql
(sum(rate(flask_http_request_total{namespace="argocd-test", status!~"5.."}[1m])) or vector(1))
/
(sum(rate(flask_http_request_total{namespace="argocd-test"}[1m])) or vector(1))
```
* **Ý nghĩa:**
  * Lấy tốc độ request thành công (tránh status lỗi `5..`) chia cho tổng tốc độ request.
  * Sử dụng toán tử `or vector(1)` để đảm bảo nếu không có traffic, tỉ lệ thành công vẫn trả về `1` (100%), tránh lỗi chia cho 0 hoặc giá trị `NaN` làm hỏng quá trình tự động phân tích.

### Quy tắc Cảnh báo (PrometheusRule)
Quy tắc cảnh báo SLO được cấu hình trong namespace `argocd-test` ( PrometheusRule tự động nạp qua Label selector). Khi tỉ lệ thành công rơi xuống dưới 95% trong khoảng thời gian liên tiếp là **5 giây** (`for: 5s`), cảnh báo `ApiAvailabilitySloBurn` sẽ chuyển sang trạng thái `Firing`.

---

## ⚡ 2. Cơ Chế Canary Tự Động (AnalysisTemplate)

Chiến lược Canary được tự động hóa bằng cách kết nối trực tiếp với Prometheus thông qua `AnalysisTemplate` (`api-success-rate`):

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: api-success-rate
  namespace: argocd-test
spec:
  metrics:
  - name: success-rate
    interval: 15s
    successCondition: len(result) == 0 or result[0] >= 0.95
    failureLimit: 5
    provider:
      prometheus:
        address: http://kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090
        query: |
          (sum(rate(flask_http_request_total{namespace="argocd-test",status!~"5.."}[1m])) or vector(1))
          /
          (sum(rate(flask_http_request_total{namespace="argocd-test"}[1m])) or vector(1))
```

* **Chiến dịch triển khai Canary:**
  * **Bước 1:** Chuyển **25%** traffic sang phiên bản mới. Dừng lại **1 phút** để phân tích nền.
  * **Bước 2:** Chuyển **50%** traffic sang phiên bản mới. Dừng lại **1 phút** để phân tích nền.
  * **Bước 3:** Chuyển **100%** traffic (hoàn tất rollout).
* **Tự động bảo vệ (Auto-abort & Rollback):**
  * `AnalysisRun` sẽ liên tục chạy truy vấn Prometheus mỗi **15 giây**.
  * Nếu tỉ lệ thành công `< 95%`, lần đo đó sẽ bị coi là `Failed`.
  * Nếu số lần đo bị lỗi tích lũy đạt tới **5 lần** (`failureLimit: 5`), `AnalysisRun` sẽ chuyển trạng thái sang `Failed`.
  * Argo Rollouts lập tức phát hiện phân tích thất bại, **hủy bỏ quá trình canary (auto-abort)** và scale-down ReplicaSet phiên bản mới về 0, đồng thời scale-up ReplicaSet của phiên bản ổn định trước đó trở lại 100% để bảo vệ người dùng.

---

## 📧 3. Cấu Hình Alertmanager & Gửi Email Cảnh Báo (Maildev)

* **Maildev:** Được deploy trong namespace `argocd-test` đóng vai trò làm SMTP Server giả lập (cổng `1025`) và cung cấp Web UI xem email (cổng `1080`).
* **Alertmanager Routing:** Được cấu hình thông qua Helm values của `kube-prometheus-stack` để chuyển tiếp tất cả alerts tới SMTP của Maildev:
  ```yaml
  alertmanager:
    config:
      global:
        smtp_smarthost: 'maildev.argocd-test.svc.cluster.local:1025'
        smtp_from: 'alertmanager@prometheus.local'
        smtp_require_tls: false
      route:
        receiver: 'email-notifications'
      receivers:
        - name: 'email-notifications'
          email_configs:
            - to: 'huyvlt@personal.email'
  ```

---

## 🧪 4. Hướng Dẫn Các Bước Kiểm Thử Chi Tiết

### 🚀 Bước 1: Tạo Traffic Liên Tục (Load Testing)
Bắt đầu tạo traffic giả lập truy cập vào backend API:
```bash
kubectl -n argocd-test run load --image=busybox --restart=Never -- sh -c "while true; do wget -qO- backend:8080/; sleep 0.1; done"
```
* **Mục đích:** Chạy một Pod tên là `load` liên tục gửi các HTTP request tới dịch vụ `backend` cứ mỗi `0.1 giây`. Lệnh này cực kỳ quan trọng để Prometheus liên tục thu thập metrics chất lượng dịch vụ (SLI/SLO) phục vụ chấm điểm tự động.

### 🚀 Bước 2: Port-Forward Tiện Ích Ra Máy Cá Nhân
Mở các terminal mới để port-forward Prometheus và Maildev:
```bash
# Terminal 1: Port-forward Prometheus Web UI
kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090:9090

# Terminal 2: Port-forward Maildev Web UI để xem hòm thư email cảnh báo
kubectl -n argocd-test port-forward svc/maildev 1080:1080
```
* Prometheus: [http://localhost:9090](http://localhost:9090)
* Maildev UI: [http://localhost:1080](http://localhost:1080)

### 🚀 Bước 3: Kiểm thử Canary Happy Path (v1 ➜ v2)
1. Sửa file `cloud/w9/k8s/backend/backend-deployment.yaml` để cập nhật `image: argocd-test-backend:v2`, `VERSION: v2` và `ERROR_RATE: "0"`.
2. **Commit và push lên GitHub:**
   ```bash
   git add cloud/w9/k8s/backend/backend-deployment.yaml
   git commit -m "deploy: upgrade backend API to v2"
   git push origin main
   ```
3. Do phiên bản `v2` hoàn toàn tốt (tỉ lệ thành công 100%), bạn sẽ thấy `AnalysisRun` đo lường thành công nền. Trọng số traffic tự động tăng dần từ `25%` ➜ `50%` ➜ `100%` hoàn thành thăng cấp tự động mà không cần can thiệp thủ công.

### 🚀 Bước 4: Kiểm thử Canary Auto-Abort & Rollback (v2 ➜ v3 lỗi)
1. Sửa file `cloud/w9/k8s/backend/backend-deployment.yaml` để cập nhật `image: argocd-test-backend:v3`, `VERSION: v3` và **`ERROR_RATE: "0.5"`** (giả lập v3 bị lỗi 50% số request).
2. **Commit và push lên GitHub:**
   ```bash
   git add cloud/w9/k8s/backend/backend-deployment.yaml
   git commit -m "deploy: upgrade backend API to v3 (failing version)"
   git push origin main
   ```
3. ArgoCD đồng bộ và scale-up 1 pod v3 (nhận 25% traffic). Pod v3 lỗi 50% dẫn đến tỉ lệ thành công tổng thể của dịch vụ giảm xuống ~87% (nhỏ hơn SLO 95%).
4. **Quan sát trạng thái phân tích tự động:**
   ```bash
   kubectl get analysisrun -n argocd-test
   ```
   Sau 5 lần đo bị lỗi liên tiếp (vượt quá `failureLimit: 5`), quá trình Canary tự động hủy bỏ (**Auto-abort**). Pod v3 bị xóa bỏ, cụm tự động khôi phục scale-up bản ổn định `v2` trở lại 100%.

### 🚀 Bước 5: Kiểm tra Email Cảnh Báo SLO trong Maildev
1. Mở trình duyệt truy cập địa chỉ Maildev Web UI: [http://localhost:1080](http://localhost:1080).
2. Khi Canary v3 gặp lỗi, Prometheus Rule `ApiAvailabilitySloBurn` sẽ chuyển trạng thái sang `Firing` sau 5 giây.
3. Alertmanager tự động gửi email cảnh báo tới SMTP Maildev với tiêu đề:
   **`[FIRING:1] ApiAvailabilitySloBurn (monitoring/kube-prometheus-stack-prometheus critical api)`**

### 🚀 Bước 6: Thực Hiện Rollback GitOps Đúng Chuẩn (< 5 phút)
Sau khi cụm Kubernetes đã tự khôi phục an toàn, cấu hình trên Git vẫn đang là bản lỗi `v3`. Bạn cần rollback Git để khớp với cụm, triệt tiêu sự lệch cấu hình (Drift):
```bash
# Quay ngược cấu hình backend-deployment.yaml về phiên bản v2 trước đó
git checkout HEAD~1 -- cloud/w9/k8s/backend/backend-deployment.yaml
git commit -m "rollback(backend): revert to stable v2 configuration"
git push origin main
```
ArgoCD sẽ nhận diện commit mới, tự động đồng bộ và hệ thống của bạn hoàn toàn trở lại trạng thái xanh, sạch, ổn định.
