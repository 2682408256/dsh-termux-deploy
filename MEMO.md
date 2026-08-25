# DSH 容器 ↔ Termux 运维备忘

> 场景：DSH App (proot Ubuntu 容器) 与 Termux 同机共存，容器远程管理 Termux。
> 日期：2026-08-25，全部经验来自实战踩坑。

## 一、核心认知：两个 App 的网络与文件边界

| 维度 | 结论 |
|---|---|
| **网络** | 两个 App **共享手机的 127.0.0.1 回环**！容器里监听的服务，Termux 可以直接访问；反之亦然。这是所有互通方案的地基。 |
| **文件系统** | **完全隔离**。容器看不到 `/data/data/com.termux/`、`/sdcard`；Termux 也看不到容器目录。传文件只能走网络(HTTP/SSH)，不能走文件系统。 |
| **外网** | 容器出网受限(实测 TCP 443 不通)；Termux 出网正常但 GitHub 下载慢(~200KB/s)。 |

## 二、容器 ↔ Termux 互通方案

### 2.1 传文件：容器起 HTTP 服务，Termux curl 下载
```bash
# 容器侧 (任意目录暴露)
cat > /tmp/srv.js <<'EOF'
const http = require('http'), fs = require('fs');
const dir = process.argv[2], port = Number(process.argv[3]);
http.createServer((req,res)=>{
  const p = dir + req.url.split('?')[0];
  try { const st = fs.statSync(p);
    if (st.isFile()) { res.writeHead(200,{'Content-Type':'application/octet-stream'}); fs.createReadStream(p).pipe(res); }
    else { const l = fs.readdirSync(p).map(f=>`<a href="${req.url==='/'?'/':req.url}/${f}">${f}</a>`).join('<br>');
      res.writeHead(200,{'Content-Type':'text/html'}); res.end(l); }
  } catch(e){ res.writeHead(404); res.end('nf'); }
}).listen(port,'127.0.0.1',()=>console.log('on 127.0.0.1:'+port));
EOF
nohup node /tmp/srv.js /path/to/serve 8123 >/tmp/srv.log 2>&1 &
# Termux 侧
curl -s http://127.0.0.1:8123/file -o file
```

### 2.2 远程管理：SSH (推荐, 一劳永逸)
```bash
# Termux 侧 (一次性)
pkg install -y openssh
mkdir -p ~/.ssh && chmod 700 ~/.ssh
# 把容器公钥放进去 (容器生成: ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519)
curl -s http://127.0.0.1:8123/id_ed25519.pub -o ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
sshd -p 8023          # 注意: 用 -p 显式指定端口!
# 容器侧
ssh -p 8023 -i ~/.ssh/id_ed25519 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null u0_a389@127.0.0.1
```

**SSH 踩坑记录 (每条都真实发生过)：**
1. **sshd 默认监听 8022，但会有"僵尸 sshd"占着端口** → 症状：`sshd -ddd` 启动时 `Bind to port 8022 on 0.0.0.0 failed: Address already in use`，连接时 `Permission denied` 但日志里没有任何连接记录（因为连的是僵尸）。解法：**换一个冷门端口(如 8023)**，一了百了。
2. **pkill 杀不干净 sshd** → Termux 的 OpenSSH 10.5 有 `sshd-session` 子进程(名字不同)，`pkill -9 sshd` 杀不死它。要 `pkill -9 sshd; pkill -9 sshd-session`。
3. **`sshd -ddd` 调试模式后台跑会自己退出**（`Exit 255`）→ 确认连通后必须换正式模式 `sshd -p <port>`。
4. **公钥不生效时别急着怀疑配置** → `sshd -T | grep -iE '^port|pubkeyauth|authorized'` 查实际生效配置；`sshd -ddd -p X > log 2>&1 &` 看服务端日志定位。
5. Termux 无 `ss`/`netstat`/`lsof`/`which`/`file`(部分缺失)，用 `/dev/tcp` 测端口: `(echo > /dev/tcp/127.0.0.1/3081) 2>/dev/null && echo OK`。
6. `/proc/net/tcp` 在 Termux 读不了(Permission denied, SELinux)。

## 三、Termux 安装 dsh 的完整踩坑史

### 3.1 正确姿势 (最终验证可行)
```bash
# 0) 必须 F-Droid/GitHub 版 Termux (Play 版无仓库)
pkg install -y python nodejs-lts     # Node 24, 严禁 nodejs(v26)!

# 1) 手动下载离线包 (41MB) —— 不要用 npm i -g <URL>!
curl -fL -o ~/dsh-termux.tgz https://github.com/sunflower2333/dsh-termux/releases/latest/download/dsh-termux.tgz
# 下载慢: 用 nohup 后台下, 别前台等 (200KB/s × 42MB ≈ 3.5min)
# 验证完整性: tar tzf ~/dsh-termux.tgz >/dev/null && echo OK

# 2) 本地安装
npm install -g ~/dsh-termux.tgz

# 3) 验证
dsh --version    # → 0.1.1-rc.2-termux.1

# 4) HMR 补丁: 改真实 bin.js 的 shebang (绝不能用 sed 改符号链接!)
sed -i '1s|^#!/usr/bin/env node|#!/data/data/com.termux/files/usr/bin/node --expose-internals|' \
  /data/data/com.termux/files/usr/lib/node_modules/dsh-termux/lib/bin.js

# 5) 启动 (端口用 3081! 3080 被 DSH App 占用)
nohup dsh --profile web --host 127.0.0.1 --port 3081 > ~/.dsh/logs/dsh-web.log 2>&1 &
# 验证: (echo > /dev/tcp/127.0.0.1/3081) 2>/dev/null && echo OK
```

### 3.2 踩坑清单 (每个都是真实教训)
1. **`npm i -g <URL>` 显示 "up to date in 418ms" 但实际没装上** → npm 11 对 URL 安装的 bug/缓存问题。必须手动下载 tgz 再 `npm install -g 本地文件`。
2. **`sed -i` 会破坏符号链接(大坑!)** → npm 安装的 `dsh` 是 symlink 指向 `lib/bin.js`。`sed -i` 会把链接替换成普通文件，普通文件在 `/usr/bin/` 下找不到同级 node_modules → `ERR_MODULE_NOT_FOUND: Cannot find package '@deepseek-ai/dsh-app-boot'`。**用户最初的报错就是它**。修复：`rm /usr/bin/dsh; ln -s .../lib/bin.js /usr/bin/dsh`，补丁打在真实文件上。
3. **端口冲突** → DSH App 和 Termux 共享回环，3080 被 DSH App 占 → Termux 用 3081。
4. **续传损坏文件** → `curl -C -` 续传后的 tgz `zlib: incorrect header check`。下载中途断了就删掉重下，别续传。
5. **GitHub 慢** → ~200KB/s；后台下载 + 轮询文件大小/tar 完整性。
6. 部分 ROM SELinux 禁 `link(2)` → 会话发布用 rename(2)（离线包已内置补丁）。

## 四、下次快速操作手册

### 连接 Termux
```bash
# 容器侧一键脚本 (已生成)
bash /home/dsh/workspace/dsh-termux/ssh-termux.sh "命令..."   # 执行命令
bash /home/dsh/workspace/dsh-termux/ssh-termux.sh            # 交互 shell
```
Termux sshd 挂了就重启: `sshd -p 8023` (Termux 里)

### 查看 Termux dsh 状态
```bash
bash /home/dsh/workspace/dsh-termux/ssh-termux.sh "pgrep -af 'dsh --profile'; (echo > /dev/tcp/127.0.0.1/3081) 2>/dev/null && echo 3081-OK"
```

### 日志位置
- Termux: `~/.dsh/logs/` (Termux 的 home, 即 /data/data/com.termux/files/home/.dsh/logs/)
- 容器:   `/home/dsh/.dsh/sessions/`

### 当前环境关键参数
- Termux 用户: `u0_a389` | sshd 端口: **8023** | dsh web 端口: **3081**
- 容器 SSH 密钥: `~/.ssh/id_ed25519`
- dsh 版本: 容器 & Termux 均为 `0.1.1-rc.2(-termux.1)`
