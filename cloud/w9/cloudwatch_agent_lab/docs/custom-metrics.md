# 📊 Custom Metrics Nâng Cao — CloudWatch Agent

## Giới thiệu

Ngoài các metrics hệ thống mặc định (CPU, RAM, Disk), CloudWatch Agent hỗ trợ thu thập **custom metrics** từ ứng dụng của bạn thông qua **StatsD** và **collectd** protocol.

---

## 1. StatsD — Custom Application Metrics

### Kích hoạt StatsD trong config

Thêm section `statsd` vào `cloudwatch-agent-config.json`:

```json
{
  "metrics": {
    "metrics_collected": {
      "statsd": {
        "service_address": ":8125",
        "metrics_collection_interval": 60,
        "metrics_aggregation_interval": 60
      }
    }
  }
}
```

### Gửi metrics từ ứng dụng

**Bash/Shell:**
```bash
# Gửi counter metric
echo "page_views:1|c" | nc -u -w1 127.0.0.1 8125

# Gửi gauge metric (giá trị tuyệt đối)
echo "active_users:42|g" | nc -u -w1 127.0.0.1 8125

# Gửi timing metric (milliseconds)
echo "api_response_time:235|ms" | nc -u -w1 127.0.0.1 8125
```

**Python:**
```python
import socket

def send_metric(metric_name, value, metric_type="g"):
    """Gửi custom metric tới StatsD."""
    message = f"{metric_name}:{value}|{metric_type}"
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.sendto(message.encode(), ("127.0.0.1", 8125))

# Ví dụ sử dụng
send_metric("app.active_sessions", 150)
send_metric("app.requests_per_min", 1200, "c")
send_metric("app.db_query_ms", 45, "ms")
```

---

## 2. Procstat — Monitor Specific Processes

Thu thập metrics của một process cụ thể (CPU, Memory, File Descriptors):

```json
{
  "metrics": {
    "metrics_collected": {
      "procstat": [
        {
          "pid_file": "/var/run/nginx.pid",
          "measurement": [
            "cpu_usage",
            "memory_rss",
            "num_threads",
            "read_bytes",
            "write_bytes"
          ]
        },
        {
          "pattern": "python3",
          "measurement": ["cpu_usage", "memory_rss"]
        }
      ]
    }
  }
}
```

---

## 3. GPU Metrics (NVIDIA)

Nếu instance có GPU (p3, g4, etc.):

```json
{
  "metrics": {
    "metrics_collected": {
      "nvidia_gpu": {
        "measurement": [
          "utilization_gpu",
          "utilization_memory",
          "temperature_gpu",
          "power_draw"
        ],
        "metrics_collection_interval": 60
      }
    }
  }
}
```

---

## 4. Dimensions Tùy Chỉnh

Thêm custom dimensions để phân loại metrics:

```json
{
  "metrics": {
    "append_dimensions": {
      "Environment": "production",
      "Application": "my-web-app",
      "Team": "backend"
    },
    "aggregation_dimensions": [
      ["InstanceId"],
      ["Environment", "Application"],
      []
    ]
  }
}
```

---

## 5. High-Resolution Metrics (Sub-Minute)

Thu thập metrics với tần suất cao hơn (1 giây thay vì 60 giây):

```json
{
  "metrics": {
    "metrics_collected": {
      "cpu": {
        "measurement": ["cpu_usage_user"],
        "metrics_collection_interval": 1,
        "totalcpu": true
      }
    }
  }
}
```

> ⚠️ **Chi phí cao hơn:** High-resolution metrics tốn phí cao hơn standard metrics. Chỉ dùng khi thực sự cần thiết.

---

## 6. CloudWatch Embedded Metric Format (EMF)

Gửi metrics trực tiếp từ ứng dụng qua log với structured JSON:

```python
import json
import time

def emit_emf_metric(metric_name, value, unit="Count"):
    """Emit metric theo EMF format qua stdout/log."""
    emf = {
        "_aws": {
            "Timestamp": int(time.time() * 1000),
            "CloudWatchMetrics": [
                {
                    "Namespace": "MyApp/Custom",
                    "Dimensions": [["Service"]],
                    "Metrics": [{"Name": metric_name, "Unit": unit}]
                }
            ]
        },
        "Service": "web-api",
        metric_name: value
    }
    print(json.dumps(emf))

# Ví dụ
emit_emf_metric("RequestLatency", 245, "Milliseconds")
emit_emf_metric("ErrorCount", 3, "Count")
```
