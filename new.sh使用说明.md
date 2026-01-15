# new.sh 使用说明

## 概述

`new.sh` 是一个交互式服务器初始化脚本，提供菜单式操作界面，用于自动化配置新的 Linux 服务器（支持 Debian/Ubuntu 系统）。脚本包含 6 个主要配置步骤，可以单独执行或一次性执行全部步骤。

## 系统要求

- **操作系统**: Debian/Ubuntu 或其他使用 APT 包管理器的 Linux 发行版
- **权限要求**: 必须以 root 权限运行
- **网络要求**: 需要稳定的网络连接以下载依赖包和脚本

## 快速开始

### 1. 下载脚本

```bash
wget https://raw.githubusercontent.com/kakakakaka1/init/main/new.sh
chmod +x new.sh
```

### 2. 运行脚本

**交互式菜单模式**（推荐）:
```bash
sudo ./new.sh
```

**直接执行所有步骤**:
```bash
sudo ./new.sh A
```

**执行单个步骤**:
```bash
sudo ./new.sh 1  # 执行步骤1
sudo ./new.sh 5  # 执行步骤5
```

## 功能详解

### 步骤 1: 安装必备软件包

**功能说明**:
- 更新 APT 软件包列表
- 安装基础工具: vim、curl、wget、telnet、iperf3

**执行流程**:
1. 运行 `apt-get update`
2. 安装预定义的软件包列表
3. 验证每个软件包的安装状态

**可能的错误**:
- 网络连接问题
- 软件源配置错误
- DNS 解析失败

---

### 步骤 2: 下载并执行工具脚本

**功能说明**:
- 从 GitHub 下载 `tools.sh` 脚本到 `/root` 目录
- 自动执行该脚本并输入选项 "2"

**脚本来源**:
```
https://raw.githubusercontent.com/kakakakaka1/init/main/tools.sh
```

**执行流程**:
1. 下载 tools.sh 到 /root/tools.sh
2. 添加执行权限
3. 自动输入 "2" 并执行脚本

---

### 步骤 3: sing-box 安装和配置

**功能说明**:
- 在 `/root` 目录下安装和配置 sing-box 代理工具
- 自动添加 Shadowsocks 配置

**执行流程**:
1. 下载 `install.sh` 脚本
2. 执行安装脚本
3. 等待 10 秒确保服务启动
4. 添加 Shadowsocks 配置（端口: 19999）

**默认配置**:
- 端口: 19999
- 密码: MJuNsV7e8onbzyAf7HdF
- 加密方式: aes-128-gcm

**安装位置**:
- 二进制文件: `/usr/local/bin/sing-box`
- 安装脚本: `/root/install.sh`

---

### 步骤 4: Snell 代理安装

**功能说明**:
- 下载并安装 Snell 代理服务
- 自动配置端口和参数

**执行流程**:
1. 下载 snell.sh 到 /root/snell.sh
2. 自动输入预设参数序列: `1 → 1 → 20000 → Enter → Enter → 0`

**默认配置**:
- 端口: 20000
- 其他参数使用默认值

**脚本来源**:
```
https://raw.githubusercontent.com/kakakakaka1/init/refs/heads/main/snell.sh
```

---

### 步骤 5: SSH 安全加固和 Fail2ban 配置

**功能说明**:
这是最重要的安全步骤，包括：
- 修改 SSH 端口为 50000
- 禁用密码登录，仅允许公钥认证
- 配置 Fail2ban 防护
- 设置端口扫描检测

**执行流程**:
1. 备份现有配置到 `/root/ssh_backup_<时间戳>/`
2. 安装 fail2ban 和 openssh-server
3. **交互式输入 SSH 公钥**（重要！）
4. 配置 SSH 服务器
5. 创建 Fail2ban 过滤器
6. 启动 Fail2ban 服务
7. 10秒后自动重启 SSH 服务

**重要配置变更**:

| 配置项 | 原值 | 新值 |
|--------|------|------|
| SSH 端口 | 22 | 50000 |
| 密码登录 | 允许 | 禁止 |
| 公钥认证 | 可选 | 必须 |
| 最大认证尝试 | 6 | 3 |
| TCP 转发 | 允许 | 禁止 |
| X11 转发 | 允许 | 禁止 |

**Fail2ban 防护规则**:
- SSH 防护: 5分钟内失败2次，封禁1小时
- 端口扫描: 1分钟内触发2次，封禁24小时
- 重复违规: 24小时内违规2次，封禁7天

**⚠️ 关键提醒**:
- 执行前请确保已准备好 SSH 公钥
- SSH 服务将在 10 秒后重启
- 新的连接命令: `ssh -p 50000 root@服务器IP`
- **当前连接会断开，请使用新端口重新连接**

---

### 步骤 6: Sub-Store 自动管理配置

**功能说明**:
- 配置 Sub-Store 订阅管理
- 设置自动同步功能
- 添加 `singbox` 命令别名

**执行流程**:
1. 下载管理脚本到 /root/manage_substore_new.sh
2. **交互式输入**:
   - Sub-Store API 地址（可选）
   - 订阅名称（可选）
3. 执行首次同步
4. 添加 `singbox` 别名到 .bashrc

**脚本来源**:
```
https://raw.githubusercontent.com/kakakakaka1/init/main/manage_substore_new.sh
```

**新增命令**:
- `singbox`: 执行 sing-box 并自动管理 Sub-Store 推荐使用singbox来管理233脚本(会自动推送或删除节点到sub-store)
- 也可以手动执行 bash manage_substore_new.sh 会将本地的sing-box和snell创建的或者删除的节点推送到sub-store
- snell 安装后不要动它 如果要重装snell或者多用户后需要手动运行bash manage_substore_new.sh 
- (snell除了第次一安装剩下的不会同步) 使用sing-box 也不会自动同步 使用singbox命令穿件删除节点可以自动同步到substore(做了alias)
---

## 使用场景

### 场景 1: 全新服务器快速配置

```bash
# 下载脚本
wget https://raw.githubusercontent.com/kakakakaka1/init/main/new.sh
chmod +x new.sh

# 执行所有步骤（推荐）
sudo ./new.sh A
```

执行过程中需要交互输入：
- 步骤5: 输入 SSH 公钥
- 步骤6: 输入 Sub-Store API 和订阅名称（可跳过）

### 场景 2: 仅配置 SSH 安全

```bash
sudo ./new.sh 5
```

### 场景 3: 单独安装代理工具

```bash
# 仅安装 sing-box
sudo ./new.sh 3

# 仅安装 Snell
sudo ./new.sh 4
```

### 场景 4: 交互式逐步执行

```bash
sudo ./new.sh
# 在菜单中选择 1-6 或 A
```

## 交互式菜单说明

运行 `./new.sh` 会显示以下菜单:

```
============================================
          初始化脚本执行菜单
============================================
1. 步骤 1: 使用 APT 安装必备软件包
2. 步骤 2: 下载并执行外部工具脚本
3. 步骤 3: 执行 sing-box 安装和配置
4. 步骤 4: 下载并执行 snell.sh 脚本
5. 步骤 5: SSH安全加固和Fail2ban配置
6. 步骤 6: 配置 Sub-Store 自动管理
A. 执行全部步骤（默认）
Q. 退出
============================================
```

**操作说明**:
- 直接按 Enter: 执行所有步骤 (等同于选择 A)
- 输入 1-6: 执行对应单个步骤
- 输入 A 或 a: 执行所有步骤
- 输入 Q 或 q: 退出脚本

## 执行摘要示例

执行所有步骤后会显示摘要:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 执行摘要
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
总执行时间: 5分32秒
状态: ✅ 所有步骤执行成功
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## 故障排除

### 问题 1: 权限不足

**错误信息**:
```
错误：此脚本需要以 root 权限运行。
```

**解决方法**:
```bash
sudo ./new.sh
```

### 问题 2: 下载失败

**可能原因**:
- 网络连接问题
- GitHub 访问受限
- DNS 解析失败

**解决方法**:
1. 检查网络连接: `ping -c 3 github.com`
2. 配置代理（如需要）
3. 检查 DNS 设置: `cat /etc/resolv.conf`

### 问题 3: SSH 端口修改后无法连接

**症状**: 执行步骤 5 后无法通过原端口连接

**解决方法**:
```bash
# 使用新端口连接
ssh -p 50000 root@服务器IP

# 如果有多个 SSH 密钥，指定密钥文件
ssh -p 50000 -i ~/.ssh/your_key root@服务器IP
```

### 问题 4: 步骤执行失败

**处理方式**:
- 脚本会询问是否继续或退出
- 可以跳过失败的步骤继续执行
- 失败步骤会在执行摘要中列出

## 安全注意事项

### 1. SSH 公钥准备

**步骤 5 执行前必须准备好 SSH 公钥**，否则配置完成后将无法登录服务器！

**生成 SSH 公钥**（在本地机器执行）:
```bash
ssh-keygen -t ed25519 -C "your_email@example.com"
cat ~/.ssh/id_ed25519.pub
```

复制输出的公钥内容，在步骤 5 中粘贴。

### 2. 备份重要配置

脚本会自动备份 SSH 配置到:
```
/root/ssh_backup_<时间戳>/
```

### 3. 默认密码安全

步骤 3 中的 Shadowsocks 密码是硬编码的，建议执行后手动修改:
```bash
/usr/local/bin/sing-box modify <配置项>
```

### 4. 防火墙配置

如果服务器有防火墙（如 ufw、iptables），需要手动开放端口:
```bash
# 开放 SSH 新端口
ufw allow 50000/tcp

# 开放 sing-box 端口
ufw allow 19999/tcp

# 开放 Snell 端口
ufw allow 20000/tcp
```

## 文件位置说明

### 下载的脚本

| 脚本名称 | 位置 | 说明 |
|---------|------|------|
| tools.sh | /root/tools.sh | 步骤2下载 |
| install.sh | /root/install.sh | 步骤3下载 |
| snell.sh | /root/snell.sh | 步骤4下载 |
| manage_substore_new.sh | /root/manage_substore_new.sh | 步骤6下载 |

### 配置文件

| 配置文件 | 位置 |
|---------|------|
| SSH 配置 | /etc/ssh/sshd_config |
| Fail2ban 主配置 | /etc/fail2ban/jail.local |
| SSH 过滤器 | /etc/fail2ban/filter.d/sshd-aggressive.conf |
| 端口扫描过滤器 | /etc/fail2ban/filter.d/port-scan.conf |
| SSH 公钥 | /root/.ssh/authorized_keys |

### 备份文件

| 备份内容 | 位置 |
|---------|------|
| SSH 配置备份 | /root/ssh_backup_<时间戳>/ |

## 常见问题 (FAQ)

### Q1: 可以在生产服务器上运行吗？

**A**: 建议先在测试环境验证，特别是步骤 5（SSH 配置）可能导致现有连接中断。

### Q2: 可以自定义端口号吗？

**A**: 目前端口号是硬编码的，需要修改脚本源码：
- SSH 端口: 第 212 行 `SSH_PORT=50000`
- Shadowsocks 端口: 第 144 行
- Snell 端口: 第 173 行

### Q3: 执行失败后可以重新执行吗？

**A**: 可以，每个步骤都是幂等的（可重复执行）。但注意：
- 步骤 5 会重新生成配置文件
- 重复执行会覆盖之前的自定义修改

### Q4: 如何卸载？

脚本不提供卸载功能，需要手动清理：

```bash
# 删除下载的脚本
rm -f /root/tools.sh /root/install.sh /root/snell.sh /root/manage_substore_new.sh

# 恢复 SSH 配置（如果有备份）
cp /root/ssh_backup_*/sshd_config.backup /etc/ssh/sshd_config
systemctl restart ssh

# 卸载 fail2ban
apt-get remove --purge fail2ban

# 删除 sing-box 和 snell（根据实际安装方式）
# ...
```

### Q5: 支持哪些 Linux 发行版？

**A**: 理论上支持所有基于 Debian 的发行版：
- Ubuntu 18.04+
- Debian 10+
- Linux Mint
- Deepin

不支持 CentOS、Fedora、Arch 等非 APT 系统。

## 进阶使用

### 修改默认参数

编辑脚本，修改以下变量:

```bash
# 步骤 1: 软件包列表
PACKAGES_TO_INSTALL="vim curl wget telnet iperf3"

# 步骤 3: Shadowsocks 配置
/usr/local/bin/sing-box add ss 19999 MJuNsV7e8onbzyAf7HdF aes-128-gcm

# 步骤 4: Snell 输入序列
SNELL_SCRIPT_INPUT_SEQUENCE="1\n1\n20000\n\n\n0\n"

# 步骤 5: SSH 端口
SSH_PORT=50000
```

### 添加自定义步骤

在脚本中添加新函数:

```bash
step7_custom() {
    echo "===== 步骤 7: 自定义步骤 ====="
    # 你的代码
    return 0
}
```

然后在菜单和执行函数中添加对应逻辑。

## 更新日志

- **最新版本**: 适用于菜单式交互执行
- 包含 6 个主要配置步骤
- 支持命令行参数直接执行
- 提供详细的错误处理和状态提示

## 获取帮助

- **GitHub 仓库**: https://github.com/kakakakaka1/init
- **问题反馈**: 提交 GitHub Issue
- **脚本更新**: 定期检查仓库获取最新版本

## 许可证

请参考原仓库的许可证说明。

---

**最后更新**: 2026-01-15
