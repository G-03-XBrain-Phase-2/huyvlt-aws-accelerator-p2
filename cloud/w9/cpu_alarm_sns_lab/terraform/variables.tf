variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-1"
}

variable "instance_id" {
  description = "EC2 Instance ID cần giám sát (bắt buộc)"
  type        = string
  # Không có default — bắt buộc nhập
}

variable "alert_email" {
  description = "Email nhận cảnh báo CPU (bắt buộc)"
  type        = string
  # Không có default — bắt buộc nhập
}

variable "cpu_threshold" {
  description = "Ngưỡng CPU (%) để trigger alarm"
  type        = number
  default     = 80
}

variable "alarm_period" {
  description = "Period tính bằng giây (300 = 5 phút)"
  type        = number
  default     = 300
}

variable "key_pair_name" {
  description = "AWS Key Pair cho EC2 (nếu tạo EC2 mới)"
  type        = string
  default     = ""
}

variable "common_tags" {
  description = "Tags chung cho tất cả resources"
  type        = map(string)
  default = {
    Project     = "CPU-Alarm-SNS-Lab"
    Environment = "lab"
    ManagedBy   = "terraform"
    Session     = "W9-Session03"
  }
}
