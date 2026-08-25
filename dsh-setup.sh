#!/usr/bin/env bash
# =============================================================================
# dsh (DeepSeek Harness) Termux 自包含一键安装脚本
# -----------------------------------------------------------------------------
# 用法:   bash dsh-setup.sh
# 说明:   一条命令完成: 环境检查 → 装 Node24 → 装 dsh-termux 离线包 → 打补丁
#         并自动生成 start-dsh-web.sh / check-dsh.sh 两个辅助脚本
# 日志:   与本脚本同目录的 dsh-setup.log (屏幕同步显示)
# 复查:   部署后执行 bash check-dsh.sh 生成报告，把报告贴给 AI 即可
# =============================================================================
set -uo pipefail

# --- 日志: 与本脚本同目录 ---
SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
LOG_FILE="$SCRIPT_DIR/dsh-setup.log"
mkdir -p "$SCRIPT_DIR"
exec > >(tee -a "$LOG_FILE") 2>&1

say()  { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
ok()   { printf '\033[1;32m   ✓ %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m   ! %s\033[0m\n' "$*"; }
fail() { printf '\033[1;31m   ✗ %s\033[0m\n' "$*"; exit 1; }

echo "======================================================================"
echo " dsh (DeepSeek Harness) Termux 自包含一键安装"
echo " 时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo " 日志: $LOG_FILE"
echo "======================================================================"

# ---------------------------------------------------------------------------
# 1. 环境检查
# ---------------------------------------------------------------------------
say "1/5 环境检查"
[ -n "${TERMUX_VERSION:-}" ] || [ -d /data/data/com.termux/files ] \
  || fail "不在 Termux 里运行。请用 F-Droid 版 Termux。"
ARCH="$(uname -m)"
echo "    - 架构: $ARCH  (离线包官方只出 arm64)"
echo "    - Termux: ${TERMUX_VERSION:-未知(请确认来自 F-Droid/GitHub Releases)}"
echo "    - Android: $(getprop ro.build.version.release 2>/dev/null || echo 未知)"

# ---------------------------------------------------------------------------
# 2. 装基础包: python + nodejs-lts (Node 24, 严禁 v26)
# ---------------------------------------------------------------------------
say "2/5 安装基础包 (python + nodejs-lts, Node 24)"
pkg update -y 2>&1 | tail -2
pkg install -y python nodejs-lts 2>&1 | tail -3 \
  || fail "pkg install 失败。Play 版 Termux 没有仓库，请换 F-Droid 版。"

NODE_V="$(node -v 2>/dev/null || true)"
case "$NODE_V" in
  v2[45].*) ok "Node $NODE_V (兼容)";;
  v2[6-9].*|v3*) fail "Node $NODE_V 是 v26+！离线包按 Node 24 编译，请 pkg install nodejs-lts";;
  *) warn "Node 版本异常: ${NODE_V:-未检测到}";;
esac

# ---------------------------------------------------------------------------
# 3. 清理残留 + 安装 dsh-termux 离线包
# ---------------------------------------------------------------------------
say "3/5 安装 dsh-termux 离线包 (41MB, 零编译)"
npm uninstall -g dsh-termux @deepseek-ai/dsh 2>/dev/null || true

DSH_TGZ_URL="https://github.com/sunflower2333/dsh-termux/releases/latest/download/dsh-termux.tgz"
echo "    - 下载: $DSH_TGZ_URL"
npm install -g "$DSH_TGZ_URL" 2>&1 | tail -5 \
  || fail "npm 下载/安装失败，请确认能访问 github.com"

dsh --version >/dev/null 2>&1 \
  || fail "dsh 安装后无法运行，请把 dsh-setup.log 内容交给 AI 排查"
ok "dsh 安装完成: $(dsh --version | head -1)"

# ---------------------------------------------------------------------------
# 4. 打 HMR 补丁 (bin.js shebang 加 --expose-internals)
# ---------------------------------------------------------------------------
say "4/5 应用运行前补丁"
DSH_BIN="$(command -v dsh)"
NODE_REAL="$(command -v node)"
if [ -n "$DSH_BIN" ]; then
  if head -1 "$DSH_BIN" | grep -q -- "--expose-internals"; then
    ok "shebang 已含 --expose-internals"
  else
    sed -i "1s|^#!/usr/bin/env node|#!$NODE_REAL --expose-internals|" "$DSH_BIN" \
      && ok "已打补丁: $DSH_BIN" \
      || warn "shebang 修改失败 (HMR 不可用, 不影响主功能)"
  fi
fi

# ---------------------------------------------------------------------------
# 5. 生成辅助脚本 + 收尾
# ---------------------------------------------------------------------------
say "5/5 生成辅助脚本并收尾"

# start-dsh-web.sh: 启动包装, 日志固定落盘
cat > "$SCRIPT_DIR/start-dsh-web.sh" <<'INNER_EOF'
#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
LOG_ROOT="$SCRIPT_DIR/.dsh-logs"
mkdir -p "$LOG_ROOT"
LOG_FILE="$LOG_ROOT/dsh-web-$(date +%Y%m%d).log"
PID_FILE="$LOG_ROOT/dsh-web.pid"
HOST="${DSH_WEB_HOST:-127.0.0.1}"
PORT="${DSH_WEB_PORT:-3080}"
echo "======================================================================"
echo " 启动 dsh Web UI  时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo " 地址: http://$HOST:$PORT  (仅本机)"
echo " 日志: $LOG_FILE"
echo "======================================================================"
command -v termux-wake-lock >/dev/null 2>&1 && termux-wake-lock 2>/dev/null
echo $$ > "$PID_FILE"
exec dsh --profile web --host "$HOST" --port "$PORT" 2>&1 | tee -a "$LOG_FILE"
INNER_EOF
chmod +x "$SCRIPT_DIR/start-dsh-web.sh"

# check-dsh.sh: 复查脚本
cat > "$SCRIPT_DIR/check-dsh.sh" <<'INNER_EOF'
#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
LOG_ROOT="$SCRIPT_DIR/.dsh-logs"
REPORT="$LOG_ROOT/check-report-$(date +%Y%m%d-%H%M%S).txt"
mkdir -p "$LOG_ROOT"
{
echo "================================================================"
echo " dsh Termux 复查报告  生成时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "================================================================"
echo "--- 1. 环境 ---"
echo "Termux: ${TERMUX_VERSION:-未知}  架构: $(uname -m)  Android: $(getprop ro.build.version.release 2>/dev/null || echo 未知)"
echo "--- 2. 版本 ---"
echo "node: $(node -v 2>&1)   npm: $(npm -v 2>&1)"
echo "dsh : $(dsh --version 2>&1 | head -1)"
DSH_BIN="$(command -v dsh 2>/dev/null)"; [ -n "$DSH_BIN" ] && echo "dsh 路径: $DSH_BIN"
echo "--- 3. 运行状态 ---"
if [ -f "$LOG_ROOT/dsh-web.pid" ]; then
  PID="$(cat "$LOG_ROOT/dsh-web.pid" 2>/dev/null)"
  if kill -0 "$PID" 2>/dev/null; then echo "dsh web: 运行中 (PID $PID)"; else echo "dsh web: 未运行 (PID $PID 已死)"; fi
else
  echo "dsh web: 未启动过"
fi
echo "--- 4. 日志清单 ---"
ls -lht "$LOG_ROOT" 2>/dev/null | head -8 | sed 's/^/  /'
echo "--- 5. 最近安装日志尾部 ---"
LATEST="$(ls -t "$SCRIPT_DIR"/dsh-setup.log 2>/dev/null | head -1)"
[ -n "$LATEST" ] && tail -25 "$LATEST" | sed 's/^/  /'
echo "--- 6. 最近运行日志尾部 ---"
LATEST_RUN="$(ls -t "$LOG_ROOT"/dsh-web-*.log 2>/dev/null | head -1)"
[ -n "$LATEST_RUN" ] && tail -30 "$LATEST_RUN" | sed 's/^/  /'
echo "================================================================"
echo " 报告: $REPORT  —— 把内容粘贴给 AI 即可复查"
echo "================================================================"
} | tee "$REPORT"
INNER_EOF
chmod +x "$SCRIPT_DIR/check-dsh.sh"

ok "辅助脚本已生成: start-dsh-web.sh / check-dsh.sh"

echo
echo "======================================================================"
echo " ✔ 安装完成！"
echo "----------------------------------------------------------------------"
echo " 启动 Web UI :   bash $SCRIPT_DIR/start-dsh-web.sh"
echo "                 (后台: nohup bash $SCRIPT_DIR/start-dsh-web.sh >/dev/null 2>&1 &)"
echo " 复查        :   bash $SCRIPT_DIR/check-dsh.sh"
echo " 日志        :   $SCRIPT_DIR/dsh-setup.log   (本次安装)"
echo "                 $SCRIPT_DIR/.dsh-logs/      (运行日志)"
echo " API Key     :   启动后浏览器开 http://127.0.0.1:3080 → Settings → Models 填入"
echo "======================================================================"
