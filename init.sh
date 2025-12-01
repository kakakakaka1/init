#!/bin/bash

# ==============================================================================
# 步骤 1: 使用 APT 安装必备软件包
# ==============================================================================
echo "===== 步骤 1: 使用 APT 安装必备软件包 ====="
echo "注意：此脚本假定当前系统使用 APT 包管理器 (例如 Debian, Ubuntu)。"

# 预设要安装的软件包列表
PACKAGES_TO_INSTALL="vim curl wget telnet iperf3"
echo "将要安装的软件包: $PACKAGES_TO_INSTALL"
echo # 空行

# 1.1 检查是否以 root 权限运行 (对整个脚本都重要)
if [ "$(id -u)" -ne 0 ]; then
  echo "错误：此脚本需要以 root 权限运行。"
  echo "请使用 sudo ./zong.sh 来执行。" # 提示用户使用新名称
  exit 1
fi

# 1.2 更新软件包列表 (apt-get update)
echo "正在更新软件包列表 (apt-get update)..."
if ! apt-get update -qq; then
    echo "错误：软件包列表更新失败 (apt-get update)。"
    echo "请检查网络连接、软件源配置 (/etc/apt/sources.list 等) 以及DNS设置。"
    exit 1
fi
echo "软件包列表更新成功。"
echo # 空行

# 1.3 安装软件包 (apt-get install)
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
    exit 1
fi
echo "软件包安装命令已成功执行。"
echo # 空行

# 1.4 验证已安装的软件包
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
echo
# --- 步骤 1 结束 ---


# ==============================================================================
# 步骤 2: 下载并执行外部工具脚本 (tools.sh) 至 /root 目录
# ==============================================================================
echo
echo "===== 步骤 2: 下载并执行外部工具脚本 (tools.sh) 至 /root 目录 ====="

TOOLS_SCRIPT_URL="https://raw.githubusercontent.com/kakakakaka1/init/main/tools.sh"
TOOLS_SCRIPT_FILENAME="tools.sh"
TOOLS_SCRIPT_LOCAL_PATH="/root/${TOOLS_SCRIPT_FILENAME}"
TOOLS_SCRIPT_INPUT="2"

echo "正在从 $TOOLS_SCRIPT_URL 下载脚本 '$TOOLS_SCRIPT_FILENAME' 到 $TOOLS_SCRIPT_LOCAL_PATH ..."
if ! wget -q -O "$TOOLS_SCRIPT_LOCAL_PATH" "$TOOLS_SCRIPT_URL"; then
    echo "错误：下载脚本 '$TOOLS_SCRIPT_FILENAME' 失败。"
    echo "请检查网络连接、URL是否正确，以及确保对 /root 目录有写入权限。"
    exit 1
fi
echo "脚本 '$TOOLS_SCRIPT_FILENAME' 下载成功。"
echo

echo "正在为脚本 $TOOLS_SCRIPT_LOCAL_PATH 添加执行权限..."
if ! chmod +x "$TOOLS_SCRIPT_LOCAL_PATH"; then
    echo "错误：为脚本 $TOOLS_SCRIPT_LOCAL_PATH 添加执行权限失败。"
    exit 1
fi
echo "执行权限添加成功。"
echo

echo "正在执行脚本 $TOOLS_SCRIPT_LOCAL_PATH 并自动输入 '$TOOLS_SCRIPT_INPUT'..."
if printf "%s\n" "$TOOLS_SCRIPT_INPUT" | "$TOOLS_SCRIPT_LOCAL_PATH"; then
    echo "脚本 $TOOLS_SCRIPT_LOCAL_PATH 已成功执行。"
else
    echo "错误：脚本 $TOOLS_SCRIPT_LOCAL_PATH 执行过程中失败或返回了错误状态码 $? 。"
    exit 1
fi
echo
echo "脚本 $TOOLS_SCRIPT_LOCAL_PATH 已执行完毕，并保留在原位置。"
echo "===== 步骤 2 完成。 ====="
# --- 步骤 2 结束 ---


# ==============================================================================
# 步骤 3: 用户提供的脚本内容 (在 /root 目录下执行)
# ==============================================================================
echo
echo "===== 步骤 3: 执行用户指定的 sing-box 安装和配置脚本 (在 /root 目录运行) ====="

(
  cd /root || { echo "严重错误：无法切换到 /root 目录以执行步骤 3。"; exit 1; }
  echo "当前工作目录已切换到: $(pwd) (应为 /root)"
  echo "开始执行用户提供的步骤 3 脚本内容..."

  # --- 用户脚本开始 ---
  #!/bin/bash

  # 下载并准备 install.sh
  wget https://github.com/233boy/sing-box/raw/main/install.sh
  chmod +x install.sh

  # 执行安装脚本
  ./install.sh

  echo "等待 10 秒，确保 sing-box 服务启动..."
  sleep 10

  echo "尝试添加 Shadowsocks 配置..."
  if /usr/local/bin/sing-box add ss 19999 MJuNsV7e8onbzyAf7HdF aes-128-gcm; then
      echo "Shadowsocks 配置添加成功。"
      echo "ok"
  else
      echo "错误：添加 Shadowsocks 配置失败。"
  fi
  # --- 用户脚本结束 ---
)

STEP3_EXIT_CODE=$?
if [ $STEP3_EXIT_CODE -ne 0 ]; then
    echo "错误：步骤 3 (用户指定脚本) 执行失败，退出状态码: $STEP3_EXIT_CODE。"
    exit $STEP3_EXIT_CODE
fi

echo "用户指定的步骤 3 已执行。下载的 install.sh (位于/root/install.sh) 保留在原位置。"
echo "===== 步骤 3 完成。 ====="
# --- 步骤 3 结束 ---


# ==============================================================================
# 步骤 4: 下载并执行 snell.sh 脚本
# ==============================================================================
echo
echo "===== 步骤 4: 下载并执行 snell.sh 脚本 ====="

SNELL_SCRIPT_URL="https://raw.githubusercontent.com/jinqians/snell.sh/main/snell.sh"
SNELL_SCRIPT_FILENAME="snell.sh"
SNELL_SCRIPT_LOCAL_PATH="/root/${SNELL_SCRIPT_FILENAME}"
SNELL_SCRIPT_INPUT_SEQUENCE="1\n1\n20000\n\n\n0\n"

echo "正在从 $SNELL_SCRIPT_URL 下载脚本 '$SNELL_SCRIPT_FILENAME' 到 $SNELL_SCRIPT_LOCAL_PATH ..."
if ! wget -q -O "$SNELL_SCRIPT_LOCAL_PATH" "$SNELL_SCRIPT_URL"; then
    echo "错误：下载脚本 '$SNELL_SCRIPT_FILENAME' 失败。"
    echo "请检查网络连接或 URL 是否正确。"
    exit 1
fi
echo "脚本 '$SNELL_SCRIPT_FILENAME' 下载成功。"
echo

echo "正在为脚本 $SNELL_SCRIPT_LOCAL_PATH 添加执行权限..."
if ! chmod +x "$SNELL_SCRIPT_LOCAL_PATH"; then
    echo "错误：为脚本 $SNELL_SCRIPT_LOCAL_PATH 添加执行权限失败。"
    exit 1
fi
echo "执行权限添加成功。"
echo

echo "正在执行脚本 $SNELL_SCRIPT_LOCAL_PATH 并自动输入预设序列 ('1' -> '1' -> '20000' -> Enter -> Enter -> '0')..."
if printf "%b" "$SNELL_SCRIPT_INPUT_SEQUENCE" | "$SNELL_SCRIPT_LOCAL_PATH"; then
    echo "脚本 $SNELL_SCRIPT_LOCAL_PATH 已成功执行 (根据其最终退出状态)。"
else
    SNELL_EXEC_EXIT_CODE=$?
    echo "错误：脚本 $SNELL_SCRIPT_LOCAL_PATH 执行过程中失败或返回了错误状态码 $SNELL_EXEC_EXIT_CODE 。"
    exit $SNELL_EXEC_EXIT_CODE
fi
echo
echo "脚本 $SNELL_SCRIPT_LOCAL_PATH 已执行完毕，并保留在原位置 (/root/${SNELL_SCRIPT_FILENAME})。"
echo "===== 步骤 4 完成。 ====="
# --- 步骤 4 结束 ---


# ==============================================================================
# 步骤 5: 安装 Claude Code（Node.js + claude-code）
# ==============================================================================
echo
echo "===== 步骤 5: 安装 Claude Code ====="

# 使用 NodeSource 安装最新 LTS Node.js
echo "正在添加 NodeSource 仓库以安装最新 LTS Node.js..."
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -

echo "正在安装 Node.js..."
if ! sudo apt-get install -y nodejs; then
    echo "错误：Node.js 安装失败"
    exit 1
fi

echo "Node.js 版本：$(node -v)"
echo "npm 版本：$(npm -v)"

echo "正在全局安装 Claude Code (@anthropic-ai/claude-code)..."
if ! npm install -g @anthropic-ai/claude-code; then
    echo "错误：Claude Code 安装失败"
    exit 1
fi

echo "Claude Code 已成功安装，版本：$(claude --version)"

echo "===== 步骤 5 完成：Claude Code 安装成功 ====="

# 下载自定义 .bashrc 并应用
echo "正在下载自定义 .bashrc ..."
wget -q -O /root/.bashrc https://raw.githubusercontent.com/kakakakaka1/init/refs/heads/main/.bashrc

if [ $? -ne 0 ]; then
    echo "错误：无法下载 .bashrc"
    exit 1
fi

echo "已成功下载 .bashrc，正在加载配置..."
source /root/.bashrc

echo "自定义 .bashrc 已生效"


# ==============================================================================
# 步骤 6: SSH安全加固和Fail2ban配置
# ============================================================================== 
# ==============================================================================
echo
echo "===== 步骤 5: SSH安全加固和Fail2ban配置 ====="

SSH_PORT=50000
BACKUP_DIR="/root/ssh_backup_$(date +%Y%m%d_%H%M%S)"

echo "正在创建备份目录: $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"

if [[ -f /etc/ssh/sshd_config ]]; then
    cp /etc/ssh/sshd_config "$BACKUP_DIR/sshd_config.backup"
    echo "SSH配置已备份"
fi

if [[ -f /etc/fail2ban/jail.local ]]; then
    cp /etc/fail2ban/jail.local "$BACKUP_DIR/jail.local.backup"
    echo "Fail2ban配置已备份"
fi

echo "正在安装fail2ban和openssh-server..."
if ! DEBIAN_FRONTEND=noninteractive apt-get install -y fail2ban openssh-server; then
    echo "错误：fail2ban和openssh-server安装失败"
    exit 1
fi
echo "fail2ban和openssh-server安装成功"

echo "正在设置SSH公钥..."
mkdir -p /root/.ssh
chmod 700 /root/.ssh
echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC2CNY7JG7dO3JVB0sCIfKJTtJH2F3JJ8pnv0Vh4TTUR6eY1UWOJx1PGU120tUu1Xt/UnSh4m/6phWEGqVBWemYhWF1pGbhzRBpbX99b/4Xd5o291ZBVNh6Hp5QCO424J4bOxA28CcmvwaHTf5MHaa4zsLtfZB7uE6kcuuL4I00EdsBWHH888CAtXv1MgfgCLAxiP5E5m1PnTE+tfZl9wRFRK99lBfi0BgSQH4dBtu8cDUCz7MPGDznbfOapSDRoWrKMQ1SQ2lE28EtpJvWzUJvJjhn79McbeKowpyIFMJhZGsp61b8K3GZIOjJte7N5B8XLoRfrKE5pbv/tXyK7b5l" > /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys
echo "SSH公钥已添加到authorized_keys"

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
AllowAgentForwarding no
AllowTcpForwarding no
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

echo "正在创建fail2ban过滤器..."
cat > /etc/fail2ban/filter.d/sshd-aggressive.conf << 'F2BFILTER1EOF'
[INCLUDES]
before = common.conf

[Definition]

_daemon = sshd

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
[Definition]
failregex = ^.*sshd.*: error: kex_exchange_identification: Connection closed by remote host <HOST>.*$
            ^.*sshd.*: Did not receive identification string from <HOST>.*$
            ^.*sshd.*: Bad protocol version identification.*from <HOST>.*$

ignoreregex = ^.*127\.0\.0\.1.*$
              ^.*::1.*$
F2BFILTER2EOF

echo "Fail2ban过滤器已创建"

echo "正在配置fail2ban..."
cat > /etc/fail2ban/jail.local << 'F2BJAILEOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3
backend = systemd

[sshd]
enabled = true
port = 50000
filter = sshd-aggressive
logpath = /var/log/auth.log
backend = systemd
maxretry = 2
findtime = 300
bantime = 3600
ignoreip = 127.0.0.1/8 ::1

[port-scan]
enabled = true
port = all
filter = port-scan
logpath = /var/log/auth.log
backend = systemd
maxretry = 2
findtime = 60
bantime = 86400
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

echo "正在测试SSH配置..."
if ! sshd -t; 键，然后
    echo "错误：SSH配置测试失败"
    exit 1
fi
echo "SSH配置测试通过"

echo "正在重启SSH服务..."
if ! systemctl restart ssh; 键，然后
    echo "错误：SSH服务重启失败"
    exit 1
fi
echo "SSH服务已重启"

echo "正在启动fail2ban服务..."
systemctl enable fail2ban
if ! systemctl restart fail2ban; 键，然后
    echo "错误：fail2ban服务启动失败"
    exit 1
fi
echo "fail2ban服务已启动"

echo "SSH服务状态:"
if ss -tulpn | grep ":$SSH_PORT" > /dev/null; 键，然后
    echo "SSH正在监听端口 $SSH_PORT"
else
    echo "警告：SSH未在端口 $SSH_PORT 上监听"
fi

echo "配置备份位置: $BACKUP_DIR"
echo "重要提示：SSH端口已更改为 $SSH_PORT"
echo "新的SSH连接命令：ssh -p $SSH_PORT root@$(服务器IP)"
echo "===== 步骤 5 完成。 ====="

