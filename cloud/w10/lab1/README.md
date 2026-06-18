# 📖 Hướng Dẫn Vận Hành & Nghiệm Thu: Lab 1 (RBAC + Gatekeeper)

Thư mục này chứa toàn bộ tài nguyên cấu hình bảo mật cấp cụm (Cluster-level Security) cho **Lab 1 (Buổi sáng)** bao gồm phân quyền RBAC và kiểm soát chính sách đầu vào Admission Policy với OPA Gatekeeper.

---

## 🏗️ 1. Cấu Trúc Tài Nguyên Lab 1
*   [rbac/](file:///C:/Project%20Web/huyvlt-aws-accelerator-p2/cloud/w10/lab1/rbac/): Định nghĩa Role, ClusterRole và RoleBinding cho Alice, Bob, Carol.
*   [gatekeeper/constraints/](file:///C:/Project%20Web/huyvlt-aws-accelerator-p2/cloud/w10/lab1/gatekeeper/constraints/): Định nghĩa 5 cặp luật (templates & constraints) cấm latest tag, cấm root, cấm hostNetwork, bắt buộc limits và bắt buộc label `owner`.
*   [scratch/](file:///C:/Project%20Web/huyvlt-aws-accelerator-p2/cloud/w10/lab1/scratch/): Các file manifest mẫu (`allowed` và `disallowed`) dùng để kiểm thử nhanh.

---

## 🛠️ 2. Các Bước Khởi Chạy Lab 1

### Bước A: Đẩy code lên GitHub
Để đảm bảo ArgoCD kéo được các cập nhật mới nhất từ repository của bạn, chạy lệnh sau ở terminal:
```powershell
git push origin main
```

### Bước B: Đồng bộ qua GitOps (ArgoCD)
Kiểm tra trạng thái các ứng dụng của Lab 1 trên cụm:
```bash
kubectl get applications -n argocd
```
*   **Kỳ vọng**: Ứng dụng `rbac` và `gatekeeper-constraints` chuyển sang trạng thái **`Synced`** và **`Healthy`**.

### Bước C: Truy cập giao diện ArgoCD UI để giám sát
1.  **Mở Port-forward** (chạy lệnh này trên một cửa sổ terminal mới):
    ```bash
    kubectl -n argocd port-forward svc/argocd-server 8080:443
    ```
2.  **Lấy mật khẩu tài khoản `admin`** (chạy trên PowerShell):
    ```powershell
    kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }; echo ""
    ```
3.  **Đường dẫn truy cập cục bộ**: [https://localhost:8080](https://localhost:8080)

---

## 🧪 3. Hướng Dẫn Kiểm Thử & Nghiệm Thu

### 👥 Phần 3.1: Nghiệm thu RBAC (Lab 1.1)

Chạy các lệnh giả lập quyền truy cập (`--as`) của Kubernetes để xác thực phân quyền:

```powershell
# 1. Alice (Developer) có quyền CRUD workload trong namespace demo? 
# Kết quả kỳ vọng: yes
kubectl auth can-i create deploy -n demo --as alice

# 2. Alice có bị chặn ghi phá ở namespace hệ thống không?
# Kết quả kỳ vọng: no
kubectl auth can-i create deploy -n kube-system --as alice

# 3. Bob (SRE) có xem được pods toàn cụm để cứu hộ?
# Kết quả kỳ vọng: yes
kubectl auth can-i get pods -A --as bob

# 4. Carol (Viewer) có quyền xóa node hay thay đổi hạ tầng không?
# Kết quả kỳ vọng: no
kubectl auth can-i delete nodes --as carol
```

---

### 🛡️ Phần 3.2: Nghiệm thu Admission Policy (Lab 1.2 & 1.3)

Sử dụng các manifest mẫu trong thư mục `scratch/` để kiểm chứng xem API Server có chặn đứng các hành vi vi phạm chính sách bảo mật hay không.

#### ❌ Thử nghiệm các manifest VI PHẠM (Phải bị chặn - REJECT)

Chạy các lệnh sau, bạn phải nhận được thông báo lỗi từ webhook từ chối tạo tài nguyên:

1.  **Chặn tag `:latest`**:
    ```bash
    kubectl apply -f cloud/w10/lab1/scratch/pod-disallowed-latest.yaml
    ```
    *   *Thông báo lỗi*: `uses disallowed image tag 'latest'...`

2.  **Chặn Pod thiếu resources limits**:
    ```bash
    kubectl apply -f cloud/w10/lab1/scratch/pod-disallowed-limits.yaml
    ```
    *   *Thông báo lỗi*: `does not have CPU/Memory limits specified.`

3.  **Chặn container chạy root (`runAsUser: 0`)**:
    ```bash
    kubectl apply -f cloud/w10/lab1/scratch/pod-disallowed-root.yaml
    ```
    *   *Thông báo lỗi*: `runAsUser cannot be 0 (root).`

4.  **Chặn Pod sử dụng host network (`hostNetwork: true`)**:
    ```bash
    kubectl apply -f cloud/w10/lab1/scratch/pod-disallowed-hostnetwork.yaml
    ```
    *   *Thông báo lỗi*: `Using hostNetwork is disallowed.`

5.  **Chặn Deployment thiếu label `owner` (Custom Policy)**:
    ```bash
    kubectl apply -f cloud/w10/lab1/scratch/deploy-disallowed-owner.yaml
    ```
    *   *Thông báo lỗi*: `Workload missing required labels: {"owner"}`

---

####  Thử nghiệm các manifest HỢP LỆ (Phải thành công - PASS)

Chạy thử các lệnh sau để đảm bảo các tài nguyên tuân thủ quy tắc vẫn triển khai bình thường:

```bash
# Pod hợp lệ
kubectl apply -f cloud/w10/lab1/scratch/pod-allowed.yaml

# Deployment hợp lệ
kubectl apply -f cloud/w10/lab1/scratch/deploy-allowed.yaml
```
*   **Kỳ vọng**: Trả về trạng thái `created` thành công.
