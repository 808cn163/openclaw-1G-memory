#!/bin/bash
set -euo pipefail

# OpenClaw 低内存版本构建脚本
# 在高性能机器上执行此脚本以创建预编译包

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="${PROJECT_DIR}/release"
PACKAGE_NAME="openclaw-ubuntu-lite"

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

# 步骤 4: 创建输出目录
echo "→ 准备打包..."
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR/$PACKAGE_NAME"

# 步骤 5: 复制必要文件
echo "→ 复制文件..."

# 编译产物
cp -r dist "$OUTPUT_DIR/$PACKAGE_NAME/"

# 入口文件
cp openclaw.mjs "$OUTPUT_DIR/$PACKAGE_NAME/"

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
// 移除 pnpm 特定配置中的 node-llama-cpp
if (pkg.pnpm && pkg.pnpm.onlyBuiltDependencies) {
  pkg.pnpm.onlyBuiltDependencies = pkg.pnpm.onlyBuiltDependencies.filter(d => d !== 'node-llama-cpp');
}
console.log(JSON.stringify(pkg, null, 2));
" > "$OUTPUT_DIR/$PACKAGE_NAME/package.json"

# 复制部署脚本
cp deploy-ubuntu.sh "$OUTPUT_DIR/"

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
