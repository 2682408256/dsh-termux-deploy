#!/usr/bin/env bash
# =============================================================================
# dsh (DeepSeek Harness) 在 Termux 上的一步到位部署脚本
# -----------------------------------------------------------------------------
# 用法:   在 Termux 里执行  bash deploy-dsh-termux.sh
# 前置:   Termux 必须来自 F-Droid 或 GitHub Releases (Play 版不支持)
#         手机建议 Android 8+，需要联网
# 输出:   部署日志 → ~/.dsh/logs/deploy-<时间戳>.log  (屏幕同时显示)
#         之后运行日志 → ~/.dsh/logs/dsh-web-<日期>.log (见 start-dsh-web.sh)
#         会话记录 → ~/.dsh/sessions/.../session.jsonl.zstd
# 复查:   部署完成后执行  bash check-dsh.sh  可生成复查报告
# =============================================================================
set -uo pipefail

# ---------------------------------------------------------------------------
# 0. 日志基础：一切输出都双写(屏幕 + 文件)，固定落盘目录便于复查
# ---------------------------------------------------------------------------
LOG_ROOT="$HOME/.dsh/logs"
DEPLOY_LOG="$LOG_ROOT/deploy-$(date +%Y%m%d-%H%M%S).log"
mkdir -p "$LOG_ROOT"
exec > >(tee -a "$DEPLOY_LOG") 2>&1

say()  { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
ok()   { printf '\033[1;32m   ✓ %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m   ! %s\033[0m\n' "$*"; }
fail() { printf '\033[1;31m   ✗ %s\033[0m\n' "$*"; exit 1; }

echo "======================================================================"
echo " dsh (DeepSeek Harness) Termux 一键部署"
echo " 开始时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo " 部署日志: $DEPLOY_LOG"
echo "======================================================================"

# ---------------------------------------------------------------------------
# 1. 环境前置检查
# ---------------------------------------------------------------------------
say "1/6 环境检查"

[ -n "${TERMUX_VERSION:-}" ] || [ -d /data/data/com.termux/files ] \
  || fail "看起来不在 Termux 里运行。请先在手机上安装 F-Droid 版 Termux。"

ARCH="$(uname -m)"
[ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ] \
  || warn "当前架构 $ARCH，离线包官方只出 arm64；x86_64 设备可能失败"

echo "    - Termux 版本: ${TERMUX_VERSION:-未知(请确认来自 F-Droid/GitHub Releases)}"
echo "    - 架构: $ARCH"
echo "    - Android: $(getprop ro.build.version.release 2>/dev/null || echo 未知)"

# ---------------------------------------------------------------------------
# 2. 安装基础包: python + nodejs-lts (Node 24)。严禁 nodejs(v26)!
# ---------------------------------------------------------------------------
say "2/6 安装基础包 (python + nodejs-lts, Node 24)"

pkg update -y 2>&1 | tail -2
pkg install -y python nodejs-lts 2>&1 | tail -3 \
  || fail "pkg install 失败，请检查网络或换源 (termux-change-repo)"

NODE_V="$(node -v 2>/dev/null || true)"
case "$NODE_V" in
  v2[45].*) ok "Node 版本 $NODE_V (兼容)";;
  v2[6-9].*|v3*) fail "检测到 Node $NODE_V (v26+)。离线包按 Node 24 编译，请 pkg install nodejs-lts";;
  *) warn "Node 版本异常: ${NODE_V:-未检测到}";;
esac

# ---------------------------------------------------------------------------
# 3. 安装 dsh 离线包 (零编译，从 GitHub Release 拉取)
# ---------------------------------------------------------------------------
say "3/6 安装 dsh 离线包 (dsh-termux)"

DSH_TGZ_URL="https://github.com/sunflower2333/dsh-termux/releases/latest/download/dsh-termux.tgz"

if command -v dsh >/dev/null 2>&1; then
  EXISTING="$(dsh --version 2>/dev/null | head -1)"
  warn "检测到已安装 dsh: $EXISTING —— 将覆盖为最新离线包"
fi

echo "    - 下载并安装: $DSH_TGZ_URL"
npm install -g "$DSH_TGZ_URL" 2>&1 | tail -5 \
  || fail "npm 下载/安装失败。请确认能访问 github.com"

INSTALLED_VERSION="$(dsh --version 2>&1 | head -1)"
ok "安装完成: $INSTALLED_VERSION"

# ---------------------------------------------------------------------------
# 4. dsh 运行前补丁
#    - bin.js shebang 加 --expose-internals (HMR 需要；Node22+ 默认禁内部模块)
# ---------------------------------------------------------------------------
say "4/6 应用运行前补丁"

DSH_BIN="$(command -v dsh)"
if [ -n "$DSH_BIN" ]; then
  NODE_REAL="$(command -v node)"
  if head -1 "$DSH_BIN" | grep -q -- "--expose-internals"; then
    ok "shebang 已含 --expose-internals"
  else
    sed -i "1s|^#!/usr/bin/env node|#!$NODE_REAL --expose-internals|" "$DSH_BIN" \
      && ok "bin.js shebang 已加 --expose-internals ($DSH_BIN)" \
      || warn "无法修改 $DSH_BIN 的 shebang (HMR 可能不可用，不影响主功能)"
  fi
else
  warn "未找到 dsh 命令路径"
fi

# ---------------------------------------------------------------------------
# 5. 初始化 ~/.dsh 与 API Key 引导
# ---------------------------------------------------------------------------
say "5/6 初始化配置目录"

DSH_HOME="$HOME/.dsh"
mkdir -p "$DSH_HOME"

echo
echo "    API Key 配置说明（官方推荐方式）:"
echo "      1) 启动 Web UI 后打开  Settings → Models"
echo "      2) 在 DeepSeek 卡片输入 API Key 并保存"
echo "         (key 将以只写方式存于 $DSH_HOME/.credentials.yaml)"
echo "      替代方式: 环境变量 DEEPSEEK_API_KEY=sk-xxx dsh web"
echo "      未配置时启动会提示 MISSING_CREDENTIAL，不影响安装本身。"

# ---------------------------------------------------------------------------
# 6. 验证 & 收尾
# ---------------------------------------------------------------------------
say "6/6 验证"

dsh --version

echo
echo "======================================================================"
echo " ✔ 部署完成"
echo "----------------------------------------------------------------------"
echo "  启动 Web UI :   bash $PWD/start-dsh-web.sh"
echo "                  (或:  nohup bash $PWD/start-dsh-web.sh >/dev/null 2>&1 &)"
echo "  复查脚本    :   bash $PWD/check-dsh.sh"
echo "  日志目录    :   ~/.dsh/logs/"
echo "     - 本次部署日志: $DEPLOY_LOG"
echo "     - 后续运行日志: ~/.dsh/logs/dsh-web-<日期>.log"
echo "  会话记录    :   ~/.dsh/sessions/"
echo "  凭据文件    :   ~/.dsh/.credentials.yaml (Web UI Settings→Models 写入)"
echo "======================================================================"
