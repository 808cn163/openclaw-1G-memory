#!/bin/bash
# OpenClaw Ubuntu 一键部署脚本 - 1GB 内存优化版本
# 适用于 Ubuntu 20.04+ 系统

set -e  # 遇到错误立即退出

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# 检查是否为 root 用户
if [ "$EUID" -eq 0 ]; then
    echo_error "请不要使用 root 用户运行此脚本"
    echo_info "建议创建普通用户: sudo adduser openclaw"
    exit 1
fi

# 检查系统内存
TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
echo_info "检测到系统总内存: ${TOTAL_MEM}MB"

if [ "$TOTAL_MEM" -lt 900 ]; then
    echo_error "系统内存不足 1GB，OpenClaw 可能无法正常运行"
    exit 1
elif [ "$TOTAL_MEM" -lt 1500 ]; then
    echo_warn "系统内存较低，已启用精简模式配置"
    MINIMAL_MODE=1
else
    echo_info "系统内存充足"
    MINIMAL_MODE=0
fi

# 检查并安装 Node.js 22+
echo_info "检查 Node.js 安装..."
if ! command -v node &> /dev/null; then
    echo_info "安装 Node.js 22 LTS..."
    curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
    sudo apt-get install -y nodejs
else
    NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
    if [ "$NODE_VERSION" -lt 22 ]; then
        echo_warn "Node.js 版本过低 (当前: v$NODE_VERSION)，需要 v22+"
        echo_info "更新 Node.js..."
        curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
        sudo apt-get install -y nodejs
    else
        echo_info "Node.js 版本符合要求: $(node -v)"
    fi
fi

# 检查并安装必要的系统依赖
echo_info "安装系统依赖..."
sudo apt-get update
sudo apt-get install -y \
    build-essential \
    python3 \
    make \
    g++ \
    libvips-dev \
    git \
    curl

# 安装 pnpm
echo_info "安装 pnpm..."
if ! command -v pnpm &> /dev/null; then
    npm install -g pnpm@latest
else
    echo_info "pnpm 已安装: $(pnpm -v)"
fi

# 克隆或更新项目
INSTALL_DIR="$HOME/openclaw"
if [ -d "$INSTALL_DIR" ]; then
    echo_warn "检测到已存在的安装目录: $INSTALL_DIR"
    read -p "是否删除并重新安装? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$INSTALL_DIR"
    else
        echo_info "使用现有目录"
        cd "$INSTALL_DIR"
        git pull || true
    fi
fi

if [ ! -d "$INSTALL_DIR" ]; then
    echo_info "克隆 openclaw-1G-memory 仓库..."
    git clone https://github.com/808cn163/openclaw-1G-memory.git "$INSTALL_DIR"
    cd "$INSTALL_DIR"
fi

cd "$INSTALL_DIR"

# 安装依赖（跳过可选依赖以节省空间和内存）
echo_info "安装项目依赖..."
pnpm install --no-optional --ignore-scripts

# 构建项目
echo_info "构建项目..."
pnpm build

# 创建配置目录
CONFIG_DIR="$HOME/.openclaw"
mkdir -p "$CONFIG_DIR"

# 复制精简配置文件
echo_info "配置 OpenClaw..."
if [ ! -f "$CONFIG_DIR/config.yaml" ]; then
    cp config.minimal.yaml "$CONFIG_DIR/config.yaml"
    echo_info "已创建配置文件: $CONFIG_DIR/config.yaml"
else
    echo_warn "配置文件已存在，跳过"
fi

# 复制环境变量配置
if [ ! -f "$CONFIG_DIR/.env" ]; then
    cp .env.minimal "$CONFIG_DIR/.env"
    echo_warn "请编辑 $CONFIG_DIR/.env 文件，添加您的 API 密钥"
else
    echo_warn "环境变量文件已存在"
fi

# 设置环境变量
if ! grep -q "OPENCLAW_CONFIG_PATH" "$HOME/.bashrc"; then
    echo "" >> "$HOME/.bashrc"
    echo "# OpenClaw 环境变量" >> "$HOME/.bashrc"
    echo "export OPENCLAW_CONFIG_PATH=\"$CONFIG_DIR/config.yaml\"" >> "$HOME/.bashrc"
    echo "export NODE_OPTIONS=\"--max-old-space-size=768\"" >> "$HOME/.bashrc"
    echo "export OPENCLAW_DISABLE_BROWSER=1" >> "$HOME/.bashrc"
    echo_info "已添加环境变量到 ~/.bashrc"
fi

# 创建 systemd 服务文件
SERVICE_FILE="/tmp/openclaw.service"
cat > "$SERVICE_FILE" << EOF
[Unit]
Description=OpenClaw WhatsApp Gateway
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

[Install]
WantedBy=multi-user.target
EOF

echo_info "创建 systemd 服务..."
sudo mv "$SERVICE_FILE" /etc/systemd/system/openclaw.service
sudo systemctl daemon-reload

# 显示后续步骤
echo ""
echo_info "====================================="
echo_info "OpenClaw 安装完成！"
echo_info "====================================="
echo ""
echo_info "后续步骤："
echo ""
echo_info "1. 配置 API 密钥："
echo "   编辑文件: $CONFIG_DIR/.env"
echo "   添加您的 OpenAI 或 Gemini API 密钥"
echo ""
echo_info "2. 配置 WhatsApp："
echo "   首次运行时会生成 QR 码，使用 WhatsApp 扫描登录"
echo ""
echo_info "3. 启动服务（二选一）："
echo ""
echo "   方式一：手动启动（用于测试）"
echo "   $ cd $INSTALL_DIR"
echo "   $ source $CONFIG_DIR/.env"
echo "   $ node openclaw.mjs gateway run --bind loopback --port 18789"
echo ""
echo "   方式二：systemd 服务（推荐用于生产）"
echo "   $ sudo systemctl enable openclaw    # 开机自启动"
echo "   $ sudo systemctl start openclaw     # 启动服务"
echo "   $ sudo systemctl status openclaw    # 查看状态"
echo "   $ sudo journalctl -u openclaw -f    # 查看日志"
echo ""
echo_info "4. 停止服务："
echo "   $ sudo systemctl stop openclaw"
echo ""
echo_info "5. 重启服务："
echo "   $ sudo systemctl restart openclaw"
echo ""
echo_info "配置文件位置："
echo "   - 主配置: $CONFIG_DIR/config.yaml"
echo "   - 环境变量: $CONFIG_DIR/.env"
echo "   - 会话数据: $CONFIG_DIR/sessions/"
echo ""
echo_warn "重要提示："
echo "   - 请勿忘记配置 .env 文件中的 API 密钥"
echo "   - 系统内存: ${TOTAL_MEM}MB (建议 1GB+)"
echo "   - 当前配置已针对低内存环境优化"
echo ""
