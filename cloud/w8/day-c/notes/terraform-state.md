# Terraform State & Remote State

## 1. Terraform State là gì?
Terraform State (`terraform.tfstate`) là file lưu trữ thông tin về trạng thái thực tế của các tài nguyên (resources) được quản lý bởi Terraform. Nó ánh xạ cấu hình trong code HCL của bạn với các tài nguyên thực tế trên Cloud (như AWS).

## 2. Tại sao Terraform State lại quan trọng?
- **Ánh xạ thực tế (Mapping):** Nhờ có state, Terraform biết resource trong code đang đại diện cho đối tượng nào ngoài thực tế.
- **Quản lý phụ thuộc (Dependency Metadata):** State lưu trữ thông tin về mối quan hệ phụ thuộc giữa các resource để lập kế hoạch tạo, cập nhật hoặc hủy tài nguyên theo đúng thứ tự.
- **Hiệu năng (Performance):** State lưu cache các thuộc tính của resource để tăng tốc độ cho lệnh `terraform plan`.
- **Đồng bộ hóa khi làm việc nhóm (Team Collaboration):** Khi nhiều người cùng làm việc trên một hạ tầng, state cần được đặt ở một vị trí dùng chung (Remote State).

## 3. Remote State & State Locking (S3 + DynamoDB)
Để tránh xung đột khi nhiều người cùng chạy `terraform apply`, ta cấu hình Remote Backend trên AWS:
- **S3 Bucket:** Nơi lưu trữ file `terraform.tfstate` tập trung và an toàn.
- **DynamoDB Table:** Sử dụng để khóa trạng thái (State Locking), ngăn chặn việc hai người cùng apply cấu hình tại cùng một thời điểm.

---
## Ghi chú quan trọng
- ⚠️ **Không bao giờ** commit trực tiếp file `terraform.tfstate` lên GitHub (vì nó chứa thông tin nhạy cảm của hạ tầng).
- Hãy cấu hình `.gitignore` cẩn thận (đã được cấu hình ở thư mục gốc của repo).
