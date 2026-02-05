# 🦞 OpenClaw 低内存版本 — 个人 AI 助手

<p align="center">
  <img src="README-header.png" alt="OpenClaw" width="520">
</p>

<p align="center">
  <strong>适用于小于 1GB 内存的 Ubuntu / Debian VPS</strong>
</p>

<p align="center">
  <a href="https://github.com/808cn163/openclaw-1G-memory/releases"><img src="https://img.shields.io/github/v/release/808cn163/openclaw-1G-memory?include_prereleases&style=for-the-badge" alt="GitHub release"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue.svg?style=for-the-badge" alt="MIT License"></a>
</p>

**OpenClaw 低内存版本** 是专为资源受限的服务器环境裁剪的 OpenClaw 发行版。通过**预编译包**避免在小内存机器上构建时的高内存消耗，让 <1GB 内存的 VPS 也能稳定运行。

## 与完整版的区别

| 功能                      | 完整版               | 低内存版                           |
| ------------------------- | -------------------- | ---------------------------------- |
| 本地 LLM (node-llama-cpp) | ✅ 支持              | ❌ 已移除                          |
| Ollama 集成               | ✅ 支持              | ❌ 已移除                          |
| 浏览器自动化              | ✅ 支持              | ❌ 已移除                          |
| Embedding                 | 本地/API             | 仅 API (OpenAI/Gemini/SiliconFlow) |
| 安装方式                  | npm install (需编译) | 预编译包 (无需编译)                |
| 内存需求                  | >2GB (编译时)        | <1GB (运行时)                      |

## 预编译安装（推荐）

### 一键部署

```bash
curl -fsSL https://github.com/808cn163/openclaw-1G-memory/releases/latest/download/deploy-ubuntu.sh | bash
```

### 跳过配置向导

```bash
curl -fsSL https://github.com/808cn163/openclaw-1G-memory/releases/latest/download/deploy-ubuntu.sh | bash -s -- --no-onboard
```

### 手动安装（预编译包）

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
sudo npm install --omit=dev --ignore-scripts --no-fund --no-audit
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

## Embedding 配置

本版本仅支持 **API 模式** embedding，支持以下提供商：

- `openai`
- `gemini`
- `siliconflow`（新增）

配置文件位于 `~/.openclaw/openclaw.json`。

### 使用 OpenAI（推荐）

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

### 使用 SiliconFlow

```json
{
  "agents": {
    "defaults": {
      "memorySearch": {
        "provider": "siliconflow",
        "siliconflow": {
          "apiKey": "YOUR_SILICONFLOW_API_KEY",
          "model": "BAAI/bge-m3"
        }
      }
    }
  }
}
```

> `model` 可选，默认 `BAAI/bge-m3`。

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

> 浏览器自动化已移除，相关配置会被忽略。

## 预编译包说明

发布包 `openclaw-ubuntu-lite.tar.gz` 已包含编译产物 (`dist/`) 和入口脚本 (`openclaw.mjs`)。安装时只需执行运行时依赖安装，无需在小内存机器上构建。

## 从源码构建（在高性能机器上执行）

如果需要自定义构建：

```bash
git clone https://github.com/808cn163/openclaw-1G-memory.git
cd openclaw-1G-memory
./scripts/build-release.sh
```

构建完成后，在 `release/` 目录中获得：

- `openclaw-ubuntu-lite.tar.gz`
- `deploy-ubuntu.sh`

## 更新

重新运行部署脚本即可更新：

```bash
curl -fsSL https://github.com/808cn163/openclaw-1G-memory/releases/latest/download/deploy-ubuntu.sh | bash
```

## 相关链接

- 本项目仓库: https://github.com/808cn163/openclaw-1G-memory
- 官方文档: https://docs.openclaw.ai
- FAQ: https://docs.openclaw.ai/start/faq

## 许可证

MIT License - 详见 [LICENSE](LICENSE) 文件。

## 致谢

本项目基于 OpenClaw 开源项目裁剪，感谢 Peter Steinberger 和社区贡献者的工作。
