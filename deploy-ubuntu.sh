#!/bin/bash
set -euo pipefail

# OpenClaw 低内存版本部署脚本 (适用于 <1GB 内存的 Ubuntu 系统)
# 用法: curl -fsSL https://github.com/808cn163/openclaw-1G-memory/releases/download/latest/deploy-ubuntu.sh | bash

BOLD='\033[1m'
ACCENT='\033[38;2;255;90;45m'
SUCCESS='\033[38;2;47;191;113m'
WARN='\033[38;2;255;176;32m'
ERROR='\033[38;2;226;61;45m'
INFO='\033[38;2;255;138;91m'
MUTED='\033[38;2;139;127;119m'
NC='\033[0m'

INSTALL_DIR="/opt/openclaw"
BIN_LINK="/usr/local/bin/openclaw"
CONFIG_DIR="$HOME/.openclaw"
RELEASE_URL="https://github.com/808cn163/openclaw-1G-memory/releases/latest/download/openclaw-ubuntu-lite.tar.gz"

NO_ONBOARD=${OPENCLAW_NO_ONBOARD:-0}

TMPFILES=()
cleanup_tmpfiles() {
    local f
    for f in "${TMPFILES[@]:-}"; do
        rm -f "$f" 2>/dev/null || true
    done
}
trap cleanup_tmpfiles EXIT

mktempfile() {
    local f
    f="$(mktemp)"
    TMPFILES+=("$f")
    echo "$f"
}

print_usage() {
    cat <<EOF
OpenClaw 低内存版本部署脚本 (Ubuntu)

用法:
  curl -fsSL <release-url>/deploy-ubuntu.sh | bash -s -- [options]

选项:
  --no-onboard    跳过配置向导 (非交互模式)
  --help, -h      显示此帮助信息

环境变量:
  OPENCLAW_NO_ONBOARD=1    跳过配置向导

示例:
  curl -fsSL <url>/deploy-ubuntu.sh | bash
  curl -fsSL <url>/deploy-ubuntu.sh | bash -s -- --no-onboard
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --no-onboard)
                NO_ONBOARD=1
                shift
                ;;
            --help|-h)
                print_usage
                exit 0
                ;;
            *)
                shift
                ;;
        esac
    done
}

is_root() {
    [[ "$(id -u)" -eq 0 ]]
}

maybe_sudo() {
    if is_root; then
        if [[ "${1:-}" == "-E" ]]; then
            shift
        fi
        "$@"
    else
        sudo "$@"
    fi
}

require_sudo() {
    if is_root; then
        return 0
    fi
    if command -v sudo &> /dev/null; then
        return 0
    fi
    echo -e "${ERROR}错误: 需要 sudo 权限进行系统安装${NC}"
    echo "请安装 sudo 或以 root 用户运行。"
    exit 1
}

check_node() {
    if command -v node &> /dev/null; then
        NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
        if [[ "$NODE_VERSION" -ge 22 ]]; then
            echo -e "${SUCCESS}✓${NC} Node.js v$(node -v | cut -d'v' -f2) 已安装"
            return 0
        else
            echo -e "${WARN}→${NC} Node.js $(node -v) 已安装，但需要 v22+"
            return 1
        fi
    else
        echo -e "${WARN}→${NC} Node.js 未安装"
        return 1
    fi
}

install_node() {
    echo -e "${WARN}→${NC} 通过 NodeSource 安装 Node.js..."
    require_sudo

    if command -v apt-get &> /dev/null; then
        local tmp
        tmp="$(mktempfile)"
        curl -fsSL https://deb.nodesource.com/setup_22.x -o "$tmp"
        maybe_sudo -E bash "$tmp"
        maybe_sudo apt-get install -y nodejs
    else
        echo -e "${ERROR}错误: 不支持的包管理器${NC}"
        echo "请手动安装 Node.js 22+: https://nodejs.org"
        exit 1
    fi
    echo -e "${SUCCESS}✓${NC} Node.js 已安装"
}

download_and_extract() {
    echo -e "${WARN}→${NC} 下载预编译包..."

    local tmp_tar
    tmp_tar="$(mktempfile)"

    if ! curl -fsSL --retry 3 --retry-delay 1 -o "$tmp_tar" "$RELEASE_URL"; then
        echo -e "${ERROR}错误: 下载失败${NC}"
        echo "请检查网络连接或手动下载: $RELEASE_URL"
        exit 1
    fi

    echo -e "${SUCCESS}✓${NC} 下载完成"

    echo -e "${WARN}→${NC} 解压到 $INSTALL_DIR..."
    require_sudo

    maybe_sudo rm -rf "$INSTALL_DIR"
    maybe_sudo mkdir -p "$INSTALL_DIR"
    maybe_sudo tar -xzf "$tmp_tar" -C "$INSTALL_DIR" --strip-components=1

    echo -e "${SUCCESS}✓${NC} 解压完成"
}

install_runtime_deps() {
    echo -e "${WARN}→${NC} 安装运行时依赖 (--omit=dev --ignore-scripts)..."

    cd "$INSTALL_DIR"
    maybe_sudo npm install --omit=dev --ignore-scripts --no-fund --no-audit

    echo -e "${SUCCESS}✓${NC} 依赖安装完成"
}

create_bin_link() {
    echo -e "${WARN}→${NC} 创建命令入口..."
    require_sudo

    maybe_sudo rm -f "$BIN_LINK"

    # 创建启动脚本
    maybe_sudo tee "$BIN_LINK" > /dev/null <<'WRAPPER'
#!/usr/bin/env bash
set -euo pipefail
exec node /opt/openclaw/openclaw.mjs "$@"
WRAPPER

    maybe_sudo chmod +x "$BIN_LINK"

    echo -e "${SUCCESS}✓${NC} 命令 'openclaw' 已可用"
}

create_default_config() {
    echo -e "${WARN}→${NC} 创建默认配置..."

    mkdir -p "$CONFIG_DIR"

    # 只有在配置文件不存在时才创建
    if [[ ! -f "$CONFIG_DIR/openclaw.json" ]]; then
        cat > "$CONFIG_DIR/openclaw.json" <<'CONFIG'
{
  "browser": {
    "enabled": false
  },
  "agents": {
    "defaults": {
      "memorySearch": {
        "provider": "openai"
      }
    }
  }
}
CONFIG
        echo -e "${SUCCESS}✓${NC} 默认配置已创建 (浏览器已禁用, embedding 使用 API 模式)"
    else
        echo -e "${INFO}i${NC} 配置文件已存在，跳过创建"
    fi
}

run_onboard() {
    if [[ "$NO_ONBOARD" == "1" ]]; then
        echo -e "${INFO}i${NC} 跳过配置向导 (--no-onboard)"
        echo -e "稍后运行 ${INFO}openclaw onboard${NC} 完成配置。"
        return 0
    fi

    if [[ ! -r /dev/tty || ! -w /dev/tty ]]; then
        echo -e "${WARN}→${NC} 无 TTY 可用，跳过配置向导"
        echo -e "稍后运行 ${INFO}openclaw onboard${NC} 完成配置。"
        return 0
    fi

    echo -e "${WARN}→${NC} 启动配置向导..."
    exec </dev/tty
    exec openclaw onboard
}

main() {
    echo -e "${ACCENT}${BOLD}"
    echo "  🦞 OpenClaw 低内存版本部署"
    echo -e "${NC}${MUTED}  适用于 <1GB 内存的 Ubuntu 系统${NC}"
    echo ""

    # 检查操作系统
    if [[ ! -f /etc/os-release ]] || ! grep -qi "ubuntu\|debian" /etc/os-release; then
        echo -e "${WARN}⚠${NC} 此脚本为 Ubuntu/Debian 优化，其他系统可能需要调整"
    fi

    echo -e "${SUCCESS}✓${NC} 检测到: Linux (Ubuntu/Debian)"

    # 步骤 1: 检查/安装 Node.js
    if ! check_node; then
        install_node
    fi

    # 步骤 2: 下载并解压预编译包
    download_and_extract

    # 步骤 3: 安装运行时依赖
    install_runtime_deps

    # 步骤 4: 创建命令入口
    create_bin_link

    # 步骤 5: 创建默认配置
    create_default_config

    echo ""
    echo -e "${SUCCESS}${BOLD}🦞 OpenClaw 低内存版本安装成功!${NC}"
    echo ""
    echo -e "安装位置: ${INFO}$INSTALL_DIR${NC}"
    echo -e "配置目录: ${INFO}$CONFIG_DIR${NC}"
    echo ""
    echo -e "快速开始:"
    echo -e "  ${INFO}openclaw --version${NC}      # 查看版本"
    echo -e "  ${INFO}openclaw onboard${NC}        # 运行配置向导"
    echo -e "  ${INFO}openclaw gateway --verbose${NC}  # 启动网关"
    echo ""
    echo -e "文档: ${INFO}https://docs.openclaw.ai${NC}"
    echo ""

    # 步骤 6: 运行配置向导
    run_onboard
}

parse_args "$@"
main
