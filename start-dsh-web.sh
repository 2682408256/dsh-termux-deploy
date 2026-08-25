#!/usr/bin/env bash
# =============================================================================
# dsh Web UI 启动包装脚本 (Termux)
# -----------------------------------------------------------------------------
# - 前台运行:  bash start-dsh-web.sh
# - 后台运行:  nohup bash start-dsh-web.sh >/dev/null 2>&1 &
# 注意: 默认端口 3081 —— 因为 3080 被 DSH App 自己的 Web GUI 占用(共享回环)
# 输出:
#   - 运行日志 → ~/.dsh/logs/dsh-web-<端口>-<日期>.log
#   - PID 文件  → ~/.dsh/logs/dsh-web.pid
# =============================================================================
set -uo pipefail

LOG_ROOT="$HOME/.dsh/logs"
mkdir -p "$LOG_ROOT"
PID_FILE="$LOG_ROOT/dsh-web.pid"

# 端口: 默认 3081 (3080 被 DSH App 占用); 可用 DSH_WEB_PORT 环境变量覆盖
HOST="${DSH_WEB_HOST:-127.0.0.1}"
PORT="${DSH_WEB_PORT:-3081}"
LOG_FILE="$LOG_ROOT/dsh-web-${PORT}-$(date +%Y%m%d).log"

echo "======================================================================"
echo " 启动 dsh Web UI"
echo " 时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo " 地址: http://$HOST:$PORT   (仅本机可访问)"
echo " 日志: $LOG_FILE"
echo "======================================================================"

# Termux 里唤醒 CPU / 避免后台被杀 (未安装 termux-api 时自动跳过)
command -v termux-wake-lock >/dev/null 2>&1 && termux-wake-lock 2>/dev/null

# 记录 PID 便于复查/停止
echo $$ > "$PID_FILE"

# 启动 dsh，stdout+stderr 全量进日志（前台仍可见）
exec dsh --profile web --host "$HOST" --port "$PORT" 2>&1 | tee -a "$LOG_FILE"
