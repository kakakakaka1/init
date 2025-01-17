#!/bin/bash

# 确保以 root 权限运行
if [ "$(id -u)" -ne 0 ]; then
  echo "请使用 root 权限运行该脚本！"
  exit 1
fi

# 定义菜单
function show_menu() {
  echo "=========================="
  echo " 多功能管理脚本"
  echo "=========================="
  echo "1. 修改 SSH 配置文件"
  echo "2. Firewalld 管理"
  echo "3. 下载文件"
  echo "4. 上传文件"
  echo "5. 退出脚本"
  echo "=========================="
}

# 修改 SSH 配置文件
function modify_ssh_config() {
  SSH_CONFIG_FILE="/etc/ssh/sshd_config"

  echo "当前 SSH 配置文件路径: $SSH_CONFIG_FILE"
  if [ ! -f "$SSH_CONFIG_FILE" ]; then
    echo "SSH 配置文件不存在，请检查系统环境！"
    return
  fi

  # 备份原始配置文件
  cp "$SSH_CONFIG_FILE" "${SSH_CONFIG_FILE}.bak"
  echo "已备份原始配置文件为 ${SSH_CONFIG_FILE}.bak"

  echo "请选择要修改的配置项："
  echo "1. 修改默认端口"
  echo "2. 禁用 Root 登录"
  echo "3. 启用密码认证"
  echo "4. 禁用密码认证（仅允许私钥登录）"
  echo "5. 添加公钥到 authorized_keys"
  read -p "请选择 (1-5): " ssh_choice

  case $ssh_choice in
    1)
      read -p "请输入新的 SSH 端口号 (1-65535): " ssh_port
      if [[ $ssh_port -ge 1 && $ssh_port -le 65535 ]]; then
        sed -i "s/^#Port .*/Port $ssh_port/" $SSH_CONFIG_FILE
        sed -i "s/^Port .*/Port $ssh_port/" $SSH_CONFIG_FILE
        echo "SSH 端口已修改为 $ssh_port"
      else
        echo "输入的端口号无效！"
      fi
      ;;
    2)
      sed -i "s/^#PermitRootLogin .*/PermitRootLogin no/" $SSH_CONFIG_FILE
      sed -i "s/^PermitRootLogin .*/PermitRootLogin no/" $SSH_CONFIG_FILE
      echo "已禁用 Root 登录"
      ;;
    3)
      sed -i "s/^#PasswordAuthentication .*/PasswordAuthentication yes/" $SSH_CONFIG_FILE
      sed -i "s/^PasswordAuthentication .*/PasswordAuthentication yes/" $SSH_CONFIG_FILE
      echo "已启用密码认证"
      ;;
    4)
      sed -i "s/^#PasswordAuthentication .*/PasswordAuthentication no/" $SSH_CONFIG_FILE
      sed -i "s/^PasswordAuthentication .*/PasswordAuthentication no/" $SSH_CONFIG_FILE
      echo "已禁用密码认证"
      ;;
    5)
      AUTH_KEYS_FILE="/root/.ssh/authorized_keys"
      mkdir -p /root/.ssh
      echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC2CNY7JG7dO3JVB0sCIfKJTtJH2F3JJ8pnv0Vh4TTUR6eY1UWOJx1PGU120tUu1Xt/UnSh4m/6phWEGqVBWemYhWF1pGbhzRBpbX99b/4Xd5o291ZBVNh6Hp5QCO424J4bOxA28CcmvwaHTf5MHaa4zsLtfZB7uE6kcuuL4I00EdsBWHH888CAtXv1MgfgCLAxiP5E5m1PnTE+tfZl9wRFRK99lBfi0BgSQH4dBtu8cDUCz7MPGDznbfOapSDRoWrKMQ1SQ2lE28EtpJvWzUJvJjhn79McbeKowpyIFMJhZGsp61b8K3GZIOjJte7N5B8XLoRfrKE5pbv/tXyK7b5l" >> "$AUTH_KEYS_FILE"
      chmod 600 "$AUTH_KEYS_FILE"
      echo "公钥已添加到 $AUTH_KEYS_FILE"
      ;;
    *)
      echo "无效选择！"
      ;;
  esac

  systemctl restart sshd
  if [ $? -eq 0 ]; then
    echo "SSH 服务已成功重启，配置修改生效！"
  else
    echo "SSH 服务重启失败，请检查配置文件！"
  fi
}

# Firewalld 管理
function firewalld_management() {
  echo "=========================="
  echo " Firewalld 管理"
  echo "=========================="
  echo "1. 下载并安装 Firewalld"
  echo "2. 控制端口放行"
  echo "3. 删除端口放行"
  echo "4. 显示 Firewalld 规则"
  echo "5. 添加白名单 IP"
  echo "6. 只允许特定 IP 访问端口"
  echo "=========================="
  read -p "请选择功能 (1-6): " firewall_choice

  case $firewall_choice in
    1)
      install_firewalld
      ;;
    2)
      allow_port
      ;;
    3)
      remove_port
      ;;
    4)
      show_firewalld_rules
      ;;
    5)
      add_whitelist_ip
      ;;
    6)
      allow_ip_for_port
      ;;
    *)
      echo "无效选择，请重新选择！"
      ;;
  esac
}

# 下载并安装 Firewalld
function install_firewalld() {
  echo "正在安装 Firewalld..."
  if ! command -v firewalld &> /dev/null; then
    # 安装 Firewalld
    if [ -f /etc/debian_version ]; then
      apt-get update
      apt-get install firewalld -y
    elif [ -f /etc/redhat-release ]; then
      yum install firewalld -y
    fi
    systemctl start firewalld
    systemctl enable firewalld
    echo "Firewalld 安装并启动成功！"
  else
    echo "Firewalld 已安装！"
  fi
}

# 控制端口放行
function allow_port() {
  read -p "请输入要放行的端口号: " port
  read -p "请输入协议 (tcp/udp/both): " protocol

  if [[ "$protocol" == "both" ]]; then
    firewall-cmd --zone=public --add-port=$port/tcp --permanent
    firewall-cmd --zone=public --add-port=$port/udp --permanent
  else
    firewall-cmd --zone=public --add-port=$port/$protocol --permanent
  fi

  firewall-cmd --reload
  echo "端口 $port ($protocol) 放行成功！"
}

# 删除端口放行
function remove_port() {
  read -p "请输入要删除放行的端口号: " port
  read -p "请输入协议 (tcp/udp/both): " protocol

  if [[ "$protocol" == "both" ]]; then
    firewall-cmd --zone=public --remove-port=$port/tcp --permanent
    firewall-cmd --zone=public --remove-port=$port/udp --permanent
  else
    firewall-cmd --zone=public --remove-port=$port/$protocol --permanent
  fi

  firewall-cmd --reload
  echo "端口 $port ($protocol) 放行已删除！"
}

# 显示 Firewalld 规则
function show_firewalld_rules() {
  firewall-cmd --list-all
}

# 添加白名单 IP
function add_whitelist_ip() {
  read -p "请输入白名单 IP 地址: " ip_address
  firewall-cmd --zone=trusted --add-source=$ip_address --permanent
  firewall-cmd --reload
  echo "IP 地址 $ip_address 已添加到白名单！"
}

# 只允许特定 IP 访问端口
function allow_ip_for_port() {
  read -p "请输入要限制访问的端口号: " port
  read -p "请输入允许访问的 IP 地址: " ip_address
  firewall-cmd --zone=public --add-rich-rule="rule family='ipv4' source address='$ip_address' port port=$port protocol=tcp accept" --permanent
  firewall-cmd --reload
  echo "仅允许 IP $ip_address 访问端口 $port！"
}

# 下载文件
function download_files() {
  read -p "请输入目标机器的 IP 地址: " remote_ip
  read -p "请输入用户名: " remote_user
  read -s -p "请输入密码: " remote_pass
  echo

  if [ ! -f "lujing.txt" ]; then
    echo "文件列表 lujing.txt 不存在！"
    return
  fi

  while IFS= read -r file_path; do
    if [ -e "$file_path" ]; then
      echo "正在上传文件: $file_path"
      sshpass -p "$remote_pass" scp -r "$file_path" "$remote_user@$remote_ip:$file_path"
      if [ $? -eq 0 ]; then
        echo "文件 $file_path 上传成功！"
      else
        echo "文件 $file_path 上传失败！"
      fi
    else
      echo "文件 $file_path 不存在，跳过！"
    fi
  done < lujing.txt
}

# 上传文件
function upload_files() {
  read -p "请输入目标机器的 IP 地址: " remote_ip
  read -p "请输入用户名: " remote_user
  read -s -p "请输入密码: " remote_pass
  echo

  if [ ! -f "lujing.txt" ]; then
    echo "文件列表 lujing.txt 不存在！"
    return
  fi

  while IFS= read -r file_path; do
    echo "正在下载文件: $file_path"
    sshpass -p "$remote_pass" scp -r "$remote_user@$remote_ip:$file_path" "$file_path"
    if [ $? -eq 0 ]; then
      echo "文件 $file_path 下载成功！"
    else
      echo "文件 $file_path 下载失败！"
    fi
  done < lujing.txt
}

# 主菜单逻辑
while true; do
  show_menu
  read -p "请选择一个操作：" choice

  case $choice in
    1)
      modify_ssh_config
      ;;
    2)
      firewalld_management
      ;;
    3)
      download_files
      ;;
    4)
      upload_files
      ;;
    5)
      echo "退出脚本"
      exit 0
      ;;
    *)
      echo "无效选择！"
      ;;
  esac
done
