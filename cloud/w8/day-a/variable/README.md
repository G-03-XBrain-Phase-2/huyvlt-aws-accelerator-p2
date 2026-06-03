# W8 Day2 - Terraform Variable

## Tóm tắt lab

Lab này thực hành cách sử dụng biến trong Terraform để tạo một S3 bucket trên AWS. Cấu hình hiện có dùng AWS provider tại region `ap-southeast-1`, profile `default`, nhận giá trị từ `variables.tf` và `terraform.tfvars`, sau đó tạo bucket với `bucket_prefix`, `tags`, `force_destroy` và điều kiện `lifecycle.precondition`.

## Mục tiêu

- Hiểu cách khai báo biến Terraform trong `variables.tf`.
- Hiểu sự khác nhau giữa `variable`, file `terraform.tfvars`, biến môi trường và tham số `-var`.
- Sử dụng `locals` để tạo giá trị trung gian và gom tag dùng chung.
- Sử dụng `validation` để giới hạn giá trị hợp lệ của biến.
- Sử dụng `lifecycle.precondition` để kiểm tra điều kiện trước khi tạo resource.

## Nội dung thực hiện

### Variable và terraform.tfvars

`variable` là nơi khai báo đầu vào cho Terraform. Trong lab này, các biến được khai báo trong `variables.tf`:

- `environment`: môi trường triển khai, mặc định là `dev`.
- `project`: tên dự án, mặc định là `myproject`.
- `force_destroy`: cho phép xóa bucket kể cả khi có object bên trong, mặc định là `false`.

`terraform.tfvars` là file gán giá trị cụ thể cho các biến đã khai báo. File hiện tại đang gán:

```hcl
environment   = "prod"
project       = "myproject"
force_destroy = false
```

Khác biệt chính:

- `variables.tf` định nghĩa biến gồm tên, kiểu dữ liệu, mô tả, giá trị mặc định và validation.
- `terraform.tfvars` cung cấp giá trị thực tế cho các biến khi chạy Terraform.
- Nếu không có giá trị trong `terraform.tfvars`, Terraform sẽ dùng `default` nếu biến có khai báo default.

### terraform.tfvars, biến môi trường và -var

Ngoài `terraform.tfvars`, Terraform còn có thể nhận giá trị biến từ biến môi trường hoặc tham số dòng lệnh.

`terraform.tfvars` phù hợp khi muốn lưu cấu hình mặc định cho lab hoặc cho một môi trường cụ thể:

```hcl
environment   = "prod"
project       = "myproject"
force_destroy = false
```

Biến môi trường dùng cú pháp `TF_VAR_<ten_bien>`. Cách này phù hợp khi không muốn ghi giá trị trực tiếp vào file, ví dụ trong terminal hoặc CI/CD:

```bash
export TF_VAR_environment=staging
export TF_VAR_project=myproject
export TF_VAR_force_destroy=false
terraform plan
```

Trên PowerShell có thể dùng:

```powershell
$env:TF_VAR_environment = "staging"
$env:TF_VAR_project = "myproject"
$env:TF_VAR_force_destroy = "false"
terraform plan
```

Tham số `-var` truyền giá trị trực tiếp khi chạy lệnh. Cách này phù hợp để override nhanh trong một lần chạy:

```bash
terraform plan -var="environment=dev" -var="project=myproject" -var="force_destroy=false"
```

So sánh nhanh:

- `terraform.tfvars`: lưu giá trị trong file, dễ dùng lại, phù hợp cho lab hoặc cấu hình theo môi trường.
- `TF_VAR_*`: truyền qua biến môi trường, hữu ích cho CI/CD hoặc giá trị không muốn ghi vào file.
- `-var`: truyền trực tiếp khi chạy `terraform plan` hoặc `terraform apply`, tiện cho override tạm thời.
- Với ba cách trên, thứ tự ưu tiên thường là `TF_VAR_*` thấp nhất, sau đó đến `terraform.tfvars`, và `-var` cao hơn để override trong một lần chạy.

### Locals

`locals` được dùng để tạo các giá trị nội bộ, giúp tái sử dụng và làm code gọn hơn. Trong `main.tf`, lab khai báo:

- `name_prefix = "${var.project}-${var.environment}"`: tạo tiền tố tên bucket từ project và environment.
- `is_prod = var.environment == "prod"`: kiểm tra môi trường có phải production không.
- `common_tags`: gom các tag dùng chung cho resource.

Resource S3 bucket sử dụng `local.name_prefix` cho `bucket_prefix` và `local.common_tags` cho `tags`.

### Validation

Biến `environment` có khối `validation` để chỉ cho phép các giá trị:

- `dev`
- `staging`
- `prod`

Nếu gán giá trị khác, Terraform sẽ báo lỗi:

```text
The environment variable must be one of 'dev', 'staging', or 'prod'.
```

Validation giúp bắt lỗi đầu vào sớm trước khi Terraform tạo tài nguyên.

### Lifecycle

Resource `aws_s3_bucket.local` có cấu hình `lifecycle.precondition`. Điều kiện hiện tại trong code là:

```hcl
condition = local.is_prod && var.force_destroy == false
```

Theo cấu hình này, Terraform chỉ cho phép tiếp tục khi:

- `environment` là `prod`
- `force_destroy` là `false`

Thông báo lỗi hiện tại là `S3 bucket can only be created in the 'prod' environment with force_destroy set to false.`. Điều kiện thực tế yêu cầu `environment = "prod"` và `force_destroy = false`, nên khi chạy lab cần giữ cấu hình này nếu muốn pass `precondition`.

## Công nghệ sử dụng

- Terraform `>= 1.0`
- AWS provider `hashicorp/aws` version `~> 6.0`
- AWS S3

## Cấu trúc file

```text
cloud/w8/day-a/variable/
├── main.tf
├── variables.tf
├── terraform.tfvars
└── README.md
```

- `main.tf`: cấu hình provider, locals, resource S3 bucket và output.
- `variables.tf`: khai báo biến đầu vào và validation.
- `terraform.tfvars`: gán giá trị thực tế cho biến.

## Cách chạy

Cần có AWS credentials/profile `default` trước khi chạy.

```bash
terraform init
terraform plan
terraform apply
```

Sau khi apply, Terraform sẽ tạo một S3 bucket với tên có tiền tố `myproject-prod-` và in ra output `bucket_name`.

## Kiểm tra kết quả

Kiểm tra output:

```bash
terraform output bucket_name
```

Or check state:

```bash
terraform state list
```

## Dọn dẹp tài nguyên

Xóa resource đã tạo:

```bash
terraform destroy
```

Nếu bucket có object bên trong và `force_destroy = false`, cần xóa object trong bucket trước khi destroy.

## Ghi chú

- File `terraform.tfvars` hiện đang cấu hình `environment = "prod"` và `force_destroy = false`, nên phù hợp với `lifecycle.precondition` theo code hiện tại.
- `lifecycle.precondition` hiện yêu cầu `environment = "prod"` và `force_destroy = false`.
