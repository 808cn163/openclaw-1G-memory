#!/bin/bash
set -euo pipefail

# OpenClaw 低内存版本构建脚本
# 在高性能机器上执行此脚本以创建预编译包

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="${PROJECT_DIR}/release"
PACKAGE_NAME="openclaw-ubuntu-lite"
DEPLOY_SCRIPT_PATH="${PROJECT_DIR}/release/deploy-ubuntu.sh"

if [[ ! -f "$DEPLOY_SCRIPT_PATH" ]]; then
    echo "✗ 缺少部署脚本: $DEPLOY_SCRIPT_PATH"
    exit 1
fi

DEPLOY_SCRIPT_TMP="$(mktemp)"
cp "$DEPLOY_SCRIPT_PATH" "$DEPLOY_SCRIPT_TMP"
trap 'rm -f "$DEPLOY_SCRIPT_TMP"' EXIT

echo "🦞 OpenClaw 低内存版本构建脚本"
echo "================================"
echo ""

cd "$PROJECT_DIR"

# 步骤 1: 安装依赖
echo "→ 安装依赖..."
pnpm install
echo "✓ 依赖安装完成"

# 步骤 2: 构建项目
echo "→ 构建项目..."
pnpm build
echo "✓ 项目构建完成"

# 步骤 3: 构建 UI
echo "→ 构建 UI..."
pnpm ui:build || echo "⚠ UI 构建失败，继续..."
echo "✓ UI 构建完成"

# 步骤 4: 编译内置插件 (memory-core)
echo "→ 编译内置插件..."
MEMORY_CORE_DIR="${PROJECT_DIR}/extensions/memory-core"
if [[ -f "$MEMORY_CORE_DIR/index.ts" ]]; then
    # 使用 esbuild 编译 TypeScript 插件为 JavaScript
    pnpm exec esbuild "$MEMORY_CORE_DIR/index.ts" \
        --outfile="$MEMORY_CORE_DIR/index.js" \
        --format=esm \
        --platform=node \
        --target=node22 \
        --bundle \
        --external:openclaw \
        --external:"openclaw/*"

    # 更新 package.json 指向编译后的 .js 文件
    node -e "
const fs = require('fs');
const pkgPath = '${MEMORY_CORE_DIR}/package.json';
const pkg = JSON.parse(fs.readFileSync(pkgPath, 'utf8'));
if (pkg.openclaw && pkg.openclaw.extensions) {
    pkg.openclaw.extensions = pkg.openclaw.extensions.map(e => e.replace(/\\.ts$/, '.js'));
}
fs.writeFileSync(pkgPath, JSON.stringify(pkg, null, 2) + '\\n');
"
    echo "✓ memory-core 插件编译完成"
else
    echo "⚠ memory-core/index.ts 不存在，跳过编译"
fi

# 步骤 5: 创建输出目录
echo "→ 准备打包..."
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR/$PACKAGE_NAME"

# 步骤 6: 复制必要文件
echo "→ 复制文件..."

# 编译产物
cp -r dist "$OUTPUT_DIR/$PACKAGE_NAME/"

# 入口文件
cp openclaw.mjs "$OUTPUT_DIR/$PACKAGE_NAME/"

# 内置插件（必须包含 memory-core，否则首次配置会因 plugins.slots.memory 校验失败）
# 只复制必要文件，不复制 node_modules 和源文件
mkdir -p "$OUTPUT_DIR/$PACKAGE_NAME/extensions/memory-core"
cp "$MEMORY_CORE_DIR/index.js" "$OUTPUT_DIR/$PACKAGE_NAME/extensions/memory-core/"
cp "$MEMORY_CORE_DIR/package.json" "$OUTPUT_DIR/$PACKAGE_NAME/extensions/memory-core/"
cp "$MEMORY_CORE_DIR/openclaw.plugin.json" "$OUTPUT_DIR/$PACKAGE_NAME/extensions/memory-core/"

# 资源文件
cp -r assets "$OUTPUT_DIR/$PACKAGE_NAME/" 2>/dev/null || true
cp -r skills "$OUTPUT_DIR/$PACKAGE_NAME/" 2>/dev/null || true

# 文档和许可
cp README.md "$OUTPUT_DIR/$PACKAGE_NAME/" 2>/dev/null || true
cp LICENSE "$OUTPUT_DIR/$PACKAGE_NAME/" 2>/dev/null || true
cp CHANGELOG.md "$OUTPUT_DIR/$PACKAGE_NAME/" 2>/dev/null || true

# 创建精简版 package.json (移除 devDependencies)
node -e "
const pkg = require('./package.json');
delete pkg.devDependencies;
delete pkg.peerDependencies;
delete pkg.scripts;
delete pkg.vitest;
delete pkg.pnpm;
console.log(JSON.stringify(pkg, null, 2));
" > "$OUTPUT_DIR/$PACKAGE_NAME/package.json"

# 在高性能机器预安装运行时依赖，避免低内存机器 npm install OOM
echo "→ 预安装运行时依赖..."
(
  cd "$OUTPUT_DIR/$PACKAGE_NAME"
  npm install --omit=dev --ignore-scripts --no-fund --no-audit --loglevel=error
)

if [[ ! -d "$OUTPUT_DIR/$PACKAGE_NAME/node_modules/chalk" ]]; then
    echo "✗ 预安装依赖失败: 缺少 node_modules/chalk"
    exit 1
fi
echo "✓ 运行时依赖已预装"

# 防回归：确保关键内置插件已打入包中
if [[ ! -f "$OUTPUT_DIR/$PACKAGE_NAME/extensions/memory-core/openclaw.plugin.json" ]]; then
    echo "✗ 预编译包不完整: 缺少 extensions/memory-core/openclaw.plugin.json"
    exit 1
fi
echo "✓ 已包含内置 memory-core 插件"

# 复制部署脚本
cp "$DEPLOY_SCRIPT_TMP" "$OUTPUT_DIR/deploy-ubuntu.sh"
chmod +x "$OUTPUT_DIR/deploy-ubuntu.sh"

echo "✓ 文件复制完成"

# 步骤 6: 创建压缩包
echo "→ 创建压缩包..."
cd "$OUTPUT_DIR"
tar -czf "${PACKAGE_NAME}.tar.gz" "$PACKAGE_NAME"

# 清理临时目录
rm -rf "$PACKAGE_NAME"

echo "✓ 压缩包创建完成"

echo ""
echo "================================"
echo "🦞 构建完成!"
echo ""
echo "输出文件:"
echo "  - $OUTPUT_DIR/${PACKAGE_NAME}.tar.gz"
echo "  - $OUTPUT_DIR/deploy-ubuntu.sh"
echo ""
echo "发布步骤:"
echo "  1. git tag -a v2026.2.3-lite -m 'OpenClaw 低内存版本'"
echo "  2. git push origin v2026.2.3-lite"
echo "  3. 在 GitHub Releases 上传以上文件"
echo ""
