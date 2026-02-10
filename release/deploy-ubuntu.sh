#!/bin/bash
set -euo pipefail

# OpenClaw 低内存版本部署脚本 (适用于 <1GB 内存的 Ubuntu / Debian)
# 用法: curl -fsSL https://github.com/808cn163/openclaw-1G-memory/releases/latest/download/deploy-ubuntu.sh | bash -s -- [options]

BOLD='\033[1m'
ACCENT='\033[38;2;255;90;45m'
# shellcheck disable=SC2034
ACCENT_BRIGHT='\033[38;2;255;122;61m'
ACCENT_DIM='\033[38;2;209;74;34m'
INFO='\033[38;2;255;138;91m'
SUCCESS='\033[38;2;47;191;113m'
WARN='\033[38;2;255;176;32m'
ERROR='\033[38;2;226;61;45m'
MUTED='\033[38;2;139;127;119m'
NC='\033[0m' # No Color

REPO_SLUG="808cn163/openclaw-1G-memory"
PACKAGE_NAME="openclaw-ubuntu-lite"
INSTALL_DIR="${OPENCLAW_INSTALL_DIR:-/opt/openclaw}"
BIN_LINK="${OPENCLAW_BIN_LINK:-/usr/local/bin/openclaw}"

INSTALL_METHOD="${OPENCLAW_INSTALL_METHOD:-prebuilt}"
OPENCLAW_VERSION="${OPENCLAW_VERSION:-}"
USE_BETA="${OPENCLAW_BETA:-0}"
GIT_DIR_DEFAULT="$HOME/openclaw"
GIT_DIR=${OPENCLAW_GIT_DIR:-$GIT_DIR_DEFAULT}
GIT_UPDATE=${OPENCLAW_GIT_UPDATE:-1}
SHARP_IGNORE_GLOBAL_LIBVIPS="${SHARP_IGNORE_GLOBAL_LIBVIPS:-1}"
NPM_LOGLEVEL="${OPENCLAW_NPM_LOGLEVEL:-error}"
NPM_SILENT_FLAG="--silent"
VERBOSE="${OPENCLAW_VERBOSE:-0}"
NO_PROMPT="${OPENCLAW_NO_PROMPT:-0}"
DRY_RUN="${OPENCLAW_DRY_RUN:-0}"
NO_ONBOARD=${OPENCLAW_NO_ONBOARD:-0}
OPENCLAW_BIN=""
STAGING_DIR=""

ORIGINAL_PATH="${PATH:-}"

TMPFILES=()
cleanup_tmpfiles() {
    local f
    for f in "${TMPFILES[@]:-}"; do
        rm -f "$f" 2>/dev/null || true
    done
}
cleanup_staging_dir() {
    if [[ -n "${STAGING_DIR:-}" && -d "${STAGING_DIR}" ]]; then
        rm -rf "${STAGING_DIR}" 2>/dev/null || true
    fi
}

cleanup_on_exit() {
    cleanup_staging_dir
    cleanup_tmpfiles
}
trap cleanup_on_exit EXIT

mktempfile() {
    local f
    f="$(mktemp)"
    TMPFILES+=("$f")
    echo "$f"
}

print_usage() {
    cat <<EOF
OpenClaw 低内存版本部署脚本 (Ubuntu / Debian)

Usage:
  curl -fsSL https://github.com/${REPO_SLUG}/releases/latest/download/deploy-ubuntu.sh | bash -s -- [options]

Options:
  --install-method, --method npm|git   仅用于兼容 install.sh，低内存版固定为预编译安装
  --npm                               兼容参数（忽略）
  --git, --github                     兼容参数（忽略）
  --version <tag>                      指定 GitHub Release tag（默认 latest）
  --beta                               使用 beta tag（若存在）
  --git-dir, --dir <path>             兼容参数（忽略）
  --no-git-update                      兼容参数（忽略）
  --no-onboard                          跳过配置向导 (非交互模式)
  --onboard                             强制执行配置向导
  --no-prompt                           禁用提示 (兼容参数)
  --dry-run                             仅显示将执行的操作
  --verbose                             输出调试信息 (set -x)
  --help, -h                            显示此帮助

Environment variables:
  OPENCLAW_VERSION=latest|<tag>
  OPENCLAW_BETA=0|1
  OPENCLAW_INSTALL_DIR=/opt/openclaw
  OPENCLAW_BIN_LINK=/usr/local/bin/openclaw
  OPENCLAW_NO_ONBOARD=1
  OPENCLAW_NO_PROMPT=1
  OPENCLAW_DRY_RUN=1
  OPENCLAW_VERBOSE=1
  OPENCLAW_NPM_LOGLEVEL=error|warn|notice
  SHARP_IGNORE_GLOBAL_LIBVIPS=0|1

Examples:
  curl -fsSL https://github.com/${REPO_SLUG}/releases/latest/download/deploy-ubuntu.sh | bash
  curl -fsSL https://github.com/${REPO_SLUG}/releases/latest/download/deploy-ubuntu.sh | bash -s -- --no-onboard
  curl -fsSL https://github.com/${REPO_SLUG}/releases/latest/download/deploy-ubuntu.sh | bash -s -- --version v2026.2.3-lite
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --no-onboard)
                NO_ONBOARD=1
                shift
                ;;
            --onboard)
                NO_ONBOARD=0
                shift
                ;;
            --dry-run)
                DRY_RUN=1
                shift
                ;;
            --verbose)
                VERBOSE=1
                shift
                ;;
            --no-prompt)
                NO_PROMPT=1
                shift
                ;;
            --help|-h)
                print_usage
                exit 0
                ;;
            --install-method|--method)
                INSTALL_METHOD="$2"
                shift 2
                ;;
            --version)
                OPENCLAW_VERSION="$2"
                shift 2
                ;;
            --beta)
                USE_BETA=1
                shift
                ;;
            --npm)
                INSTALL_METHOD="npm"
                shift
                ;;
            --git|--github)
                INSTALL_METHOD="git"
                shift
                ;;
            --git-dir|--dir)
                GIT_DIR="$2"
                shift 2
                ;;
            --no-git-update)
                GIT_UPDATE=0
                shift
                ;;
            *)
                shift
                ;;
        esac
    done
}

configure_verbose() {
    if [[ "$VERBOSE" != "1" ]]; then
        return 0
    fi
    if [[ "$NPM_LOGLEVEL" == "error" ]]; then
        NPM_LOGLEVEL="notice"
    fi
    NPM_SILENT_FLAG=""
    set -x
}

DOWNLOADER=""
detect_downloader() {
    if command -v curl &> /dev/null; then
        DOWNLOADER="curl"
        return 0
    fi
    if command -v wget &> /dev/null; then
        DOWNLOADER="wget"
        return 0
    fi
    echo -e "${ERROR}Error: Missing downloader (curl or wget required)${NC}"
    exit 1
}

download_file() {
    local url="$1"
    local output="$2"
    if [[ -z "$DOWNLOADER" ]]; then
        detect_downloader
    fi
    if [[ "$DOWNLOADER" == "curl" ]]; then
        curl -fsSL --proto '=https' --tlsv1.2 --retry 3 --retry-delay 1 --retry-connrefused -o "$output" "$url"
        return
    fi
    wget -q --https-only --secure-protocol=TLSv1_2 --tries=3 --timeout=20 -O "$output" "$url"
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
        local node_major
        node_major=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
        if [[ "$node_major" -ge 22 ]]; then
            echo -e "${SUCCESS}✓${NC} Node.js v$(node -v | cut -d'v' -f2) 已安装"
            return 0
        fi
        echo -e "${WARN}→${NC} Node.js $(node -v) 已安装，但需要 v22+"
        return 1
    fi
    echo -e "${WARN}→${NC} Node.js 未安装"
    return 1
}

install_node() {
    echo -e "${WARN}→${NC} 通过 NodeSource 安装 Node.js..."
    require_sudo

    if command -v apt-get &> /dev/null; then
        local tmp
        tmp="$(mktempfile)"
        download_file "https://deb.nodesource.com/setup_22.x" "$tmp"
        maybe_sudo -E bash "$tmp"
        maybe_sudo apt-get install -y nodejs
    else
        echo -e "${ERROR}错误: 不支持的包管理器${NC}"
        echo "请手动安装 Node.js 22+: https://nodejs.org"
        exit 1
    fi
    echo -e "${SUCCESS}✓${NC} Node.js 已安装"
}

resolve_release_url() {
    local version="${OPENCLAW_VERSION:-}"
    if [[ "$USE_BETA" == "1" && -z "$version" ]]; then
        version="beta"
    fi
    if [[ -z "$version" || "$version" == "latest" ]]; then
        echo "https://github.com/${REPO_SLUG}/releases/latest/download/${PACKAGE_NAME}.tar.gz"
        return 0
    fi
    echo "https://github.com/${REPO_SLUG}/releases/download/${version}/${PACKAGE_NAME}.tar.gz"
}

download_and_extract() {
    local url
    url="$(resolve_release_url)"

    echo -e "${WARN}→${NC} 下载预编译包..."

    local tmp_tar
    tmp_tar="$(mktempfile)"

    download_file "$url" "$tmp_tar" || {
        echo -e "${ERROR}错误: 下载失败${NC}"
        echo "请检查网络连接或手动下载: $url"
        exit 1
    }

    echo -e "${SUCCESS}✓${NC} 下载完成"
    echo -e "${WARN}→${NC} 解压到临时目录..."

    STAGING_DIR="$(mktemp -d)"
    tar -xzf "$tmp_tar" -C "$STAGING_DIR" --strip-components=1

    echo -e "${SUCCESS}✓${NC} 解压完成 (staging: ${STAGING_DIR})"
}

verify_runtime_deps() {
    local target_dir="$1"
    local -a required_modules=("chalk" "commander")
    local -a missing=()

    local module_name
    for module_name in "${required_modules[@]}"; do
        if [[ ! -d "${target_dir}/node_modules/${module_name}" ]]; then
            missing+=("${module_name}")
        fi
    done

    if [[ "${#missing[@]}" -gt 0 ]]; then
        echo -e "${ERROR}错误: 运行时依赖不完整，缺少: ${missing[*]}${NC}"
        return 1
    fi
    return 0
}

install_runtime_deps() {
    local target_dir="${STAGING_DIR:-$INSTALL_DIR}"

    if verify_runtime_deps "$target_dir"; then
        echo -e "${SUCCESS}✓${NC} 预编译包已包含运行时依赖，跳过 npm 安装"
        return 0
    fi

    echo -e "${WARN}→${NC} 安装运行时依赖 (--omit=dev --ignore-scripts)..."

    cd "$target_dir"

    local npm_mode="install"
    if [[ -f package-lock.json || -f npm-shrinkwrap.json ]]; then
        npm_mode="ci"
    else
        echo -e "${WARN}→${NC} 未检测到 lockfile，将使用 npm install（小内存机器可能更容易 OOM）"
    fi

    if ! SHARP_IGNORE_GLOBAL_LIBVIPS="$SHARP_IGNORE_GLOBAL_LIBVIPS" npm --loglevel "$NPM_LOGLEVEL" ${NPM_SILENT_FLAG:+$NPM_SILENT_FLAG} --no-fund --no-audit "$npm_mode" --omit=dev --ignore-scripts; then
        echo -e "${ERROR}错误: 运行时依赖安装失败${NC}"
        echo -e "${WARN}建议:${NC} 请在高性能机器重新打包（包含 node_modules），再发布到 GitHub Release。"
        return 1
    fi

    verify_runtime_deps "$target_dir"

    echo -e "${SUCCESS}✓${NC} 依赖安装完成"
}

promote_install_tree() {
    local target_dir="${STAGING_DIR:-$INSTALL_DIR}"

    if [[ "$target_dir" == "$INSTALL_DIR" ]]; then
        return 0
    fi

    echo -e "${WARN}→${NC} 安装到 ${INSTALL_DIR}..."
    require_sudo
    maybe_sudo rm -rf "$INSTALL_DIR"
    maybe_sudo mkdir -p "$(dirname "$INSTALL_DIR")"
    maybe_sudo mv "$target_dir" "$INSTALL_DIR"
    STAGING_DIR=""
    echo -e "${SUCCESS}✓${NC} 安装目录就绪"
}

cleanup_old_wrappers() {
    echo -e "${WARN}→${NC} 检查旧版本安装..."

    local old_locations=(
        "$HOME/.local/bin/openclaw"
        "$HOME/bin/openclaw"
        "$HOME/openclaw/openclaw"
        "$HOME/openclaw"
    )

    local found_old=0
    for loc in "${old_locations[@]}"; do
        if [[ -f "$loc" ]] || [[ -d "$loc" ]]; then
            echo -e "${INFO}i${NC} 发现旧安装: $loc"
            if [[ -f "$loc" ]]; then
                rm -f "$loc" 2>/dev/null || true
            fi
            found_old=1
        fi
    done

    if [[ "$found_old" -eq 1 ]]; then
        echo -e "${SUCCESS}✓${NC} 已清理旧版本包装器"
    else
        echo -e "${SUCCESS}✓${NC} 未发现旧版本安装"
    fi
}

create_bin_link() {
    echo -e "${WARN}→${NC} 创建命令入口..."
    require_sudo

    maybe_sudo rm -f "$BIN_LINK"

    local heap_size=896

    maybe_sudo tee "$BIN_LINK" > /dev/null <<WRAPPER
#!/usr/bin/env bash
set -euo pipefail
# 低内存优化: 在 1G 机器上默认使用已验证的 896MB 堆
# 不覆盖用户显式设置的 --max-old-space-size
export OPENCLAW_FORCE_MAX_OLD_SPACE_SIZE="\${OPENCLAW_FORCE_MAX_OLD_SPACE_SIZE:-${heap_size}}"

if [[ ! " \${NODE_OPTIONS:-} " =~ [[:space:]]--max-old-space-size(=|[[:space:]])[0-9]+ ]]; then
  export NODE_OPTIONS="\${NODE_OPTIONS:+\${NODE_OPTIONS} }--max-old-space-size=\${OPENCLAW_FORCE_MAX_OLD_SPACE_SIZE}"
fi

# 交互式向导保护: 某些 SSH/PTY 场景下 stty 会返回 0 0，导致 TUI 渲染异常并放大内存占用
if [[ -t 1 ]]; then
  if command -v stty >/dev/null 2>&1; then
    tty_size="\$(stty size 2>/dev/null || true)"
    tty_rows="\${tty_size%% *}"
    tty_cols="\${tty_size##* }"
    if [[ "\${tty_rows:-0}" == "0" || "\${tty_cols:-0}" == "0" ]]; then
      export COLUMNS="\${COLUMNS:-120}"
      export LINES="\${LINES:-40}"
      stty cols "\${COLUMNS}" rows "\${LINES}" 2>/dev/null || true
    fi
  fi
fi

exec node "${INSTALL_DIR}/openclaw.mjs" "\$@"
WRAPPER

    maybe_sudo chmod +x "$BIN_LINK"

    echo -e "${SUCCESS}✓${NC} 命令 'openclaw' 已可用"
}

check_existing_openclaw() {
    if [[ -n "$(type -P openclaw 2>/dev/null || true)" ]]; then
        echo -e "${WARN}→${NC} Existing OpenClaw installation detected"
        return 0
    fi
    return 1
}

resolve_openclaw_bin() {
    if command -v openclaw &> /dev/null; then
        command -v openclaw
        return 0
    fi
    if [[ -x "$BIN_LINK" ]]; then
        echo "$BIN_LINK"
        return 0
    fi
    return 1
}

warn_openclaw_not_found() {
    echo -e "${WARN}→${NC} Installed, but ${INFO}openclaw${NC} is not discoverable on PATH in this shell."
    echo -e "Try: ${INFO}hash -r${NC} (bash) or ${INFO}rehash${NC} (zsh), then retry."
}

run_doctor() {
    # 低内存版本: 跳过自动运行 doctor，避免 OOM
    # doctor 命令加载 30+ 模块，在 <1GB 内存机器上容易 OOM
    echo -e "${WARN}→${NC} 低内存模式: 跳过自动 doctor 检查"
    echo -e "${INFO}i${NC} 如需迁移设置，请稍后手动运行: ${INFO}openclaw doctor${NC}"
    return 0
}

resolve_workspace_dir() {
    local profile="${OPENCLAW_PROFILE:-default}"
    if [[ "${profile}" != "default" ]]; then
        echo "${HOME}/.openclaw/workspace-${profile}"
    else
        echo "${HOME}/.openclaw/workspace"
    fi
}

run_bootstrap_onboarding_if_needed() {
    if [[ "${NO_ONBOARD}" == "1" ]]; then
        return
    fi

    local workspace_dir
    workspace_dir="$(resolve_workspace_dir)"
    local bootstrap="${workspace_dir}/BOOTSTRAP.md"
    if [[ ! -f "$bootstrap" ]]; then
        return
    fi

    if [[ ! -r /dev/tty || ! -w /dev/tty ]]; then
        echo -e "${WARN}→${NC} BOOTSTRAP.md found at ${INFO}${bootstrap}${NC}; no TTY, skipping onboarding."
        echo -e "Run ${INFO}openclaw onboard${NC} later to finish setup."
        return
    fi

    echo -e "${WARN}→${NC} BOOTSTRAP.md found at ${INFO}${bootstrap}${NC}; starting onboarding..."

    local claw="${OPENCLAW_BIN:-}"
    if [[ -z "$claw" ]]; then
        claw="$(resolve_openclaw_bin || true)"
    fi
    if [[ -z "$claw" ]]; then
        echo -e "${WARN}→${NC} BOOTSTRAP.md found, but ${INFO}openclaw${NC} not on PATH yet; skipping onboarding."
        warn_openclaw_not_found
        return
    fi

    "$claw" onboard || {
        echo -e "${ERROR}Onboarding failed; BOOTSTRAP.md still present. Re-run ${INFO}openclaw onboard${ERROR}.${NC}"
        return
    }
}

resolve_openclaw_version() {
    local version=""
    local claw="${OPENCLAW_BIN:-}"
    if [[ -z "$claw" ]] && command -v openclaw &> /dev/null; then
        claw="$(command -v openclaw)"
    fi
    if [[ -n "$claw" ]]; then
        version=$("$claw" --version 2>/dev/null | head -n 1 | tr -d '\r')
    fi
    if [[ -z "$version" && -f "${INSTALL_DIR}/package.json" ]]; then
        version=$(node -e "console.log(require('${INSTALL_DIR}/package.json').version)" 2>/dev/null || true)
    fi
    echo "$version"
}

is_gateway_daemon_loaded() {
    local claw="$1"
    if [[ -z "$claw" ]]; then
        return 1
    fi

    # 添加超时防止卡住
    local status_json=""
    status_json="$(timeout 5 "$claw" daemon status --json 2>/dev/null || true)"
    if [[ -z "$status_json" ]]; then
        return 1
    fi

    if echo "$status_json" | grep -q '"loaded"[[:space:]]*:[[:space:]]*true'; then
        return 0
    fi
    return 1
}

main() {
    echo -e "${ACCENT}${BOLD}"
    echo "  🦞 OpenClaw 低内存版本部署"
    echo -e "${NC}${MUTED}  适用于 <1GB 内存的 Ubuntu / Debian${NC}"
    echo ""

    if [[ "$INSTALL_METHOD" != "prebuilt" && -n "$INSTALL_METHOD" ]]; then
        echo -e "${WARN}→${NC} 低内存版本仅支持预编译安装，已忽略 --install-method=${INSTALL_METHOD}"
    fi

    if [[ "$DRY_RUN" == "1" ]]; then
        echo -e "${SUCCESS}✓${NC} Dry run"
        echo -e "${SUCCESS}✓${NC} Release URL: $(resolve_release_url)"
        echo -e "${SUCCESS}✓${NC} Install dir: ${INSTALL_DIR}"
        echo -e "${SUCCESS}✓${NC} Bin link: ${BIN_LINK}"
        echo -e "${MUTED}Dry run complete (no changes made).${NC}"
        return 0
    fi

    local is_upgrade=false
    if check_existing_openclaw; then
        is_upgrade=true
    fi

    cleanup_old_wrappers

    if ! check_node; then
        install_node
    fi

    download_and_extract
    install_runtime_deps
    promote_install_tree
    create_bin_link

    OPENCLAW_BIN="$(resolve_openclaw_bin || true)"

    if [[ "$is_upgrade" == "true" ]]; then
        run_doctor
    fi

    run_bootstrap_onboarding_if_needed

    local installed_version
    installed_version=$(resolve_openclaw_version)

    echo ""
    if [[ -n "$installed_version" ]]; then
        echo -e "${SUCCESS}${BOLD}🦞 OpenClaw 低内存版安装成功 (${installed_version})!${NC}"
    else
        echo -e "${SUCCESS}${BOLD}🦞 OpenClaw 低内存版安装成功!${NC}"
    fi
    echo ""

    echo -e "安装位置: ${INFO}${INSTALL_DIR}${NC}"
    echo -e "配置目录: ${INFO}${HOME}/.openclaw${NC}"
    echo ""
    echo -e "快速开始:"
    echo -e "  ${INFO}openclaw --version${NC}      # 查看版本"
    echo -e "  ${INFO}openclaw onboard${NC}        # 运行配置向导"
    echo -e "  ${INFO}openclaw gateway --verbose${NC}  # 启动网关"
    echo ""

    if [[ "$is_upgrade" == "true" ]]; then
        echo -e "升级完成。"
    else
        if [[ "$NO_ONBOARD" == "1" ]]; then
            echo -e "Skipping onboard (requested). Run ${INFO}openclaw onboard${NC} later."
        else
            local config_path="${OPENCLAW_CONFIG_PATH:-$HOME/.openclaw/openclaw.json}"
            if [[ -f "${config_path}" || -f "$HOME/.clawdbot/clawdbot.json" || -f "$HOME/.moltbot/moltbot.json" || -f "$HOME/.moldbot/moldbot.json" ]]; then
                echo -e "Config already present; running doctor..."
                run_doctor
                echo -e "Config already present; skipping onboarding."
            else
                # 检测是否为交互式终端环境
                # -t 0 检测 stdin 是否连接到终端（curl | bash 时为 false）
                local is_interactive=0
                if [[ -t 0 ]] && [[ -r /dev/tty && -w /dev/tty ]]; then
                    is_interactive=1
                fi

                if [[ "$is_interactive" == "1" ]]; then
                    echo -e "Starting setup..."
                    echo ""
                    local claw="${OPENCLAW_BIN:-}"
                    if [[ -z "$claw" ]]; then
                        claw="$(resolve_openclaw_bin || true)"
                    fi
                    if [[ -z "$claw" ]]; then
                        echo -e "${WARN}→${NC} Skipping onboarding: ${INFO}openclaw${NC} not on PATH yet."
                        warn_openclaw_not_found
                        return 0
                    fi
                    # 在交互式终端中直接运行 onboard
                    "$claw" onboard </dev/tty
                else
                    # 非交互式环境（如 curl | bash），跳过自动 onboard
                    echo ""
                    echo -e "${INFO}i${NC} 检测到非交互式环境 (如 curl | bash)，跳过配置向导。"
                    echo -e "请手动运行以下命令完成配置："
                    echo -e "  ${INFO}openclaw onboard${NC}"
                    echo ""
                fi
            fi
        fi
    fi

    if command -v openclaw &> /dev/null; then
        local claw="${OPENCLAW_BIN:-}"
        if [[ -z "$claw" ]]; then
            claw="$(resolve_openclaw_bin || true)"
        fi
        if [[ -n "$claw" ]] && is_gateway_daemon_loaded "$claw"; then
            echo -e "${INFO}i${NC} Gateway daemon detected; restarting..."
            if timeout 10 env OPENCLAW_UPDATE_IN_PROGRESS=1 "$claw" daemon restart >/dev/null 2>&1; then
                echo -e "${SUCCESS}✓${NC} Gateway restarted."
            else
                echo -e "${WARN}→${NC} Gateway restart failed; try: ${INFO}openclaw daemon restart${NC}"
            fi
        fi
    fi

    echo ""
    echo -e "FAQ: ${INFO}https://docs.openclaw.ai/start/faq${NC}"
}

parse_args "$@"
configure_verbose
main
