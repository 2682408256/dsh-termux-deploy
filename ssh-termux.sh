#!/usr/bin/env bash
# =============================================================================
# 一键连接 Termux (DSH 容器侧使用)
# -----------------------------------------------------------------------------
# 前置:  Termux 里 sshd 已在运行 (Termux: sshd -p 8023)
# 用法:
#   bash ssh-termux.sh <命令...>   # 执行单条命令
#   bash ssh-termux.sh             # 进入交互式 shell
# 示例:
#   bash ssh-termux.sh "dsh --version"
#   bash ssh-termux.sh "tail -20 ~/.dsh/logs/dsh-web-*.log"
# =============================================================================
set -uo pipefail

TERMUX_USER="u0_a389"
TERMUX_HOST="127.0.0.1"
TERMUX_PORT="${TERMUX_SSH_PORT:-8023}"
KEY="${HOME}/.ssh/id_ed25519"

SSH_ARGS=(-p "$TERMUX_PORT" -i "$KEY"
  -o StrictHostKeyChecking=no
  -o UserKnownHostsFile=/dev/null
  -o ConnectTimeout=8
  -o ServerAliveInterval=10
  -o ServerAliveCountMax=3)

if [ "$#" -eq 0 ]; then
  # 交互式 shell
  exec ssh "${SSH_ARGS[@]}" "${TERMUX_USER}@${TERMUX_HOST}"
else
  # 执行命令
  exec ssh "${SSH_ARGS[@]}" "${TERMUX_USER}@${TERMUX_HOST}" "$@"
fi
