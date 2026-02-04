# OpenClaw Ubuntu 精简部署指南

## 概述

这是 OpenClaw 的 Ubuntu 精简版部署方案，专门优化用于 **1GB 内存**的低配置服务器环境。

## 主要优化

### 内存优化
- ✅ **删除本地 LLM 支持**：移除 `node-llama-cpp` 依赖，强制使用云端 API
- ✅ **移除多消息通道**：仅保留 WhatsApp 通道，删除 Telegram、Discord、Slack、Signal、Line、Feishu 等依赖
- ✅ **浏览器默认禁用**：`playwright-core` 代码保留但默认不启动，节省 200-300MB 内存
- ✅ **限制并发处理**：最大并发数设为 1-2，减少内存峰值
- ✅ **优化缓存策略**：限制历史消息、向量缓存等大小

### 功能裁剪
- ❌ 本地 LLM 模型（使用云端 API 替代）
- ❌ Telegram、Discord、Slack 等其他消息通道（仅保留 WhatsApp）
- ❌ 浏览器自动化（默认禁用，可按需启用）
- ❌ TUI 界面（命令行精简模式）
- ❌ 语音合成功能

### 预期内存占用
- **最小运行时**：~350-400MB
- **正常运行时**：~500-600MB
- **安全余量**：保持在 700MB 以下

---

## 系统要求

### 最低要求
- **操作系统**：Ubuntu 20.04 LTS 或更高版本
- **内存**：1GB RAM（建议配置 swap）
- **存储**：2GB 可用空间
- **Node.js**：v22.12.0 或更高版本

### 推荐配置
- **内存**：2GB RAM
- **存储**：5GB 可用空间
- **网络**：稳定的互联网连接

---

## 快速部署（一键脚本）

### 1. 下载部署脚本

```bash
# 克隆仓库或下载脚本
git clone https://github.com/openclaw/openclaw.git
cd openclaw

# 或直接下载脚本
curl -O https://raw.githubusercontent.com/openclaw/openclaw/main/deploy-ubuntu.sh
chmod +x deploy-ubuntu.sh
```

### 2. 运行部署脚本

```bash
./deploy-ubuntu.sh
```

脚本会自动完成：
- ✅ 检查系统内存
- ✅ 安装 Node.js 22+
- ✅ 安装系统依赖（build-essential, libvips-dev 等）
- ✅ 安装 pnpm
- ✅ 克隆项目并安装依赖
- ✅ 构建项目
- ✅ 创建配置文件
- ✅ 设置 systemd 服务

### 3. 配置 API 密钥

编辑环境变量文件：

```bash
nano ~/.openclaw/.env
```

添加您的 API 密钥（至少配置一个）：

```bash
# OpenAI API
OPENAI_API_KEY=sk-your-api-key-here

# 或使用 Gemini API
# GEMINI_API_KEY=your-gemini-api-key-here

# 或使用 Anthropic Claude API
# ANTHROPIC_API_KEY=your-anthropic-api-key-here
```

### 4. 启动服务

**方式一：手动启动（测试用）**

```bash
cd ~/openclaw
source ~/.openclaw/.env
node openclaw.mjs gateway run --bind loopback --port 18789
```

首次启动会显示 WhatsApp QR 码，使用手机扫描登录。

**方式二：systemd 服务（生产推荐）**

```bash
# 启动服务
sudo systemctl start openclaw

# 查看状态
sudo systemctl status openclaw

# 查看日志
sudo journalctl -u openclaw -f

# 开机自启动
sudo systemctl enable openclaw
```

---

## 手动部署（分步骤）

### 1. 安装 Node.js 22+

```bash
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt-get install -y nodejs
```

### 2. 安装系统依赖

```bash
sudo apt-get update
sudo apt-get install -y \
    build-essential \
    python3 \
    make \
    g++ \
    libvips-dev \
    git \
    curl
```

### 3. 安装 pnpm

```bash
npm install -g pnpm@latest
```

### 4. 克隆和构建项目

```bash
cd ~
git clone https://github.com/openclaw/openclaw.git
cd openclaw

# 安装依赖（跳过可选依赖以节省空间）
pnpm install --omit=peer

# 构建项目
pnpm build
```

### 5. 配置文件设置

```bash
# 创建配置目录
mkdir -p ~/.openclaw

# 复制精简配置模板
cp config.minimal.yaml ~/.openclaw/config.yaml

# 复制环境变量模板
cp .env.minimal ~/.openclaw/.env

# 编辑 .env 添加 API 密钥
nano ~/.openclaw/.env
```

### 6. 设置环境变量

添加到 `~/.bashrc`：

```bash
echo 'export NODE_OPTIONS="--max-old-space-size=768"' >> ~/.bashrc
echo 'export OPENCLAW_DISABLE_BROWSER=1' >> ~/.bashrc
echo 'export OPENCLAW_CONFIG_PATH="$HOME/.openclaw/config.yaml"' >> ~/.bashrc
source ~/.bashrc
```

### 7. 创建 systemd 服务

创建服务文件 `/etc/systemd/system/openclaw.service`：

```ini
[Unit]
Description=OpenClaw WhatsApp Gateway
After=network.target

[Service]
Type=simple
User=your-username
WorkingDirectory=/home/your-username/openclaw
Environment="NODE_OPTIONS=--max-old-space-size=768"
Environment="OPENCLAW_DISABLE_BROWSER=1"
EnvironmentFile=/home/your-username/.openclaw/.env
ExecStart=/usr/bin/node /home/your-username/openclaw/openclaw.mjs gateway run --bind loopback --port 18789
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=openclaw

[Install]
WantedBy=multi-user.target
```

启用服务：

```bash
sudo systemctl daemon-reload
sudo systemctl enable openclaw
sudo systemctl start openclaw
```

---

## 配置说明

### config.minimal.yaml 关键配置

```yaml
agents:
  defaults:
    memorySearch:
      provider: "openai"  # 使用云端 API
      fallback: "none"
    tools:
      browser:
        enabled: false  # 禁用浏览器
        maxInstances: 1

channels:
  whatsapp:
    enabled: true  # 仅启用 WhatsApp

gateway:
  maxConcurrentRequests: 2  # 限制并发

media:
  maxImageSize: 1024  # 限制图像尺寸
  maxConcurrentProcessing: 1

sessions:
  maxHistoryMessages: 50  # 限制历史消息

memory:
  maxVectorCacheSize: 500  # 限制缓存
```

### .env.minimal 关键配置

```bash
# Node.js 内存限制
NODE_OPTIONS="--max-old-space-size=768"

# 禁用浏览器
OPENCLAW_DISABLE_BROWSER=1

# 跳过其他通道
OPENCLAW_SKIP_CHANNELS=telegram,discord,slack,signal,line,feishu,imessage

# API 密钥
OPENAI_API_KEY=your_key_here

# 日志级别
OPENCLAW_LOG_LEVEL=warn
```

---

## 常用操作

### 查看服务状态

```bash
sudo systemctl status openclaw
```

### 查看实时日志

```bash
sudo journalctl -u openclaw -f
```

### 重启服务

```bash
sudo systemctl restart openclaw
```

### 停止服务

```bash
sudo systemctl stop openclaw
```

### 查看内存使用

```bash
ps aux | grep openclaw
top -p $(pgrep -f openclaw)
```

### 更新 OpenClaw

```bash
cd ~/openclaw
git pull
pnpm install
pnpm build
sudo systemctl restart openclaw
```

---

## 故障排查

### 1. 内存不足

**症状**：进程被 OOM Killer 杀死

**解决**：
```bash
# 添加 swap 空间
sudo fallocate -l 1G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# 永久启用
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

### 2. WhatsApp 无法连接

**症状**：QR 码无法生成或扫描后断连

**解决**：
```bash
# 删除旧会话
rm -rf ~/.openclaw/sessions/*

# 重启服务
sudo systemctl restart openclaw

# 查看日志获取新 QR 码
sudo journalctl -u openclaw -f
```

### 3. API 密钥错误

**症状**：日志显示 "No API key found"

**解决**：
```bash
# 检查 .env 文件
cat ~/.openclaw/.env | grep API_KEY

# 编辑添加密钥
nano ~/.openclaw/.env

# 重启服务
sudo systemctl restart openclaw
```

### 4. 端口被占用

**症状**：启动失败，提示端口 18789 已被使用

**解决**：
```bash
# 查找占用端口的进程
sudo lsof -i :18789

# 杀死进程或修改配置文件中的端口
nano ~/.openclaw/config.yaml
# 修改 gateway.port 为其他值（如 18790）
```

---

## 性能监控

### 实时监控脚本

创建 `monitor.sh`：

```bash
#!/bin/bash
while true; do
    clear
    echo "========== OpenClaw 性能监控 =========="
    echo ""
    echo "时间: $(date)"
    echo ""

    # 内存使用
    echo "--- 内存使用 ---"
    free -h
    echo ""

    # 进程信息
    echo "--- OpenClaw 进程 ---"
    ps aux | grep openclaw | grep -v grep | awk '{printf "PID: %s | CPU: %s%% | MEM: %s%% | RSS: %s KB\n", $2, $3, $4, $6}'
    echo ""

    # 服务状态
    echo "--- 服务状态 ---"
    systemctl is-active openclaw
    echo ""

    sleep 5
done
```

运行监控：

```bash
chmod +x monitor.sh
./monitor.sh
```

---

## 安全建议

### 1. 防火墙配置

```bash
# 仅允许本地访问（默认已配置）
sudo ufw allow from 127.0.0.1 to any port 18789
```

### 2. 日志轮转

创建 `/etc/logrotate.d/openclaw`：

```
/var/log/openclaw/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 0640 your-username your-username
}
```

### 3. 自动备份会话

添加到 crontab：

```bash
# 每天备份 WhatsApp 会话
0 2 * * * tar -czf ~/.openclaw/backups/sessions-$(date +\%Y\%m\%d).tar.gz ~/.openclaw/sessions/
```

---

## 文件位置

- **项目目录**：`~/openclaw/`
- **配置文件**：`~/.openclaw/config.yaml`
- **环境变量**：`~/.openclaw/.env`
- **会话数据**：`~/.openclaw/sessions/`
- **日志文件**：通过 `journalctl` 查看
- **systemd 服务**：`/etc/systemd/system/openclaw.service`

---

## 支持与帮助

- **官方文档**：https://docs.openclaw.ai
- **GitHub 仓库**：https://github.com/openclaw/openclaw
- **问题反馈**：https://github.com/openclaw/openclaw/issues

---

## 附录：完整命令速查表

```bash
# 启动服务
sudo systemctl start openclaw

# 停止服务
sudo systemctl stop openclaw

# 重启服务
sudo systemctl restart openclaw

# 查看状态
sudo systemctl status openclaw

# 查看日志
sudo journalctl -u openclaw -f

# 开机自启
sudo systemctl enable openclaw

# 禁用自启
sudo systemctl disable openclaw

# 查看内存
free -h

# 查看进程
ps aux | grep openclaw

# 编辑配置
nano ~/.openclaw/config.yaml

# 编辑环境变量
nano ~/.openclaw/.env

# 更新项目
cd ~/openclaw && git pull && pnpm install && pnpm build

# 清理会话
rm -rf ~/.openclaw/sessions/*
```

---

**最后更新**：2026-02-04
