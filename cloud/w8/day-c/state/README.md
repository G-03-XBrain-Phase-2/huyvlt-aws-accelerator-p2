# W8 Day2 - Terraform Import và State

## Tóm tắt lab

Lab này thực hành import một AWS S3 bucket có sẵn vào Terraform state, sinh cấu hình từ tài nguyên đã import, áp dụng cấu hình, kiểm tra state và xóa resource khỏi state.

Tài nguyên trong lab là S3 bucket `hoangcuteday` ở region `ap-southeast-1`.

## Mục tiêu

- Dùng `import` block để khai báo tài nguyên AWS có sẵn cần đưa vào Terraform.
- Dùng `terraform plan -generate-config-out` để sinh file cấu hình từ tài nguyên import.
- Dùng `terraform apply` để import tài nguyên vào Terraform state.
- Dùng `terraform state list` để xem resource đang được Terraform quản lý.
- Dùng `terraform state rm` để xóa resource khỏi state mà không xóa tài nguyên thật trên AWS.

## Nội dung thực hiện

File `main.tf` cấu hình AWS provider và import block:

```hcl
provider "aws" {
  region  = "ap-southeast-1"
  profile = "default"
}

import {
  to = aws_s3_bucket.local
  id = "hoangcuteday"
}
```

File `generated.tf` được Terraform sinh ra từ bucket `hoangcuteday` và chứa resource:

```hcl
resource "aws_s3_bucket" "local" {
  bucket              = "hoangcuteday"
  bucket_namespace    = "global"
  force_destroy       = false
  object_lock_enabled = false
  region              = "ap-southeast-1"
  tags                = {}
  tags_all            = {}
}
```

State hiện tại không còn resource nào vì resource đã được xóa khỏi state bằng `terraform state rm`. File backup state `terraform.tfstate.1780376345.backup` cho thấy trước đó bucket từng nằm trong state với địa chỉ `aws_s3_bucket.local`.

## Công nghệ sử dụng

- Terraform `>= 1.0`
- Terraform AWS provider `~> 6.0`
- AWS profile `default`
- AWS region `ap-southeast-1`
- AWS S3

## Cấu trúc file

```text
cloud/w8/day-c/state/
|-- .terraform.lock.hcl
|-- generated.tf
|-- main.tf
|-- README.md
```

## Cách chạy

Chạy các lệnh trong thư mục lab:

```bash
cd cloud/w8/day-c/state
```

Khởi tạo Terraform:

```bash
terraform init
```

Sinh cấu hình từ import block:

```bash
terraform plan -generate-config-out=generated.tf
```

Nếu `generated.tf` đã tồn tại, Terraform có thể yêu cầu chọn file output khác hoặc xóa file cũ trước khi sinh lại.

Áp dụng cấu hình và import bucket vào state:

```bash
terraform apply
```

## Kiểm tra kết quả

Kiểm tra các resource đang có trong Terraform state:

```bash
terraform state list
```

Sau khi import thành công, kết quả mong đợi có resource:

```text
aws_s3_bucket.local
```

## Xóa resource khỏi state

Để xóa bucket khỏi Terraform state nhưng không xóa bucket thật trên AWS:

```bash
terraform state rm aws_s3_bucket.local
```

Sau đó kiểm tra lại:

```bash
terraform state list
```

Nếu không có output, state hiện tại không còn quản lý resource nào.

Lưu ý: nếu đã chạy `terraform state rm aws_s3_bucket.local` nhưng trong cấu hình vẫn còn resource `aws_s3_bucket.local` và không có `import` block, lần chạy `terraform apply` tiếp theo sẽ cố tạo mới bucket. Vì bucket `hoangcuteday` đã tồn tại trên AWS, thao tác này có thể bị xung đột. Khi còn `import` block, Terraform sẽ import lại bucket có sẵn vào state thay vì tạo bucket mới.

## Dọn dẹp tài nguyên

Lab này thao tác với S3 bucket có sẵn. Lệnh `terraform state rm` chỉ xóa liên kết trong Terraform state, không xóa bucket trên AWS.

Nếu cần xóa bucket thật, cần kiểm tra thêm nội dung bucket và thực hiện bằng AWS Console, AWS CLI hoặc Terraform sau khi đã đảm bảo an toàn.

## Ghi chú

- Không sửa thủ công `.terraform.lock.hcl` vì file này được Terraform quản lý.
- Cần đảm bảo AWS profile `default` có quyền đọc và import S3 bucket `hoangcuteday`.
- Sắp xếp và tổ chức thư mục học tập của bạn giúp theo dõi dễ dàng hơn.
