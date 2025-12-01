#!/bin/bash

# 确保 Node.js 版本 >= 18.0
echo "设置 Node.js LTS 源..."
curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
echo "安装 Node.js..."
apt-get install -y nodejs

# 检查 Node.js 版本
node --version

# 安装 Claude Code
echo "安装 Claude Code..."
npm install -g @anthropic-ai/claude-code

# 检查 Claude Code 版本
claude --version

# 下载并替换 /root/.bashrc 文件
echo "下载并替换 .bashrc 文件..."
curl -fsSL https://raw.githubusercontent.com/kakakakaka1/init/refs/heads/main/.bashrc -o /root/.bashrc

# 执行 source 命令使新 .bashrc 生效
echo "更新 .bashrc 并执行 source..."
source /root/.bashrc

# 在 /root 下创建 claude 文件夹
echo "在 /root 目录下创建 claude 文件夹..."
mkdir -p /root/claude

echo "安装完成！"
