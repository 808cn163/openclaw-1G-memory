# OpenClaw - 智能代理网关 (1G 内存优化版)

OpenClaw 是一个轻量级的 WhatsApp 网关和智能代理运行时环境，专为低资源环境（如 1G 内存 VPS）进行了优化。它支持多种 AI 模型（OpenAI, Gemini, SiliconFlow 等）并集成了向量记忆功能。

- 项目名称：`openclaw`
- 配置目录：`~/.openclaw`
- GitHub 仓库：`https://github.com/808cn163/openclaw-1G-memory`

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

### 一键部署（推荐）

请使用 GitHub Release 的预编译安装脚本（适合 <1GB 内存环境）：

```bash
curl -fsSL https://github.com/808cn163/openclaw-1G-memory/releases/latest/download/deploy-ubuntu.sh | bash
```

该脚本将自动执行以下操作：

1. 检查并安装 Node.js 22+
2. 下载预编译包并安装到 `/opt/openclaw`
3. 创建 `openclaw` 命令入口
4. 保留并迁移原有 `~/.openclaw` 配置

> 注意：不要使用仓库 `main/deploy-ubuntu.sh` 的 raw 链接，该文件已移除，发布渠道以 Release 资产为准。

## 📦 预编译安装（低内存机器推荐）

当目标机器内存小于 1GB 时，建议使用预编译产物，避免在目标机执行构建。

### 方式一：直接使用最新 Release（推荐）

```bash
curl -fsSL https://github.com/808cn163/openclaw-1G-memory/releases/latest/download/deploy-ubuntu.sh | bash
```

> 说明：`deploy-ubuntu.sh` 与 `openclaw-ubuntu-lite.tar.gz` 均以 GitHub Releases 为唯一发布入口，脚本会自动下载最新预编译产物并安装。

### 方式二：指定版本安装

```bash
curl -fsSL https://github.com/808cn163/openclaw-1G-memory/releases/latest/download/deploy-ubuntu.sh | bash -s -- --version v2026.2.3-lite
```

### 方式三：离线/半离线安装

```bash
# 在可联网机器下载
wget https://github.com/808cn163/openclaw-1G-memory/releases/latest/download/deploy-ubuntu.sh
wget https://github.com/808cn163/openclaw-1G-memory/releases/latest/download/openclaw-ubuntu-lite.tar.gz

# 拷贝到目标机后执行
bash deploy-ubuntu.sh --version latest
```

安装完成后可验证：

```bash
openclaw --version
openclaw status
```

如果在超低内存环境中执行 `openclaw onboard` 出现长时间无响应，建议先用非交互模式完成最小初始化：

```bash
openclaw onboard --non-interactive --accept-risk --auth-choice skip --skip-channels --skip-skills --skip-health --skip-ui
```

随后可再运行 `openclaw configure` 或重新执行 `openclaw onboard` 做交互式完善配置。

如果仍希望使用交互式向导，可启用低内存交互模式（首轮 prompt 数量更少）：

```bash
openclaw onboard --low-memory
```

该模式会优先走 `quickstart + local`，并默认跳过 channels/skills/health/UI 的首次引导步骤。

## 🧠 低内存与 Swap 配置建议（1G VPS）

在 `1GB RAM` 的 Ubuntu 24.04 机器上，建议预先配置 swap 再运行 OpenClaw。

- 建议值：`swap = 6G`（已验证可稳定运行）
- 最小值：`swap >= 4G`（低于 4G 容易在安装/onboard 阶段 OOM）
- `vm.swappiness` 建议：`60`

### 一次性检查当前状态

```bash
free -h
swapon --show
cat /proc/sys/vm/swappiness
```

### 创建或重建 6G swap（Ubuntu）

```bash
sudo swapoff -a || true
sudo rm -f /swapfile
sudo fallocate -l 6G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
echo 'vm.swappiness=60' | sudo tee /etc/sysctl.d/99-openclaw-memory.conf
sudo sysctl -p /etc/sysctl.d/99-openclaw-memory.conf
free -h
swapon --show
```

## 🚑 OOM 修复参数（已实测）

在 1G 内存机器上，如果 `openclaw onboard` 报错 `JavaScript heap out of memory`，请使用以下参数：

```bash
OPENCLAW_FORCE_MAX_OLD_SPACE_SIZE=896 NODE_OPTIONS="--max-old-space-size=896" openclaw onboard
```

已验证结果：使用 `896` 后可稳定进入 `openclaw onboard` 交互向导页面，不再出现 OOM 崩溃。

从本仓库最新 `deploy-ubuntu.sh` 安装后，默认包装器会自动注入上述 `896` 参数（且不覆盖用户显式自定义的 `NODE_OPTIONS`）。

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

核心配置文件默认位于 `~/.openclaw/openclaw.json`。您可以通过 `openclaw config` 命令进行管理。

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

**Q: 在 1GB 内存机器执行 `openclaw onboard` 仍然 OOM？**
A: 低内存版会自动为 `onboard/setup/configure` 注入已验证的 `896MB` 堆参数。你也可以手动执行：`OPENCLAW_FORCE_MAX_OLD_SPACE_SIZE=896 NODE_OPTIONS="--max-old-space-size=896" openclaw onboard`。

**Q: 如何保持后台运行？**
A: 推荐使用 `pm2` 或 `systemd` 来管理进程。一键脚本会自动配置 systemd 服务。

**Q: WhatsApp 连接断开怎么办？**
A: 运行 `openclaw gateway run --force` 重新启动网关，或者通过 `openclaw status` 检查连接状态。

---

_本项目由 OpenClaw 社区维护，专为高效能低资源环境打造。_
