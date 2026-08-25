#!/usr/bin/env bash
# =============================================================================
# dsh (Termux) 部署复查脚本
# -----------------------------------------------------------------------------
# 用法: bash check-dsh.sh [--full]
# 输出: ~/.dsh/logs/check-report-<时间戳>.txt  —— 把这个文件内容交给 AI 即可复查
#       --full 追加运行日志尾部与 dsh 版本详情
# =============================================================================
set -uo pipefail

LOG_ROOT="$HOME/.dsh/logs"
REPORT="$LOG_ROOT/check-report-$(date +%Y%m%d-%H%M%S).txt"
mkdir -p "$LOG_ROOT"

{
echo "================================================================"
echo " dsh Termux 部署复查报告"
echo " 生成时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "================================================================"

echo
echo "--- 1. 基础环境 ---"
echo "Termux 版本 : ${TERMUX_VERSION:-未知}"
echo "架构        : $(uname -m)"
echo "Android     : $(getprop ro.build.version.release 2>/dev/null || echo 未知)"
echo "内核        : $(uname -r)"

echo
echo "--- 2. Node / dsh 版本 ---"
echo "node        : $(node -v 2>&1 || echo 未安装)"
echo "npm         : $(npm -v 2>&1 || echo 未安装)"
echo "dsh         : $(dsh --version 2>&1 | head -1 || echo 未安装)"
DSH_BIN="$(command -v dsh 2>/dev/null)"
if [ -n "$DSH_BIN" ]; then
  echo "dsh 路径    : $DSH_BIN"
  echo "dsh shebang : $(head -1 "$DSH_BIN")"
fi

echo
echo "--- 3. 关键目录 ---"
echo "DSH_HOME    : $HOME/.dsh"
echo "日志目录    : $LOG_ROOT"
echo "会话目录    : $HOME/.dsh/sessions/"
ls -d "$LOG_ROOT" "$HOME/.dsh/sessions" 2>/dev/null | sed 's/^/  存在: /'
[ -f "$HOME/.dsh/.credentials.yaml" ] && echo "凭据文件    : 已存在 (DEEPSEEK_API_KEY 引用数: $(grep -c DEEPSEEK_API_KEY "$HOME/.dsh/.credentials.yaml"))" \
                                       || echo "凭据文件    : 缺失 (需配置 ~/.dsh/.credentials.yaml)"

echo
echo "--- 4. 运行状态 ---"
if [ -f "$LOG_ROOT/dsh-web.pid" ]; then
  PID="$(cat "$LOG_ROOT/dsh-web.pid" 2>/dev/null)"
  if kill -0 "$PID" 2>/dev/null; then
    echo "dsh web     : 运行中 (PID $PID)"
    echo "监听端口    : $( (ss -tlnp 2>/dev/null || netstat -tln 2>/dev/null) | grep -E ':3080' | head -3 )"
  else
    echo "dsh web     : 未运行 (PID $PID 已不存在)"
  fi
else
  echo "dsh web     : 未运行 (无 PID 文件，尚未启动过)"
fi

echo
echo "--- 5. 日志文件清单 ---"
ls -lht "$LOG_ROOT" 2>/dev/null | head -10 | sed 's/^/  /'

echo
echo "--- 6. 最近部署日志尾部 ---"
LATEST_DEPLOY="$(ls -t "$LOG_ROOT"/deploy-*.log 2>/dev/null | head -1)"
if [ -n "$LATEST_DEPLOY" ]; then
  echo "文件: $LATEST_DEPLOY"
  tail -30 "$LATEST_DEPLOY" | sed 's/^/  /'
else
  echo "未找到部署日志 (尚未运行 deploy-dsh-termux.sh?)"
fi

if [ "${1:-}" = "--full" ]; then
  echo
  echo "--- 7. 最近运行日志尾部 (--full) ---"
  LATEST_RUN="$(ls -t "$LOG_ROOT"/dsh-web-*.log 2>/dev/null | head -1)"
  if [ -n "$LATEST_RUN" ]; then
    echo "文件: $LATEST_RUN"
    tail -40 "$LATEST_RUN" | sed 's/^/  /'
  else
    echo "未找到运行日志"
  fi
fi

echo
echo "================================================================"
echo " 复查报告已写入: $REPORT"
echo " 把该文件内容粘贴给 AI 即可复查部署状态"
echo "================================================================"
} | tee "$REPORT"
