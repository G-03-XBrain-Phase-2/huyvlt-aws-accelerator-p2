variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-1"
}

variable "alert_email" {
  description = "Email nhận cảnh báo Root login (bắt buộc)"
  type        = string
}

variable "alert_phone" {
  description = "Số điện thoại SMS, định dạng E.164 (vd: +84912345678). Để trống nếu không cần SMS."
  type        = string
  default     = ""
}

variable "deploy_lambda" {
  description = "Có deploy Lambda auto-disable root không? (true/false)"
  type        = bool
  default     = false
}

variable "common_tags" {
  description = "Tags chung cho tất cả resources"
  type        = map(string)
  default = {
    Project     = "Root-Account-Alert-Lab"
    Environment = "security"
    ManagedBy   = "terraform"
    Session     = "W9-Session05"
  }
}
