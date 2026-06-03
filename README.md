# AWS Accelerator — Phase 2 Portfolio

- **Họ và tên:** Võ Lê Trường Huy
- **ID:** XB-DN26-102
- **Group:** 3
- **Chuyên ngành:** Cloud / DevOps
- **GitHub Username:** HuyVLT

---

## Lộ trình & Theo dõi Tiến độ (Week 8)

Dưới đây là tiến độ học tập và thực hành các nội dung IaC & Kubernetes trong Phase 2:

| Tuần | Chuyên đề | Trạng thái | Nội dung trọng tâm / Sản phẩm | Liên kết |
|---|---|---|---|---|
| **W8** | **Day A: Terraform Basics** | 🟢 Hoàn thành | Tìm hiểu IaC, cú pháp HCL, CLI workflow, Data source, Variable và Import State. | [Xem chi tiết](cloud/w8/day-a/) |
| | **Day B: Kubernetes Basics** | 🟡 Đang học | Đọc tài liệu Container Orchestration, Pod, Service, Probes. Setup Minikube local. | [Xem chi tiết](cloud/w8/day-b/) |
| | **Day C: Terraform Advanced** | ⚪ Lên kế hoạch | Quản lý State (S3 & DynamoDB lock), Modules, Live Q&A và làm Test 1. | [Xem chi tiết](cloud/w8/day-c/) |
| | **Lab: Mini K8s Platform** | ⚪ Lên kế hoạch | Hoàn thiện Lab onsite, show-and-tell nhóm và làm Test 2. | [Xem chi tiết](cloud/w8/lab/) |
| | **Reflection W8** | 🟡 Đang thực hiện | Ghi chép nhật ký phản hồi và bài học rút ra cuối tuần. | [Xem chi tiết](cloud/w8/reflection.md) |
| **W9** | **GitOps & Advanced CI/CD** | ⚪ Lên kế hoạch | Học Helm, ArgoCD và Continuous Delivery. | [Thư mục W9](cloud/w9/) |
| **W10** | **Observability & Security** | ⚪ Lên kế hoạch | Prometheus, Grafana, Canary Deployment và Security. | [Thư mục W10](cloud/w10/) |

---

## Cấu trúc thư mục dự án

```text
HuyVLT-aws-accelerator-p2/
├── .gitignore               # Loại bỏ các file nhạy cảm và .terraform/
├── README.md                # Trang tổng quan tiến độ (File này)
└── cloud/
    ├── w8/
    │   ├── day-a/           # Thực hành Terraform Basics (Data source, Variable) + Lý thuyết (theory/)
    │   ├── day-b/           # Thực hành Kubernetes cơ bản (Pod, Service)
    │   ├── day-c/           # Thực hành Terraform Advanced (Import State, Remote State, Ghi chép State)
    │   ├── lab/             # Lab chính thức cuối tuần (Mini K8s platform)
    │   └── reflection.md    # Nhật ký tự học và đánh giá cuối tuần
    ├── w9/
    └── w10/
```
