#!/bin/bash
# =============================================================================
# install-agent.sh — Tự động cài đặt & khởi động CloudWatch Agent
# Hỗ trợ: Amazon Linux 2, Amazon Linux 2023, Ubuntu 20.04+
# =============================================================================

set -euo pipefail

# ── Màu sắc terminal ──────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_success() { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# ── Phát hiện OS ──────────────────────────────────────────────────────────────
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        OS_VERSION=$VERSION_ID
    else
        log_error "Không thể phát hiện OS. Script chỉ hỗ trợ Amazon Linux và Ubuntu."
        exit 1
    fi
    log_info "Phát hiện OS: ${OS} ${OS_VERSION}"
}

# ── Cài đặt Agent ────────────────────────────────────────────────────────────
install_cloudwatch_agent() {
    log_info "Bắt đầu cài đặt Amazon CloudWatch Agent..."

    case "$OS" in
        amzn)
            log_info "Cài đặt trên Amazon Linux..."
            sudo yum install -y amazon-cloudwatch-agent
            ;;
        ubuntu)
            log_info "Cài đặt trên Ubuntu..."
            sudo apt-get update -qq
            sudo apt-get install -y amazon-cloudwatch-agent
            ;;
        *)
            log_error "OS không được hỗ trợ: $OS"
            log_warn "Hỗ trợ: amazon linux (amzn), ubuntu"
            exit 1
            ;;
    esac

    log_success "Cài đặt agent thành công!"
}

# ── Áp dụng Config ───────────────────────────────────────────────────────────
apply_config() {
    CONFIG_FILE="${1:-/opt/aws/amazon-cloudwatch-agent/bin/config.json}"

    if [ ! -f "$CONFIG_FILE" ]; then
        log_warn "File config không tồn tại: $CONFIG_FILE"
        log_warn "Vui lòng chạy wizard hoặc cung cấp file config thủ công."
        log_info "  Chạy wizard: sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-config-wizard"
        return 0
    fi

    log_info "Áp dụng config từ: $CONFIG_FILE"
    sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
        -a fetch-config \
        -m ec2 \
        -s \
        -c "file:${CONFIG_FILE}"

    log_success "Config đã được áp dụng!"
}

# ── Khởi động Agent ──────────────────────────────────────────────────────────
start_agent() {
    log_info "Kích hoạt và khởi động amazon-cloudwatch-agent service..."

    sudo systemctl enable amazon-cloudwatch-agent
    sudo systemctl start amazon-cloudwatch-agent

    sleep 3

    if sudo systemctl is-active --quiet amazon-cloudwatch-agent; then
        log_success "Agent đang chạy!"
    else
        log_error "Agent không khởi động được. Kiểm tra logs:"
        log_error "  sudo journalctl -u amazon-cloudwatch-agent -n 50"
        exit 1
    fi
}

# ── Kiểm tra IAM Role ────────────────────────────────────────────────────────
check_iam_role() {
    log_info "Kiểm tra IAM Role của EC2 instance..."

    ROLE=$(curl -sf --max-time 5 \
        "http://169.254.169.254/latest/meta-data/iam/security-credentials/" \
        2>/dev/null || echo "")

    if [ -z "$ROLE" ]; then
        log_warn "⚠️  Không phát hiện IAM Role nào được gắn vào instance này."
        log_warn "   CloudWatch Agent cần IAM Role với CloudWatchAgentServerPolicy."
        log_warn "   Tham khảo: scripts/create-iam-role.sh"
    else
        log_success "Tìm thấy IAM Role: $ROLE"
    fi
}

# ── Main ─────────────────────────────────────────────────────────────────────
main() {
    echo ""
    echo "============================================================"
    echo "   🔍 CloudWatch Agent Installer — TechX AWS Lab           "
    echo "============================================================"
    echo ""

    detect_os
    check_iam_role
    install_cloudwatch_agent

    # Nếu có file config trong cùng thư mục lab, dùng nó
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    LAB_CONFIG="${SCRIPT_DIR}/../configs/cloudwatch-agent-config.json"

    if [ -f "$LAB_CONFIG" ]; then
        log_info "Tìm thấy config mẫu từ lab: $LAB_CONFIG"
        sudo cp "$LAB_CONFIG" /opt/aws/amazon-cloudwatch-agent/bin/config.json
        apply_config "/opt/aws/amazon-cloudwatch-agent/bin/config.json"
    else
        apply_config
    fi

    start_agent

    echo ""
    echo "============================================================"
    log_success "🎉 Hoàn tất! Kiểm tra trạng thái agent:"
    echo "   sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \\"
    echo "       -m ec2 -a status"
    echo ""
    log_info "📊 Xem metrics tại: CloudWatch Console → Metrics → CWAgent"
    echo "============================================================"
    echo ""
}

main "$@"
