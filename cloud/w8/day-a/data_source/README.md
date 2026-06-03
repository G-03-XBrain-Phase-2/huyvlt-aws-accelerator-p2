# W8 Day2 - Terraform Data Source

## Tóm tắt lab

Lab này minh họa cách dùng Terraform data source trên AWS để lấy thông tin tài khoản hiện tại, danh sách Availability Zone, AMI mới nhất và VPC mặc định. Lab cũng tạo một Security Group với các rule ingress sinh từ `dynamic block`.

## Mục tiêu

- Cấu hình Terraform với AWS provider.
- Đọc dữ liệu có sẵn trên AWS bằng data source.
- Dùng `for` expression trong `locals`.
- Dùng `dynamic block` để tạo nhiều rule ingress cho Security Group.
- Xuất các giá trị lấy được từ data source qua output.

## Nội dung thực hiện

- Sử dụng AWS provider ở region `ap-southeast-1` với profile `default`.
- Lấy AWS account ID hiện tại bằng `aws_caller_identity`.
- Lấy danh sách Availability Zone đang available bằng `aws_availability_zones`.
- Tìm AMI Amazon Linux 2023 mới nhất bằng `aws_ami`.
- Lấy default VPC bằng `aws_vpc`.
- Tạo Security Group `web-sg` trong default VPC.
- Tạo rule ingress theo danh sách `allowed_ports`, bỏ qua port `32`.
- Cho phép toàn bộ outbound traffic từ Security Group.

## Công nghệ sử dụng

- Terraform `>= 1.10`
- HashiCorp AWS provider `~> 6.0`
- AWS region `ap-southeast-1`

## Cấu trúc file

```text
cloud/w8/day-a/data_source/
|-- main.tf
|-- variables.tf
`-- README.md
```

## Cách chạy

Cần cấu hình AWS credentials cho profile `default` trước khi chạy.

```bash
terraform init
terraform plan
terraform apply
```

Giá trị mặc định của `allowed_ports` là:

```hcl
[80, 443, 32]
```

Khi apply, Security Group chỉ tạo ingress cho port `80` và `443` vì port `32` bị lọc ra trong `locals.web_ports`.

## Kiểm tra kết quả

Sau khi apply, kiểm tra output:

- `account_id`: AWS account ID của caller hiện tại.
- `availability_zones`: danh sách Availability Zone available trong region.
- `ubuntu_ami_id`: ID của AMI Amazon Linux 2023 mới nhất theo filter trong `main.tf`.

Có thể xem Security Group trên AWS Console hoặc bằng AWS CLI nếu cần kiểm tra rule ingress/egress.

## Dọn dẹp tài nguyên

Chạy lệnh sau để xóa Security Group đã tạo:

```bash
terraform destroy
```

## Ghi chú

- Data source chỉ đọc thông tin có sẵn, không tạo tài nguyên AWS.
- Tài nguyên được tạo trong lab này là Security Group `web-sg`.
- Tên output `ubuntu_ami_id` đang trỏ tới AMI Amazon Linux 2023 theo filter hiện tại trong file Terraform.
