#!/bin/bash
# OpenClaw 预编译打包脚本
# 在高性能机器上运行，生成预编译包供低内存机器使用

set -euo pipefail

# 颜色输出
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

# 检查是否在项目根目录
if [ ! -f "package.json" ] || [ ! -f "pnpm-workspace.yaml" ]; then
    echo_error "请在 OpenClaw 项目根目录运行此脚本"
    exit 1
fi

# 获取版本号
VERSION=$(node -e "console.log(require('./package.json').version)")
RELEASE_NAME="openclaw-${VERSION}-linux-x64"
RELEASE_DIR="releases"
RELEASE_FILE="${RELEASE_DIR}/${RELEASE_NAME}.tar.gz"

echo_info "======================================"
echo_info "OpenClaw 预编译打包工具"
echo_info "======================================"
echo_info "版本: ${VERSION}"
echo_info "目标平台: Linux x64"
echo_info "输出文件: ${RELEASE_FILE}"
echo ""

# 创建 releases 目录
mkdir -p "$RELEASE_DIR"

# 步骤 1: 清理旧的构建
echo_step "1/6 清理旧的构建文件..."
if [ -d "dist" ]; then
    rm -rf dist
    echo_info "已清理 dist 目录"
fi

# 步骤 2: 安装依赖（生产环境）
echo_step "2/6 安装生产依赖..."
if ! command -v pnpm &> /dev/null; then
    echo_error "pnpm 未安装，请先安装: npm install -g pnpm"
    exit 1
fi

# 使用 --prod 安装生产依赖，跳过 devDependencies
pnpm install --prod --no-optional --ignore-scripts

# 步骤 3: 构建项目（禁用 UI 构建以节省空间）
echo_step "3/6 构建项目..."
echo_info "跳过 UI 构建（ui:build）以减少包体积"

# 只运行核心构建
pnpm build || {
    echo_error "构建失败！"
    exit 1
}

echo_info "构建成功"

# 步骤 4: 创建预编译包目录结构
echo_step "4/6 准备打包目录..."
BUILD_DIR="${RELEASE_DIR}/build-${VERSION}"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# 复制必要文件
echo_info "复制必要文件到打包目录..."
cp -r dist "$BUILD_DIR/"
cp package.json "$BUILD_DIR/"
cp openclaw.mjs "$BUILD_DIR/"
cp README.md "$BUILD_DIR/"
cp LICENSE "$BUILD_DIR/" 2>/dev/null || echo_warn "LICENSE 文件不存在，跳过"

# 复制必要的配置文件（如果存在）
[ -f "config.minimal.yaml" ] && cp config.minimal.yaml "$BUILD_DIR/" || echo_warn "config.minimal.yaml 不存在"
[ -f ".env.minimal" ] && cp .env.minimal "$BUILD_DIR/" || echo_warn ".env.minimal 不存在"

# 创建版本信息文件
cat > "$BUILD_DIR/BUILD_INFO.txt" <<EOF
OpenClaw 预编译版本
====================
版本: ${VERSION}
构建时间: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
平台: Linux x64
Node.js 要求: >=22.0.0

特性:
- 已移除本地 LLM 支持
- 优化内存占用 (<1GB)
- 仅包含生产依赖
- 预编译二进制文件

安装说明:
1. 解压到目标目录
2. 确保 Node.js >= 22
3. 运行 node openclaw.mjs --version 验证
4. 配置 .env 文件
5. 启动: node openclaw.mjs gateway run

更多信息: https://github.com/808cn163/openclaw-1G-memory
EOF

# 复制最小化的 node_modules（仅运行时必需的）
echo_info "准备运行时依赖..."
mkdir -p "$BUILD_DIR/node_modules"

# 只复制核心运行时依赖（不包括构建工具）
RUNTIME_DEPS=(
    "@whiskeysockets/baileys"
    "sharp"
    "sqlite-vec"
    "ws"
    "express"
    "hono"
    "@agentclientprotocol/sdk"
    "@aws-sdk/client-bedrock"
    "@mariozechner/pi-agent-core"
    "@mariozechner/pi-ai"
    "@mariozechner/pi-coding-agent"
)

echo_info "复制核心运行时依赖..."
for dep in "${RUNTIME_DEPS[@]}"; do
    if [ -d "node_modules/$dep" ]; then
        mkdir -p "$BUILD_DIR/node_modules/$(dirname "$dep")"
        cp -r "node_modules/$dep" "$BUILD_DIR/node_modules/$(dirname "$dep")/" 2>/dev/null || true
        echo "  ✓ $dep"
    fi
done

# 复制其他必需的小型依赖
rsync -a --exclude='*.md' --exclude='test' --exclude='tests' \
    --exclude='*.map' --exclude='example' --exclude='examples' \
    node_modules/ "$BUILD_DIR/node_modules/" \
    --include='*/' \
    --include='*.js' --include='*.node' --include='*.json' \
    --exclude='*' 2>/dev/null || {
    echo_warn "rsync 失败，使用 cp 复制所有依赖"
    cp -r node_modules "$BUILD_DIR/"
}

# 步骤 5: 打包
echo_step "5/6 创建压缩包..."
cd "$RELEASE_DIR"
tar -czf "${RELEASE_NAME}.tar.gz" "build-${VERSION}/" || {
    echo_error "打包失败！"
    exit 1
}
cd ..

# 计算文件大小和 SHA256
FILE_SIZE=$(du -h "$RELEASE_FILE" | cut -f1)
SHA256=$(sha256sum "$RELEASE_FILE" | cut -d' ' -f1)

# 步骤 6: 清理临时文件
echo_step "6/6 清理临时文件..."
rm -rf "$BUILD_DIR"

# 完成
echo ""
echo_info "======================================"
echo_info "打包完成！"
echo_info "======================================"
echo ""
echo_info "文件信息:"
echo "  路径: $RELEASE_FILE"
echo "  大小: $FILE_SIZE"
echo "  SHA256: $SHA256"
echo ""
echo_info "下一步操作:"
echo ""
echo "1. 测试预编译包:"
echo "   $ mkdir -p /tmp/test-openclaw"
echo "   $ tar -xzf $RELEASE_FILE -C /tmp/test-openclaw --strip-components=1"
echo "   $ cd /tmp/test-openclaw"
echo "   $ node openclaw.mjs --version"
echo ""
echo "2. 上传到 GitHub Releases:"
echo "   $ gh release create v${VERSION} $RELEASE_FILE --title \"v${VERSION}\" --notes \"预编译版本\""
echo ""
echo "3. 或手动上传到:"
echo "   https://github.com/808cn163/openclaw-1G-memory/releases"
echo ""
echo_warn "记录 SHA256 校验和到 Release 说明中！"
echo ""
