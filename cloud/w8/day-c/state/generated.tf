# __generated__ by Terraform
# Please review these resources and move them into your main configuration files.

resource "aws_s3_bucket" "local" {
  bucket              = "hoangcuteday"
  bucket_namespace    = "global"
  force_destroy       = false
  object_lock_enabled = false
  region              = "ap-southeast-1"
  tags                = {}
  tags_all            = {}
}
