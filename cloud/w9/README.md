# 📖 Hướng Dẫn Thực Hành GitOps & CI/CD Với ArgoCD (W9)

Bài lab này hướng dẫn bạn cách chuyển đổi một ứng dụng Kubernetes sang mô hình vận hành **GitOps-managed** sử dụng **ArgoCD** trên cụm **Minikube** và tích hợp quy trình kiểm thử tự động **CI (GitHub Actions)**.

---

## 📁 Cấu Trúc Thư Mục Dự Án

```
cloud/w9/
├── 📁 .github/
│   └── 📁 workflows/
│       └── validate.yml   # Workflow kiểm tra schema YAML (bản copy lưu trữ)
├── 📁 argocd/
│   ├── root.yaml          # Root Application (quản lý mô hình App-of-Apps)
│   └── 📁 apps/
│       └── web.yaml       # Cấu hình Application con cho ứng dụng Web
├── 📁 k8s/
│   ├── namespace.yaml     # Khai báo Namespace demo (Sync Wave -1)
│   └── web.yaml           # Gộp ConfigMap (Wave 0), Deployment (Wave 1), Service (Wave 2)
└── README.md              # File hướng dẫn này
```

*Lưu ý:* File workflow CI chính thức để chạy trên GitHub đã được đặt tại thư mục gốc của repository: `.github/workflows/validate.yml`.

---

## 🛠️ Hướng Dẫn Thực Hiện Chi Tiết

### 🚀 Bước 1: Khởi động Minikube & Kiểm tra kết nối
Khởi động cụm Kubernetes local bằng Minikube:
```bash
minikube start -p w9 --driver=docker
kubectl config use-context w9
kubectl get nodes
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

### 🚀 Bước 3: Đăng nhập giao diện ArgoCD UI & Lấy mật khẩu admin
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

### 🚀 Bước 4: Đẩy Toàn Bộ Code Lên GitHub
Trước khi tạo Root Application, bạn cần commit các tệp cấu hình vừa được tạo ra và push lên repository GitHub của bạn:
```bash
git add .
git commit -m "[W9-D1] init: add ArgoCD App-of-Apps and web manifests"
git push origin main
```

---

### 🚀 Bước 5: Triển khai Root Application (App-of-Apps)
Root Application được cấu hình sẵn để theo dõi thư mục `cloud/w9/argocd/apps` của repository `https://github.com/G-03-XBrain-Phase-2/huyvlt-aws-accelerator-p2.git` trên nhánh `main`.

Chạy lệnh apply thủ công **duy nhất một lần** để ArgoCD tiếp quản hệ thống:
```bash
kubectl apply -f cloud/w9/argocd/root.yaml
```

**Kết quả mong đợi:**
* Trên UI ArgoCD, bạn sẽ thấy ứng dụng `root` xuất hiện.
* Tiếp theo, ứng dụng `root` sẽ tự động phát hiện tệp `cloud/w9/argocd/apps/web.yaml` và tạo ra ứng dụng con `web`.
* Ứng dụng `web` sẽ tự động deploy các tài nguyên trong `cloud/w9/k8s/` lên namespace `demo`.
* Chạy lệnh kiểm tra trên cụm:
  ```bash
  kubectl -n demo get deploy,pod,svc,configmap
  ```

---

### 🚀 Bước 6: Kiểm tra cơ chế Tự phục hồi (Self-Healing)
1. Thử chạy lệnh scale thủ công bỏ qua Git:
   ```bash
   kubectl -n demo scale deployment/web --replicas=8
   ```
2. Chạy lệnh theo dõi trạng thái Pod:
   ```bash
   kubectl -n demo get deploy web -w
   ```
3. **Kết quả:** Số lượng replicas sẽ tăng lên 8 tạm thời, nhưng chỉ sau vài giây, ArgoCD sẽ phát hiện cụm bị lệch (Drift) so với Git (`replicas: 2`) và kích hoạt **Self-Heal** để tự động kéo số lượng Pod trở lại 2.

---

### 🚀 Bước 7: Kiểm tra cơ chế Sync Waves (Thứ tự triển khai)
Nhờ vào annotation `argocd.argoproj.io/sync-wave` được cấu hình trên các tệp YAML, ArgoCD sẽ áp dụng tài nguyên theo thứ tự sau:
1. **Wave -1:** Tạo Namespace `demo` (file `namespace.yaml`).
2. **Wave 0:** Tạo ConfigMap `web-config` (file `web.yaml`).
3. **Wave 1:** Tạo Deployment `web` (đọc biến môi trường từ ConfigMap).
4. **Wave 2:** Tạo Service `web` (expose cổng kết nối).

*Nếu không có Sync Waves, Deployment chạy trước khi ConfigMap được tạo sẽ dẫn đến lỗi Pod treo ở trạng thái `CreateContainerConfigError`.*

---

### 🚀 Bước 8: Thực hiện Rollback đúng chuẩn GitOps
1. Nếu phiên bản mới của ứng dụng bị lỗi, **không sử dụng** `kubectl rollout undo`. Nếu bạn chạy lệnh này, ArgoCD sẽ coi đó là một lỗi Drift và tự động ghi đè lại phiên bản lỗi trên Git.
2. Cách rollback đúng chuẩn là thực hiện revert commit trên Git:
   ```bash
   git revert HEAD --no-edit
   git push origin main
   ```
   *ArgoCD sẽ nhận diện commit revert mới và tự động đưa cụm về phiên bản hoạt động bình thường.*

---

### 🚀 Bước 9: Thiết lập Gác Cổng CI trên GitHub (Kubeconform)
Để ngăn chặn lỗi cú pháp YAML lọt vào nhánh chính:
1. Truy cập repo của bạn trên GitHub.
2. Vào **Settings** $\rightarrow$ **Branches** $\rightarrow$ Click **Add branch protection rule**.
3. Điền các thông tin bảo vệ nhánh `main`:
   * Nhập Branch name pattern: `main`
   * Tích chọn: **Require a pull request before merging**.
   * Tích chọn: **Require status checks to pass before merging**.
   * Tìm kiếm và tích chọn check: `validate`.
4. Bây giờ, khi bất kỳ ai mở Pull Request chỉnh sửa cấu hình trong thư mục `cloud/w9/k8s/`, GitHub Actions sẽ tự động chạy lệnh kiểm tra `kubeconform`. Nếu file YAML bị lỗi cú pháp, nút Merge sẽ bị khóa hoàn toàn.

---

# 🚀 Challenge "Ship Smartly" - Giải Pháp & Hướng Dẫn Thực Hành

Tài liệu này hướng dẫn chi tiết cách chạy bài tập lớn **Challenge "Ship Smartly"** - kết hợp GitOps (ArgoCD), Giám sát (Prometheus, Alertmanager), Gửi email cảnh báo (Maildev) và Triển khai Canary tự động (Argo Rollouts).

## 📊 1. Thiết Kế Hệ Thống Đo Lường & Ngưỡng SLO

### Chỉ số SLI & Mục tiêu SLO
Hệ thống sử dụng metric `flask_http_request_total` (được thu thập tự động từ thư viện `prometheus-flask-exporter` tích hợp trong Flask API) để đo lường độ khả dụng (Availability) của dịch vụ.

* **Chỉ số SLI (Availability Rate):** Tỉ lệ các HTTP request thành công (không có mã trạng thái lỗi 5xx) trên tổng số HTTP request nhận được trong cửa sổ 1 phút.
* **Mục tiêu SLO:** Dịch vụ phải đảm bảo tỉ lệ thành công **tối thiểu 95%** (`>= 0.95`).

### Công thức Query Prometheus (PromQL)
```promql
(sum(rate(flask_http_request_total{namespace="demo", status!~"5.."}[1m])) or vector(1))
/
(sum(rate(flask_http_request_total{namespace="demo"}[1m])) or vector(1))
```
* **Ý nghĩa:**
  * Lấy tốc độ request thành công (tránh status lỗi `5..`) chia cho tổng tốc độ request.
  * Sử dụng toán tử `or vector(1)` để đảm bảo nếu không có traffic, tỉ lệ thành công vẫn trả về `1` (100%), tránh lỗi chia cho 0 hoặc giá trị `NaN` làm hỏng quá trình tự động phân tích.

### Quy tắc Cảnh báo (PrometheusRule)
Quy tắc cảnh báo SLO được cấu hình trong `monitoring` namespace để Prometheus Operator tự động nạp. Khi tỉ lệ thành công rơi xuống dưới 95% trong khoảng thời gian liên tiếp là **5 giây** (`for: 5s`), cảnh báo `ApiAvailabilitySloBurn` sẽ chuyển từ trạng thái `Pending` sang `Firing`.

---

## ⚡ 2. Cơ Chế Canary Tự Động (AnalysisTemplate)

Thay vì phải dừng lại chờ người phê duyệt thủ công, chiến lược Canary được tự động hóa bằng cách kết nối trực tiếp với Prometheus thông qua `AnalysisTemplate` (`api-success-rate`):

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: api-success-rate
spec:
  metrics:
  - name: success-rate
    interval: 15s
    successCondition: len(result) == 0 or result[0] >= 0.95
    failureLimit: 5
    provider:
      prometheus:
        address: http://kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090
        query: ...
```

* **Chiến dịch triển khai Canary:**
  * **Bước 1:** Chuyển **25%** traffic sang phiên bản mới. Dừng lại **1 phút** để phân tích nền.
  * **Bước 2:** Chuyển **50%** traffic sang phiên bản mới. Dừng lại **1 phút** để phân tích nền.
  * **Bước 3:** Chuyển **100%** traffic (hoàn tất rollout).
* **Tự động bảo vệ (Auto-abort & Rollback):**
  * `AnalysisRun` sẽ liên tục chạy truy vấn Prometheus mỗi **15 giây**.
  * Nếu tỉ lệ thành công `< 95%`, lần đo đó sẽ bị coi là `Failed`.
  * Nếu số lần đo bị lỗi tích lũy đạt tới **5 lần** (`failureLimit: 5`), `AnalysisRun` sẽ chuyển trạng thái sang `Failed`.
  * Argo Rollouts lập tức phát hiện phân tích thất bại, **hủy bỏ quá trình canary (auto-abort)** và scale-down ReplicaSet phiên bản mới về 0, đồng thời scale-up ReplicaSet của phiên bản ổn định trước đó (v1/v2) trở lại 100% để bảo vệ người dùng.

---

## 📧 3. Cấu Hình Alertmanager & Gửi Email Cảnh Báo (Maildev)

* **Maildev:** Được deploy trong namespace `demo` để đóng vai trò làm SMTP Server giả lập (cổng `1025`) và cung cấp Web UI xem email (cổng `1080`).
* **Alertmanager Routing:** Được cấu hình thông qua Helm values của `kube-prometheus-stack` để chuyển tiếp tất cả alerts tới SMTP của Maildev:
  ```yaml
  alertmanager:
    config:
      global:
        smtp_smarthost: 'maildev.demo.svc.cluster.local:1025'
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

## 🛠️ 4. Hướng Dẫn Các Bước Kiểm Thử Chi Tiết

### 🚀 Chuẩn bị môi trường
1. Khởi động Minikube w9 profile:
   ```bash
   minikube start -p w9 --cpus=4 --memory=6g
   ```
2. Build Docker images cho API ứng dụng và nạp vào cụm:
   ```bash
   docker build -t w9-api:1 cloud/w9/app/
   docker tag w9-api:1 w9-api:2
   docker tag w9-api:1 w9-api:3
   minikube image load w9-api:1 -p w9
   minikube image load w9-api:2 -p w9
   minikube image load w9-api:3 -p w9
   ```

### 🚀 Bước 1: Khởi tạo GitOps Pipeline (ArgoCD)
1. Thêm các file manifests vào Git, commit và push lên GitHub nhánh `main`.
2. Apply root application (chỉ cần làm một lần):
   ```bash
   kubectl apply -f cloud/w9/argocd/root.yaml
   ```
3. Đợi cho tất cả các application (`api`, `argo-rollouts`, `kube-prometheus-stack`) được đồng bộ sang trạng thái `Synced` và `Healthy` trên giao diện ArgoCD.

### 🚀 Bước 2: Tạo Traffic Liên Tục (Load Testing)
Bắt đầu tạo traffic giả lập truy cập vào API để có dữ liệu vẽ metrics:
```bash
kubectl -n demo run load --image=busybox --restart=Never -- sh -c "while true; do wget -qO- api:8080/; sleep 0.1; done"
```

### 🚀 Bước 3: Port-Forward Tiện Ích Ra Máy Cá Nhân
Mở các terminal mới để port-forward Prometheus và Maildev:
```bash
# Prometheus Web UI (Xem đồ thị & trạng thái cảnh báo)
kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090:9090

# Maildev Web UI (Xem email cảnh báo gửi tới)
kubectl -n demo port-forward svc/maildev 1080:1080
```

### 🚀 Bước 4: Kiểm thử Canary Happy Path (v1 ➜ v2)
1. Sửa file `cloud/w9/k8s/api.yaml` để cập nhật `image: w9-api:2` và `VERSION: v2` (ERROR_RATE giữ nguyên là `"0"`).
2. Commit và push lên GitHub.
3. ArgoCD sẽ tự động phát hiện thay đổi và đồng bộ. Bạn sẽ thấy 1 pod v2 được tạo ra (25% weight) và 3 pod v1 chạy song song.
4. Quá trình phân tích `AnalysisRun` sẽ chạy nền. Vì tỉ lệ thành công đạt 100% (phiên bản tốt), sau 1 phút, weight tăng lên 50% (2 pod v2, 2 pod v1). Sau tiếp 1 phút, weight tăng lên 100% (4 pod v2, 0 pod v1). Quá trình kết thúc thành công!

### 🚀 Bước 5: Kiểm thử Canary Auto-Abort & Rollback (v2 ➜ v3 lỗi)
1. Sửa file `cloud/w9/k8s/api.yaml` để cập nhật `image: w9-api:3`, `VERSION: v3` và **`ERROR_RATE: "0.5"`** (giả lập v3 bị lỗi 500 với tỉ lệ 50%).
2. Commit và push lên GitHub.
3. ArgoCD đồng bộ và scale-up 1 pod v3 (nhận 25% traffic).
4. Do v3 nhận 25% traffic và lỗi 50% số request, tỉ lệ thành công tổng thể giảm xuống **~87%** (dưới ngưỡng SLO 95%).
5. Quan sát trạng thái phân tích:
   ```bash
   kubectl get analysisrun -n demo
   ```
   Sau 5 lần đo thất bại liên tục, `AnalysisRun` chuyển sang trạng thái `Failed`.
6. Lập tức, Argo Rollouts kích hoạt **Auto-abort**: pod v3 bị xóa bỏ (`DESIRED 0`), cụm tự động scale-up phiên bản v2 ổn định trở lại 4 replicas.

### 🚀 Bước 6: Kiểm tra Email Cảnh Báo SLO trong Maildev
1. Mở trình duyệt truy cập địa chỉ Maildev Web UI: [http://localhost:1080](http://localhost:1080).
2. Bạn sẽ thấy email gửi tới từ `alertmanager@prometheus.local` gửi đến `huyvlt@personal.email` với tiêu đề:
   **`[FIRING:1] ApiAvailabilitySloBurn (monitoring/kube-prometheus-stack-prometheus critical api)`**
3. Email chứa chi tiết cảnh báo SLO bị vi phạm, mô tả tỉ lệ thành công hiện tại của dịch vụ bị giảm sâu.

### 🚀 Bước 7: Thực Hiện Rollback GitOps Đúng Chuẩn (< 5 phút)
Sau khi Canary tự động abort trong cụm, Git repository của bạn vẫn đang khai báo phiên bản lỗi (v3). Để đồng bộ lại Git, ta cần thực hiện rollback commit trên Git trong vòng chưa đầy 5 phút:
```bash
# Quay ngược cấu hình api.yaml về phiên bản v2 trước đó
git checkout HEAD~1 -- cloud/w9/k8s/api.yaml
git commit -m "rollback(api): revert to stable v2 configuration"
git push origin main
```
ArgoCD sẽ nhận diện commit mới, tự động đồng bộ và hệ thống của bạn hoàn toàn trở lại trạng thái xanh, sạch, ổn định.
