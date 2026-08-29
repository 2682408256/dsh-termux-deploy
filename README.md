# dsh-termux-deploy

在 **Termux (Android)** 上部署 [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness) (`dsh`) 的一键脚本集，以及 **DSH 容器 ↔ Termux** 互通运维工具。

基于社区预编译离线包 [sunflower2333/dsh-termux](https://github.com/sunflower2333/dsh-termux)（零编译、原生模块齐备），附全流程踩坑记录。

## ✨ 特性

- **一键安装**：`bash dsh-setup.sh` —— 环境检查 → Node 24 → 下载 41MB 离线包 → 自动打 HMR 补丁 → 生成辅助脚本
- **日志落盘**：部署日志、运行日志、复查报告统一落在脚本同目录，方便远程排查
- **SSH 互通**：容器侧 `ssh-termux.sh` 一键免密连接 Termux，告别手动复制粘贴
- **复查脚本**：`check-dsh.sh` 一键生成环境/版本/运行状态报告，可直接交给 AI 复查

## 📦 文件清单

| 文件 | 用途 |
|---|---|
| `dsh-setup.sh` | **自包含一键安装**（推荐入口） |
| `start-dsh-web.sh` | 启动 Web UI，日志固定落盘（默认端口 **3081**，避开 DSH App 的 3080） |
| `check-dsh.sh` | 复查脚本：生成完整状态报告 |
| `ssh-setup.sh` | Termux 侧一键开启 SSH（装 openssh + 放公钥 + 起 sshd） |
| `ssh-termux.sh` | DSH 容器侧一键连接 Termux |
| `MEMO.md` | 全部踩坑经验 + 快速操作手册 |
| `deploy-dsh-termux.sh` | 旧版分步部署脚本（保留） |
| `dsh-start.sh` | **Termux 一键拉起**（sshd + dsh 守护 + wake-lock，Termux 被杀后重开跑它） |
| `dsh-keepalive.sh` | dsh 保活守护（dsh 死了自动重启） |
| `ui-preview.html` | 手机 UI 暗色科技风预览（纯前端） |

## 🚀 快速开始

### 在 Termux 中安装 dsh

```bash
# 前置: F-Droid/GitHub 版 Termux (Play 版不支持), Android 8+
pkg install -y python nodejs-lts   # Node 24, 不要装 nodejs (v26)

# 下载并安装
curl -fL -o ~/dsh-termux.tgz https://github.com/sunflower2333/dsh-termux/releases/latest/download/dsh-termux.tgz
npm install -g ~/dsh-termux.tgz
dsh --version    # → 0.1.1-rc.2-termux.1

# 启动 (端口 3081, 3080 被 DSH App 占用)
nohup dsh --profile web --host 127.0.0.1 --port 3081 > ~/.dsh/logs/dsh-web.log 2>&1 &
```

手机浏览器打开 `http://127.0.0.1:3081`，在 **Settings → Models** 填入 DeepSeek API Key。

### 一键安装脚本

```bash
# 下载脚本后执行（日志自动写在同目录 dsh-setup.log）
curl -s http://127.0.0.1:8123/dsh-setup.sh -o dsh-setup.sh
bash dsh-setup.sh
```

### 容器 ↔ Termux SSH 互通

```bash
# Termux 侧 (一次性): 下载并执行 ssh-setup.sh
# 容器侧: 一键连接
bash ssh-termux.sh "dsh --version"
bash ssh-termux.sh              # 交互式 shell
```

## ⚠️ 已知坑（全部实战踩过）

| 坑 | 解法 |
|---|---|
| `npm i -g <URL>` 装不上（显示 up to date 但没装） | 手动下载 tgz 再本地安装 |
| `sed -i` 破坏 dsh 符号链接 → `ERR_MODULE_NOT_FOUND` | 重建链接，补丁打在真实 bin.js 上 |
| 端口 3080 被 DSH App 占用 | Termux 用 **3081** |
| 僵尸 sshd 占 8022 | sshd 用冷门端口 **8023** |
| `pkill` 杀不干净 sshd | 同时 `pkill -9 sshd-session` |
| GitHub 下载慢 (~200KB/s) | 后台 nohup 下载，不要续传（会损坏文件） |

详见 [MEMO.md](MEMO.md)。

## 📄 许可

MIT License，见 [LICENSE](LICENSE)。

## 🙏 致谢

- [sunflower2333/dsh-termux](https://github.com/sunflower2333/dsh-termux) — Termux 离线打包与原生模块预编译
- [deepseek-ai/deepseek-harness](https://github.com/deepseek-ai/deepseek-harness) — DeepSeek Harness

---

## 📤 DSH 数据同步（手机容器 → GitHub → Windows）

`dsh-data/` 目录存放可从容器导出的 dsh 用户数据，跨设备同步用。

### 包含（安全、可移植）

| 路径 | 说明 |
|---|---|
| `dsh-data/settings.yaml` | 全局设置 + 模型供应商配置（只含环境变量引用，**无明文密钥**） |
| `dsh-data/skills/` | 自定义技能（SKILL.md） |
| `dsh-data/storages/` | 工作区/会话缓存 JSON |
| `dsh-data/skin-center-active.json` | 皮肤设置 |
| `dsh-data/sessions/` | 会话文件（**仅元数据**；dsh 设计如此，对话正文在机器本地 sqlite，不可移植） |

### 明确不包含（机器本地/敏感）

- `.credentials.yaml` — 明文 API key，**永不入库**。跨设备请手动拷贝：
  `cp /home/dsh/.dsh/.credentials.yaml <目标机>/.dsh/`（Windows: `%USERPROFILE%\.dsh\`）
- `profiles/`（9.7M node_modules 运行时）、`state.db*`（sqlite 会话索引）、`auth.lock` 等

### 手机容器侧导出

```bash
# 密钥打码（如含历史密钥）: zstd 解压→替换→重压，见会话记录
rsync -a /home/dsh/.dsh/{settings.yaml,skills,storages,skin-center-active.json,sessions} dsh-data/
git add dsh-data/ && git commit -m "sync dsh data" && git push
```

### Windows 侧恢复

```powershell
# 1) 拉取仓库
git clone git@github.com:2682408256/dsh-termux-deploy.git
# 2) 合并进用户 dsh 目录 (注意: 若 Windows 已有 ~/.dsh 先备份)
robocopy dsh-termux-deploy\dsh-data %USERPROFILE%\.dsh /E /NJH /NJS
# 3) 手动补凭据: 把 .credentials.yaml 放进 %USERPROFILE%\.dsh\
```

> ⚠️ 本仓库为**公开仓库**：dsh-data 里只有打码/无敏感数据，但如需同步含个人内容的文件，请把仓库改为 **Private**（Settings → General → Danger Zone）。
