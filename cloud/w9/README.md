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
