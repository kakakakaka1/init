#!/bin/bash

# ==============================================================================
# 初始化脚本 - 菜单式执行
# ==============================================================================

# 检查是否以 root 权限运行
if [ "$(id -u)" -ne 0 ]; then
    echo "错误：此脚本需要以 root 权限运行。"
    echo "请使用 sudo $0 来执行。"
    exit 1
fi

# ==============================================================================
# 函数定义
# ==============================================================================

# 步骤 1: 使用 APT 安装必备软件包
step1_install_packages() {
    echo ""
    echo "===== 步骤 1: 使用 APT 安装必备软件包 ====="
    echo "注意：此脚本假定当前系统使用 APT 包管理器 (例如 Debian, Ubuntu)。"

    # 预设要安装的软件包列表
    PACKAGES_TO_INSTALL="vim curl wget telnet iperf3"
    echo "将要安装的软件包: $PACKAGES_TO_INSTALL"
    echo # 空行

    # 更新软件包列表 (apt-get update)
    echo "正在更新软件包列表 (apt-get update)..."
    if ! apt-get update -qq; then
        echo "错误：软件包列表更新失败 (apt-get update)。"
        echo "请检查网络连接、软件源配置 (/etc/apt/sources.list 等) 以及DNS设置。"
        return 1
    fi
    echo "软件包列表更新成功。"
    echo # 空行

    # 安装软件包 (apt-get install)
    echo "正在安装软件包：$PACKAGES_TO_INSTALL ..."
    if ! DEBIAN_FRONTEND=noninteractive apt-get install -y $PACKAGES_TO_INSTALL; then
        echo "错误：软件包安装命令 (apt-get install) 执行失败。"
        UNINSTALLED_PKGS=""
        for pkg in $PACKAGES_TO_INSTALL; do
            if ! dpkg -s "$pkg" &> /dev/null; then
                UNINSTALLED_PKGS="$UNINSTALLED_PKGS $pkg"
            fi
        done
        if [ -n "$UNINSTALLED_PKGS" ]; then
            echo "以下软件包可能未能成功安装: $UNINSTALLED_PKGS"
        fi
        echo "===== 步骤 1 失败：软件包安装过程中发生错误。 ====="
        return 1
    fi
    echo "软件包安装命令已成功执行。"
    echo # 空行

    # 验证已安装的软件包
    echo "正在验证已安装的软件包..."
    ALL_PACKAGES_VERIFIED=true
    MISSING_PACKAGES_AFTER_INSTALL=""
    for pkg in $PACKAGES_TO_INSTALL; do
        if ! dpkg -s "$pkg" &> /dev/null; then
            echo "警告：软件包 '$pkg' 在安装后未能通过 dpkg -s 验证。"
            MISSING_PACKAGES_AFTER_INSTALL="$MISSING_PACKAGES_AFTER_INSTALL $pkg"
            ALL_PACKAGES_VERIFIED=false
        fi
    done

    if $ALL_PACKAGES_VERIFIED; then
        echo "所有预定软件包 ($PACKAGES_TO_INSTALL) 已成功安装并验证。"
        echo "===== 步骤 1 完成。 ====="
    else
        echo "警告：以下软件包在安装命令成功后未能通过验证: $MISSING_PACKAGES_AFTER_INSTALL"
        echo "===== 步骤 1 完成，但有警告。 ====="
    fi
    return 0
}

# 步骤 2: 下载并执行外部工具脚本 (tools.sh) 至 /root 目录
step2_tools_script() {
    echo ""
    echo "===== 步骤 2: 下载并执行外部工具脚本 (tools.sh) 至 /root 目录 ====="

    TOOLS_SCRIPT_URL="https://raw.githubusercontent.com/kakakakaka1/init/main/tools.sh"
    TOOLS_SCRIPT_FILENAME="tools.sh"
    TOOLS_SCRIPT_LOCAL_PATH="/root/${TOOLS_SCRIPT_FILENAME}"
    TOOLS_SCRIPT_INPUT="2"

    echo "正在从 $TOOLS_SCRIPT_URL 下载脚本 '$TOOLS_SCRIPT_FILENAME' 到 $TOOLS_SCRIPT_LOCAL_PATH ..."
    if ! wget -q -O "$TOOLS_SCRIPT_LOCAL_PATH" "$TOOLS_SCRIPT_URL"; then
        echo "错误：下载脚本 '$TOOLS_SCRIPT_FILENAME' 失败。"
        echo "请检查网络连接、URL是否正确，以及确保对 /root 目录有写入权限。"
        return 1
    fi
    echo "脚本 '$TOOLS_SCRIPT_FILENAME' 下载成功。"
    echo # 空行

    echo "正在为脚本 $TOOLS_SCRIPT_LOCAL_PATH 添加执行权限..."
    if ! chmod +x "$TOOLS_SCRIPT_LOCAL_PATH"; then
        echo "错误：为脚本 $TOOLS_SCRIPT_LOCAL_PATH 添加执行权限失败。"
        return 1
    fi
    echo "执行权限添加成功。"
    echo # 空行

    echo "正在执行脚本 $TOOLS_SCRIPT_LOCAL_PATH 并自动输入 '$TOOLS_SCRIPT_INPUT'..."
    if printf "%s\n" "$TOOLS_SCRIPT_INPUT" | "$TOOLS_SCRIPT_LOCAL_PATH"; then
        echo "脚本 $TOOLS_SCRIPT_LOCAL_PATH 已成功执行。"
    else
        echo "错误：脚本 $TOOLS_SCRIPT_LOCAL_PATH 执行过程中失败或返回了错误状态码 $? 。"
        return 1
    fi
    echo # 空行
    echo "脚本 $TOOLS_SCRIPT_LOCAL_PATH 已执行完毕，并保留在原位置。"
    echo "===== 步骤 2 完成。 ====="
    return 0
}

# 步骤 3: 用户提供的脚本内容 (在 /root 目录下执行)
step3_singbox_install() {
    echo ""
    echo "===== 步骤 3: 执行用户指定的 sing-box 安装和配置脚本 (在 /root 目录运行) ====="

    # 将用户提供的脚本包裹在子 shell 中，并首先切换到 /root 目录
    (
        cd /root || { echo "严重错误：无法切换到 /root 目录以执行步骤 3。"; exit 1; }
        echo "当前工作目录已切换到: $(pwd) (应为 /root)"
        echo "开始执行用户提供的步骤 3 脚本内容..."

        # 下载并准备 install.sh（使用我们修改后的版本，包含自动同步功能）
        wget https://raw.githubusercontent.com/kakakakaka1/init/main/install.sh
        chmod +x install.sh

        # 执行安装脚本
        ./install.sh

        # 等待一段时间，让 sing-box 服务有更充足的时间启动和初始化
        echo "等待 10 秒，确保 sing-box 服务启动..."
        sleep 10

        # 使用 sing-box 的完整路径执行 add 命令
        echo "尝试添加 Shadowsocks 配置..."
        if /usr/local/bin/sing-box add ss 19999 MJuNsV7e8onbzyAf7HdF aes-128-gcm; then
            echo "Shadowsocks 配置添加成功。"
            echo "ok"
        else
            echo "错误：添加 Shadowsocks 配置失败。"
        fi
    )

    # 检查子shell的退出状态
    STEP3_EXIT_CODE=$?
    if [ $STEP3_EXIT_CODE -ne 0 ]; then
        echo "错误：步骤 3 (用户指定脚本) 执行失败，退出状态码: $STEP3_EXIT_CODE。"
        return $STEP3_EXIT_CODE
    fi

    echo "用户指定的步骤 3 已执行。下载的 install.sh (位于/root/install.sh) 保留在原位置。"
    echo "===== 步骤 3 完成。 ====="
    return 0
}

# 步骤 4: 下载并执行 snell.sh 脚本
step4_snell_install() {
    echo ""
    echo "===== 步骤 4: 下载并执行 snell.sh 脚本 ====="

    SNELL_SCRIPT_URL="https://raw.githubusercontent.com/kakakakaka1/init/refs/heads/main/snell.sh"
    SNELL_SCRIPT_FILENAME="snell.sh"
    SNELL_SCRIPT_LOCAL_PATH="/root/${SNELL_SCRIPT_FILENAME}"
    # 预设输入：先输入 "1" 然后回车，然后再输入1回车 再输入 "20000" 然后回车，然后回车，然后回车，最后输入 "0" 然后回车
    SNELL_SCRIPT_INPUT_SEQUENCE="1\n1\n20000\n\n\n0\n"

    echo "正在从 $SNELL_SCRIPT_URL 下载脚本 '$SNELL_SCRIPT_FILENAME' 到 $SNELL_SCRIPT_LOCAL_PATH ..."
    if ! wget -q -O "$SNELL_SCRIPT_LOCAL_PATH" "$SNELL_SCRIPT_URL"; then
        echo "错误：下载脚本 '$SNELL_SCRIPT_FILENAME' 失败。"
        echo "请检查网络连接或 URL 是否正确。"
        return 1
    fi
    echo "脚本 '$SNELL_SCRIPT_FILENAME' 下载成功。"
    echo # 空行

    echo "正在为脚本 $SNELL_SCRIPT_LOCAL_PATH 添加执行权限..."
    if ! chmod +x "$SNELL_SCRIPT_LOCAL_PATH"; then
        echo "错误：为脚本 $SNELL_SCRIPT_LOCAL_PATH 添加执行权限失败。"
        return 1
    fi
    echo "执行权限添加成功。"
    echo # 空行

    echo "正在执行脚本 $SNELL_SCRIPT_LOCAL_PATH 并自动输入预设序列 ('1' -> '1' -> '20000' -> Enter -> Enter -> '0')..."
    if printf "%b" "$SNELL_SCRIPT_INPUT_SEQUENCE" | "$SNELL_SCRIPT_LOCAL_PATH"; then
        echo "脚本 $SNELL_SCRIPT_LOCAL_PATH 已成功执行 (根据其最终退出状态)。"
    else
        SNELL_EXEC_EXIT_CODE=$?
        echo "错误：脚本 $SNELL_SCRIPT_LOCAL_PATH 执行过程中失败或返回了错误状态码 $SNELL_EXEC_EXIT_CODE 。"
        return $SNELL_EXEC_EXIT_CODE
    fi
    echo # 空行
    echo "脚本 $SNELL_SCRIPT_LOCAL_PATH 已执行完毕，并保留在原位置 (/root/${SNELL_SCRIPT_FILENAME})。"
    echo "===== 步骤 4 完成。 ====="
    return 0
}

# 步骤 5: SSH安全加固和Fail2ban配置
step5_ssh_hardening() {
    echo ""
    echo "===== 步骤 5: SSH安全加固和Fail2ban配置 ====="

    # SSH安全配置参数
    SSH_PORT=50000
    BACKUP_DIR="/root/ssh_backup_$(date +%Y%m%d_%H%M%S)"

    # 创建备份目录
    echo "正在创建备份目录: $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"

    # 备份现有配置
    if [[ -f /etc/ssh/sshd_config ]]; then
        cp /etc/ssh/sshd_config "$BACKUP_DIR/sshd_config.backup"
        echo "SSH配置已备份"
    fi

    if [[ -f /etc/fail2ban/jail.local ]]; then
        cp /etc/fail2ban/jail.local "$BACKUP_DIR/jail.local.backup"
        echo "Fail2ban配置已备份"
    fi

    # 安装fail2ban和openssh-server
    echo "正在安装fail2ban和openssh-server..."
    if ! DEBIAN_FRONTEND=noninteractive apt-get install -y fail2ban openssh-server; then
        echo "错误：fail2ban和openssh-server安装失败"
        return 1
    fi
    echo "fail2ban和openssh-server安装成功"

    # 设置SSH公钥
    echo "正在设置SSH公钥..."
    mkdir -p /root/.ssh
    chmod 700 /root/.ssh
    echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC2CNY7JG7dO3JVB0sCIfKJTtJH2F3JJ8pnv0Vh4TTUR6eY1UWOJx1PGU120tUu1Xt/UnSh4m/6phWEGqVBWemYhWF1pGbhzRBpbX99b/4Xd5o291ZBVNh6Hp5QCO424J4bOxA28CcmvwaHTf5MHaa4zsLtfZB7uE6kcuuL4I00EdsBWHH888CAtXv1MgfgCLAxiP5E5m1PnTE+tfZl9wRFRK99lBfi0BgSQH4dBtu8cDUCz7MPGDznbfOapSDRoWrKMQ1SQ2lE28EtpJvWzUJvJjhn79McbeKowpyIFMJhZGsp61b8K3GZIOjJte7N5B8XLoRfrKE5pbv/tXyK7b5l" > /root/.ssh/authorized_keys
    chmod 600 /root/.ssh/authorized_keys
    echo "SSH公钥已添加到authorized_keys"

    # 配置SSH
    echo "正在配置SSH服务器 (端口: $SSH_PORT)..."
    cat > /etc/ssh/sshd_config << 'SSHEOF'
# SSH Security Hardening Configuration
# Generated by init.sh SSH hardening step

Include /etc/ssh/sshd_config.d/*.conf

# Network
Port 50000
AddressFamily any
ListenAddress 0.0.0.0
ListenAddress ::

# Host Keys
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key
HostKey /etc/ssh/ssh_host_ed25519_key

# Ciphers and keying
RekeyLimit default none

# Logging
SyslogFacility AUTH
LogLevel VERBOSE

# Authentication
LoginGraceTime 60
PermitRootLogin prohibit-password
StrictModes yes
MaxAuthTries 3
MaxSessions 10

PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys

# Password authentication (DISABLED)
PasswordAuthentication no
PermitEmptyPasswords no
KbdInteractiveAuthentication no

# Kerberos options
KerberosAuthentication no

# GSSAPI options
GSSAPIAuthentication no

# PAM
UsePAM yes

# Network options
AllowAgentForwarding yes
AllowTcpForwarding yes
GatewayPorts no
X11Forwarding no
PermitTTY yes
PrintMotd no
TCPKeepAlive yes
PermitUserEnvironment no
Compression delayed
ClientAliveInterval 300
ClientAliveCountMax 2
UseDNS no
PidFile /run/sshd.pid
MaxStartups 10:30:100
PermitTunnel no

# Locale
AcceptEnv LANG LC_*

# Subsystem
Subsystem sftp /usr/lib/openssh/sftp-server
SSHEOF

    echo "SSH配置已更新"

    # 创建fail2ban过滤器
    echo "正在创建fail2ban过滤器..."
    cat > /etc/fail2ban/filter.d/sshd-aggressive.conf << 'F2BFILTER1EOF'
# Enhanced SSH filter for aggressive protection
[INCLUDES]
before = common.conf

[Definition]

_daemon = sshd

# Aggressive SSH attack patterns - simplified
failregex = ^.*sshd.*authentication failure.*rhost=<HOST>.*$
            ^.*sshd.*Failed password for .* from <HOST>.*$
            ^.*sshd.*Failed password for invalid user .* from <HOST>.*$
            ^.*sshd.*Invalid user .* from <HOST>.*$
            ^.*sshd.*Connection closed by <HOST> port.*\[preauth\]$
            ^.*sshd.*Did not receive identification string from <HOST>.*$
            ^.*sshd.*Bad protocol version identification .* from <HOST>.*$
            ^.*sshd.*error: kex_exchange_identification.*<HOST>.*$
            ^.*sshd.*Connection reset by <HOST> port.*$

ignoreregex =
F2BFILTER1EOF

    cat > /etc/fail2ban/filter.d/port-scan.conf << 'F2BFILTER2EOF'
# Fail2Ban filter for port scanning detection
[Definition]
# Detect connection attempts and port scans

# Match SSH-specific scanning patterns only
failregex = ^.*sshd.*: error: kex_exchange_identification: Connection closed by remote host <HOST>.*$
            ^.*sshd.*: Did not receive identification string from <HOST>.*$
            ^.*sshd.*: Bad protocol version identification.*from <HOST>.*$

# Ignore local connections
ignoreregex = ^.*127\.0\.0\.1.*$
              ^.*::1.*$
F2BFILTER2EOF

    echo "Fail2ban过滤器已创建"

    # 配置fail2ban
    echo "正在配置fail2ban..."
    cat > /etc/fail2ban/jail.local << 'F2BJAILEOF'
# Aggressive SSH protection and port scan detection
# Generated by init.sh SSH hardening step

[DEFAULT]
bantime = 360000
findtime = 60000
maxretry = 3
backend = systemd

[sshd]
enabled = true
port = 50000
filter = sshd-aggressive
logpath = /var/log/auth.log
backend = systemd
maxretry = 2
findtime = 315360000
bantime = -1
ignoreip = 127.0.0.1/8 ::1

[port-scan]
enabled = true
port = all
filter = port-scan
logpath = /var/log/auth.log
backend = systemd
maxretry = 2
findtime = 315360000
bantime = -1
ignoreip = 127.0.0.1/8 ::1

[recidive]
enabled = true
filter = recidive
logpath = /var/log/fail2ban.log
bantime = 604800
findtime = 86400
maxretry = 2
ignoreip = 127.0.0.1/8 ::1
F2BJAILEOF

    echo "Fail2ban配置已更新"

    # 测试SSH配置
    echo "正在测试SSH配置..."
    if ! sshd -t; then
        echo "错误：SSH配置测试失败"
        return 1
    fi
    echo "SSH配置测试通过"

    # 启动fail2ban服务（先启动，避免SSH重启时中断）
    echo "正在启动fail2ban服务..."
    systemctl enable fail2ban
    if ! systemctl restart fail2ban; then
        echo "错误：fail2ban服务启动失败"
        return 1
    fi
    echo "fail2ban服务已启动"

    # 重启SSH服务 - 使用延迟重启避免立即断开连接
    echo ""
    echo "============================================"
    echo "⚠️  重要提示：即将重启 SSH 服务"
    echo "============================================"
    echo "SSH 端口已更改为: $SSH_PORT"
    echo "新的连接命令: ssh -p $SSH_PORT root@<服务器IP>"
    echo ""
    echo "当前 SSH 连接将在 10 秒后断开。"
    echo "请准备好使用新端口重新连接。"
    echo "============================================"

    # 使用 at 命令延迟重启（如果可用）
    if command -v at &> /dev/null; then
        echo "使用延迟重启方式（10秒后）..."
        echo "systemctl restart ssh" | at now + 10 seconds 2>/dev/null
        echo "SSH 服务将在 10 秒后自动重启。"
    else
        # 如果没有 at 命令，使用后台延迟
        echo "使用后台延迟重启方式（10秒后）..."
        (sleep 10 && systemctl restart ssh) &
        echo "SSH 服务将在 10 秒后自动重启。"
    fi

    echo ""
    echo "您可以保持当前连接，等待重启完成后使用新端口连接。"

    # 显示状态
    echo "SSH服务状态:"
    if ss -tulpn | grep ":$SSH_PORT" > /dev/null; then
        echo "SSH正在监听端口 $SSH_PORT"
    else
        echo "警告：SSH未在端口 $SSH_PORT 上监听"
    fi

    echo "配置备份位置: $BACKUP_DIR"
    echo "重要提示：SSH端口已更改为 $SSH_PORT"
    echo "新的SSH连接命令：ssh -p $SSH_PORT root@\$(服务器IP)"
    echo "===== 步骤 5 完成。 ====="
    return 0
}

# 步骤 6: 配置 Sub-Store 自动管理
step6_substore_config() {
    echo ""
    echo "===== 步骤 6: 配置 Sub-Store 自动管理 ====="

    MANAGE_SCRIPT_URL="https://raw.githubusercontent.com/kakakakaka1/init/main/manage_substore.sh"
    MANAGE_SCRIPT_LOCAL_PATH="/root/manage_substore.sh"

    echo "正在下载 Sub-Store 管理脚本..."
    if ! wget -q -O "$MANAGE_SCRIPT_LOCAL_PATH" "$MANAGE_SCRIPT_URL"; then
        echo "错误：下载管理脚本失败。"
        return 1
    fi
    chmod +x "$MANAGE_SCRIPT_LOCAL_PATH"
    echo "Sub-Store 管理脚本下载成功。"
    echo # 空行

    echo "请配置 Sub-Store 信息："
    read -p "请输入 Sub-Store API 地址（留空跳过）: " SUBSTORE_API
    read -p "请输入订阅名称（留空跳过）: " SUB_NAME

    # 分别处理每个配置项
    local config_updated=false

    if [ -n "$SUBSTORE_API" ]; then
        echo "正在更新 Sub-Store API 地址..."
        sed -i "s|^SUBSTORE_API_BASE=.*|SUBSTORE_API_BASE=\"$SUBSTORE_API\"|" "$MANAGE_SCRIPT_LOCAL_PATH"
        echo "Sub-Store API 地址已更新。"
        config_updated=true
    else
        echo "跳过 Sub-Store API 地址配置（将使用脚本中的默认值）。"
    fi

    if [ -n "$SUB_NAME" ]; then
        echo "正在更新订阅名称..."
        sed -i "s|^SUB_NAME=.*|SUB_NAME=\"$SUB_NAME\"|" "$MANAGE_SCRIPT_LOCAL_PATH"
        echo "订阅名称已更新。"
        config_updated=true
    else
        echo "跳过订阅名称配置（将使用脚本中的默认值）。"
    fi

    if [ "$config_updated" = false ]; then
        echo "警告：未配置任何 Sub-Store 信息。"
        echo "您可以稍后手动编辑 $MANAGE_SCRIPT_LOCAL_PATH 进行配置。"
    fi
    echo # 空行

    echo "正在执行首次同步..."
    if "$MANAGE_SCRIPT_LOCAL_PATH" sync; then
        echo "首次同步完成。"
    else
        echo "警告：首次同步失败，请检查配置。"
    fi

    # 添加 singbox 别名
    echo ""
    echo "正在添加 singbox 别名..."
    if ! grep -q "alias singbox=" ~/.bashrc 2>/dev/null; then
        echo "alias singbox='sing-box; bash manage_substore.sh'" >> ~/.bashrc
        echo "别名已添加。"
    else
        echo "别名已存在，跳过添加。"
    fi
    source ~/.bashrc
    echo "现在可以使用 'singbox' 命令来管理节点。"

    echo "===== 步骤 6 完成。 ====="
    return 0
}

# 执行所有步骤
execute_all() {
    echo "===== 开始执行所有步骤 ====="
    echo "提示：每个步骤执行完后会暂停，按任意键继续下一步"
    echo ""

    local start_time=$(date +%s)
    local failed_steps=""

    # 步骤 1
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "▶ 正在执行步骤 1/6: 安装必备软件包"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    step1_install_packages
    if [ $? -ne 0 ]; then
        echo "❌ 步骤 1 失败"
        failed_steps="$failed_steps 1"
        read -p "按 Enter 继续执行下一步，或输入 Q 退出: " choice
        [[ "$choice" =~ ^[Qq]$ ]] && return 1
    else
        echo "✅ 步骤 1 完成"
        echo ""
        read -n 1 -s -p "按任意键继续下一步..."
        echo ""
    fi

    # 步骤 2
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "▶ 正在执行步骤 2/6: 下载并执行工具脚本"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    step2_tools_script
    if [ $? -ne 0 ]; then
        echo "❌ 步骤 2 失败"
        failed_steps="$failed_steps 2"
        read -p "按 Enter 继续执行下一步，或输入 Q 退出: " choice
        [[ "$choice" =~ ^[Qq]$ ]] && return 1
    else
        echo "✅ 步骤 2 完成"
        echo ""
        read -n 1 -s -p "按任意键继续下一步..."
        echo ""
    fi

    # 步骤 3
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "▶ 正在执行步骤 3/6: sing-box 安装和配置"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    step3_singbox_install
    if [ $? -ne 0 ]; then
        echo "❌ 步骤 3 失败"
        failed_steps="$failed_steps 3"
        read -p "按 Enter 继续执行下一步，或输入 Q 退出: " choice
        [[ "$choice" =~ ^[Qq]$ ]] && return 1
    else
        echo "✅ 步骤 3 完成"
        echo ""
        read -n 1 -s -p "按任意键继续下一步..."
        echo ""
    fi

    # 步骤 4
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "▶ 正在执行步骤 4/6: 下载并执行 snell.sh"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    step4_snell_install
    if [ $? -ne 0 ]; then
        echo "❌ 步骤 4 失败"
        failed_steps="$failed_steps 4"
        read -p "按 Enter 继续执行下一步，或输入 Q 退出: " choice
        [[ "$choice" =~ ^[Qq]$ ]] && return 1
    else
        echo "✅ 步骤 4 完成"
        echo ""
        read -n 1 -s -p "按任意键继续下一步..."
        echo ""
    fi

    # 步骤 5
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "▶ 正在执行步骤 5/6: SSH 安全加固"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    step5_ssh_hardening
    if [ $? -ne 0 ]; then
        echo "❌ 步骤 5 失败"
        failed_steps="$failed_steps 5"
        read -p "按 Enter 继续执行下一步，或输入 Q 退出: " choice
        [[ "$choice" =~ ^[Qq]$ ]] && return 1
    else
        echo "✅ 步骤 5 完成"
        echo ""
        read -n 1 -s -p "按任意键继续下一步..."
        echo ""
    fi

    # 步骤 6
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "▶ 正在执行步骤 6/6: Sub-Store 自动管理"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    step6_substore_config
    if [ $? -ne 0 ]; then
        echo "❌ 步骤 6 失败（非关键步骤）"
        failed_steps="$failed_steps 6"
    else
        echo "✅ 步骤 6 完成"
    fi

    # 计算总执行时间
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))

    # 显示执行摘要
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📊 执行摘要"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "总执行时间: ${minutes}分${seconds}秒"

    if [ -z "$failed_steps" ]; then
        echo "状态: ✅ 所有步骤执行成功"
    else
        echo "状态: ⚠️  部分步骤失败"
        echo "失败的步骤:$failed_steps"
    fi
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "===== 所有自动化步骤已执行完毕。 ====="
}

# 显示菜单
show_menu() {
    echo ""
    echo "============================================"
    echo "          初始化脚本执行菜单"
    echo "============================================"
    echo "1. 步骤 1: 使用 APT 安装必备软件包"
    echo "2. 步骤 2: 下载并执行外部工具脚本"
    echo "3. 步骤 3: 执行 sing-box 安装和配置"
    echo "4. 步骤 4: 下载并执行 snell.sh 脚本"
    echo "5. 步骤 5: SSH安全加固和Fail2ban配置"
    echo "6. 步骤 6: 配置 Sub-Store 自动管理"
    echo "A. 执行全部步骤（默认）"
    echo "Q. 退出"
    echo "============================================"
}

# ==============================================================================
# 主程序
# ==============================================================================

# 主循环函数
main_loop() {
    while true; do
        show_menu
        read -p "请选择要执行的步骤 [默认: A]: " choice

        # 如果用户直接按回车，使用默认值 A
        if [ -z "$choice" ]; then
            choice="A"
        fi

        # 转换为大写
        choice=$(echo "$choice" | tr '[:lower:]' '[:upper:]')

        # 执行相应的步骤
        case $choice in
            1)
                step1_install_packages
                ;;
            2)
                step2_tools_script
                ;;
            3)
                step3_singbox_install
                ;;
            4)
                step4_snell_install
                ;;
            5)
                step5_ssh_hardening
                ;;
            6)
                step6_substore_config
                ;;
            A)
                execute_all
                echo ""
                echo "全部步骤执行完毕，按任意键返回菜单..."
                read -n 1 -s
                continue
                ;;
            Q)
                echo "退出脚本。"
                exit 0
                ;;
            *)
                echo "无效的选择: $choice"
                ;;
        esac

        # 步骤执行完后，询问是否继续
        echo ""
        read -p "按 Enter 返回菜单，或输入 Q 退出: " continue_choice
        if [[ "$continue_choice" =~ ^[Qq]$ ]]; then
            echo "退出脚本。"
            exit 0
        fi
    done
}

# 如果有命令行参数，直接执行；否则进入循环菜单
if [ $# -eq 0 ]; then
    # 没有参数，进入循环菜单
    main_loop
else
    # 使用第一个命令行参数作为选择
    choice=$1
    choice=$(echo "$choice" | tr '[:lower:]' '[:upper:]')

    case $choice in
        1)
            step1_install_packages
            ;;
        2)
            step2_tools_script
            ;;
        3)
            step3_singbox_install
            ;;
        4)
            step4_snell_install
            ;;
        5)
            step5_ssh_hardening
            ;;
        6)
            step6_substore_config
            ;;
        A)
            execute_all
            ;;
        Q)
            echo "退出脚本。"
            exit 0
            ;;
        *)
            echo "无效的选择: $choice"
            echo "请运行 $0 查看菜单"
            exit 1
            ;;
    esac
fi

exit 0
