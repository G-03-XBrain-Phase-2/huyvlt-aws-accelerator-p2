# 📋 Báo Cáo Quá Trình Thực Hiện & Cấu Hợp Bảo Mật: Lab 1 (RBAC + Gatekeeper)

Tài liệu này tổng hợp chi tiết toàn bộ quá trình thực hiện bài Lab 1, các vấn đề phát sinh cùng giải pháp khắc phục, cũng như các vị trí khai báo cấu hình phân quyền (RBAC) và chính sách kiểm duyệt đầu vào (Admission Policy).

---

## 🕒 1. Nhật Ký Quá Trình Thực Hiện (Troubleshooting & Setup)

Để hoàn thành bài Lab 1 và chạy ổn định trên cụm Minikube cục bộ, chúng ta đã đi qua các bước giải quyết sự cố sau:

### Giai đoạn 1: Sửa lỗi đường dẫn Image (Rollout API)
*   **Vấn đề:** File rollout gốc chứa image của một repository khác (`ghcr.io/Vuong-Bach/...`), dẫn đến việc kéo image thất bại do thiếu quyền truy cập (ErrImagePull).
*   **Khắc phục:** Cập nhật đường dẫn image sang repository của bạn (`ghcr.io/g-03-xbrain-phase-2/w10-api:0.0.1`) trong file [rollout.yaml](file:///c:/Project%20Web/huyvlt-aws-accelerator-p2/cloud/w10/lab1/app-api/rollout.yaml).
*   **Tự động hóa:** Thiết lập và kiểm tra CI/CD workflow [.github/workflows/build-push-w10.yml](file:///c:/Project%20Web/huyvlt-aws-accelerator-p2/.github/workflows/build-push-w10.yml) để tự động hóa build/push image của bạn lên GitHub Packages.

### Giai đoạn 2: Tối ưu tài nguyên Minikube
*   **Vấn đề:** Khi deploy đồng thời ArgoCD, Gatekeeper, Prometheus-Stack và Rollout API, cụm Minikube mặc định bị thiếu RAM/CPU dẫn đến tình trạng API Server bị OOM-Killed, CoreDNS bị timeout và không thể đồng bộ ứng dụng.
*   **Khắc phục:** Sử dụng driver `docker` thay vì `hyperv` (bị lỗi permission) và khởi tạo cụm với cấu hình tài nguyên đủ lớn:
    ```powershell
    minikube start -p minikube-docker --cpus=4 --memory=6g --driver=docker
    ```

### Giai đoạn 3: Sửa lỗi phiên bản Helm Chart của Sigstore Policy Controller
*   **Vấn đề:** File ứng dụng ArgoCD [policy-controller.yaml](file:///c:/Project%20Web/huyvlt-aws-accelerator-p2/cloud/w10/argocd/apps/policy-controller.yaml) khai báo phiên bản chart `0.8.2` không tồn tại trên kho Sigstore Helm Repo, khiến ứng dụng ArgoCD bị lỗi "chart not found".
*   **Khắc phục:** Hạ cấp phiên bản chart về bản ổn định gần nhất **`0.8.1`** để ArgoCD tải và đồng bộ thành công.

### Giai đoạn 4: Giải quyết xung đột thứ tự đồng bộ (Race Conditions)
*   **Vấn đề Namespace:** Một số Helm charts (như `external-secrets` hay `cosign-system`) yêu cầu namespace tồn tại trước khi cài đặt nhưng ArgoCD đồng bộ đồng thời gây lỗi.
    *   *Khắc phục:* Tạo thủ công namespace `external-secrets` và `cosign-system` bằng `kubectl create ns`.
*   **Vấn đề CRD Gatekeeper:** ArgoCD cố gắng apply các Gatekeeper `Constraints` trước khi controller xử lý xong `ConstraintTemplates` để đăng ký các Custom Resource Definitions (CRDs). Điều này làm ArgoCD báo lỗi vì API Server chưa nhận diện được schema của Constraints.
    *   *Khắc phục:* Apply thủ công các file `ConstraintTemplates` trước để API Server tạo các CRD, sau đó để ArgoCD đồng bộ phần còn lại một cách mượt mà.

---

## 👥 2. Vị Trí Cấu Hình Phân Quyền (RBAC)

Toàn bộ cấu hình RBAC được định nghĩa trong thư mục [cloud/w10/lab1/rbac/](file:///c:/Project%20Web/huyvlt-aws-accelerator-p2/cloud/w10/lab1/rbac/).

### A. Định nghĩa các Role
Nằm trong file [roles.yaml](file:///c:/Project%20Web/huyvlt-aws-accelerator-p2/cloud/w10/lab1/rbac/roles.yaml):
*   **`developer-role` (Role)**:
    *   *Dòng cấu hình:* [roles.yaml:L1-L22](file:///c:/Project%20Web/huyvlt-aws-accelerator-p2/cloud/w10/lab1/rbac/roles.yaml#L1-L22)
    *   *Quyền hạn:* CRUD (`get`, `list`, `watch`, `create`, `update`, `patch`, `delete`) trên các tài nguyên chạy ứng dụng (`pods`, `deployments`, `services`, `replicasets`, `statefulsets`, `configmaps`, `secrets`, `ingresses`, `persistentvolumeclaims`, `cronjobs`, `jobs`).
    *   *Quyền debug:* Được phép chạy lệnh debug container (`pods/exec`, `pods/log`).
*   **`sre-role` (ClusterRole)**:
    *   *Dòng cấu hình:* [roles.yaml:L24-L35](file:///c:/Project%20Web/huyvlt-aws-accelerator-p2/cloud/w10/lab1/rbac/roles.yaml#L24-L35)
    *   *Quyền hạn:* CRUD pod, debug container (`pods/exec`, `pods/log`) và mở cổng dịch vụ (`pods/portforward`) trên phạm vi toàn bộ các namespace trong cụm.
*   **`viewer-role` (ClusterRole)**:
    *   *Dòng cấu hình:* [roles.yaml:L36-L45](file:///c:/Project%20Web/huyvlt-aws-accelerator-p2/cloud/w10/lab1/rbac/roles.yaml#L36-L45)
    *   *Quyền hạn:* Chỉ đọc (`get`, `list`, `watch`) toàn bộ các tài nguyên trong cụm (`*`).

### B. Liên kết quyền (Bindings)
Nằm trong file [rolebindings.yaml](file:///c:/Project%20Web/huyvlt-aws-accelerator-p2/cloud/w10/lab1/rbac/rolebindings.yaml):
*   **Alice Binding (RoleBinding)**:
    *   *Dòng cấu hình:* [rolebindings.yaml:L1-L14](file:///c:/Project%20Web/huyvlt-aws-accelerator-p2/cloud/w10/lab1/rbac/rolebindings.yaml#L1-L14)
    *   *Ý nghĩa:* Bó hẹp quyền của user `alice` (`developer-role`) chỉ được thao tác trong duy nhất namespace **`demo`**.
*   **Bob Binding (ClusterRoleBinding)**:
    *   *Dòng cấu hình:* [rolebindings.yaml:L15-L27](file:///c:/Project%20Web/huyvlt-aws-accelerator-p2/cloud/w10/lab1/rbac/rolebindings.yaml#L15-L27)
    *   *Ý nghĩa:* Cấp quyền cho user `bob` (`sre-role`) có thể thao tác và gỡ lỗi trên pod ở bất kỳ namespace nào trong cụm.
*   **Carol Binding (ClusterRoleBinding)**:
    *   *Dòng cấu hình:* [rolebindings.yaml:L28-L40](file:///c:/Project%20Web/huyvlt-aws-accelerator-p2/cloud/w10/lab1/rbac/rolebindings.yaml#L28-L40)
    *   *Ý nghĩa:* Cấp quyền cho user `carol` (`viewer-role`) xem/đọc cấu hình của toàn bộ cụm.

---

## 🛡️ 3. Vị Trí Cấu Hình Admission Policy (Gatekeeper)

Các chính sách Admission Policy (Gatekeeper Constraints & ConstraintTemplates) được lưu trữ tại thư mục [cloud/w10/lab1/gatekeeper/constraints/](file:///c:/Project%20Web/huyvlt-aws-accelerator-p2/cloud/w10/lab1/gatekeeper/constraints/). 

Mỗi chính sách bảo mật bao gồm một cặp file: **Template** (định nghĩa cấu trúc schema và mã Rego) và **Constraint** (khai báo các tham số đầu vào và phạm vi áp dụng/loại trừ).

| Stt | Chính Sách Bảo Mật | Vị Trí File Template | Vị Trí File Constraint | Logic Rego & Cách hoạt động |
| :---: | :--- | :--- | :--- | :--- |
| **1** | **Cấm Image tag `:latest`** | [template-no-latest.yaml](file:///c:/Project%20Web/huyvlt-aws-accelerator-p2/cloud/w10/lab1/gatekeeper/constraints/template-no-latest.yaml) | [constraint-no-latest.yaml](file:///c:/Project%20Web/huyvlt-aws-accelerator-p2/cloud/w10/lab1/gatekeeper/constraints/constraint-no-latest.yaml) | Kiểm tra thuộc tính `image` của mọi container. Nếu tag rỗng hoặc có giá trị là `"latest"` sẽ bị từ chối (trừ các namespace hệ thống). |
| **2** | **Bắt buộc Resource Limits** | [template-require-limits.yaml](file:///c:/Project%20Web/huyvlt-aws-accelerator-p2/cloud/w10/lab1/gatekeeper/constraints/template-require-limits.yaml) | [constraint-require-limits.yaml](file:///c:/Project%20Web/huyvlt-aws-accelerator-p2/cloud/w10/lab1/gatekeeper/constraints/constraint-require-limits.yaml) | Kiểm tra xem container có thiết lập đầy đủ `resources.limits.cpu` và `resources.limits.memory` hay không. |
| **3** | **Cấm Container chạy Root** | [template-no-root.yaml](file:///c:/Project%20Web/huyvlt-aws-accelerator-p2/cloud/w10/lab1/gatekeeper/constraints/template-no-root.yaml) | [constraint-no-root.yaml](file:///c:/Project%20Web/huyvlt-aws-accelerator-p2/cloud/w10/lab1/gatekeeper/constraints/constraint-no-root.yaml) | Kiểm tra `securityContext.runAsUser`. Nếu giá trị bằng `0` ở cấp độ Pod hoặc Container thì sẽ bị từ chối triển khai. |
| **4** | **Cấm Host Network** | [template-no-hostnetwork.yaml](file:///c:/Project%20Web/huyvlt-aws-accelerator-p2/cloud/w10/lab1/gatekeeper/constraints/template-no-hostnetwork.yaml) | [constraint-no-hostnetwork.yaml](file:///c:/Project%20Web/huyvlt-aws-accelerator-p2/cloud/w10/lab1/gatekeeper/constraints/constraint-no-hostnetwork.yaml) | Kiểm tra thuộc tính `spec.hostNetwork`. Nếu bằng `true` thì không cho phép pod deploy lên node. |
| **5** | **Bắt buộc nhãn `owner` (Custom)** | [template-require-owner.yaml](file:///c:/Project%20Web/huyvlt-aws-accelerator-p2/cloud/w10/lab1/gatekeeper/constraints/template-require-owner.yaml) | [constraint-require-owner.yaml](file:///c:/Project%20Web/huyvlt-aws-accelerator-p2/cloud/w10/lab1/gatekeeper/constraints/constraint-require-owner.yaml) | Kiểm tra các nhãn (`metadata.labels`). Nếu thiếu nhãn `"owner"` trên các tài nguyên `Deployment` và `Rollout` sẽ bị từ chối. |

---

## 🧪 4. Tóm Tắt Lệnh Kiểm Chứng Nhanh

Bạn có thể chạy các lệnh này để kiểm chứng trực tiếp sự hoạt động của các phân quyền và chính sách trên:

### A. Kiểm chứng RBAC:
```powershell
# Alice được tạo Deployment ở namespace demo? (Kỳ vọng: yes)
kubectl auth can-i create deploy -n demo --as alice

# Alice có bị cấm tạo ở namespace kube-system? (Kỳ vọng: no)
kubectl auth can-i create deploy -n kube-system --as alice

# Bob (SRE) xem được pod toàn cụm? (Kỳ vọng: yes)
kubectl auth can-i get pods -A --as bob

# Carol (Viewer) có bị cấm xóa node hạ tầng? (Kỳ vọng: no)
kubectl auth can-i delete nodes --as carol
```

### B. Kiểm chứng Admission Policy (Gatekeeper):
```powershell
# 1. Test cấm latest tag (Bị chặn)
kubectl apply -f cloud/w10/lab1/scratch/pod-disallowed-latest.yaml

# 2. Test bắt buộc limit (Bị chặn)
kubectl apply -f cloud/w10/lab1/scratch/pod-disallowed-limits.yaml

# 3. Test cấm root (Bị chặn)
kubectl apply -f cloud/w10/lab1/scratch/pod-disallowed-root.yaml

# 4. Test cấm host network (Bị chặn)
kubectl apply -f cloud/w10/lab1/scratch/pod-disallowed-hostnetwork.yaml

# 5. Test bắt buộc label owner (Bị chặn)
kubectl apply -f cloud/w10/lab1/scratch/deploy-disallowed-owner.yaml

# 6. Triển khai các tài nguyên hợp lệ (Được chấp nhận thành công)
kubectl apply -f cloud/w10/lab1/scratch/pod-allowed.yaml
kubectl apply -f cloud/w10/lab1/scratch/deploy-allowed.yaml
```
