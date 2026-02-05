# 🦞 OpenClaw 低内存版本 — 个人 AI 助手

<p align="center">
    <picture>
        <source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/openclaw/openclaw/main/docs/assets/openclaw-logo-text-dark.png">
        <img src="https://raw.githubusercontent.com/openclaw/openclaw/main/docs/assets/openclaw-logo-text.png" alt="OpenClaw" width="500">
    </picture>
</p>

<p align="center">
  <strong>适用于小于 1GB 内存的 Ubuntu 系统</strong>
</p>

<p align="center">
  <a href="https://github.com/808cn163/openclaw-1G-memory/releases"><img src="https://img.shields.io/github/v/release/808cn163/openclaw-1G-memory?include_prereleases&style=for-the-badge" alt="GitHub release"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue.svg?style=for-the-badge" alt="MIT License"></a>
</p>

**OpenClaw 低内存版本** 是专为资源受限的服务器环境设计的 OpenClaw 发行版。通过预编译方式避免编译时的高内存消耗，使其可以在小于 1GB 内存的 Ubuntu 系统上正常运行。

## 与完整版的区别

| 功能                      | 完整版               | 低内存版               |
| ------------------------- | -------------------- | ---------------------- |
| 本地 LLM (node-llama-cpp) | ✅ 支持              | ❌ 已移除              |
| Ollama 集成               | ✅ 支持              | ❌ 已移除              |
| 浏览器自动化              | ✅ 默认启用          | ⚠️ 默认禁用            |
| Embedding                 | 本地/API             | 仅 API (OpenAI/Gemini) |
| 安装方式                  | npm install (需编译) | 预编译包 (无需编译)    |
| 内存需求                  | >2GB (编译时)        | <1GB                   |

## 快速安装

### 一键部署 (推荐)

```bash
curl -fsSL https://github.com/808cn163/openclaw-1G-memory/releases/latest/download/deploy-ubuntu.sh | bash
```

### 跳过配置向导

```bash
curl -fsSL https://github.com/808cn163/openclaw-1G-memory/releases/latest/download/deploy-ubuntu.sh | bash -s -- --no-onboard
```

### 手动安装

1. 下载预编译包：

```bash
wget https://github.com/808cn163/openclaw-1G-memory/releases/latest/download/openclaw-ubuntu-lite.tar.gz
```

2. 解压到安装目录：

```bash
sudo mkdir -p /opt/openclaw
sudo tar -xzf openclaw-ubuntu-lite.tar.gz -C /opt/openclaw --strip-components=1
```

3. 安装运行时依赖：

```bash
cd /opt/openclaw
sudo npm install --omit=dev --ignore-scripts
```

4. 创建命令入口：

```bash
sudo ln -sf /opt/openclaw/openclaw.mjs /usr/local/bin/openclaw
```

5. 运行配置向导：

```bash
openclaw onboard
```

## 系统要求

- **操作系统**: Ubuntu 20.04+ / Debian 11+
- **Node.js**: 22.0.0+
- **内存**: 512MB+ (运行时)
- **磁盘**: 500MB+

## Embedding API 配置

由于本版本移除了本地 embedding 支持，您需要配置 API 模式的 embedding：

### 使用 OpenAI (推荐)

在配置向导中选择 OpenAI，或手动编辑 `~/.openclaw/openclaw.json`：

```json
{
  "agents": {
    "defaults": {
      "memorySearch": {
        "provider": "openai"
      }
    }
  }
}
```

### 使用 Gemini

```json
{
  "agents": {
    "defaults": {
      "memorySearch": {
        "provider": "gemini"
      }
    }
  }
}
```

## 常用命令

```bash
# 查看版本
openclaw --version

# 运行配置向导
openclaw onboard

# 启动网关
openclaw gateway --verbose

# 发送消息
openclaw message send --to +1234567890 --message "Hello"

# 运行诊断
openclaw doctor
```

## 配置文件

配置文件位于 `~/.openclaw/openclaw.json`。

默认配置 (低内存版本)：

```json
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
```

## 启用浏览器自动化 (可选)

如果您的系统有足够资源，可以启用浏览器自动化：

```json
{
  "browser": {
    "enabled": true
  }
}
```

注意：启用浏览器自动化会增加内存使用。

## 支持的模型提供商

- **Anthropic** (Claude Pro/Max) - 推荐
- **OpenAI** (ChatGPT/Codex)
- **Google** (Gemini)
- **GitHub Copilot**
- **Amazon Bedrock**
- 以及更多...

## 支持的消息渠道

- WhatsApp
- Telegram
- Slack
- Discord
- Google Chat
- Signal
- iMessage (通过 BlueBubbles)
- Microsoft Teams
- Matrix
- WebChat

## 故障排除

### 内存不足

如果遇到内存不足问题：

1. 确保禁用了浏览器自动化
2. 减少并发会话数
3. 考虑添加 swap 空间

### Node.js 版本过低

```bash
# 安装 Node.js 22
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt-get install -y nodejs
```

### 权限问题

```bash
# 确保配置目录权限正确
mkdir -p ~/.openclaw
chmod 700 ~/.openclaw
```

## 从源码构建

如果您需要自定义构建：

```bash
git clone https://github.com/808cn163/openclaw-1G-memory.git
cd openclaw-1G-memory
./scripts/build-release.sh
```

## 更新

重新运行部署脚本即可更新：

```bash
curl -fsSL https://github.com/808cn163/openclaw-1G-memory/releases/latest/download/deploy-ubuntu.sh | bash
```

## 相关链接

- [OpenClaw 官方仓库](https://github.com/openclaw/openclaw)
- [官方文档](https://docs.openclaw.ai)
- [FAQ](https://docs.openclaw.ai/start/faq)

## 许可证

MIT License - 详见 [LICENSE](LICENSE) 文件。

## 致谢

本项目基于 [OpenClaw](https://github.com/openclaw/openclaw) 修改，感谢 Peter Steinberger 和社区贡献者的工作。
