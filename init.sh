#!/bin/bash

# 变量定义
SSH_PORT=50000
ROOT_PUBLIC_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC2CNY7JG7dO3JVB0sCIfKJTtJH2F3JJ8pnv0Vh4TTUR6eY1UWOJx1PGU120tUu1Xt/UnSh4m/6phWEGqVBWemYhWF1pGbhzRBpbX99b/4Xd5o291ZBVNh6Hp5QCO424J4bOxA28CcmvwaHTf5MHaa4zsLtfZB7uE6kcuuL4I00EdsBWHH888CAtXv1MgfgCLAxiP5E5m1PnTE+tfZl9wRFRK99lBfi0BgSQH4dBtu8cDUCz7MPGDznbfOapSDRoWrKMQ1SQ2lE28EtpJvWzUJvJjhn79McbeKowpyIFMJhZGsp61b8K3GZIOjJte7N5B8XLoRfrKE5pbv/tXyK7b5l"  # 替换为你的实际公钥内容

# 1. 关闭防火墙
echo "关闭防火墙..."
sudo systemctl stop firewalld
sudo systemctl disable firewalld
# 2. 修改 SSH 配置
echo "修改 SSH 配置..."
sudo sed -i "s/#Port 22/Port $SSH_PORT/" /etc/ssh/sshd_config
sudo sed -i "s/#PermitRootLogin yes/PermitRootLogin prohibit-password/" /etc/ssh/sshd_config
sudo sed -i "s/#PasswordAuthentication yes/PasswordAuthentication no/" /etc/ssh/sshd_config
sudo sed -i "s/PasswordAuthentication yes/PasswordAuthentication no/" /etc/ssh/sshd_config.d/50-cloud-init.conf
# 添加公钥到 root 用户的 authorized_keys
echo "配置 root 用户的 SSH 公钥认证..."
sudo mkdir -p /root/.ssh
echo "$ROOT_PUBLIC_KEY" | sudo tee /root/.ssh/authorized_keys > /dev/null
sudo chmod 600 /root/.ssh/authorized_keys
sudo chmod 700 /root/.ssh


# 重启 SSH 服务
echo "重启 SSH 服务..."
sudo systemctl restart sshd

# 3. 更改 YUM 源为本地最常用的源
echo "更改 YUM 源为本地最常用的源..."
sudo cp /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.bak
sudo sed -i 's|mirrorlist=|#mirrorlist=|g' /etc/yum.repos.d/CentOS-Base.repo
sudo sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://mirror.centos.org|g' /etc/yum.repos.d/CentOS-Base.repo

# 你可以根据需要更新为本地的镜像地址，例如：
# sudo sed -i 's|baseurl=http://mirror.centos.org|baseurl=http://mirrors.aliyun.com|g' /etc/yum.repos.d/CentOS-Base.repo

# 刷新 YUM 缓存
echo "刷新 YUM 缓存..."
sudo yum makecache


# 4. 安装 vim 和 telnet
echo "安装 vim 和 telnet..."
sudo yum install -y vim telnet

echo "脚本执行完毕。"
