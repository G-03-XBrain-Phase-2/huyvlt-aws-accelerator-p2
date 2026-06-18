# 📖 Giải Thích Chi Tiết Mã Nguồn & Nguyên Lý Hoạt Động: Lab 1 (RBAC + Gatekeeper)

Tài liệu này giải thích chi tiết từng khối mã nguồn YAML và Rego được sử dụng trong bài Lab 1 giúp người học nắm vững bản chất hoạt động của hệ thống.

---

## 👥 1. Giải thích mã nguồn Phân quyền (RBAC)

Các quyền hạn được định nghĩa trong [roles.yaml](file:///c:/Project%20Web/huyvlt-aws-accelerator-p2/cloud/w10/lab1/rbac/roles.yaml) và liên kết quyền trong [rolebindings.yaml](file:///c:/Project%20Web/huyvlt-aws-accelerator-p2/cloud/w10/lab1/rbac/rolebindings.yaml).

### A. Quyền của Alice (Developer)
#### Định nghĩa quyền (Role):
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: developer-role
  namespace: demo
rules:
- apiGroups: ["", "apps", "networking.k8s.io", "batch"] # Các nhóm API tài nguyên
  resources: ["pods", "deployments", "services", "replicasets", "statefulsets", "configmaps", "secrets", "ingresses", "persistentvolumeclaims", "cronjobs", "jobs"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"] # Cho phép đầy đủ CRUD
- apiGroups: [""]
  resources: ["pods/exec", "pods/log"] # Cho phép debug bằng logs và shell exec
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
```
*   **Giải thích:** Sử dụng `Role` với namespace chỉ định là `demo`. Alice chỉ có quyền thực thi các hành động (`verbs`) trên các tài nguyên (`resources`) liệt kê trong phạm vi duy nhất namespace `demo`.

#### Gán quyền (RoleBinding):
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: developer-binding
  namespace: demo
subjects:
- kind: User
  name: alice
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: developer-role
  apiGroup: rbac.authorization.k8s.io
```
*   **Giải thích:** Ràng buộc `RoleBinding` này liên kết user `alice` với `developer-role`. Vì là `RoleBinding` nên quyền của Alice bị giới hạn chặt chẽ trong namespace `demo`.

---

### B. Quyền của Bob (SRE)
#### Định nghĩa quyền (ClusterRole):
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: sre-role
rules:
- apiGroups: [""]
  resources: ["pods", "pods/exec", "pods/log", "pods/portforward"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
```
*   **Giải thích:** Sử dụng `ClusterRole` (không khai báo namespace). Định nghĩa các quyền debug cấp cao như xem pod, truy cập console (`pods/exec`), xem logs (`pods/log`), và chuyển tiếp cổng (`pods/portforward`).

#### Gán quyền (ClusterRoleBinding):
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: sre-binding
subjects:
- kind: User
  name: bob
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: sre-role
  apiGroup: rbac.authorization.k8s.io
```
*   **Giải thích:** Sử dụng `ClusterRoleBinding` để gán `ClusterRole` toàn quốc cho Bob. Bob có quyền debug pod ở **bất kỳ namespace nào** trên toàn cụm.

---

### C. Quyền của Carol (Viewer)
#### Định nghĩa quyền (ClusterRole):
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: viewer-role
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["get", "list", "watch"] # Chỉ cho phép các quyền Đọc (Read-only)
```
*   **Giải thích:** Cho phép đọc (`get`, `list`, `watch`) trên tất cả các nhóm API (`*`) và tài nguyên cụm (`*`).

#### Gán quyền (ClusterRoleBinding):
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: viewer-binding
subjects:
- kind: User
  name: carol
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: viewer-role
  apiGroup: rbac.authorization.k8s.io
```
*   **Giải thích:** Cho phép Carol xem thông số, cấu hình của toàn cụm nhưng chặn mọi hành vi thay đổi/xóa.

---

## 🛡️ 2. Giải thích mã nguồn Admission Policy (Gatekeeper OPA)

Các chính sách được khai báo dưới dạng cặp: **ConstraintTemplate** (định nghĩa Rego logic) và **Constraint** (áp dụng thực tế).

### 2.1. Chính sách cấm Image tag `:latest`
#### Mã nguồn Rego trong Template:
```rego
violation[{"msg": msg}] {
  # Lấy danh sách các container từ đối tượng đầu vào (input)
  container := input.review.object.spec.containers[_]
  
  # Gọi hàm phụ trợ "has_latest_tag" truyền vào đường dẫn image của container
  has_latest_tag(container.image)
  
  # Trả về thông báo lỗi vi phạm chỉ rõ tên container và image vi phạm
  msg := sprintf("Container '%v' sử dụng image tag không được phép 'latest' hoặc rỗng trong image '%v'. Hãy ghim cụ thể tag phiên bản (ví dụ: nginx:1.25.1).", [container.name, container.image])
}

# Định nghĩa hàm kiểm tra tag: image kết thúc bằng ":latest"
has_latest_tag(image) {
  endswith(image, ":latest")
}

# Định nghĩa hàm kiểm tra tag: image rỗng tag (không chứa ký tự hai chấm ":")
has_latest_tag(image) {
  not contains(image, ":")
}
```
*   **Nguyên lý hoạt động:** Webhook duyệt qua tất cả container trong Pod. Nếu image kết thúc bằng `:latest` hoặc không có dấu `:` (khi đó K8s tự hiểu là latest), điều kiện sẽ Đúng ➔ Trả về `msg` chặn deploy.

---

### 2.2. Chính sách bắt buộc khai báo CPU/Memory limits
#### Mã nguồn Rego trong Template:
```rego
violation[{"msg": msg}] {
  # Lấy container trong pods
  container := input.review.object.spec.containers[_]
  
  # Gọi hàm kiểm tra xem container có thiếu limits hay không
  missing_limits(container)
  
  msg := sprintf("Container '%v' thiếu khai báo CPU hoặc Memory limits. Vui lòng thêm resources.limits.cpu và resources.limits.memory vào manifest.", [container.name])
}

# Trường hợp 1: Hoàn toàn không khai báo block "resources" hoặc "limits"
missing_limits(container) {
  not container.resources.limits
}

# Trường hợp 2: Có block limits nhưng thiếu trường "cpu"
missing_limits(container) {
  not container.resources.limits.cpu
}

# Trường hợp 3: Có block limits nhưng thiếu trường "memory"
missing_limits(container) {
  not container.resources.limits.memory
}
```
*   **Nguyên lý hoạt động:** Chặn bất kỳ Pod nào có container không định nghĩa đầy đủ cả 2 thông số giới hạn `cpu` và `memory` ở cấu hình `resources.limits`.

---

### 2.3. Chính sách cấm container chạy Root (`runAsUser: 0`)
#### Mã nguồn Rego trong Template:
```rego
violation[{"msg": msg}] {
  # Kiểm tra ở cấp độ Pod SecurityContext
  input.review.object.spec.securityContext.runAsUser == 0
  msg := "Không được phép chạy ở quyền Root: Pod-level securityContext.runAsUser không được phép bằng 0."
}

violation[{"msg": msg}] {
  # Kiểm tra ở cấp độ từng Container SecurityContext
  container := input.review.object.spec.containers[_]
  container.securityContext.runAsUser == 0
  msg := sprintf("Không được phép chạy ở quyền Root: Container '%v' có securityContext.runAsUser bằng 0.", [container.name])
}
```
*   **Nguyên lý hoạt động:** Quét cả 2 tầng: tầng Pod và tầng Container. Nếu bất kỳ tầng nào cài đặt ID của User chạy là `0` (Root), request sẽ bị từ chối nhằm tránh lỗ hổng bảo mật leo thang đặc quyền.

---

### 2.4. Chính sách cấm Host Network
#### Mã nguồn Rego trong Template:
```rego
violation[{"msg": msg}] {
  # Kiểm tra trường hostNetwork trong spec của Pod
  input.review.object.spec.hostNetwork == true
  msg := "Cấm sử dụng Host Network: spec.hostNetwork không được phép thiết lập bằng true nhằm tránh rủi ro nghe lén dữ liệu trên node."
}
```
*   **Nguyên lý hoạt động:** Chặn đứng các Pod cố gắng liên kết trực tiếp với card mạng vật lý của Node Host (`hostNetwork: true`).

---

### 2.5. Custom Policy: Bắt buộc nhãn `owner` cho Deployment/Rollout
#### Mã nguồn Rego trong Template:
```rego
violation[{"msg": msg}] {
  # Lấy danh sách toàn bộ labels trên tài nguyên
  provided := {l | input.review.object.metadata.labels[l]}
  
  # Định nghĩa nhãn bắt buộc phải có
  required := {"owner"}
  
  # Phép trừ tập hợp: Lấy các nhãn bắt buộc nhưng bị thiếu
  missing := required - provided
  
  # Nếu số lượng nhãn thiếu > 0
  count(missing) > 0
  
  msg := sprintf("Workload thiếu nhãn bắt buộc định danh FinOps/Quy trách nhiệm: %v", [missing])
}
```
#### File cấu hình Constraint áp dụng:
```yaml
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequiredLabels
metadata:
  name: deployment-must-have-owner
spec:
  enforcementAction: deny # Từ chối deploy nếu vi phạm
  match:
    kinds:
      - apiGroups: ["apps", "argoproj.io"]
        kinds: ["Deployment", "Rollout"] # Chỉ áp dụng cho Deployment và Rollout
```
*   **Nguyên lý hoạt động:** Sử dụng phép toán trừ tập hợp để so sánh nhãn hiện có với nhãn bắt buộc (`owner`). Chỉ áp dụng kiểm tra này cho `Deployment` và `Rollout` để tránh làm ảnh hưởng đến các pods sinh tự động của hệ thống.
