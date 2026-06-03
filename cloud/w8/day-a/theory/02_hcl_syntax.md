# 02. Cú pháp HCL (HashiCorp Configuration Language)

## 1. Cấu trúc cú pháp cơ bản của HCL
Một file cấu hình HCL chủ yếu được cấu thành từ các **Blocks** (Khối) và các **Arguments** (Đối số).

```hcl
# <BLOCK TYPE> "<BLOCK LABEL 1>" "<BLOCK LABEL 2>" {
#   <IDENTIFIER> = <EXPRESSION> # Argument
# }

resource "aws_instance" "web" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"
}
```

- **Block Type:** Loại khối (ví dụ: `resource`, `provider`, `variable`, `output`, `locals`, `data`).
- **Block Labels:** Các nhãn định danh (ví dụ: `aws_instance` chỉ loại tài nguyên AWS, `web` là tên logic của tài nguyên trong code).
- **Arguments:** Cặp key-value cấu hình thuộc tính cho block (ví dụ: `instance_type = "t2.micro"`).

## 2. Các kiểu dữ liệu phổ biến trong HCL
- **String:** Chuỗi ký tự, nằm trong dấu nháy kép `""` (Ví dụ: `"ap-southeast-1"`).
- **Number:** Số nguyên hoặc số thực (Ví dụ: `80`, `3.14`).
- **Bool:** Giá trị logic (`true` hoặc `false`).
- **List:** Mảng danh sách tuần tự (Ví dụ: `["ap-southeast-1a", "ap-southeast-1b"]`).
- **Map:** Cặp khóa-giá trị (Ví dụ: `tags = { Name = "my-web", Env = "Dev" }`).

## 3. Khác biệt giữa Resource và Data Source
- **Resource (`resource`):** Khai báo tài nguyên mới cần tạo ra và quản lý trên Cloud.
- **Data Source (`data`):** Lấy thông tin từ các tài nguyên đã tồn tại sẵn trên Cloud (ví dụ: thông tin VPC mặc định, AWS Account ID của caller hiện tại) để sử dụng trong code Terraform mà không tạo mới chúng.
