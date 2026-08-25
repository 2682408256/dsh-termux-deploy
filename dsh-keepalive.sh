#!/usr/bin/env bash
# dsh 保活守护: 持有 wake-lock + dsh 死了自动重启
set -uo pipefail
LOG=~/.dsh/logs/keepalive.log
mkdir -p ~/.dsh/logs

# 获取 wake-lock (防止 CPU 睡眠)
termux-wake-lock 2>/dev/null

echo "[$(date '+%F %T')] keepalive 启动" >> $LOG

while true; do
  if ! pgrep -f 'dsh --profile web' >/dev/null 2>&1; then
    echo "[$(date '+%F %T')] dsh 未运行, 重启" >> $LOG
    (nohup dsh --profile web --host 127.0.0.1 >> ~/.dsh/logs/dsh-web-$(date +%Y%m%d).log 2>&1 &)
  fi
  sleep 15
done
