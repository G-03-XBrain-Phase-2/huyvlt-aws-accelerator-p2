variable "project_name" {
  description = "Name of the project to prefix resources"
  type        = string
}

variable "common_tags" {
  description = "Common tags to apply to resources"
  type        = map(string)
}

variable "bucket_name" {
  description = "Name of the static assets S3 bucket (globally unique)"
  type        = string
}
