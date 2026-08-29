---
name: github-push
description: Push local repositories to the user's GitHub account 2682408256 (yangkk) over SSH. Documents the registered SSH key, the hermes-phone repo, and the critical /root/.ssh vs $HOME mismatch gotcha. Use whenever asked to commit and push code to GitHub for this account.
whenToUse: When the user asks to push code/experiences to GitHub, create a GitHub repository commit, or otherwise interact with their GitHub account 2682408256.
---

# GitHub SSH 推送（账号 2682408256 / yangkk）

## 账号与仓库

- GitHub 账号: `2682408256`（显示名 yangkk）
- 已推送仓库: `hermes-phone` → `git@github.com:2682408256/hermes-phone.git`（公开）
- 本地工程: `/home/dsh/workspace/hermes-phone`（git 工作树，main 分支）

## SSH key（已注册到该账号）

- 私钥: `/root/.ssh/id_ed25519`（权限 600）
- 公钥: `/root/.ssh/id_ed25519.pub`（权限 644）
- 公钥内容: `ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB16Sm6IEVBdwR0HTNFmAFZCihG7+IZxiz3W++DZqYfn dsh-container`
- 指纹: `SHA256:0AV9w+qjhw8yD+OWQpkt/nr6BHi8RYbhqMratqWkmW4`
- 验证命令: `ssh -T git@github.com` → 应输出 `Hi 2682408256!`

## ⚠️ 关键坑：HOME 不一致

- bash 工具环境的 `$HOME=/home/dsh`，但 ssh/git 以 passwd 为准，默认在 `/root/.ssh` 找 key
- key 必须存在于 `/root/.ssh/` 才能免 `-i` 直连（已就位）
- 若 `/root/.ssh` 丢失而 `/home/dsh/.ssh` 有副本：`cp /home/dsh/.ssh/id_ed25519* /root/.ssh/` 后 `chmod 600` 私钥、`chmod 644` 公钥
- 备用方案：`GIT_SSH_COMMAND="ssh -i /home/dsh/.ssh/id_ed25519" git push ...`

## 推送流程

```bash
cd /home/dsh/workspace/hermes-phone
git add -A
git commit -m "描述性提交信息"
git push origin main
```

## 历史教训（勿重蹈）

- 该账号的 fine-grained PAT 曾推送失败（`403 Resource not accessible by personal access token`）：
  GitHub 创建页/API 显示的读写权限 ≠ token 实际生效的 Contents 权限，PAT 路线已弃用，一律走 SSH
- 用户名含纯数字（2682408256），拼 URL 时别漏
