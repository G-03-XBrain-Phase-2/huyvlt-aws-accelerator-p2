# HƯỚNG DẪN HỌC TẬP & THỰC HÀNH · WEEK 10
## Chủ đề: Secure & Operate (RBAC + Admission Policy + Secrets + Supply Chain)

Chào mừng bạn đến với Week 10! Tài liệu này được thiết kế đặc biệt giúp bạn đi từ **con số 0** (hoặc người mất gốc) có thể hiểu rõ bản chất và tự tay vận hành hệ thống bảo mật cấp cụm (Cluster-level Security) trên Kubernetes.

---

## 🗺️ PHẦN 1: BẢN ĐỒ KIẾN THỨC (Cho người mới bắt đầu)

Để dễ hình dung, hãy tưởng tượng cụm Kubernetes của bạn là một **Sân bay quốc tế**:
1.  **Hành khách** (Users, Pods) muốn vào sân bay và thực hiện các hoạt động.
2.  **Lớp 1: RBAC** giống như **Hộ chiếu (Passport) & Thị thực (Visa)**. Nó xác định: Bạn là ai? Bạn có quyền đi vào phòng chờ VIP hay không? Bạn có được bay không?
3.  **Lớp 2: Admission Policy (Gatekeeper)** giống như **Máy quét an ninh hành lý**. Cho dù Visa của bạn có hợp lệ đi chăng nữa, nếu trong vali của bạn có chứa hàng cấm (như ma túy, chất nổ - tương đương với image `:latest`, chạy quyền root, thiếu limit tài nguyên), bạn vẫn sẽ bị chặn đứng tại cửa an ninh.
4.  **Lớp 3: Secrets Operator (ESO)** giống như **Két sắt ngân hàng thông minh**. Thay vì bạn tự mang theo vàng bạc (mật khẩu) trên người và dễ bị cướp (commit lên Git), bạn gửi nó ở một két sắt bảo mật trên mây (AWS Secrets Manager). Khi cần, ngân hàng sẽ tự động chuyển vào ví của bạn (K8s Secret) một cách an toàn và tự cập nhật mỗi 15 giây.
5.  **Lớp 4: Supply Chain Security (Trivy + Cosign)** giống như **Tem chống hàng giả & Kiểm dịch**. Image trước khi xuất xưởng phải được quét virus (Trivy) và dán tem kiểm định chất lượng (Cosign). Sân bay sẽ quét mã QR trên tem này, nếu tem giả hoặc không có tem ➔ Cấm bay lập tức.

---

### 👥 1.1. Lớp 1: RBAC (Role-Based Access Control)
RBAC là cơ chế kiểm soát quyền hạn dựa trên vai trò. Để hiểu RBAC, bạn chỉ cần nhớ **3 mảnh ghép cốt lõi**:

#### 1. Đối tượng (Subject) - "Ai?"
*   **User:** Người dùng vật lý (như `alice`, `bob` dùng lệnh `kubectl`).
*   **Group:** Nhóm người dùng (ví dụ: nhóm `developers`, nhóm `sre`).
*   **ServiceAccount (SA):** Tài khoản dành riêng cho ứng dụng chạy bên trong Pod (ví dụ: Prometheus cần SA có quyền đọc danh sách Pods để thu thập số liệu).

#### 2. Tài nguyên (Resource) & Hành động (Verb) - "Làm gì với cái gì?"
*   **Resource:** `pods`, `deployments`, `services`, `secrets`, `nodes`, `namespaces`...
*   **Verb (Hành động):** 
    *   `get`: Xem chi tiết 1 tài nguyên.
    *   `list`: Xem danh sách tài nguyên.
    *   `create`: Tạo mới.
    *   `update` / `patch`: Sửa đổi cấu hình.
    *   `delete`: Xóa bỏ.

#### 3. Bản quyền (Role) & Gán quyền (Binding) - "Gán quyền thế nào?"
Kubernetes chia quyền hạn thành 2 cấp độ phạm vi (Scope):
*   **Cấp độ Namespace (Tỉnh lẻ):**
    *   **Role (Giấy thông hành tỉnh):** Định nghĩa danh sách hành động được phép bên trong **1 Namespace** cụ thể (ví dụ: chỉ được tạo pod trong namespace `demo`).
    *   **RoleBinding (Gán quyền tỉnh):** Trao tờ giấy `Role` đó cho một User/SA trong namespace đó.
*   **Cấp độ Cluster (Toàn quốc):**
    *   **ClusterRole (Giấy thông hành toàn quốc):** Định nghĩa quyền hạn trên toàn bộ cụm, áp dụng cho mọi namespace hoặc tài nguyên hệ thống (như Nodes, Namespaces).
    *   **ClusterRoleBinding (Gán quyền toàn quốc):** Trao tờ giấy `ClusterRole` cho một User/SA để họ có quyền hoạt động ở bất kỳ đâu trên toàn cụm.

| Khái niệm trực quan | Scope | Ví dụ thực tế |
| :--- | :--- | :--- |
| **Role** | Namespace | *"Được phép đọc và ghi Pod trong namespace `demo`"* |
| **ClusterRole** | Toàn cụm | *"Được phép xem Logs của Pods ở mọi namespace và quản lý Nodes"* |
| **RoleBinding** | Namespace | *"Gán quyền của Role trên cho Alice (Alice chỉ quậy được ở `demo`)"* |
| **ClusterRoleBinding** | Toàn cụm | *"Gán quyền của ClusterRole cho Bob (Bob đi cứu hộ toàn cụm)"* |

---

### 🛡️ 1.2. Lớp 2: Admission Policy (OPA Gatekeeper)
Tại sao có RBAC rồi vẫn cần Gatekeeper?
*   *Tình huống:* Alice là Developer có quyền `create pod` (RBAC cho phép). Nhưng Alice viết manifest pod dùng image `:latest` hoặc không set CPU/RAM. Nếu cụm cho chạy, Pod của Alice có thể ăn hết RAM của Node và làm sập các ứng dụng khác.
*   **Gatekeeper** sinh ra để kiểm duyệt cấu trúc bên trong của file manifest trước khi nó được ghi vào cơ sở dữ liệu `etcd`.

Gatekeeper chia luật làm 2 phần:
1.  **ConstraintTemplate (Khung định nghĩa luật - viết bằng ngôn ngữ Rego):**
    *   Giống như luật pháp ban hành: *"Tất cả mọi người tham gia giao thông bắt buộc phải đội mũ bảo hiểm có chứng nhận chất lượng"*.
    *   Nó quy định cách kiểm tra dữ liệu đầu vào và cấu trúc viết luật, nhưng chưa chỉ định áp dụng cụ thể cho ai hay ở đâu.
2.  **Constraint (Lệnh thực thi luật):**
    *   Giống như biển báo giao thông cắm ở đường: *"Tuyến đường này bắt buộc đội mũ bảo hiểm, ai vi phạm sẽ bị phạt (deny) hoặc cảnh báo (warn)"*.
    *   Nó truyền tham số cụ thể và chỉ ra phạm vi áp dụng (ví dụ: áp dụng cho mọi Namespace trừ `kube-system`).

#### ✍️ Ngôn ngữ viết luật Rego (Đọc hiểu dễ dàng)
Rego hoạt động theo nguyên lý **"Tìm kiếm vi phạm"**. Bạn định nghĩa một khối luật `violation`. Nếu tất cả các dòng điều kiện bên trong khối đó đều **ĐÚNG (True)**, thì có nghĩa là manifest đó **VI PHẠM** và Gatekeeper sẽ trả về thông báo lỗi, chặn đứng yêu cầu deploy.

*Ví dụ luật cấm chạy dưới quyền Root (`runAsUser: 0`):*
```rego
# Nếu dòng 1 ĐÚNG (user chạy là root)
# VÀ dòng 2 ĐÚNG (không được phép)
# => VI PHẠM => Chặn!
violation[{"msg": msg}] {
  input.review.object.spec.securityContext.runAsUser == 0
  msg := "Thất bại! Không được phép chạy container dưới quyền Root (user id 0)."
}
```

---

### 🔑 1.3. Lớp 3: Secrets Rotation (External Secrets Operator - ESO)
Trong thực tế, việc lưu trữ mật khẩu DB dạng plaintext trong Git là cực kỳ nguy hiểm.
*   **Vấn đề của K8s Secret:** Mặc định chỉ mã hóa dạng `base64` (chỉ cần chạy lệnh `base64 -d` là giải mã được ngay lập tức, hoàn toàn không có tính bảo mật thực sự).
*   **Giải pháp:** Sử dụng **External Secrets Operator (ESO)** để kết nối két sắt AWS Secrets Manager với cụm Kubernetes.

#### Cách hoạt động của ESO:
1.  **SecretStore (Chìa khóa két):** Định nghĩa cách cụm Kubernetes đăng nhập vào AWS (dùng Access Key/Secret Key hoặc IAM Role).
2.  **ExternalSecret (Tờ hướng dẫn đồng bộ):** Định nghĩa:
    *   *Lấy ở đâu:* Tên secret trên AWS (ví dụ: `demo/db/password`).
    *   *Tần suất quét:* Quét thay đổi mỗi 15 giây (`refreshInterval: 15s`).
    *   *Đổ vào đâu:* Tên K8s Secret tự động tạo ra trong cụm (ví dụ: `db-secret`).
3.  **Xoay vòng không restart pod:** 
    *   Nếu bạn cấu hình Pod nhận secret qua biến môi trường (`env`), khi mật khẩu đổi, Pod bắt buộc phải restart mới nhận giá trị mới.
    *   Nếu bạn cấu hình Pod nhận secret qua **Volume Mount (Mount file)**, Kubelet sẽ tự động cập nhật nội dung tệp tin mật khẩu trong container mà không làm pod bị restart ➔ Đảm bảo hệ thống hoạt động liên tục (Zero Downtime).

---

### 🛡️ 1.4. Lớp 4: Supply Chain Security (Trivy + Cosign)
Làm thế nào để đảm bảo code từ máy developer đến khi chạy trên cụm không bị sửa đổi lén hoặc chứa virus bảo mật?

1.  **Bước 1: Quét lỗ hổng (Trivy Scan) trong CI/CD:**
    *   Trivy sẽ tự động rà soát các thư viện code và hệ điều hành base image xem có chứa lỗ hổng bảo mật nghiêm trọng (CVE `HIGH` hoặc `CRITICAL`) không.
    *   Nếu có lỗi nghiêm trọng ➔ Pipeline đỏ (Fail CI), không cho phép đẩy lên kho chứa (Registry).
2.  **Bước 2: Ký số (Cosign Sign):**
    *   Nếu image sạch sẽ, pipeline CI/CD sử dụng một **Private Key** bảo mật để dán một chữ ký số công khai lên registry đi kèm với image đó.
3.  **Bước 3: Xác thực đầu vào (Sigstore Policy Controller):**
    *   Khi bạn chạy lệnh deploy image lên Kubernetes, **Policy Controller** sẽ chặn lại.
    *   Nó sử dụng **Public Key** được cấu hình sẵn trong cụm để giải mã và kiểm tra chữ ký số của image trên Registry.
    *   Nếu chữ ký hợp lệ ➔ Cho phép chạy.
    *   Nếu image chưa ký hoặc bị giả mạo chữ ký ➔ Từ chối chạy ngay lập tức.

---

## 🛠️ PHẦN 2: LỘ TRÌNH THỰC HÀNH (Cần làm gì?)

Bạn cần hoàn thành các bài Lab dưới đây và triển khai mọi thứ thông qua mô hình **GitOps (ArgoCD)**.

```
Thư mục dự án sau khi tổ chức lại:
└── cloud/w10/
    ├── argocd/                     # Quản lý khai báo ứng dụng ArgoCD
    ├── lab1/                       # Toàn bộ bài thực hành buổi sáng
    │   ├── rbac/                   # Định nghĩa Roles và RoleBindings
    │   ├── gatekeeper/             # Định nghĩa OPA Constraints & Templates
    │   └── scratch/                # Các file test thử nghiệm Allowed / Disallowed
    └── lab2/                       # Toàn bộ bài thực hành buổi chiều
        ├── eso/                    # Cấu hình SecretStore và ExternalSecret
        ├── policies/               # Cấu hình ClusterImagePolicy cho Cosign
        └── runbooks/               # Sách hướng dẫn chạy và exception ADR
```

---

### 👤 Lab 1.1: Cấu hình RBAC qua GitOps
Tạo và cấu hình phân quyền cho 3 User giả lập với các đặc quyền sau:

| Đối tượng (User) | Vai trò (Role) | Phạm vi | Quyền hạn được phép |
| :--- | :--- | :--- | :--- |
| **alice** | `developer` | Namespace `demo` | CRUD (Create, Read, Update, Delete) trên workloads: Pods, Deployments, Services, ReplicaSets, StatefulSets. |
| **bob** | `sre` | Toàn cụm (Cluster) | Thao tác (CRUD) trên các resource liên quan đến Pods (logs, exec, delete) ở mọi namespace để debug nhanh. |
| **carol** | `viewer` | Toàn cụm (Cluster) | Chỉ đọc (Read-only / get, list, watch) toàn bộ tài nguyên trong cụm. Không được phép tạo, sửa, xóa bất kỳ thứ gì. |

#### 💡 Gợi ý thiết kế:
* **alice**: Tạo một `Role` trong namespace `demo` định nghĩa đầy đủ verbs (`*` hoặc cụ thể) cho các resources cần thiết. Liên kết bằng `RoleBinding` trong namespace `demo` cho `User` alice.
* **bob**: Tạo một `ClusterRole` chứa quyền với resource `pods` và subresources như `pods/log`, `pods/exec`. Liên kết bằng `ClusterRoleBinding` cho `User` bob.
* **carol**: Tạo một `ClusterRole` chỉ chứa các verbs `get`, `list`, `watch` cho tất cả các tài nguyên cơ bản. Liên kết bằng `ClusterRoleBinding` cho `User` carol.
* Đừng quên tạo file ArgoCD Application `cloud/w10/argocd/apps/rbac.yaml` để quản lý thư mục `cloud/w10/lab1/rbac/`.

---

### 🛡️ Lab 1.2: Triển khai OPA Gatekeeper & 4 Constraints chống lỗi
Cài đặt Gatekeeper controller và thiết lập 4 luật chặn tự động:

| STT | Tên chính sách | Mô tả kiểm tra | Rủi ro ngăn chặn |
| :---: | :--- | :--- | :--- |
| **1** | **Cấm image `:latest`** | Chặn mọi Container sử dụng image tag `:latest` hoặc không có tag (mặc định là latest). | **F-01**: Khó kiểm soát version, lỗi trôi nổi code trên production. |
| **2** | **Bắt buộc có RAM/CPU limits** | Chặn các Pod không cấu hình `resources.limits.cpu` và `resources.limits.memory`. | **F-02**: Pod ăn hết tài nguyên của Node, gây evict hàng loạt Pod khác. |
| **3** | **Cấm chạy dưới quyền Root** | Chặn các cấu hình có `runAsUser: 0` hoặc cho phép chạy root privilege. | **F-04**: Lỗ hổng bảo mật leo thang đặc quyền (Container breakout). |
| **4** | **Cấm sử dụng Host Network** | Chặn các Pod cấu hình `hostNetwork: true`. | **Bảo mật**: Pod có thể nghe lén traffic của host hoặc bypass network policy. |

#### 💡 Gợi ý triển khai:
1. Đăng ký cài đặt Gatekeeper controller thông qua ArgoCD Application (`cloud/w10/argocd/apps/gatekeeper.yaml`). Nên đặt `sync-wave` sớm để Controller lên trước.
2. Tìm kiếm các `ConstraintTemplate` sẵn có từ thư viện chuẩn [Gatekeeper Library](https://github.com/open-policy-agent/gatekeeper-library) (ví dụ: `k8sallowedrepos`, `k8srequiredresources`, `k8spspallowprivilegeescalation`...). **Bạn không cần tự viết mã Rego cho 4 chính sách này.**
3. Tạo các file `Constraint` tương ứng.
4. **BẪY CẦN TRÁNH**: Hãy kiểm tra xem các ứng dụng hiện tại trên platform (Prometheus, ArgoCD, Ingress Controller...) có đang vi phạm các quy tắc trên không.
   * *Mẹo*: Hãy bật `enforcementAction: warn` trước. Check log hoặc xem trạng thái Constraint để biết các resource vi phạm. Sau khi sửa hết các cấu hình vi phạm trên cụm, mới đổi sang `enforcementAction: deny`.

---

### 🎨 Lab 1.3: Tự viết 1 Custom Policy (Rego)
Viết một chính sách của riêng bạn để làm quen với ngôn ngữ Rego. Chọn **1 trong 3** đề bài sau:

1. **Chặn Deployment có `replicas > 5`**: Ngăn chặn lỗi scale vô tội vạ làm cạn kiệt tài nguyên node hoặc làm tăng chi phí AWS (nếu có Cluster Autoscaler).
2. **Bắt buộc mọi workload phải cấu hình label `owner`**: Giúp định danh đội nhóm sở hữu tài nguyên để dễ dàng quy trách nhiệm hoặc tính toán chi phí (FinOps).
3. **Chỉ cho phép Image từ Registry an toàn (Whitelist)**: Chỉ cho phép pull image từ các registry uy tín (ví dụ: `ghcr.io/your-username/*`, `*.dkr.ecr.ap-southeast-1.amazonaws.com`), chặn đứng việc dùng image trôi nổi trên internet.

#### 💡 Ví dụ cấu trúc file Custom Policy (Ví dụ: Yêu cầu label `owner`):
* **ConstraintTemplate (`gatekeeper/constraints/template-required-labels.yaml`)**:
  ```yaml
  apiVersion: templates.gatekeeper.sh/v1
  kind: ConstraintTemplate
  metadata:
    name: k8srequiredlabels
  spec:
    crd:
      spec:
        names:
          kind: K8sRequiredLabels
        validation:
          openAPIV3Schema:
            properties:
              labels:
                type: array
                items:
                  type: string
    targets:
      - target: admission.k8s.gatekeeper.sh
        rego: |
          package k8srequiredlabels
          violation[{"msg": msg}] {
            provided := {l | input.review.object.metadata.labels[l]}
            required := {l | l := input.parameters.labels[_]}
            missing := required - provided
            count(missing) > 0
            msg := sprintf("Thất bại! Manifest thiếu các labels bắt buộc: %v", [missing])
          }
  ```
* **Constraint (`gatekeeper/constraints/constraint-owner-label.yaml`)**:
  ```yaml
  apiVersion: constraints.gatekeeper.sh/v1beta1
  kind: K8sRequiredLabels
  metadata:
    name: deployment-must-have-owner
  spec:
    enforcementAction: deny
    match:
      kinds:
        - apiGroups: ["apps"]
          kinds: ["Deployment"]
    parameters:
      labels: ["owner"]
  ```

---

## 🧪 PHẦN 3: HƯỚNG DẪN NGHIỆM THU (Verification)

Sau khi hoàn thành commit code lên GitHub và ArgoCD báo trạng thái xanh (`Synced`), bạn cần tự chạy các lệnh kiểm tra sau để nghiệm thu:

### 3.1. Nghiệm thu RBAC
Chạy 4 lệnh test giả lập sau trên Terminal:
```bash
# 1. Kiểm tra alice có quyền CRUD workload trong namespace demo không?
# Kỳ vọng: yes
kubectl auth can-i create deployment -n demo --as alice

# 2. Kiểm tra alice có quyền ghi phá ở namespace hệ thống không?
# Kỳ vọng: no
kubectl auth can-i create deployment -n kube-system --as alice

# 3. Kiểm tra bob (SRE) có xem được pods toàn cụm để cứu hộ không?
# Kỳ vọng: yes
kubectl auth can-i get pods -A --as bob

# 4. Kiểm tra carol (viewer) có quyền xóa node hay hạ tầng không?
# Kỳ vọng: no
kubectl auth can-i delete nodes --as carol
```

### 3.2. Nghiệm thu OPA Gatekeeper & Custom Policy
Thử tạo các Pod/Deployment vi phạm trực tiếp hoặc dùng lệnh `kubectl apply --dry-run=server` để test:
* **Test Image `:latest`**: Deploy pod có image `nginx:latest` -> Phải bị từ chối kèm lỗi chỉ rõ vi phạm.
* **Test Resources Limits**: Deploy pod không khai báo RAM/CPU limits -> Phải bị từ chối.
* **Test Privilege Escalation**: Deploy pod có `runAsUser: 0` -> Phải bị từ chối.
* **Test Host Network**: Deploy pod có `hostNetwork: true` -> Phải bị từ chối.
* **Test Custom Policy**: Deploy pod không có label `owner` (hoặc replicas > 5 tuỳ theo lựa chọn của bạn) -> Phải bị từ chối.
* **Test Pod hợp lệ**: Một manifest chuẩn chỉnh (đủ limits, pin version image `nginx:1.25.1`, non-root, có label `owner`) -> Phải đi qua Validation và deploy thành công (`pass`).

---

## 📝 PHẦN 4: CHECKLIST HOÀN THÀNH (Deliverables)

Hãy chắc chắn rằng bạn đã hoàn thành và đẩy các thành phần sau lên nhánh chính của repository fork:
- [ ] Thư mục `cloud/w10/rbac/` chứa đầy đủ cấu hình Roles, ClusterRoles, RoleBindings, ClusterRoleBindings.
- [ ] Thư mục `cloud/w10/gatekeeper/constraints/` chứa đầy đủ các file Constraints và ConstraintTemplates (bao gồm cả luật Custom).
- [ ] Thư mục `cloud/w10/argocd/apps/` chứa các file đăng ký Application để ArgoCD tự động quản lý vòng đời của RBAC và Gatekeeper.
- [ ] Đảm bảo Platform chung vẫn hoạt động bình thường, các ứng dụng Prometheus, Grafana, Ingress Controller, Argo Rollouts không bị chính sách Gatekeeper chặn đứng.

*Chúc các bạn hoàn thành tốt buổi Lab để chuẩn bị sẵn sàng cho Capstone Project (W11-W12)!*
