output "bucket_name" {
  description = "The name of the static assets S3 bucket"
  value       = aws_s3_bucket.static_assets.id
}

output "bucket_arn" {
  description = "The ARN of the static assets S3 bucket"
  value       = aws_s3_bucket.static_assets.arn
}

output "bucket_domain_name" {
  description = "The domain name of the static assets S3 bucket"
  value       = aws_s3_bucket.static_assets.bucket_regional_domain_name
}

output "logo_object_key" {
  description = "The S3 object key of the uploaded sample logo"
  value       = aws_s3_object.sample_image.key
}

output "s3_objects_ready" {
  description = "Trigger list of uploaded objects to ensure dependency ordering"
  value       = [
    aws_s3_object.sample_image.id,
    aws_s3_object.app_py.id,
    aws_s3_object.index_html.id
  ]
}
