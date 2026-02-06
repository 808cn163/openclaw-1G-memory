# OpenClaw - 智能代理网关 (1G 内存优化版)

OpenClaw 是一个轻量级的 WhatsApp 网关和智能代理运行时环境，专为低资源环境（如 1G 内存 VPS）进行了优化。它支持多种 AI 模型（OpenAI, Gemini, SiliconFlow 等）并集成了向量记忆功能。

## ✨ 主要特性

- **轻量级架构**: 移除冗余依赖，专为小内存服务器优化。
- **多模型支持**: 内置支持 OpenAI, Gemini, SiliconFlow 等主流大模型。
- **WhatsApp 集成**: 基于 Baileys 的稳定 WhatsApp Web 协议接入。
- **向量记忆**: 支持基于 embeddings 的长期记忆检索。
- **插件系统**: 灵活的插件扩展机制。

## 🚀 快速上手

### 环境要求

- Ubuntu 20.04 或更高版本
- Node.js 22+
- 至少 1GB 内存

### 一键部署

我们在 Ubuntu 上提供了一键部署脚本，自动处理环境安装和配置：

```bash
curl -sL https://raw.githubusercontent.com/808cn163/openclaw-1G-memory/main/deploy-ubuntu.sh | bash
```

该脚本将自动执行以下操作：

1. 安装 Node.js 和系统依赖
2. 克隆代码仓库
3. 安装项目依赖 (自动优化内存占用)
4. 引导进行初始配置 (WhatsApp 登录、API Key 设置等)

### 手动安装

如果您偏好手动控制，可以按照以下步骤操作：

```bash
# 1. 克隆代码
git clone https://github.com/808cn163/openclaw-1G-memory.git openclaw
cd openclaw

# 2. 安装依赖 (生产环境)
npm install --omit=dev

# 3. 构建项目
npm run build

# 4. 运行配置向导
./bin/openclaw onboard

# 5. 启动服务
./bin/openclaw gateway run
```

## ⚙️ 配置说明

核心配置文件位于 `~/.openclaw/config.yaml`。您可以通过 `openclaw config` 命令进行管理。

### 常用配置命令

- **设置 API Key**:

  ```bash
  openclaw config set agents.defaults.llm.provider siliconflow
  openclaw config set agents.defaults.llm.apiKey sk-xxxxxxxx
  ```

- **启用/禁用功能**:
  ```bash
  openclaw config set agents.defaults.memorySearch.enabled true
  ```

## ❓ 常见问题

**Q: 安装依赖时出现 `ERR_MODULE_NOT_FOUND` 或内存溢出？**
A: 请确保使用 `npm install --omit=dev` 来跳过开发依赖，这可以显著降低内存占用。如果仍然遇到问题，尝试增加 swap 空间。

**Q: 如何保持后台运行？**
A: 推荐使用 `pm2` 或 `systemd` 来管理进程。一键脚本会自动配置 systemd 服务。

**Q: WhatsApp 连接断开怎么办？**
A: 运行 `openclaw gateway run --force` 重新启动网关，或者通过 `openclaw status` 检查连接状态。

---

_本项目由 OpenClaw 社区维护，专为高效能低资源环境打造。_
