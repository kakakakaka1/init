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
echo # 添加一个空行
# --- 步骤 1 结束 ---


# ==============================================================================
# 步骤 2: 下载并执行外部工具脚本 (tools.sh) 至 /root 目录
# ==============================================================================
echo # 空行，用以分隔不同的执行步骤
echo "===== 步骤 2: 下载并执行外部工具脚本 (tools.sh) 至 /root 目录 ====="

TOOLS_SCRIPT_URL="https://raw.githubusercontent.com/kakakakaka1/init/main/tools.sh"
TOOLS_SCRIPT_FILENAME="tools.sh" # 第二步的脚本名
TOOLS_SCRIPT_LOCAL_PATH="/root/${TOOLS_SCRIPT_FILENAME}" # 第二步脚本的本地路径
TOOLS_SCRIPT_INPUT="2"

echo "正在从 $TOOLS_SCRIPT_URL 下载脚本 '$TOOLS_SCRIPT_FILENAME' 到 $TOOLS_SCRIPT_LOCAL_PATH ..."
if ! wget -q -O "$TOOLS_SCRIPT_LOCAL_PATH" "$TOOLS_SCRIPT_URL"; then
    echo "错误：下载脚本 '$TOOLS_SCRIPT_FILENAME' 失败。"
    echo "请检查网络连接、URL是否正确，以及确保对 /root 目录有写入权限。"
    exit 1
fi
echo "脚本 '$TOOLS_SCRIPT_FILENAME' 下载成功。"
echo # 空行

echo "正在为脚本 $TOOLS_SCRIPT_LOCAL_PATH 添加执行权限..."
if ! chmod +x "$TOOLS_SCRIPT_LOCAL_PATH"; then
    echo "错误：为脚本 $TOOLS_SCRIPT_LOCAL_PATH 添加执行权限失败。"
    exit 1
fi
echo "执行权限添加成功。"
echo # 空行

echo "正在执行脚本 $TOOLS_SCRIPT_LOCAL_PATH 并自动输入 '$TOOLS_SCRIPT_INPUT'..."
if printf "%s\n" "$TOOLS_SCRIPT_INPUT" | "$TOOLS_SCRIPT_LOCAL_PATH"; then
    echo "脚本 $TOOLS_SCRIPT_LOCAL_PATH 已成功执行。"
else
    echo "错误：脚本 $TOOLS_SCRIPT_LOCAL_PATH 执行过程中失败或返回了错误状态码 $? 。"
    exit 1
fi
echo # 空行
echo "脚本 $TOOLS_SCRIPT_LOCAL_PATH 已执行完毕，并保留在原位置。"
echo "===== 步骤 2 完成。 ====="
# --- 步骤 2 结束 ---


# ==============================================================================
# 步骤 3: 用户提供的脚本内容 (在 /root 目录下执行)
# ==============================================================================
echo # 空行
echo "===== 步骤 3: 执行用户指定的 sing-box 安装和配置脚本 (在 /root 目录运行) ====="

# 将用户提供的脚本包裹在子 shell 中，并首先切换到 /root 目录
# 这样，用户脚本中的 wget 和 ./install.sh 会在 /root 目录下操作
# 注意：用户脚本本身的错误处理（例如 wget 或 chmod 失败）依赖于其内部逻辑。
(
  cd /root || { echo "严重错误：无法切换到 /root 目录以执行步骤 3。"; exit 1; }
  echo "当前工作目录已切换到: $(pwd) (应为 /root)"
  echo "开始执行用户提供的步骤 3 脚本内容..."

  # 以下是用户提供的脚本内容，原封不动地粘贴：
  # --- 用户脚本开始 ---
  #!/bin/bash
  # 假设这是您的单脚本内容

  # 下载并准备 install.sh
  wget https://github.com/233boy/sing-box/raw/main/install.sh
  chmod +x install.sh

  # 执行安装脚本
  ./install.sh

  # 等待一段时间，让 sing-box 服务有更充足的时间启动和初始化
  echo "等待 10 秒，确保 sing-box 服务启动..."
  sleep 10 # 您可以将 5 秒增加到 10 秒或更长，进行测试

  # 使用 sing-box 的完整路径执行 add 命令
  echo "尝试添加 Shadowsocks 配置..."
  if /usr/local/bin/sing-box add ss 19999 MJuNsV7e8onbzyAf7HdF aes-128-gcm; then
      echo "Shadowsocks 配置添加成功。"
      echo "ok"
  else
      echo "错误：添加 Shadowsocks 配置失败。"
      # 您可以在这里检查 /usr/local/bin/sing-box 是否存在，或者 sing-box 服务的状态
      # 例如：ls -l /usr/local/bin/sing-box; systemctl status sing-box --no-pager
      # 由于此部分在子shell中，如果希望主脚本因此失败，需要确保子shell以非0状态退出
      # 用户脚本本身没有在 add 失败时显式 exit 1，这里我们也不添加，遵循“不修改”原则
      # 但如果 ./install.sh 失败（且其内部有 exit 1），子shell会退出。
  fi
  # --- 用户脚本结束 ---

  # 检查子shell中最后一个命令的退出状态，如果需要，可以基于此决定主脚本是否继续
  # 但为简单起见并遵循“不修改用户脚本行为”的原则，这里不添加额外的退出逻辑
  # 用户脚本的成功与否主要由其内部的 if/else 和 echo 语句来体现
)
# 子shell执行完毕

# 检查上一个命令（即子shell）的退出状态
# 如果子shell因为错误而退出（例如 cd 失败，或者用户脚本内部执行了 exit 1），则主脚本也应该退出
STEP3_EXIT_CODE=$?
if [ $STEP3_EXIT_CODE -ne 0 ]; then
    echo "错误：步骤 3 (用户指定脚本) 执行失败，退出状态码: $STEP3_EXIT_CODE。"
    exit $STEP3_EXIT_CODE
fi

echo "用户指定的步骤 3 已执行。下载的 install.sh (位于/root/install.sh) 保留在原位置。"
echo "===== 步骤 3 完成。 ====="
# --- 步骤 3 结束 ---


# ==============================================================================
# 步骤 4: 下载并执行 gost.sh 脚本
# ==============================================================================
echo # 空行
echo "===== 步骤 4: 下载并执行 gost.sh 脚本 ====="

GOST_SCRIPT_URL="https://raw.githubusercontent.com/kakakakaka1/init/refs/heads/main/gost.sh"
GOST_SCRIPT_FILENAME="gost.sh" # 步骤四的脚本特定文件名 (已修改)
GOST_SCRIPT_LOCAL_PATH="/root/${GOST_SCRIPT_FILENAME}" # 步骤四脚本的本地路径
# 预设输入：先输入 "1" 然后回车，再输入 "n" 然后回车
GOST_SCRIPT_INPUT_SEQUENCE="1\nn\n"

echo "正在从 $GOST_SCRIPT_URL 下载脚本 '$GOST_SCRIPT_FILENAME' 到 $GOST_SCRIPT_LOCAL_PATH ..."
if ! wget -q -O "$GOST_SCRIPT_LOCAL_PATH" "$GOST_SCRIPT_URL"; then
    echo "错误：下载脚本 '$GOST_SCRIPT_FILENAME' 失败。"
    echo "请检查网络连接或 URL 是否正确。"
    exit 1
fi
echo "脚本 '$GOST_SCRIPT_FILENAME' 下载成功。"
echo # 空行

echo "正在为脚本 $GOST_SCRIPT_LOCAL_PATH 添加执行权限..."
if ! chmod +x "$GOST_SCRIPT_LOCAL_PATH"; then
    echo "错误：为脚本 $GOST_SCRIPT_LOCAL_PATH 添加执行权限失败。"
    exit 1
fi
echo "执行权限添加成功。"
echo # 空行

echo "正在执行脚本 $GOST_SCRIPT_LOCAL_PATH 并自动输入预设序列 ('1' then 'n')..."
# 使用 printf 将输入序列通过管道传递给脚本
# 脚本的输出将直接显示在终端
if printf "%b" "$GOST_SCRIPT_INPUT_SEQUENCE" | "$GOST_SCRIPT_LOCAL_PATH"; then
    echo "脚本 $GOST_SCRIPT_LOCAL_PATH 已成功执行 (根据其最终退出状态)。"
else
    # $? 会捕获管道中最后一个命令 (即 $GOST_SCRIPT_LOCAL_PATH) 的退出状态
    GOST_EXEC_EXIT_CODE=$?
    echo "错误：脚本 $GOST_SCRIPT_LOCAL_PATH 执行过程中失败或返回了错误状态码 $GOST_EXEC_EXIT_CODE 。"
    # 即使脚本执行失败，也保留下载的脚本，以便调试
    exit $GOST_EXEC_EXIT_CODE # 主脚本因步骤四失败而退出
fi
echo # 空行
echo "脚本 $GOST_SCRIPT_LOCAL_PATH 已执行完毕，并保留在原位置 (/root/${GOST_SCRIPT_FILENAME})。"
echo "===== 步骤 4 完成。 ====="
# --- 步骤 4 结束 ---


# ==============================================================================
# 步骤 5: 下载并执行 snell.sh 脚本
# ==============================================================================
echo # 空行
echo "===== 步骤 5: 下载并执行 snell.sh 脚本 ====="

SNELL_SCRIPT_URL="https://raw.githubusercontent.com/jinqians/snell.sh/main/snell.sh"
SNELL_SCRIPT_FILENAME="snell.sh" # 步骤五的脚本文件名
SNELL_SCRIPT_LOCAL_PATH="/root/${SNELL_SCRIPT_FILENAME}" # 步骤五脚本的本地路径
# 预设输入：先输入 "1" 然后回车，再输入 "20000" 然后回车，然后回车，然后回车，最后输入 "0" 然后回车
SNELL_SCRIPT_INPUT_SEQUENCE="1\n20000\n\n\n0\n" # 修改: 更新输入序列

echo "正在从 $SNELL_SCRIPT_URL 下载脚本 '$SNELL_SCRIPT_FILENAME' 到 $SNELL_SCRIPT_LOCAL_PATH ..."
# 使用 -O 选项确保文件直接保存到指定路径和名称
if ! wget -q -O "$SNELL_SCRIPT_LOCAL_PATH" "$SNELL_SCRIPT_URL"; then
    echo "错误：下载脚本 '$SNELL_SCRIPT_FILENAME' 失败。"
    echo "请检查网络连接或 URL 是否正确。"
    exit 1
fi
echo "脚本 '$SNELL_SCRIPT_FILENAME' 下载成功。"
echo # 空行

echo "正在为脚本 $SNELL_SCRIPT_LOCAL_PATH 添加执行权限..."
if ! chmod +x "$SNELL_SCRIPT_LOCAL_PATH"; then
    echo "错误：为脚本 $SNELL_SCRIPT_LOCAL_PATH 添加执行权限失败。"
    exit 1
fi
echo "执行权限添加成功。"
echo # 空行

echo "正在执行脚本 $SNELL_SCRIPT_LOCAL_PATH 并自动输入预设序列 ('1' -> '20000' -> Enter -> Enter -> '0')..."
# 使用 printf 将输入序列通过管道传递给脚本
# 脚本的输出将直接显示在终端
if printf "%b" "$SNELL_SCRIPT_INPUT_SEQUENCE" | "$SNELL_SCRIPT_LOCAL_PATH"; then
    echo "脚本 $SNELL_SCRIPT_LOCAL_PATH 已成功执行 (根据其最终退出状态)。"
    # 移除了之前的 sleep 和 exit 0，脚本将正常继续
else
    # $? 会捕获管道中最后一个命令 (即 $SNELL_SCRIPT_LOCAL_PATH) 的退出状态
    SNELL_EXEC_EXIT_CODE=$?
    echo "错误：脚本 $SNELL_SCRIPT_LOCAL_PATH 执行过程中失败或返回了错误状态码 $SNELL_EXEC_EXIT_CODE 。"
    # 即使脚本执行失败，也保留下载的脚本，以便调试
    exit $SNELL_EXEC_EXIT_CODE # 主脚本因步骤五失败而退出
fi
echo # 空行
echo "脚本 $SNELL_SCRIPT_LOCAL_PATH 已执行完毕，并保留在原位置 (/root/${SNELL_SCRIPT_FILENAME})。"
echo "===== 步骤 5 完成。 ====="
# --- 步骤 5 结束 ---


echo # Final blank line for separation
echo "===== 所有自动化步骤已执行完毕。 ====="
exit 0
