# 📝 Báo Cáo Cấu Hình & Quá Trình Thực Hiện: Lab 1 (RBAC + Gatekeeper)

Tài liệu này tổng hợp toàn bộ quá trình pair-programming, các quyết định kỹ thuật và chi tiết vị trí cấu hình phân quyền (RBAC) cùng chính sách kiểm duyệt (Admission Policy) đã triển khai trong cụm.

---

## 🕒 1. Nhật Ký Quá Trình Thực Hiện (Step-by-Step)

Quá trình triển khai và sửa lỗi được thực hiện qua các giai đoạn sau:

### Giai đoạn 1: Khảo sát và Phân tích cấu trúc thư mục
*   Xác định cấu trúc phân tách giữa **Orchestration** (`argocd/`), **Platform Infrastructure** (`eso/`, `policies/`) và **Application/Lab configs** (`lab1/`).
*   Xác định các placeholders và thông tin cần chỉnh sửa để khớp với repository chính chủ của bạn (`HuyVLT`).

### Giai đoạn 2: Khắc phục lỗi Đường dẫn Image của Rollout API
*   **Vấn đề**: File [rollout.yaml](file:///C:/Project%20Web/huyvlt-aws-accelerator-p2/cloud/w10/lab1/app-api/rollout.yaml) ban đầu trỏ về Registry của học viên khác (`ghcr.io/Vuong-Bach/...`).
*   **Xử lý**: Cập nhật đường dẫn về đúng tổ chức GitHub của bạn (`ghcr.io/g-03-xbrain-phase-2/w10-api:0.0.1`).
*   **Tự động hóa**: Tìm hiểu và giải thích luồng CI/CD trong [.github/workflows/build-push-w10.yml](file:///C:/Project%20Web/huyvlt-aws-accelerator-p2/.github/workflows/build-push-w10.yml) giúp tự động cập nhật tag phiên bản mới kèm mã Git SHA mỗi khi push code lên thư mục `api/`.

### Giai đoạn 3: Khởi động Cụm Minikube tối ưu tài nguyên
*   **Vấn đề**: Cụm ban đầu được tạo bằng driver Hyper-V nhưng bị lỗi phân quyền Windows. Sau đó khi chuyển sang Docker driver mặc định, cụm bị thiếu tài nguyên gây sập API Server (OOM) và lỗi timeout DNS (CoreDNS).
*   **Xử lý**: Xóa cụm cũ và khởi tạo lại cụm `minikube-docker` với cấu hình tài nguyên mạnh mẽ:
    ```powershell
    minikube start -p minikube-docker --cpus=4 --memory=6g --driver=docker
    ```

### Giai đoạn 4: Sửa lỗi phiên bản Sigstore Policy Controller trên ArgoCD
*   **Vấn đề**: Ứng dụng `policy-controller` báo lỗi đồng bộ vì Helm chart phiên bản `0.8.2` không tồn tại trên kho ứng dụng chính thức của Sigstore.
*   **Xử lý**: Tra cứu và cập nhật phiên bản chart về bản ổn định gần nhất là **`0.8.1`** trong file [policy-controller.yaml](file:///C:/Project%20Web/huyvlt-aws-accelerator-p2/cloud/w10/argocd/apps/policy-controller.yaml).

### Giai đoạn 5: Giải quyết xung đột thứ tự tạo Namespace & CRD
*   **Xử lý Namespace**: Tạo thủ công namespace `external-secrets` và `cosign-system` để tránh lỗi race condition khi các ứng dụng con của ArgoCD deploy trước khi namespace được Helm hooks khởi tạo.
*   **Xử lý CRD**: Áp dụng trước các file `ConstraintTemplate` bằng lệnh `kubectl apply` để API Server đăng ký các CRD tương ứng trước khi ArgoCD đẩy `Constraint` vào cụm.

---

## 👥 2. Chi Tiết Cấu Hình Phân Quyền (RBAC)

Các quyền hạn được thiết lập trong thư mục [cloud/w10/lab1/rbac/](file:///C:/Project%20Web/huyvlt-aws-accelerator-p2/cloud/w10/lab1/rbac/):

### A. alice (developer) — Namespace Scope (`demo`)
*   **Định nghĩa quyền**: [roles.yaml:L1-L22](file:///C:/Project%20Web/huyvlt-aws-accelerator-p2/cloud/w10/lab1/rbac/roles.yaml#L1-L22)
    *   Quyền CRUD (`get`, `list`, `watch`, `create`, `update`, `patch`, `delete`) trên các tài nguyên chạy ứng dụng: `pods`, `deployments`, `services`, `replicasets`, `statefulsets`, `configmaps`, `secrets`, `ingresses`, `persistentvolumeclaims`, `cronjobs`, `jobs`.
    *   Quyền bổ sung: debug container (`pods/exec`, `pods/log`).
*   **Gán quyền**: [rolebindings.yaml:L1-L14](file:///C:/Project%20Web/huyvlt-aws-accelerator-p2/cloud/w10/lab1/rbac/rolebindings.yaml#L1-L14)
    *   Sử dụng `RoleBinding` để bó hẹp quyền của `alice` chỉ hoạt động được bên trong namespace **`demo`**.

### B. bob (sre) — Cluster Scope
*   **Định nghĩa quyền**: [roles.yaml:L24-L35](file:///C:/Project%20Web/huyvlt-aws-accelerator-p2/cloud/w10/lab1/rbac/roles.yaml#L24-L35)
    *   Quyền thao tác gỡ lỗi chuyên sâu trên pod (`pods`, `pods/exec`, `pods/log`, `pods/portforward`).
*   **Gán quyền**: [rolebindings.yaml:L15-L27](file:///C:/Project%20Web/huyvlt-aws-accelerator-p2/cloud/w10/lab1/rbac/rolebindings.yaml#L15-L27)
    *   Sử dụng `ClusterRoleBinding` để bob có thể debug sự cố pod trên **mọi namespace** toàn cụm.

### C. carol (viewer) — Cluster Scope
*   **Định nghĩa quyền**: [roles.yaml:L36-L45](file:///C:/Project%20Web/huyvlt-aws-accelerator-p2/cloud/w10/lab1/rbac/roles.yaml#L36-L45)
    *   Quyền chỉ đọc (`get`, `list`, `watch`) trên toàn bộ tài nguyên cụm (`*`).
*   **Gán quyền**: [rolebindings.yaml:L28-L40](file:///C:/Project%20Web/huyvlt-aws-accelerator-p2/cloud/w10/lab1/rbac/rolebindings.yaml#L28-L40)
    *   Sử dụng `ClusterRoleBinding` cấp quyền đọc thông tin kiểm toán (audit) toàn cụm.

---

## 🛡️ 3. Chi Tiết Cấu Hình Admission Policy (Gatekeeper)

Các chính sách được lưu cấu hình trong thư mục [cloud/w10/lab1/gatekeeper/constraints/](file:///C:/Project%20Web/huyvlt-aws-accelerator-p2/cloud/w10/lab1/gatekeeper/constraints/):

### A. Cấm Image tag `:latest` (Luật 1)
*   **Tập tin**: [constraint-no-latest.yaml](file:///C:/Project%20Web/huyvlt-aws-accelerator-p2/cloud/w10/lab1/gatekeeper/constraints/constraint-no-latest.yaml) & [template-no-latest.yaml](file:///C:/Project%20Web/huyvlt-aws-accelerator-p2/cloud/w10/lab1/gatekeeper/constraints/template-no-latest.yaml)
*   **Logic Rego**: Kiểm tra phần tag của image. Nếu tag rỗng (mặc định hiểu là latest) hoặc bằng chữ `"latest"` thì báo lỗi vi phạm.
*   **Phạm vi áp dụng**: Mọi Pod trừ các namespace hệ thống (`kube-system`, `monitoring`, `argocd`, `gatekeeper-system`).

### B. Bắt buộc khai báo CPU/Memory limits (Luật 2)
*   **Tập tin**: [constraint-require-limits.yaml](file:///C:/Project%20Web/huyvlt-aws-accelerator-p2/cloud/w10/lab1/gatekeeper/constraints/constraint-require-limits.yaml) & [template-require-limits.yaml](file:///C:/Project%20Web/huyvlt-aws-accelerator-p2/cloud/w10/lab1/gatekeeper/constraints/template-require-limits.yaml)
*   **Logic Rego**: Kiểm tra cấu hình `resources.limits.cpu` và `resources.limits.memory` của tất cả container (kể cả initContainers). Nếu thiếu bất kỳ chỉ số nào sẽ báo lỗi.

### C. Cấm chạy dưới quyền Root (Luật 3)
*   **Tập tin**: [constraint-no-root.yaml](file:///C:/Project%20Web/huyvlt-aws-accelerator-p2/cloud/w10/lab1/gatekeeper/constraints/constraint-no-root.yaml) & [template-no-root.yaml](file:///C:/Project%20Web/huyvlt-aws-accelerator-p2/cloud/w10/lab1/gatekeeper/constraints/template-no-root.yaml)
*   **Logic Rego**: Kiểm tra `securityContext.runAsUser`. Nếu giá trị bằng `0` ở cấp độ Pod hoặc ở bất kỳ cấp container nào sẽ bị chặn.

### D. Cấm Host Network (Luật 4)
*   **Tập tin**: [constraint-no-hostnetwork.yaml](file:///C:/Project%20Web/huyvlt-aws-accelerator-p2/cloud/w10/lab1/gatekeeper/constraints/constraint-no-hostnetwork.yaml) & [template-no-hostnetwork.yaml](file:///C:/Project%20Web/huyvlt-aws-accelerator-p2/cloud/w10/lab1/gatekeeper/constraints/template-no-hostnetwork.yaml)
*   **Logic Rego**: Kiểm tra trường `spec.hostNetwork`. Nếu bằng `true` sẽ bị từ chối.

### E. Custom Policy: Bắt buộc có label `owner` (Lab 1.3)
*   **Tập tin**: [constraint-require-owner.yaml](file:///C:/Project%20Web/huyvlt-aws-accelerator-p2/cloud/w10/lab1/gatekeeper/constraints/constraint-require-owner.yaml) & [template-require-owner.yaml](file:///C:/Project%20Web/huyvlt-aws-accelerator-p2/cloud/w10/lab1/gatekeeper/constraints/template-require-owner.yaml)
*   **Logic Rego**:
    *   Lấy toàn bộ danh sách keys của label hiện tại trên tài nguyên: `metadata.labels`.
    *   Đối chiếu xem có chứa nhãn `"owner"` hay không. Nếu thiếu nhãn này sẽ từ chối deploy.
*   **Phạm vi áp dụng**: Chỉ áp dụng cho các workload dạng `Deployment` và `Rollout` để tránh ảnh hưởng đến các pods đơn lẻ/hệ thống.
