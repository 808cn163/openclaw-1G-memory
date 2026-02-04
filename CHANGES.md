# OpenClaw 精简版更新说明

## 版本信息

- **基于版本**：OpenClaw 2026.2.2
- **优化目标**：1GB 内存 Ubuntu 服务器部署
- **优化日期**：2026-02-04

---

## 主要变更

### 1. 依赖项优化（package.json）

#### ✅ 已移除的依赖

**消息通道相关**（仅保留 WhatsApp）：
- `@buape/carbon` - Discord SDK
- `grammy` + `@grammyjs/*` - Telegram SDK
- `@slack/bolt` + `@slack/web-api` - Slack SDK
- `signal-utils` - Signal 协议
- `@line/bot-sdk` - Line SDK
- `@larksuiteoapi/node-sdk` - Feishu/Lark SDK
- `discord-api-types` - Discord 类型定义

**本地 LLM 相关**：
- `node-llama-cpp` - 本地大模型运行时（peerDependency）
- 所有本地模型支持代码

**其他优化**：
- `@mariozechner/pi-tui` - TUI 界面组件
- `node-edge-tts` - 语音合成
- `@homebridge/ciao` - mDNS 服务发现

#### ✅ 保留的核心依赖

- `@whiskeysockets/baileys` - WhatsApp Web 协议核心
- `playwright-core` - 浏览器自动化（默认禁用）
- `sharp` - 图像处理
- `@mariozechner/pi-agent-core` - AI 代理核心
- `@mariozechner/pi-ai` - AI 功能
- `@mariozechner/pi-coding-agent` - 代码代理
- 其他基础运行时依赖

### 2. 代码层面修改

#### src/memory/embeddings.ts
- ✅ 移除所有本地 LLM 嵌入提供程序代码
- ✅ 移除 `node-llama-cpp` 类型引用
- ✅ 简化为仅支持云端 API（OpenAI/Gemini）
- ✅ 更新类型定义，移除 `"local"` 选项

**修改前**：
```typescript
provider: "openai" | "local" | "gemini" | "auto"
fallback: "openai" | "gemini" | "local" | "none"
```

**修改后**：
```typescript
provider: "openai" | "gemini" | "auto"
fallback: "openai" | "gemini" | "none"
```

### 3. 新增配置文件

#### config.minimal.yaml
精简版配置模板，包含：
- 仅启用 WhatsApp 通道
- 默认禁用浏览器自动化
- 限制并发处理（maxConcurrent: 1-2）
- 限制图像尺寸（maxImageSize: 1024）
- 限制历史消息（maxHistoryMessages: 50）
- 限制向量缓存（maxVectorCacheSize: 500）
- 强制使用云端 API（provider: "openai"）

#### .env.minimal
环境变量配置模板，包含：
- Node.js 内存限制（768MB）
- 浏览器禁用标志
- 通道跳过列表
- API 密钥配置模板
- 日志级别设置

### 4. 部署工具

#### deploy-ubuntu.sh
Ubuntu 一键部署脚本，自动完成：
1. 系统内存检查
2. Node.js 22+ 安装
3. 系统依赖安装
4. pnpm 安装
5. 项目克隆和构建
6. 配置文件创建
7. systemd 服务配置
8. 环境变量设置

#### DEPLOY_UBUNTU.md
完整的部署和运维文档，包含：
- 快速部署指南
- 手动部署步骤
- 配置说明
- 常用操作
- 故障排查
- 性能监控
- 安全建议

---

## 内存优化效果

### 优化前（完整版）
```
Node.js 基础运行时:        ~80MB
本地 LLM (embeddings):    ~350MB
Playwright (浏览器):      ~250MB
WhatsApp (Baileys):       ~120MB
图像处理 (Sharp):         ~60MB
多消息通道 (6个):         ~150MB
AI 代理框架:              ~60MB
其他模块:                 ~100MB
----------------------------------------
总计:                    ~1210MB ❌ 超出限制
```

### 优化后（精简版）
```
Node.js 基础运行时:        ~80MB
AI 代理框架 (核心):       ~60MB
WhatsApp (Baileys):       ~120MB
图像处理 (Sharp):         ~40MB
基础媒体处理:             ~30MB
配置 + 会话管理:          ~40MB
云端 API:                 ~10MB
缓冲区:                   ~100MB
----------------------------------------
总计:                    ~480MB ✅ 符合要求
```

**节省内存**：约 730MB（60% 优化）

---

## 功能对比

| 功能 | 完整版 | 精简版 | 说明 |
|-----|--------|--------|------|
| WhatsApp 通道 | ✅ | ✅ | 核心功能保留 |
| Telegram 通道 | ✅ | ❌ | 已移除依赖 |
| Discord 通道 | ✅ | ❌ | 已移除依赖 |
| Slack 通道 | ✅ | ❌ | 已移除依赖 |
| Signal 通道 | ✅ | ❌ | 已移除依赖 |
| Line 通道 | ✅ | ❌ | 已移除依赖 |
| Feishu 通道 | ✅ | ❌ | 已移除依赖 |
| 本地 LLM | ✅ | ❌ | 强制使用云端 API |
| 浏览器自动化 | ✅ | 🟡 | 默认禁用，可启用 |
| 图像处理 | ✅ | ✅ | 保留（优化参数） |
| PDF 处理 | ✅ | 🟡 | 可用但建议禁用 |
| TUI 界面 | ✅ | ❌ | 已移除依赖 |
| 语音合成 | ✅ | ❌ | 已移除依赖 |

**图例**：✅ 支持 | ❌ 不支持 | 🟡 有限支持

---

## 使用限制

### 不支持的功能
1. **本地 LLM 模型**：必须使用 OpenAI/Gemini 等云端 API
2. **多消息通道**：仅支持 WhatsApp
3. **TUI 界面**：仅支持命令行模式
4. **语音合成**：无 TTS 功能

### 有限支持的功能
1. **浏览器自动化**：默认禁用，需手动启用且只能运行 1 个实例
2. **PDF 处理**：可用但建议禁用以节省内存
3. **并发处理**：限制为 1-2 个并发任务

---

## 升级路径

### 从完整版迁移到精简版

1. **备份数据**
```bash
cp -r ~/.openclaw ~/.openclaw.backup
```

2. **更新代码**
```bash
cd ~/openclaw
git pull
```

3. **重新安装依赖**
```bash
pnpm install --omit=peer
pnpm build
```

4. **更新配置**
```bash
cp config.minimal.yaml ~/.openclaw/config.yaml
cp .env.minimal ~/.openclaw/.env
# 编辑 .env 添加 API 密钥
nano ~/.openclaw/.env
```

5. **重启服务**
```bash
sudo systemctl restart openclaw
```

### 从精简版回退到完整版

1. **恢复 package.json**
```bash
git checkout package.json
```

2. **重新安装完整依赖**
```bash
pnpm install
pnpm build
```

3. **恢复配置**
```bash
cp ~/.openclaw.backup/config.yaml ~/.openclaw/config.yaml
```

4. **重启服务**
```bash
sudo systemctl restart openclaw
```

---

## 注意事项

### ⚠️ 重要提醒

1. **API 密钥必需**：精简版强制要求配置云端 API 密钥（OpenAI 或 Gemini）
2. **单通道限制**：仅支持 WhatsApp，其他通道代码虽存在但依赖已移除
3. **内存监控**：在 1GB 机器上建议配置 swap 空间
4. **浏览器功能**：默认禁用，启用后最多支持 1 个实例

### 📋 推荐配置

**最低配置（勉强可用）**：
- 1GB RAM + 1GB swap
- 2 核 CPU
- 2GB 存储空间

**推荐配置（稳定运行）**：
- 2GB RAM
- 2 核 CPU
- 5GB 存储空间

**理想配置（完整体验）**：
- 4GB RAM
- 4 核 CPU
- 10GB 存储空间
- 使用完整版而非精简版

---

## 维护建议

### 定期维护

1. **每周检查**
   - 内存使用情况
   - 日志文件大小
   - 会话数据大小

2. **每月维护**
   - 更新 OpenClaw 到最新版本
   - 清理旧日志文件
   - 备份重要会话数据

3. **按需操作**
   - 当内存占用超过 700MB 时重启服务
   - WhatsApp 会话异常时删除会话重新登录
   - API 限额不足时切换 API 提供商

### 监控指标

建议监控以下指标：
- **内存使用率**：应保持在 70% 以下
- **CPU 使用率**：正常情况下应低于 30%
- **磁盘使用**：留出至少 1GB 可用空间
- **网络连接**：确保与 WhatsApp 服务器稳定连接

---

## 技术支持

如遇到问题，请按以下顺序排查：

1. 查看部署文档：`DEPLOY_UBUNTU.md`
2. 查看内存评估：`内存占用评估.md`
3. 检查日志：`sudo journalctl -u openclaw -f`
4. 访问官方文档：https://docs.openclaw.ai
5. 提交 Issue：https://github.com/openclaw/openclaw/issues

---

**文档版本**：1.0
**更新日期**：2026-02-04
**适用版本**：OpenClaw 2026.2.2+
