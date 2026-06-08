# 🚀 Multi-Tier Web Application Deployment on AWS (Capstone W8 Final)

This project implements the Week 8 Capstone assignment: designing and deploying a multi-tier web application architecture on AWS with Terraform, securing access with least-privilege security groups, and storing state in an S3 remote backend with DynamoDB locking.

---

## 📐 Architecture Design

The deployed architecture is fully isolated and secure:

```text
┌────────────────────────────────────────────────────────────────────────┐
│                      VPC Network (10.0.0.0/16)                         │
│                                                                        │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │                     Internet Gateway (IGW)                       │  │
│  └─────────────────────────────────┬────────────────────────────────┘  │
│                                    │                                   │
│  ┌─────────────────────────────────▼────────────────────────────────┐  │
│  │                    Public Subnets (10.0.1.0/24)                 │  │
│  │                                                                  │  │
│  │   ┌──────────────────────────────────────────────────────────┐   │  │
│  │   │          EC2 Web Server (t3.micro, Public IP)            │   │  │
│  │   │          Security Group: Inbound HTTP (80), SSH (22)     │   │  │
│  │   │          IAM Profile: Read/Write Access to S3            │   │  │
│  │   │                                                          │   │  │
│  │   │   ┌────────────────────────┐                             │   │  │
│  │   │   │   Flask Web Application│                             │   │  │
│  │   │   └───────────┬────────────┘                             │   │  │
│  │   └───────────────┼───────────────────▲──────────────────────┘   │  │
│  └───────────────────┼───────────────────┼──────────────────────────┘  │
│                      │ Private Port 3306 │ IAM Pre-signed URL         │
│  ┌───────────────────┼───────────────────┼──────────────────────────┐  │
│  │  Private Subnets  │ (10.0.10.0/24)    │                          │  │
│  │                   ▼                   │                          │  │
│  │   ┌────────────────────────────────┐  │  ┌────────────────────┐  │  │
│  │   │       RDS MySQL Database       │  │  │  Static S3 Bucket  │  │  │
│  │   │  (Port 3306, Private, No IGW)  │  └──┤  (Private Assets)  │  │  │
│  │   │  SG: Allow Inbound Web Server   │     │  Object: logo.png  │  │  │
│  │   └────────────────────────────────┘     └────────────────────┘  │  │
│  └──────────────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────────────┘
```

### Key Architectural Highlights:
1. **Isolated Database Tier**: The RDS MySQL instance is placed strictly in the private subnets with no internet route. Its security group allows inbound connections on port 3306 **only** from the EC2 Web Server's security group.
2. **Credential-Free S3 Access**: The EC2 Web Server is assigned an IAM Instance Profile containing an IAM Role with read-only/write access policies to the private static assets S3 bucket. Access is authenticated transparently without storing AWS access keys on the server.
3. **Remote State Backend**: The infrastructure's `.tfstate` is stored remotely in S3 with versioning enabled and encrypted at rest. Concurrent execution is prevented by DynamoDB state locking.
4. **Dynamic AMI Resolution**: The EC2 instance retrieves the latest Amazon Linux 2023 AMI dynamically using SSM Parameter store query, avoiding hardcoded values.
5. **Interactive Dashboard App**: The user data bootstrap script automatically installs Python, Flask, and packages to run a real-time cybersecurity-styled dashboard. It links VPC, RDS, and S3 status indicators, displays EC2 IMDSv2 metadata, loads static assets from S3 via pre-signed URLs, and offers a Guestbook form to write and fetch rows from RDS MySQL.

---

## ⚡ Deployment Instructions (Step-by-Step)

### Prerequisites
- AWS CLI configured with administrator permissions.
- Terraform CLI (`>= 1.6.0`) installed.

---

### Step 1: Deploy Remote Backend Infrastructure
Before initializing the main configuration with S3 backend storage, we must provision the S3 state bucket and DynamoDB table.

1. Navigate to the bootstrapper directory:
   ```bash
   cd backend-setup
   ```
2. Initialize and deploy the S3/DynamoDB resources:
   ```bash
   terraform init
   terraform apply -auto-approve
   ```
3. Copy the output bucket name (`s3_bucket_name`) and DynamoDB table name (`dynamodb_table_name`) into `../providers.tf` under the `backend "s3"` block if you changed the defaults. (Defaults are pre-configured to `huyvlt-xb-dn26-102-tfstate-bucket` and `terraform-state-locks`).

---

### Step 2: Deploy Main Infrastructure
1. Return to the root capstone directory:
   ```bash
   cd ..
   ```
2. Initialize the main directory (this will hook into the S3 Remote Backend automatically):
   ```bash
   terraform init
   ```
3. Review the execution plan to see the 14+ resources being provisioned:
   ```bash
   terraform plan
   ```
4. Deploy the infrastructure:
   ```bash
   terraform apply -auto-approve
   ```

*(⏱ Deployment takes approximately 5-7 minutes for the RDS database provisioning).*

---

## 🔍 Verification & Accessing the Application

### 1. View the Web Dashboard
After the deployment completes, copying the `application_url` output from the terminal (or running `terraform output application_url`) will provide the address:
```text
http://<EC2-Public-IP>/
```
Open this link in your browser. You will see a futuristic, responsive dark-themed Cyberpunk dashboard displaying:
- **System Connections**: Real-time health check status of VPC, S3 static storage, and RDS MySQL database.
- **EC2 Instance Metadata**: Real-time information (Instance ID, Instance Type, Availability Zone, Private IP) retrieved dynamically via IMDSv2.
- **Static S3 Image Asset**: An image fetched securely from the S3 bucket using a secure, temporary pre-signed URL.
- **Guestbook Database**: A form allowing you to submit entries (Name, Message) which are saved directly into the RDS database and re-loaded onto the table below.

### 2. SSH Debugging (Optional)
A cryptographic SSH key pair is created dynamically. To connect to the instance:
```bash
# Set appropriate permissions (Mac/Linux only)
chmod 400 generated-key.pem

# SSH into the server
ssh -i generated-key.pem ec2-user@<EC2-Public-IP>
```
To view the bootstrapping process on the EC2 instance:
```bash
sudo tail -f /var/log/bootstrap.log
```

---

## 🛑 Clean Up (Destroy)
To avoid incurring unnecessary AWS costs:

1. Destroy the main resources:
   ```bash
   terraform destroy -auto-approve
   ```
2. Destroy the remote backend bootstrapping resources:
   ```bash
   cd backend-setup
   terraform destroy -auto-approve
   ```
