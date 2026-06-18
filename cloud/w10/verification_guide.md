# 📖 Hướng Dẫn Vận Hành & Kiểm Thử: Lab 1 (RBAC + Gatekeeper)

Tài liệu này hướng dẫn cách chạy lab, kiểm tra tính đúng đắn và xác nhận bạn đã hoàn thành bài Lab 1 (gồm RBAC, 4 chính sách OPA Gatekeeper và 1 Custom Policy bắt buộc label `owner`).

---

## 🛠️ 1. Các bước kích hoạt và đồng bộ cụm

### Bước A: Đẩy thay đổi mới lên GitHub
Trong cửa sổ terminal của bạn, hãy chạy lệnh dưới đây để đẩy cấu hình sửa lỗi phiên bản `policy-controller` lên repo:
```powershell
git push origin main
```

### Bước B: Đợi ArgoCD đồng bộ
Truy cập vào giao diện ArgoCD hoặc kiểm tra trạng thái ứng dụng trên cụm:
```bash
kubectl get applications -n argocd
```
*   **Mục tiêu**: Ứng dụng `rbac` và `gatekeeper-constraints` chuyển sang trạng thái **`Synced`** và **`Healthy`**.
*   *Lưu ý*: Với namespace `external-secrets` và `cosign-system` (cho policy controller), hệ thống sẽ mất khoảng 1-2 phút để tự động tải các Helm chart và khởi chạy các pods.

---

## 🧪 2. Cách kiểm tra và nghiệm thu các phần Lab

### 👥 Phần 1: Nghiệm thu phân quyền RBAC (Lab 1.1)

Sử dụng lệnh giả lập quyền (`impersonation` qua tham số `--as`) của Kubernetes để xác minh đặc quyền của 3 vai trò:

| Lệnh Kiểm Tra | Ý Nghĩa | Kết Quả Kỳ Vọng |
| :--- | :--- | :---: |
| `kubectl auth can-i create deploy -n demo --as alice` | Kiểm tra **alice** có được tạo ứng dụng ở namespace `demo`? | **`yes`** |
| `kubectl auth can-i create deploy -n kube-system --as alice` | Kiểm tra **alice** có bị chặn phá hoại ở namespace hệ thống? | **`no`** |
| `kubectl auth can-i get pods -A --as bob` | Kiểm tra **bob (SRE)** có xem được pods toàn cụm để ứng cứu? | **`yes`** |
| `kubectl auth can-i delete nodes --as carol` | Kiểm tra **carol (Viewer)** có bị cấm can thiệp hạ tầng/xóa node? | **`no`** |

> [!TIP]
> **Cách chạy nhanh**: Bạn có thể copy/paste trực tiếp các lệnh trên vào terminal để đối chiếu kết quả trả về `yes` hoặc `no`.

---

### 🛡️ Phần 2: Nghiệm thu Chính sách Bảo mật OPA Gatekeeper (Lab 1.2 & 1.3)

Trong thư mục [cloud/w10/lab1/scratch/](file:///C:/Project%20Web/huyvlt-aws-accelerator-p2/cloud/w10/lab1/scratch/) đã chuẩn bị sẵn các manifest mẫu để bạn test nhanh cơ chế chặn của admission controller.

#### ❌ Kiểm thử kịch bản VI PHẠM (Phải bị chặn - Reject)

Hãy chạy các lệnh sau để thử apply các pod xấu vào namespace `demo`. Toàn bộ các yêu cầu này **phải bị API Server từ chối** lập tức với thông báo lỗi cụ thể:

1.  **Thử deploy Pod dùng image `:latest`**:
    ```bash
    kubectl apply -f cloud/w10/lab1/scratch/pod-disallowed-latest.yaml
    ```
    *   **Kỳ vọng lỗi**: `Container '...' uses disallowed image tag 'latest'...`

2.  **Thử deploy Pod thiếu RAM/CPU limits**:
    ```bash
    kubectl apply -f cloud/w10/lab1/scratch/pod-disallowed-limits.yaml
    ```
    *   **Kỳ vọng lỗi**: `Container '...' does not have CPU/Memory limits specified.`

3.  **Thử deploy Pod chạy dưới quyền root (`runAsUser: 0`)**:
    ```bash
    kubectl apply -f cloud/w10/lab1/scratch/pod-disallowed-root.yaml
    ```
    *   **Kỳ vọng lỗi**: `securityContext.runAsUser cannot be 0 (root).`

4.  **Thử deploy Pod dùng Host Network (`hostNetwork: true`)**:
    ```bash
    kubectl apply -f cloud/w10/lab1/scratch/pod-disallowed-hostnetwork.yaml
    ```
    *   **Kỳ vọng lỗi**: `Using hostNetwork is disallowed.`

5.  **Test Custom Policy: Thử deploy Deployment thiếu label `owner`**:
    ```bash
    kubectl apply -f cloud/w10/lab1/scratch/deploy-disallowed-owner.yaml
    ```
    *   **Kỳ vọng lỗi**: `Workload missing required labels: {"owner"}`

---

####  Kiểm thử kịch bản HỢP LỆ (Phải thành công - Pass)

Hãy chạy lệnh apply các pod/deployment chuẩn chỉnh (đã được cấu hình non-root, khai báo limits đầy đủ, ghim cụ thể tag phiên bản và có label `owner` đầy đủ):

```bash
# Apply pod hợp lệ
kubectl apply -f cloud/w10/lab1/scratch/pod-allowed.yaml

# Apply deployment hợp lệ
kubectl apply -f cloud/w10/lab1/scratch/deploy-allowed.yaml
```

*   **Kỳ vọng**: Cả hai tài nguyên trên đều được tạo thành công (`pod/test-pod-allowed created` và `deployment.apps/test-deploy-allowed created`).

---

## 🔍 3. Xem danh sách các vi phạm hiện tại (Audit Mode)

Nếu muốn biết trong cụm của bạn hiện tại có những resources nào (kể cả các resources hệ thống) đang vi phạm chính sách đã cài đặt, bạn có thể kiểm tra trực tiếp qua Custom Resource của Gatekeeper:

```bash
# Xem thống kê tổng quát số lượng vi phạm của mỗi chính sách
kubectl get constraints

# Xem chi tiết các tài nguyên vi phạm cụ thể của một chính sách (ví dụ: cấm root)
kubectl describe K8sDisallowRoot disallow-root
```
*   *Mẹo*: Trong phần `status.violations` của lệnh `describe`, Gatekeeper sẽ liệt kê chi tiết tên pod và namespace của các tài nguyên đang vi phạm chính sách.
