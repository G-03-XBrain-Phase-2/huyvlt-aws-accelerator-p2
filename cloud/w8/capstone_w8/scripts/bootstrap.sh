#!/bin/bash
# =============================================================
# Bootstrap Script — Run automatically during EC2 initialization
# Installs: Docker -> Minikube -> kubectl -> Deploy app
# =============================================================
set -euxo pipefail

# Redirect logs
exec > >(tee /var/log/bootstrap.log) 2>&1

NODE_PORT="${node_port}"
APP_PORT="${app_port}"

echo "=== [1/6] Configure Swap Space ==="
if [ ! -f /swapfile ]; then
  dd if=/dev/zero of=/swapfile bs=1M count=4096
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

echo "=== [2/6] Install dependencies (Docker, git, tar, jq) ==="
dnf install -y --allowerasing wget git tar jq docker
systemctl enable --now docker
usermod -aG docker ec2-user

echo "=== [3/6] Install kubectl & Minikube ==="
KUBECTL_VERSION=$(curl -sL https://dl.k8s.io/release/stable.txt)
curl -Lo /usr/local/bin/kubectl "https://dl.k8s.io/release/$${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
chmod +x /usr/local/bin/kubectl

curl -Lo /usr/local/bin/minikube "https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64"
chmod +x /usr/local/bin/minikube

# Start Minikube as ec2-user
echo "=== [4/6] Start Minikube as ec2-user ==="
su - ec2-user -c "minikube start --driver=docker --wait=all"

echo "=== [5/6] Deploy App into Minikube ==="
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id || echo "unknown")
LOCAL_IP=$(hostname -I | awk '{print $1}')
BUILD_TIME=$(date "+%Y-%m-%d %H:%M:%S")

# Create deployment manifest
cat > /tmp/app-deployment.yaml <<K8SYAML
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-html
  namespace: default
data:
  index.html: |
    <!DOCTYPE html>
    <html lang="en">
    <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>K8s on AWS — 1-Click Terraform</title>
    <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@300;400;600;800&family=JetBrains+Mono:wght@400;700&display=swap" rel="stylesheet">
    <style>
    :root{--bg-color:#0b0f19;--panel-bg:rgba(17,24,39,0.7);--primary-glow:#00ff88;--secondary-glow:#00bfff;--text-main:#f3f4f6;--text-muted:#9ca3af;--border-color:rgba(0,255,136,0.2)}
    *{margin:0;padding:0;box-sizing:border-box}
    body{font-family:'Outfit',sans-serif;background-color:var(--bg-color);background-image:radial-gradient(at 10% 20%,rgba(0,255,136,0.05) 0,transparent 50%),radial-gradient(at 90% 80%,rgba(0,191,255,0.05) 0,transparent 50%);color:var(--text-main);min-height:100vh;display:flex;align-items:center;justify-content:center;padding:1.5rem;overflow-x:hidden}
    .container{width:100%;max-width:750px;background:var(--panel-bg);backdrop-filter:blur(16px);-webkit-backdrop-filter:blur(16px);border:1px solid var(--border-color);border-radius:20px;padding:2rem;box-shadow:0 20px 50px rgba(0,0,0,0.3),0 0 40px rgba(0,255,136,0.05);position:relative}
    .container::before{content:'';position:absolute;top:-1px;left:-1px;right:-1px;bottom:-1px;border-radius:20px;background:linear-gradient(135deg,var(--primary-glow),var(--secondary-glow));z-index:-1;opacity:0.15;pointer-events:none}
    .header{display:flex;justify-content:space-between;align-items:start;border-bottom:1px solid rgba(255,255,255,0.08);padding-bottom:1rem;margin-bottom:1.5rem}
    .header-title h1{font-size:2rem;font-weight:800;background:linear-gradient(135deg,#fff 30%,#00ff88 100%);-webkit-background-clip:text;-webkit-text-fill-color:transparent;letter-spacing:-0.5px}
    .header-title p{color:var(--text-muted);font-size:0.9rem;margin-top:0.25rem}
    .status-badge{display:flex;align-items:center;gap:0.5rem;background:rgba(0,255,136,0.1);border:1px solid rgba(0,255,136,0.2);color:var(--primary-glow);padding:0.3rem 0.8rem;border-radius:50px;font-family:'JetBrains Mono',monospace;font-size:0.75rem;font-weight:bold;letter-spacing:0.5px}
    .pulse-dot{width:8px;height:8px;background-color:var(--primary-glow);border-radius:50%;box-shadow:0 0 10px var(--primary-glow);animation:pulse 1.8s infinite}
    @keyframes pulse{0%%{transform:scale(0.95);box-shadow:0 0 0 0 rgba(0,255,136,0.7)}70%%{transform:scale(1);box-shadow:0 0 0 8px rgba(0,255,136,0)}100%%{transform:scale(0.95);box-shadow:0 0 0 0 rgba(0,255,136,0)}}
    .profile-section{background:rgba(255,255,255,0.02);border:1px solid rgba(255,255,255,0.05);border-radius:12px;padding:1rem;margin-bottom:1.5rem;display:grid;grid-template-columns:repeat(auto-fit,minmax(180px,1fr));gap:1rem}
    .profile-card h3{font-size:0.7rem;text-transform:uppercase;color:var(--text-muted);letter-spacing:1px;margin-bottom:0.25rem}
    .profile-card p{font-size:1rem;font-weight:600;color:#fff}
    .grid-spec{display:grid;gap:0.5rem;margin-bottom:1.5rem}
    .spec-item{display:flex;align-items:center;justify-content:space-between;padding:0.75rem 1rem;background:rgba(255,255,255,0.03);border:1px solid rgba(255,255,255,0.05);border-radius:10px;transition:all 0.2s}
    .spec-item:hover{background:rgba(0,255,136,0.02);border-color:rgba(0,255,136,0.15);transform:translateX(4px)}
    .spec-label{display:flex;align-items:center;gap:0.5rem;color:var(--text-muted);font-size:0.85rem}
    .spec-icon{color:var(--primary-glow);font-size:1rem}
    .spec-value{font-family:'JetBrains Mono',monospace;font-size:0.85rem;color:#fff;font-weight:500}
    .footer{text-align:center;font-size:0.75rem;color:var(--text-muted);border-top:1px solid rgba(255,255,255,0.08);padding-top:1rem;line-height:1.4}
    .footer-flow{display:inline-block;background:rgba(255,255,255,0.03);padding:0.3rem 0.6rem;border-radius:6px;margin-top:0.5rem;font-family:'JetBrains Mono',monospace;font-size:0.7rem;color:var(--secondary-glow)}
    .knowledge-section{margin-top:1.5rem;background:rgba(255,255,255,0.015);border:1px dashed rgba(0,255,136,0.15);border-radius:12px;padding:1rem;margin-bottom:1.5rem;text-align:left}
    .knowledge-section h2{font-size:1.1rem;color:var(--primary-glow);margin-bottom:1rem;font-weight:700;letter-spacing:-0.3px}
    .faq-card{background:rgba(255,255,255,0.02);border:1px solid rgba(255,255,255,0.04);border-radius:8px;padding:0.8rem;margin-bottom:0.6rem}
    .faq-card:last-child{margin-bottom:0}
    .faq-card h3{font-size:0.9rem;color:#fff;margin-bottom:0.3rem;font-weight:600}
    .faq-card p,.faq-card li{font-size:0.8rem;color:var(--text-muted);line-height:1.5}
    .faq-card ul{margin-left:1rem;margin-top:0.25rem}
    .faq-card li{margin-bottom:0.15rem}
    .faq-card strong{color:var(--secondary-glow)}
    .faq-card code{background:rgba(255,255,255,0.07);padding:1px 4px;border-radius:3px;color:#fff;font-family:'JetBrains Mono',monospace;font-size:0.75rem}
    </style>
    </head>
    <body>
    <div class="container">
    <div class="header">
    <div class="header-title">
    <h1>K8s on AWS (Minikube)</h1>
    <p>1-Click Infrastructure & Container Automation</p>
    </div>
    <div class="status-badge">
    <div class="pulse-dot"></div>
    <span>RUNNING</span>
    </div>
    </div>
    <div class="profile-section">
    <div class="profile-card">
    <h3>Student Name</h3>
    <p>Võ Lê Trường Huy</p>
    </div>
    <div class="profile-card">
    <h3>Student ID</h3>
    <p>XB-DN26-102</p>
    </div>
    <div class="profile-card">
    <h3>Class Group</h3>
    <p>Group 3 — DevOps</p>
    </div>
    </div>
    <div class="grid-spec">
    <div class="spec-item">
    <span class="spec-label"><span class="spec-icon">☸</span> Control Plane</span>
    <span class="spec-value">Kubernetes (Minikube Node)</span>
    </div>
    <div class="spec-item">
    <span class="spec-label"><span class="spec-icon">🐳</span> Container Runtime</span>
    <span class="spec-value">Docker Engine on Minikube VM</span>
    </div>
    <div class="spec-item">
    <span class="spec-label"><span class="spec-icon">⚡</span> IaC Core</span>
    <span class="spec-value">Terraform (AWS + TLS + Local)</span>
    </div>
    <div class="spec-item">
    <span class="spec-label"><span class="spec-icon">🖥</span> EC2 Instance ID</span>
    <span class="spec-value">thay_the_id</span>
    </div>
    <div class="spec-item">
    <span class="spec-label"><span class="spec-icon">🌐</span> EC2 Private IP</span>
    <span class="spec-value">thay_the_ip</span>
    </div>
    <div class="spec-item">
    <span class="spec-label"><span class="spec-icon">📅</span> Build Timestamp</span>
    <span class="spec-value">thay_the_time</span>
    </div>
    </div>
    <div class="knowledge-section">
    <h2>💡 Tài Liệu Ôn Tập Hệ Thống</h2>
    <div class="faq-card">
    <h3>1. Luồng chạy của Traffic (Traffic Flow) chi tiết</h3>
    <p><strong>Bước 1 (User to ALB)</strong>: Truy cập ALB DNS qua trình duyệt ở cổng 80 (HTTP).</p>
    <p><strong>Bước 2 (ALB to Target Group)</strong>: ALB nhận yêu cầu và điều hướng (Forward) đến Target Group đã đăng ký EC2 tại cổng NodePort <code>30080</code>.</p>
    <p><strong>Bước 3 (EC2 Host to Minikube)</strong>: Một tiến trình Port Forward chạy ngầm trên EC2 lắng nghe cổng <code>30080</code> và chuyển hướng lưu lượng vào Service của Minikube.</p>
    <p><strong>Bước 4 (Service to Pod Nginx)</strong>: K8s Service <code>demo-app-svc</code> nhận traffic ở cổng 30080 và định tuyến vào các Pod Nginx (cổng container 80).</p>
    </div>
    <div class="faq-card">
    <h3>2. Giải thích cấu trúc mã nguồn Terraform (Code Architecture)</h3>
    <p><strong><code>main.tf</code> (Root)</strong>: Kết nối 3 providers (AWS, TLS, Local). Tự động tạo và lưu trữ SSH Key Pair an toàn.</p>
    <p><strong>Module <code>vpc</code></strong>: Thiết lập VPC CIDR <code>10.0.0.0/16</code>, 2 Public Subnets ở 2 AZ khác nhau (yêu cầu của ALB), Internet Gateway và Security Groups.</p>
    <p><strong>Module <code>ec2</code></strong>: Khởi tạo EC2 Instance loại <code>t3.medium</code> dùng Amazon Linux 2023 và kích hoạt Minikube qua script bootstrap.</p>
    <p><strong>Module <code>alb</code></strong>: Khởi tạo Application Load Balancer để nhận traffic internet công cộng và định tuyến về EC2 NodePort.</p>
    </div>
    <div class="faq-card">
    <h3>3. Tại sao chọn Minikube cho môi trường thực tế?</h3>
    <ul>
    <li><strong>Chuẩn hóa Onsite Lab</strong>: Thống nhất công cụ thực hành tại Lab giúp mentor dễ dàng đối chiếu và chấm điểm.</li>
    <li><strong>Tính năng đầy đủ</strong>: Hỗ trợ 100% các add-ons chuẩn của K8s và dễ cấu hình chuyển đổi driver linh hoạt.</li>
    <li><strong>Môi trường tách biệt</strong>: Minikube bọc các tiến trình quản trị K8s trong một container riêng, không làm bẩn môi trường của máy chủ EC2.</li>
    </ul>
    </div>
    <div class="faq-card">
    <h3>4. Minikube hoạt động như thế nào & khác biệt cốt lõi?</h3>
    <p><strong>Kiến trúc Nodes</strong>: Chạy API Server, Kubelet và etcd riêng biệt đúng quy chuẩn của cụm K8s chuyên nghiệp.</p>
    <p><strong>Port Forwarding</strong>: Do Minikube chạy trong container biệt lập, ta dùng tiến trình <code>kubectl port-forward --address 0.0.0.0</code> để lộ cổng ra máy chủ host EC2.</p>
    </div>
    </div>
    <div class="footer">
    <p>Application successfully deployed via Kubernetes Pod replicas</p>
    <div class="footer-flow">
    Traffic: Internet - ALB:80 - EC2:30080 - Minikube Service - Nginx Pod
    </div>
    </div>
    </div>
    </body>
    </html>

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-app
  namespace: default
spec:
  replicas: 2
  selector:
    matchLabels:
      app: demo-app
  template:
    metadata:
      labels:
        app: demo-app
    spec:
      containers:
        - name: nginx
          image: nginx:alpine
          ports:
            - containerPort: 80
          volumeMounts:
            - name: html
              mountPath: /usr/share/nginx/html
      volumes:
        - name: html
          configMap:
            name: app-html

---
apiVersion: v1
kind: Service
metadata:
  name: demo-app-svc
  namespace: default
spec:
  type: NodePort
  selector:
    app: demo-app
  ports:
    - port: 80
      targetPort: 80
      nodePort: 30080
K8SYAML

# Replace variables using sed
sed -i "s/thay_the_id/$${INSTANCE_ID}/g" /tmp/app-deployment.yaml
sed -i "s/thay_the_ip/$${LOCAL_IP}/g" /tmp/app-deployment.yaml
sed -i "s/thay_the_time/$${BUILD_TIME}/g" /tmp/app-deployment.yaml

# Apply deployment as ec2-user
su - ec2-user -c "kubectl apply -f /tmp/app-deployment.yaml"

echo "=== [6/6] Expose Minikube NodePort to EC2 Host ==="
# Wait for pods to be ready
su - ec2-user -c "kubectl rollout status deployment/demo-app --timeout=180s"

# Run port-forward in background as ec2-user to route traffic from host port 30080 to service port 80
su - ec2-user -c "nohup kubectl port-forward --address 0.0.0.0 service/demo-app-svc 30080:80 > /tmp/port-forward.log 2>&1 &"

echo "=== Setup complete ==="
