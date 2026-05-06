#!/bin/bash
# nft-ctl 一键安装+运行
SCRIPT_URL="https://raw.githubusercontent.com/kakakakaka1/init/main/nft-ctl.sh"
INSTALL_PATH="/usr/local/bin/nft-ctl"

echo "📦 下载 nft-ctl..."
curl -sL "$SCRIPT_URL" -o "$INSTALL_PATH"
chmod +x "$INSTALL_PATH"
echo "✅ 已安装到 $INSTALL_PATH"
echo ""
bash "$INSTALL_PATH"
