# Create the static assets S3 bucket
resource "aws_s3_bucket" "static_assets" {
  bucket        = var.bucket_name
  force_destroy = true

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-static-assets"
    }
  )
}

# Keep the S3 bucket private
resource "aws_s3_bucket_public_access_block" "static_block" {
  bucket = aws_s3_bucket.static_assets.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Upload a sample asset (logo/image) to the bucket
resource "aws_s3_object" "sample_image" {
  bucket       = aws_s3_bucket.static_assets.id
  key          = "logo.png"
  source       = "${path.module}/../../assets/logo.png"
  content_type = "image/png"

  # Ensure the object exists before EC2 tries to fetch it
  depends_on = [aws_s3_bucket.static_assets]
}

# Upload app.py to S3 for EC2 download
resource "aws_s3_object" "app_py" {
  bucket       = aws_s3_bucket.static_assets.id
  key          = "app.py"
  source       = "${path.module}/../../app/app.py"
  content_type = "text/x-python"
  etag         = filemd5("${path.module}/../../app/app.py")
  depends_on   = [aws_s3_bucket.static_assets]
}

# Upload index.html to S3 for EC2 download
resource "aws_s3_object" "index_html" {
  bucket       = aws_s3_bucket.static_assets.id
  key          = "index.html"
  source       = "${path.module}/../../app/templates/index.html"
  content_type = "text/html"
  etag         = filemd5("${path.module}/../../app/templates/index.html")
  depends_on   = [aws_s3_bucket.static_assets]
}
