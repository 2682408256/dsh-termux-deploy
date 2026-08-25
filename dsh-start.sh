#!/usr/bin/env bash
# dsh 一键拉起: sshd + dsh 守护(自动带起 dsh web) + wake-lock
set -uo pipefail

echo '==> 1/4 wake-lock'
termux-wake-lock 2>/dev/null && echo '    ✓ 已获取' || echo '    ! 跳过'

echo '==> 2/4 sshd (8023)'
pkill -f 'sshd -p 8023' 2>/dev/null; sleep 1
sshd -p 8023 2>/dev/null
pgrep -f 'sshd -p 8023' >/dev/null 2>&1 && echo '    ✓ sshd 运行' || echo '    ! sshd 失败'

echo '==> 3/4 守护脚本'
pkill -f 'dsh-keepalive' 2>/dev/null; pkill -f 'dsh --profile' 2>/dev/null
sleep 1
cd ~
# 用 setsid + 重定向 stdin 完全脱离会话, 避免被 SSH 断开带走
setsid ./dsh-keepalive.sh < /dev/null >> ~/.dsh/logs/keepalive.log 2>&1 &
disown 2>/dev/null || true
sleep 2
pgrep -f 'dsh-keepalive' >/dev/null 2>&1 && echo '    ✓ 守护运行' || echo '    ! 守护失败'

echo '==> 4/4 等待 dsh (约 20 秒)'
sleep 20
pgrep -f 'dsh --profile web' >/dev/null 2>&1 && echo '    ✓ dsh 运行' || echo '    ! dsh 未起'
(echo > /dev/tcp/127.0.0.1/3081) 2>/dev/null && echo '    ✓ 3081 可达 → http://127.0.0.1:3081' || echo '    ! 3081 不可达'
echo '完成.'
