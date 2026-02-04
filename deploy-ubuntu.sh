#!/bin/bash
# OpenClaw Ubuntu 一键部署脚本 - 1GB 内存优化版本（预编译模式）
# 适用于 Ubuntu 20.04+ 系统
# 使用预编译包，避免在低内存机器上编译

set -euo pipefail  # 严格错误处理

# ========================================
# 颜色输出配置
# ========================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

echo_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

echo_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# ========================================
# 临时文件管理
# ========================================
TMPFILES=()

cleanup_tmpfiles() {
    local f
    for f in "${TMPFILES[@]:-}"; do
        if [ -f "$f" ]; then
            rm -f "$f" 2>/dev/null || true
        fi
    done
}

trap cleanup_tmpfiles EXIT INT TERM

mktempfile() {
    local f
    f="$(mktemp)"
    TMPFILES+=("$f")
    echo "$f"
}

# ========================================
# 下载函数（带重试机制）
# ========================================
download_with_retry() {
    local url="$1"
    local output="$2"
    local max_attempts=3
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        echo_info "下载中... (尝试 $attempt/$max_attempts)"

        if curl -fsSL --proto '=https' --tlsv1.2 \
            --retry 3 --retry-delay 2 \
            --retry-connrefused \
            --connect-timeout 30 \
            --max-time 600 \
            -o "$output" "$url"; then
            echo_info "下载成功"
            return 0
        fi

        echo_warn "下载失败，等待 5 秒后重试..."
        sleep 5
        attempt=$((attempt + 1))
    done

    echo_error "下载失败，已尝试 $max_attempts 次"
    return 1
}

# ========================================
# 系统资源检查
# ========================================
check_system_resources() {
    echo_step "检查系统资源..."

    # 1. 检查内存
    local total_mem=$(free -m | awk '/^Mem:/{print $2}')
    local available_mem=$(free -m | awk '/^Mem:/{print $7}')

    echo_info "系统总内存: ${total_mem}MB"
    echo_info "可用内存: ${available_mem}MB"

    if [ "$total_mem" -lt 800 ]; then
        echo_error "系统内存不足 800MB，OpenClaw 无法运行"
        echo_error "当前: ${total_mem}MB < 800MB (最低要求)"
        exit 1
    fi

    if [ "$available_mem" -lt 400 ]; then
        echo_warn "可用内存较低 (${available_mem}MB)"
        echo_warn "建议关闭其他程序以释放内存"

        read -p "是否继续安装? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo_info "安装已取消"
            exit 0
        fi
    fi

    # 2. 检查磁盘空间
    local disk_available=$(df -m "$HOME" | awk 'NR==2 {print $4}')
    echo_info "可用磁盘空间: ${disk_available}MB"

    if [ "$disk_available" -lt 1024 ]; then
        echo_error "磁盘空间不足 1GB"
        echo_error "当前: ${disk_available}MB < 1024MB (最低要求)"
        exit 1
    fi

    if [ "$disk_available" -lt 2048 ]; then
        echo_warn "磁盘空间较低 (${disk_available}MB)，建议 2GB+ 以确保正常运行"
    fi

    # 3. 检查网络连接
    echo_info "检查网络连接..."
    if ! ping -c 1 -W 5 github.com &> /dev/null; then
        echo_error "无法连接到 GitHub"
        echo_error "请检查网络连接或防火墙设置"
        exit 1
    fi
    echo_info "网络连接正常"

    echo_info "系统资源检查通过 ✓"
    echo ""
}

# ========================================
# 检查 root 用户
# ========================================
check_root_user() {
    if [ "$EUID" -eq 0 ]; then
        echo_error "请不要使用 root 用户运行此脚本"
        echo_info "建议创建普通用户: sudo adduser openclaw"
        exit 1
    fi
}

# ========================================
# 检查并安装 Node.js 22+
# ========================================
check_and_install_nodejs() {
    echo_step "检查 Node.js 安装..."

    if command -v node &> /dev/null; then
        local node_version=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)

        if [ "$node_version" -ge 22 ]; then
            echo_info "Node.js 版本符合要求: $(node -v)"
            return 0
        else
            echo_warn "Node.js 版本过低 (当前: v$node_version)，需要 v22+"
        fi
    else
        echo_warn "Node.js 未安装"
    fi

    echo_info "安装 Node.js 22 LTS..."
    local setup_script=$(mktempfile)

    if ! download_with_retry "https://deb.nodesource.com/setup_22.x" "$setup_script"; then
        echo_error "下载 Node.js 安装脚本失败"
        exit 1
    fi

    sudo -E bash "$setup_script"
    sudo apt-get install -y nodejs

    echo_info "Node.js 安装成功: $(node -v)"
}

# ========================================
# 安装系统依赖
# ========================================
install_system_dependencies() {
    echo_step "安装系统依赖..."

    sudo apt-get update
    sudo apt-get install -y \
        curl \
        ca-certificates \
        gnupg \
        libvips42 \
        || {
        echo_error "系统依赖安装失败"
        exit 1
    }

    echo_info "系统依赖安装完成 ✓"
}

# ========================================
# 下载并安装预编译包
# ========================================
install_prebuilt_package() {
    echo_step "下载预编译包..."

    # GitHub Release 信息
    local REPO="808cn163/openclaw-1G-memory"
    local RELEASE_API="https://api.github.com/repos/${REPO}/releases/latest"

    # 获取最新版本信息
    echo_info "获取最新版本信息..."
    local release_info=$(mktempfile)

    if ! curl -fsSL "$RELEASE_API" -o "$release_info"; then
        echo_error "无法获取 Release 信息"
        echo_info "请检查网络连接或手动下载预编译包"
        exit 1
    fi

    # 解析下载 URL
    local download_url=$(grep -o '"browser_download_url": *"[^"]*"' "$release_info" | grep "linux-x64.tar.gz" | head -1 | sed 's/"browser_download_url": *"\([^"]*\)"/\1/')

    if [ -z "$download_url" ]; then
        echo_error "未找到预编译包下载链接"
        echo_warn "切换到源码编译模式..."
        install_from_source
        return
    fi

    local version=$(grep -o '"tag_name": *"[^"]*"' "$release_info" | head -1 | sed 's/"tag_name": *"\([^"]*\)"/\1/')
    echo_info "最新版本: ${version}"
    echo_info "下载地址: ${download_url}"

    # 下载预编译包
    local download_file=$(mktempfile)
    echo_info "下载预编译包（这可能需要几分钟）..."

    if ! download_with_retry "$download_url" "$download_file"; then
        echo_error "下载预编译包失败"
        echo_warn "切换到源码编译模式..."
        install_from_source
        return
    fi

    # 解压到安装目录
    local INSTALL_DIR="$HOME/openclaw"

    if [ -d "$INSTALL_DIR" ]; then
        echo_warn "检测到已存在的安装目录: $INSTALL_DIR"
        local backup_dir="${INSTALL_DIR}.backup.$(date +%Y%m%d_%H%M%S)"
        echo_info "备份到: $backup_dir"
        mv "$INSTALL_DIR" "$backup_dir"
    fi

    mkdir -p "$INSTALL_DIR"
    echo_info "解压预编译包到: $INSTALL_DIR"

    if ! tar -xzf "$download_file" -C "$INSTALL_DIR" --strip-components=1; then
        echo_error "解压失败"
        exit 1
    fi

    echo_info "预编译包安装成功 ✓"
    echo_info "安装目录: $INSTALL_DIR"

    # 验证安装
    cd "$INSTALL_DIR"
    if ! node openclaw.mjs --version &> /dev/null; then
        echo_error "安装验证失败"
        exit 1
    fi

    local installed_version=$(node openclaw.mjs --version 2>/dev/null || echo "unknown")
    echo_info "已安装版本: $installed_version"
}

# ========================================
# 备用：从源码安装（如果预编译包不可用）
# ========================================
install_from_source() {
    echo_warn "========================================="
    echo_warn "预编译包不可用，切换到源码编译模式"
    echo_warn "注意: 源码编译在低内存机器上可能失败"
    echo_warn "========================================="

    local INSTALL_DIR="$HOME/openclaw"

    # 安装额外依赖
    sudo apt-get install -y build-essential python3 make g++ git

    # 安装 pnpm
    if ! command -v pnpm &> /dev/null; then
        echo_info "安装 pnpm..."
        npm install -g pnpm@latest
    fi

    # 克隆仓库
    if [ ! -d "$INSTALL_DIR" ]; then
        echo_info "克隆仓库..."
        git clone https://github.com/808cn163/openclaw-1G-memory.git "$INSTALL_DIR"
    fi

    cd "$INSTALL_DIR"

    # 设置内存限制
    export NODE_OPTIONS="--max-old-space-size=512"

    echo_warn "开始编译（可能需要 10-20 分钟，请耐心等待）..."

    # 安装依赖（精简模式）
    if ! pnpm install --prod --no-optional --ignore-scripts; then
        echo_error "依赖安装失败"
        exit 1
    fi

    # 构建（可能会因内存不足而失败）
    if ! pnpm build; then
        echo_error "构建失败（内存不足）"
        echo_error "建议使用预编译包或在更高配置的机器上编译"
        exit 1
    fi

    echo_info "源码编译完成"
}

# ========================================
# 配置 OpenClaw
# ========================================
configure_openclaw() {
    echo_step "配置 OpenClaw..."

    local INSTALL_DIR="$HOME/openclaw"
    local CONFIG_DIR="$HOME/.openclaw"

    mkdir -p "$CONFIG_DIR"

    # 复制配置文件模板
    if [ ! -f "$CONFIG_DIR/config.yaml" ]; then
        if [ -f "$INSTALL_DIR/config.minimal.yaml" ]; then
            cp "$INSTALL_DIR/config.minimal.yaml" "$CONFIG_DIR/config.yaml"
            echo_info "已创建配置文件: $CONFIG_DIR/config.yaml"
        else
            echo_warn "未找到配置模板，需要手动创建配置文件"
        fi
    else
        echo_warn "配置文件已存在，跳过"
    fi

    # 复制环境变量模板
    if [ ! -f "$CONFIG_DIR/.env" ]; then
        if [ -f "$INSTALL_DIR/.env.minimal" ]; then
            cp "$INSTALL_DIR/.env.minimal" "$CONFIG_DIR/.env"
            echo_warn "请编辑 $CONFIG_DIR/.env 文件，添加您的 API 密钥"
        else
            # 创建默认 .env 文件
            cat > "$CONFIG_DIR/.env" <<'EOF'
# OpenClaw API 配置
# 请至少配置一个 API 密钥

# OpenAI API 密钥
OPENAI_API_KEY=

# Google Gemini API 密钥
GEMINI_API_KEY=

# 内存限制（适合 1GB 内存机器）
NODE_OPTIONS=--max-old-space-size=768

# 禁用浏览器功能（节省内存）
OPENCLAW_DISABLE_BROWSER=1
EOF
            echo_info "已创建环境变量文件: $CONFIG_DIR/.env"
            echo_warn "请编辑此文件添加您的 API 密钥"
        fi
    fi

    # 配置环境变量到 .bashrc
    if ! grep -q "OPENCLAW_CONFIG_PATH" "$HOME/.bashrc" 2>/dev/null; then
        cat >> "$HOME/.bashrc" <<EOF

# OpenClaw 环境变量
export OPENCLAW_CONFIG_PATH="$CONFIG_DIR/config.yaml"
export NODE_OPTIONS="--max-old-space-size=768"
export OPENCLAW_DISABLE_BROWSER=1
EOF
        echo_info "已添加环境变量到 ~/.bashrc"
    fi

    # 同样添加到 .zshrc（如果存在）
    if [ -f "$HOME/.zshrc" ] && ! grep -q "OPENCLAW_CONFIG_PATH" "$HOME/.zshrc" 2>/dev/null; then
        cat >> "$HOME/.zshrc" <<EOF

# OpenClaw 环境变量
export OPENCLAW_CONFIG_PATH="$CONFIG_DIR/config.yaml"
export NODE_OPTIONS="--max-old-space-size=768"
export OPENCLAW_DISABLE_BROWSER=1
EOF
        echo_info "已添加环境变量到 ~/.zshrc"
    fi
}

# ========================================
# 创建 systemd 服务
# ========================================
create_systemd_service() {
    echo_step "创建 systemd 服务..."

    local INSTALL_DIR="$HOME/openclaw"
    local CONFIG_DIR="$HOME/.openclaw"
    local SERVICE_FILE=$(mktempfile)

    cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=OpenClaw WhatsApp Gateway (Low Memory)
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$INSTALL_DIR
Environment="NODE_OPTIONS=--max-old-space-size=768"
Environment="OPENCLAW_DISABLE_BROWSER=1"
Environment="OPENCLAW_CONFIG_PATH=$CONFIG_DIR/config.yaml"
EnvironmentFile=$CONFIG_DIR/.env
ExecStart=$(which node) $INSTALL_DIR/openclaw.mjs gateway run --bind loopback --port 18789
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=openclaw

# 内存限制保护（可选）
MemoryMax=900M
MemoryHigh=800M

[Install]
WantedBy=multi-user.target
EOF

    sudo mv "$SERVICE_FILE" /etc/systemd/system/openclaw.service
    sudo systemctl daemon-reload

    echo_info "systemd 服务创建成功 ✓"
}

# ========================================
# 显示安装完成信息
# ========================================
show_completion_info() {
    local INSTALL_DIR="$HOME/openclaw"
    local CONFIG_DIR="$HOME/.openclaw"
    local total_mem=$(free -m | awk '/^Mem:/{print $2}')

    echo ""
    echo_info "========================================="
    echo_info "    OpenClaw 安装完成！"
    echo_info "========================================="
    echo ""
    echo_step "下一步操作："
    echo ""
    echo "1️⃣  配置 API 密钥（必需）："
    echo "   编辑: $CONFIG_DIR/.env"
    echo "   至少配置一个: OPENAI_API_KEY 或 GEMINI_API_KEY"
    echo ""
    echo "2️⃣  测试运行："
    echo "   $ cd $INSTALL_DIR"
    echo "   $ source $CONFIG_DIR/.env"
    echo "   $ node openclaw.mjs --version"
    echo ""
    echo "3️⃣  启动 OpenClaw（二选一）："
    echo ""
    echo "   方式 A: 手动启动（用于测试）"
    echo "   $ cd $INSTALL_DIR"
    echo "   $ source $CONFIG_DIR/.env"
    echo "   $ node openclaw.mjs gateway run --bind loopback --port 18789"
    echo ""
    echo "   方式 B: systemd 服务（推荐，后台运行）"
    echo "   $ sudo systemctl enable openclaw    # 开机自启"
    echo "   $ sudo systemctl start openclaw     # 启动服务"
    echo "   $ sudo systemctl status openclaw    # 查看状态"
    echo "   $ sudo journalctl -u openclaw -f    # 查看日志"
    echo ""
    echo "4️⃣  管理服务："
    echo "   $ sudo systemctl stop openclaw      # 停止"
    echo "   $ sudo systemctl restart openclaw   # 重启"
    echo "   $ sudo systemctl disable openclaw   # 禁用自启"
    echo ""
    echo_info "配置文件位置："
    echo "   主配置: $CONFIG_DIR/config.yaml"
    echo "   环境变量: $CONFIG_DIR/.env"
    echo "   会话数据: $CONFIG_DIR/sessions/"
    echo "   日志: sudo journalctl -u openclaw"
    echo ""
    echo_warn "重要提示："
    echo "   ✓ 系统内存: ${total_mem}MB"
    echo "   ✓ 内存限制: 768MB (NODE_OPTIONS)"
    echo "   ✓ 已禁用浏览器功能（节省内存）"
    echo "   ✓ 已移除本地 LLM（节省内存）"
    echo "   ✓ 请务必配置 API 密钥后再启动"
    echo ""
    echo_info "文档: https://github.com/808cn163/openclaw-1G-memory"
    echo ""
}

# ========================================
# 主函数
# ========================================
main() {
    echo ""
    echo_info "========================================="
    echo_info "  OpenClaw 低内存优化安装程序"
    echo_info "  适用于 <1GB 内存的 Ubuntu 系统"
    echo_info "========================================="
    echo ""

    # 检查
    check_root_user
    check_system_resources

    # 安装
    check_and_install_nodejs
    install_system_dependencies
    install_prebuilt_package

    # 配置
    configure_openclaw
    create_systemd_service

    # 完成
    show_completion_info
}

# 运行主函数
main "$@"
