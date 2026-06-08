#!/bin/bash
# Send all output to bootstrap.log for debugging
exec > >(tee -i /var/log/bootstrap.log) 2>&1
echo "=== Starting Web App Bootstrapping ==="

# Install updates and dependencies
dnf update -y
dnf install -y python3-pip python3-devel git gcc

# Install required Python libraries
pip3 install Flask pymysql boto3 requests cryptography

# Create app directory structure
mkdir -p /var/www/app/templates

# Download Python app and HTML template from private S3 bucket
# EC2 has permission via IAM Instance Profile
echo "Downloading application files from S3..."
aws s3 cp s3://${s3_bucket_name}/app.py /var/www/app/app.py
aws s3 cp s3://${s3_bucket_name}/index.html /var/www/app/templates/index.html

# Create the systemd service file with injected environment variables
cat << 'EOF' > /etc/systemd/system/webapp.service
[Unit]
Description=Flask Capstone Web Application
After=network.target

[Service]
User=root
WorkingDirectory=/var/www/app
Environment="DB_HOST=${db_host}"
Environment="DB_NAME=${db_name}"
Environment="DB_USER=${db_username}"
Environment="DB_PASS=${db_password}"
Environment="S3_BUCKET=${s3_bucket_name}"
Environment="AWS_REGION=${aws_region}"
ExecStart=/usr/bin/python3 /var/www/app/app.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Start and enable the service
systemctl daemon-reload
systemctl start webapp.service
systemctl enable webapp.service

echo "=== Web App Bootstrapping Completed Successfully ==="
