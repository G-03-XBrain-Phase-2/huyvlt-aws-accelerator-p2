#!/bin/bash
# =============================================================================
# stress-cpu.sh — Stress CPU để trigger CloudWatch Alarm
# Chạy trực tiếp trên EC2 instance
# =============================================================================

set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log_info() { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_ok()   { echo -e "${GREEN}[OK]${NC}    $*"; }

DURATION="${1:-600}"   # Thời gian stress (giây), default 10 phút
CPU_COUNT=$(nproc)

echo ""
echo "============================================================"
echo "   🔥 CPU Stress Test — CloudWatch Alarm Trigger           "
echo "============================================================"
echo ""
echo "  CPUs:     ${CPU_COUNT} cores"
echo "  Duration: ${DURATION}s ($(( DURATION / 60 )) phút)"
echo "  Mục tiêu: CPU > 80% trong ít nhất 5 phút"
echo ""

# ── Cài stress nếu chưa có ──────────────────────────────────────────────────
install_stress() {
    if command -v stress &>/dev/null; then
        log_ok "stress đã được cài sẵn"
        return
    fi

    log_info "Cài đặt stress..."
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            amzn)
                sudo amazon-linux-extras install epel -y 2>/dev/null || true
                sudo yum install -y stress
                ;;
            ubuntu|debian)
                sudo apt-get update -qq
                sudo apt-get install -y stress
                ;;
            *)
                # Thử yum rồi apt
                sudo yum install -y stress 2>/dev/null || \
                sudo apt-get install -y stress 2>/dev/null || \
                { echo "Không cài được stress. Cài thủ công."; exit 1; }
                ;;
        esac
    fi
    log_ok "stress đã cài xong"
}

install_stress

# ── Hiển thị CPU hiện tại ────────────────────────────────────────────────────
CURRENT_CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d. -f1 2>/dev/null || echo "?")
log_info "CPU hiện tại: ~${CURRENT_CPU}%"

# ── Chạy stress ──────────────────────────────────────────────────────────────
log_warn "🔥 Bắt đầu stress test trong ${DURATION} giây..."
log_warn "   Nhấn Ctrl+C để dừng sớm."
echo ""
echo "  ⏱  Timeline dự kiến:"
echo "     0 phút  — CPU bắt đầu tăng"
echo "     1 phút  — CloudWatch bắt đầu ghi nhận"
echo "     5 phút  — Alarm chuyển sang ALARM state"
echo "     5-6 phút — Email cảnh báo được gửi"
echo ""

# Monitor CPU trong khi stress đang chạy
stress --cpu "$CPU_COUNT" --timeout "$DURATION" &
STRESS_PID=$!

# Theo dõi CPU mỗi 30 giây
ELAPSED=0
while kill -0 $STRESS_PID 2>/dev/null; do
    sleep 30
    ELAPSED=$((ELAPSED + 30))
    CURRENT=$(grep 'cpu ' /proc/stat | awk '{usage=($2+$4)*100/($2+$4+$5)} END {printf "%.0f", usage}')
    echo "  [$(printf '%3d' $ELAPSED)s] CPU Usage: ${CURRENT}%"
done

echo ""
log_ok "✅ Stress test hoàn tất!"
echo ""
echo "  📧 Kiểm tra email để xem cảnh báo đã được gửi chưa."
echo "  🔍 Xem alarm state:"
echo "     aws cloudwatch describe-alarms --alarm-names 'High-CPU-Alert'"
echo ""
