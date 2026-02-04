# OpenClaw 预编译部署方案

## 📌 问题背景

在 <1GB 内存的小型服务器上编译 OpenClaw 会导致：
- 编译过程消耗大量内存（pnpm build 需要 1.5GB+）
- 系统卡死或 OOM（Out of Memory）
- 编译时间长达 20-30 分钟

## 🎯 解决方案

采用**预编译 + 分发**模式：
1. **高配机器**：编译打包生成预编译包
2. **低配机器**：直接下载预编译包安装（无需编译）

---

## 🔧 使用流程

### 方案 A：使用 GitHub Releases（推荐）

#### 步骤 1：在高配机器上编译打包

```bash
# 1. 克隆或进入项目目录
cd openclaw-1G-memory

# 2. 运行预编译脚本
chmod +x build-release.sh
./build-release.sh
```

**输出**：
```
releases/openclaw-2026.2.3-linux-x64.tar.gz
```

#### 步骤 2：上传到 GitHub Releases

**方式 A：使用 GitHub CLI（推荐）**
```bash
# 获取版本号
VERSION=$(node -e "console.log(require('./package.json').version)")

# 创建 Release 并上传
gh release create v${VERSION} \
  releases/openclaw-${VERSION}-linux-x64.tar.gz \
  --title "v${VERSION} - 低内存优化版" \
  --notes "预编译版本，适用于 <1GB 内存环境

**特性：**
- ✅ 已移除本地 LLM 支持
- ✅ 优化内存占用（768MB 限制）
- ✅ 预编译二进制，无需编译
- ✅ 仅包含运行时依赖

**安装：**
\`\`\`bash
curl -fsSL https://raw.githubusercontent.com/808cn163/openclaw-1G-memory/main/deploy-ubuntu.sh | bash
\`\`\`

**SHA256：**
\`$(sha256sum releases/openclaw-${VERSION}-linux-x64.tar.gz | cut -d' ' -f1)\`
"
```

**方式 B：手动上传**
1. 访问 https://github.com/808cn163/openclaw-1G-memory/releases
2. 点击 "Create a new release"
3. 填写版本号（如 v2026.2.3）
4. 上传 `openclaw-*-linux-x64.tar.gz` 文件
5. 发布

#### 步骤 3：在低配机器上安装

```bash
# 运行部署脚本（自动下载最新 Release）
curl -fsSL https://raw.githubusercontent.com/808cn163/openclaw-1G-memory/main/deploy-ubuntu.sh | bash

# 或者手动下载并运行
wget https://raw.githubusercontent.com/808cn163/openclaw-1G-memory/main/deploy-ubuntu.sh
chmod +x deploy-ubuntu.sh
./deploy-ubuntu.sh
```

**安装过程**：
1. ✅ 检查系统资源（内存/磁盘/网络）
2. ✅ 安装 Node.js 22+
3. ✅ 下载预编译包（从 GitHub Releases）
4. ✅ 解压到 ~/openclaw
5. ✅ 配置环境变量和 systemd 服务
6. ✅ 无需编译！

---

### 方案 B：手动部署预编译包

如果无法访问 GitHub Releases，可以手动传输：

#### 在高配机器上：
```bash
# 1. 编译
./build-release.sh

# 2. 传输到低配机器
scp releases/openclaw-*.tar.gz user@low-memory-server:~/
```

#### 在低配机器上：
```bash
# 1. 解压
mkdir -p ~/openclaw
tar -xzf openclaw-*.tar.gz -C ~/openclaw --strip-components=1

# 2. 验证
cd ~/openclaw
node openclaw.mjs --version

# 3. 配置环境变量
mkdir -p ~/.openclaw

cat > ~/.openclaw/.env <<'EOF'
OPENAI_API_KEY=your_key_here
NODE_OPTIONS=--max-old-space-size=768
OPENCLAW_DISABLE_BROWSER=1
EOF

# 4. 运行
source ~/.openclaw/.env
node openclaw.mjs gateway run --bind loopback --port 18789
```

---

## 📊 改进对比

### 旧方案（源码编译）
```bash
❌ 克隆完整仓库（200MB+）
❌ pnpm install（安装所有依赖，500MB+）
❌ pnpm build（编译，消耗 1.5GB+ 内存）
❌ 总耗时：20-30 分钟
❌ 内存不足时会卡死
```

### 新方案（预编译）
```bash
✅ 下载预编译包（~150MB）
✅ 解压即用（无需编译）
✅ 总耗时：3-5 分钟
✅ 内存占用：<300MB
✅ 不会卡死
```

---

## 🔍 新版 deploy-ubuntu.sh 特性

### 1. 资源检查增强
```bash
✓ 内存检查（总量 + 可用）
✓ 磁盘空间检查
✓ 网络连接检查
✓ 早期失败，避免浪费时间
```

### 2. 错误处理改进
```bash
✓ 临时文件自动清理（trap 机制）
✓ 下载重试机制（最多 3 次）
✓ 超时控制（避免无限等待）
✓ 详细的错误提示
```

### 3. 智能安装模式
```bash
优先：从 GitHub Releases 下载预编译包
备用：如果预编译包不可用，自动切换到源码编译
降级：源码编译失败时给出明确提示
```

### 4. 内存保护
```bash
✓ systemd MemoryMax=900M（硬限制）
✓ systemd MemoryHigh=800M（软限制）
✓ NODE_OPTIONS=--max-old-space-size=768
✓ 禁用浏览器功能
```

---

## 📦 预编译包内容

```
openclaw-2026.2.3-linux-x64/
├── dist/                    # 编译后的代码
├── node_modules/            # 运行时依赖（精简）
├── package.json
├── openclaw.mjs             # 入口文件
├── config.minimal.yaml      # 配置模板
├── .env.minimal             # 环境变量模板
├── BUILD_INFO.txt           # 构建信息
└── README.md
```

**包体积**：约 150MB（已压缩）

---

## 🚀 快速开始

### 最简单的方式（一键安装）

```bash
curl -fsSL https://raw.githubusercontent.com/808cn163/openclaw-1G-memory/main/deploy-ubuntu.sh | bash
```

### 安装后配置

```bash
# 1. 配置 API 密钥
nano ~/.openclaw/.env
# 添加: OPENAI_API_KEY=sk-xxx

# 2. 启动服务
sudo systemctl start openclaw

# 3. 查看状态
sudo systemctl status openclaw

# 4. 查看日志
sudo journalctl -u openclaw -f
```

---

## ⚠️ 注意事项

### 系统要求
- **内存**：800MB 最低，1GB 推荐
- **磁盘**：1GB 最低，2GB 推荐
- **系统**：Ubuntu 20.04+（Debian 系）
- **Node.js**：22+ 自动安装

### 限制说明
- ❌ 不支持本地 LLM（已移除）
- ❌ 不支持浏览器功能（已禁用）
- ✅ 支持 OpenAI/Gemini 云端 API
- ✅ 支持本地 SQLite 存储

---

## 🛠️ 故障排除

### 问题 1：下载预编译包失败
```bash
# 检查网络连接
ping -c 3 github.com

# 手动下载
wget https://github.com/808cn163/openclaw-1G-memory/releases/download/v2026.2.3/openclaw-2026.2.3-linux-x64.tar.gz

# 手动解压
tar -xzf openclaw-*.tar.gz -C ~/openclaw --strip-components=1
```

### 问题 2：内存不足
```bash
# 查看内存使用
free -h

# 关闭不必要的服务
sudo systemctl stop apache2
sudo systemctl stop mysql

# 降低内存限制
export NODE_OPTIONS="--max-old-space-size=512"
```

### 问题 3：验证安装
```bash
cd ~/openclaw
node openclaw.mjs --version
node openclaw.mjs gateway --help
```

---

## 📚 相关文档

- [GitHub 仓库](https://github.com/808cn163/openclaw-1G-memory)
- [原始文档](https://docs.openclaw.ai)
- [问题反馈](https://github.com/808cn163/openclaw-1G-memory/issues)

---

## 🎉 总结

采用预编译方案后：
- ✅ **内存占用**：从 1.5GB+ 降到 300MB
- ✅ **安装时间**：从 20-30 分钟降到 3-5 分钟
- ✅ **成功率**：接近 100%（不再卡死）
- ✅ **用户体验**：大幅提升

**推荐使用预编译包，告别编译卡死的烦恼！**
