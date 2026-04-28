# wdog

轻量级进程监控告警服务。独立于任何业务项目，可复用。

## 功能

- 定时检测注册进程是否存活（基于 `pgrep -f`，与运行方式无关）
- 进程挂了 → 发送邮件告警（Resend API）
- 同一进程 24 小时内只告警一次，避免重复通知
- 系统进程黑名单，注册时自动警告
- systemd 托管，守护进程挂了自动拉起，开机自启

## 安装

一键安装：

```bash
curl -sL https://raw.githubusercontent.com/timshuang/wdog/main/install.sh | sudo bash
```

或克隆后安装：

```bash
git clone https://github.com/<user>/wdog.git
cd wdog
sudo bash install.sh
```

安装过程会交互式引导输入：

| 输入项 | 校验规则 |
|--------|---------|
| Resend API Key | 必须以 `re_` 开头 |
| 告警邮箱 | 合法邮箱格式 |
| 检查间隔 | 1-1440 正整数（分钟） |

安装完成后 wdog 守护进程自动启动并注册开机自启。

## 命令

### wdog -h

显示帮助信息。

### wdog reg \<name\> [-m \<pattern\>]

注册进程监控。重复注册则覆盖更新。

| 参数 | 说明 |
|------|------|
| `name` | 进程标识名，用于显示和默认匹配 |
| `-m <pattern>` | pgrep -f 匹配模式，不传则默认等于 name |

```bash
# 注册 keepalive，默认用 "keepalive" 做 pgrep 匹配
wdog reg keepalive

# 注册 myapp，用精确匹配模式
wdog reg myapp -m "node /opt/myapp/index.js"

# 注册时碰到系统进程会警告确认
wdog reg sshd
# ⚠ "sshd" appears to be a system process. Are you sure? [y/N]
```

### wdog unreg \<name\>

解除注册。进程不存在于注册表时静默退出。

```bash
wdog unreg keepalive
```

### wdog setmail \<email\> \<resend_api_key\>

配置告警邮件。重复设置则覆盖。

```bash
wdog setmail admin@example.com re_xxxxxxxxx
```

### wdog interval \<minutes\>

设置检查间隔，1-1440 正整数（分钟）。重复设置则覆盖。

```bash
wdog interval 5
```

### wdog list

查看注册列表及各进程实时状态。

```bash
$ wdog list
Name                 Match                          Status   Last Alert
----                 -----                          ------   -----------
keepalive            keepalive                      ALIVE    -
myapp                node /opt/myapp/index.js       DEAD     2026-04-28T10:05:00+08:00

Interval: 5 min | Alert email: admin@example.com
```

### wdog daemon

启动守护循环。由 systemd 调用，一般不需要手动执行。

## 服务管理

```bash
systemctl start wdog      # 启动
systemctl stop wdog       # 停止
systemctl restart wdog    # 重启
systemctl status wdog     # 查看状态
systemctl enable wdog     # 开机自启
systemctl disable wdog    # 取消开机自启
```

修改 service 文件后需要：

```bash
sudo systemctl daemon-reload
sudo systemctl restart wdog
```

## 卸载

```bash
sudo bash uninstall.sh
```

会删除 `/opt/wdog`、`/etc/wdog`、systemd service、软链接、日志和 pidfile。

## 文件

| 路径 | 说明 |
|------|------|
| `/opt/wdog/bin/wdog` | 主程序 |
| `/etc/wdog/config.json` | 全局配置（邮件、检查间隔） |
| `/etc/wdog/regs.json` | 进程注册表 |
| `/var/log/wdog.log` | 日志 |
| `/var/run/wdog.pid` | PID 文件（防多实例） |
| `/usr/local/bin/wdog` | 软链接 |

## 告警机制

- 检测到进程挂了 → 通过 Resend HTTP API 发送邮件
- 开发阶段 from 地址为 `wdog <onboarding@resend.dev>`，只能发给 Resend 注册邮箱
- 绑定自定义域名后可发给任意邮箱（在 resend.com 后台配置）
- 同一进程 24 小时告警冷却期，避免重复通知

## 依赖

- `jq`（JSON 解析，安装脚本自动安装）
- `curl`（调用 Resend API，一般系统自带）
- `systemd`（守护进程管理）
