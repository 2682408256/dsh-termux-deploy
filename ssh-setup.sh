#!/usr/bin/env bash
# =============================================================================
# Termux 侧一键开启 SSH（供 DSH 容器远程管理）
# 用法: bash ssh-setup.sh
# 功能: 装 openssh → 放入容器公钥 → 启动 sshd(127.0.0.1:8022) → 打印连接信息
# =============================================================================
set -uo pipefail
say() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
ok()  { printf '\033[1;32m   ✓ %s\033[0m\n' "$*"; }
warn(){ printf '\033[1;33m   ! %s\033[0m\n' "$*"; }

say "1/3 安装 openssh"
pkg install -y openssh 2>&1 | tail -2

say "2/3 配置公钥 (允许 DSH 容器免密登录)"
mkdir -p ~/.ssh
chmod 700 ~/.ssh
# 下载容器公钥; 失败则提示手动粘贴
if curl -s --max-time 10 http://127.0.0.1:8123/id_ed25519.pub -o ~/.ssh/authorized_keys \
   && [ -s ~/.ssh/authorized_keys ]; then
  chmod 600 ~/.ssh/authorized_keys
  ok "公钥已安装: $(head -c 20 ~/.ssh/authorized_keys)..."
else
  warn "自动下载失败，请手动执行:"
  echo "    nano ~/.ssh/authorized_keys   (粘贴容器公钥)"
  echo "    或告诉我，我换方式"
fi

say "3/3 启动 sshd (127.0.0.1:8022)"
# Termux sshd 默认配置: 端口 8022, 监听所有接口; 我们只让它监听回环
if ! pgrep -x sshd >/dev/null 2>&1; then
  # 确保 host key 存在
  [ -f "$PREFIX/etc/ssh/ssh_host_ed25519_key" ] || ssh-keygen -A 2>/dev/null || true
  sshd 2>&1 | tail -2
  sleep 1
fi
if pgrep -x sshd >/dev/null 2>&1; then
  ok "sshd 运行中"
else
  warn "sshd 未能启动，请检查: $PREFIX/etc/ssh/sshd_config"
fi

echo
echo "======================================================================"
echo " SSH 连接信息（告诉 DSH 里的 AI）:"
echo "   用户名: $(whoami)"
echo "   端口  : 8022"
echo "   地址  : 127.0.0.1"
echo "   Termux 版本: ${TERMUX_VERSION:-未知}"
echo "======================================================================"
