# 01. Nền tảng Infrastructure as Code (IaC) & Terraform CLI

## 1. IaC (Infrastructure as Code) là gì?
IaC là phương pháp quản lý và thiết lập hạ tầng công nghệ thông tin thông qua mã nguồn (code) thay vì cấu hình thủ công bằng giao diện đồ họa (UI) hoặc các script cấu hình ad-hoc.

### Declarative (Khai báo) vs Imperative (Mệnh lệnh):
- **Declarative (Terraform):** Bạn chỉ cần định nghĩa trạng thái mong muốn của hạ tầng (Ví dụ: "Tôi muốn có 1 EC2 instance"). Terraform sẽ tự tính toán các bước cần thiết để đạt được trạng thái đó.
- **Imperative (AWS CLI, Ansible):** Bạn phải viết từng bước lệnh để tạo hạ tầng (Ví dụ: "Bước 1: Tạo VPC. Bước 2: Tạo Subnet. Bước 3: Tạo EC2").

## 2. Quy trình làm việc với Terraform CLI (Workflow)
Quy trình làm việc cơ bản gồm 4 bước chính:

1.  **`terraform init`:**
    *   Khởi tạo thư mục làm việc.
    *   Tải về các provider plugin cần thiết (ví dụ: AWS provider) và lưu thông tin vào file `.terraform/` và `.terraform.lock.hcl`.
2.  **`terraform plan`:**
    *   So sánh code cấu hình với trạng thái thực tế trên Cloud.
    *   Hành động "xem trước" các tài nguyên sẽ được tạo mới (+), thay đổi (~), hoặc xóa bỏ (-).
3.  **`terraform apply`:**
    *   Áp dụng và triển khai các thay đổi hạ tầng lên Cloud thực tế.
    *   Ghi lại trạng thái hạ tầng vào file `terraform.tfstate`.
4.  **`terraform destroy`:**
    *   Xóa toàn bộ các tài nguyên được quản lý bởi cấu hình Terraform này để tránh phát sinh chi phí.
