#!/bin/bash
# Sub-Store 自动同步脚本 - 用于远程服务器
# 自动获取所有 sing-box 节点并同步到 Sub-Store
# 版本：v2.1 - 支持追加模式和去重
#
# 使用方法：
# 1. 修改下方配置区域
# 2. 运行: ./sync_to_substore.sh

set -e

# ============================================================
# 配置区域 - 请修改以下变量
# ============================================================

# Sub-Store API 基础地址（包含你的 API token）
SUBSTORE_API_BASE="https://dy.rar.li/c63dc7a823f46c070369df9bbff370812f1948d3e86af1fecc452dc397f2d06f"

# 目标订阅名称
SUB_NAME="backet"

# 同步模式：append（追加，推荐多服务器）
# 追加模式会自动去重，不会重复添加相同节点
SYNC_MODE="append"

# sing-box 配置目录
SING_BOX_CONF_DIR="/etc/sing-box/conf"

# 节点名称前缀（用于标识来自此服务器的节点）
NODE_PREFIX="hinet"

# ============================================================
# 以下为脚本逻辑，无需修改
# ============================================================

# 颜色定义
red='\e[31m'
green='\e[92m'
yellow='\e[33m'
cyan='\e[96m'
none='\e[0m'

# 检查依赖
if ! command -v jq &> /dev/null; then
    echo -e "${red}错误: 需要安装 jq 工具${none}"
    echo "安装命令: apt install jq 或 yum install jq"
    exit 1
fi

if ! command -v sing-box &> /dev/null; then
    echo -e "${red}错误: 未找到 sing-box 命令${none}"
    exit 1
fi

if ! command -v curl &> /dev/null; then
    echo -e "${red}错误: 需要安装 curl 工具${none}"
    exit 1
fi

echo ""
echo "=================================================="
echo "Sub-Store 自动同步工具 (智能去重版)"
echo "=================================================="
echo "订阅名称: $SUB_NAME"
echo "同步模式: $SYNC_MODE (追加 + 自动去重)"
echo "节点前缀: $NODE_PREFIX"
echo ""

# 1. 获取当前订阅
echo "[1/5] 获取当前订阅..."
CURRENT_SUB=$(curl -s "${SUBSTORE_API_BASE}/api/subs" | jq --arg name "$SUB_NAME" '.data[] | select(.name==$name)')

if [ -z "$CURRENT_SUB" ]; then
    echo -e "${red}✗ 错误: 未找到订阅 '$SUB_NAME'${none}"
    echo ""
    echo "可用的订阅列表:"
    curl -s "${SUBSTORE_API_BASE}/api/subs" | jq -r '.data[].name' | sed 's/^/  - /'
    exit 1
fi

CURRENT_CONTENT=$(echo "$CURRENT_SUB" | jq -r '.content')
echo -e "${green}✓ 找到订阅 '$SUB_NAME'${none}"

# 统计当前节点数
CURRENT_NODE_COUNT=$(echo "$CURRENT_CONTENT" | grep -c "^[^[:space:]]" || echo "0")
echo "  当前订阅有 $CURRENT_NODE_COUNT 个节点"

# 2. 扫描 sing-box 配置
echo ""
echo "[2/5] 扫描 sing-box 配置..."
if [ ! -d "$SING_BOX_CONF_DIR" ]; then
    echo -e "${red}✗ 错误: sing-box 配置目录不存在${none}"
    exit 1
fi

CONFIG_FILES=$(ls $SING_BOX_CONF_DIR/*.json 2>/dev/null || echo "")
if [ -z "$CONFIG_FILES" ]; then
    echo -e "${yellow}⚠ 警告: 未找到任何配置文件${none}"
    exit 0
fi

CONFIG_COUNT=$(echo "$CONFIG_FILES" | wc -l)
echo -e "${green}✓ 找到 $CONFIG_COUNT 个配置${none}"

# 3. 提取所有节点 URL
echo ""
echo "[3/5] 提取节点 URL..."
ALL_NODES=""
EXTRACTED_COUNT=0

for config_file in $CONFIG_FILES; do
    config_name=$(basename "$config_file" .json)
    echo "  - 处理: $config_name"

    # 获取节点 URL（过滤掉颜色代码和其他输出）
    NODE_URL=$(sing-box url "$config_name" 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | grep -E "^(ss|vless|vmess|trojan|hysteria)://" || echo "")

    if [ -n "$NODE_URL" ]; then
        # 修改节点备注名，添加前缀
        if [[ "$NODE_URL" =~ \# ]]; then
            # 提取原有备注
            OLD_REMARK=$(echo "$NODE_URL" | sed 's/.*#//')
            # 替换为新备注
            NEW_REMARK="${NODE_PREFIX}-${OLD_REMARK}"
            NODE_URL=$(echo "$NODE_URL" | sed "s/#.*/#${NEW_REMARK}/")
        fi

        ALL_NODES="${ALL_NODES}${NODE_URL}
"
        EXTRACTED_COUNT=$((EXTRACTED_COUNT + 1))
        echo -e "    ${green}✓${none} 已提取"
    else
        echo -e "    ${yellow}⚠ 跳过（无法提取 URL）${none}"
    fi
done

# 3.5. 提取 Snell 节点（如果存在）
if [ -d "/etc/snell/users" ]; then
    echo ""
    echo "[3.5/5] 提取 Snell 节点..."
    SNELL_COUNT=0

    for snell_conf in /etc/snell/users/*.conf; do
        [ ! -f "$snell_conf" ] && continue

        snell_name=$(basename "$snell_conf" .conf)
        echo "  - 处理: $snell_name"

        # 读取配置文件
        SNELL_PORT=$(grep "^listen" "$snell_conf" | awk -F':' '{print $NF}')
        SNELL_PSK=$(grep "^psk" "$snell_conf" | awk '{print $NF}')

        if [ -n "$SNELL_PORT" ] && [ -n "$SNELL_PSK" ]; then
            # 获取服务器 IP
            SERVER_IP=$(curl -s4 --max-time 3 https://api.ipify.org || echo "")

            if [ -n "$SERVER_IP" ]; then
                # 生成 Surge 格式的 Snell 节点（v4 和 v5）
                SNELL_NODE_V4="${NODE_PREFIX}-snell-${snell_name}-v4 = snell, ${SERVER_IP}, ${SNELL_PORT}, psk = ${SNELL_PSK}, version = 4, reuse = true, tfo = true"
                SNELL_NODE_V5="${NODE_PREFIX}-snell-${snell_name}-v5 = snell, ${SERVER_IP}, ${SNELL_PORT}, psk = ${SNELL_PSK}, version = 5, reuse = true, tfo = true"

                ALL_NODES="${ALL_NODES}${SNELL_NODE_V4}
${SNELL_NODE_V5}
"
                EXTRACTED_COUNT=$((EXTRACTED_COUNT + 2))
                SNELL_COUNT=$((SNELL_COUNT + 2))
                echo -e "    ${green}✓${none} 已提取 (v4 + v5)"
            else
                echo -e "    ${yellow}⚠ 跳过（无法获取服务器 IP）${none}"
            fi
        else
            echo -e "    ${yellow}⚠ 跳过（配置不完整）${none}"
        fi
    done

    if [ $SNELL_COUNT -gt 0 ]; then
        echo -e "${green}✓ 成功提取 $SNELL_COUNT 个 Snell 节点${none}"
    fi
fi

if [ $EXTRACTED_COUNT -eq 0 ]; then
    echo -e "${yellow}⚠ 警告: 未能提取任何节点${none}"
    exit 0
fi

echo ""
echo -e "${green}✓ 总共提取 $EXTRACTED_COUNT 个节点${none}"

# 4. 智能去重（追加模式）
echo ""
echo "[4/5] 智能去重检查..."

NEW_NODES=""
DUPLICATE_COUNT=0
ADDED_COUNT=0

# 将新节点按行分割
while IFS= read -r node_line; do
    [ -z "$node_line" ] && continue

    # 提取节点的关键信息用于去重（去除备注部分）
    # 例如: ss://xxx@1.2.3.4:1234#备注 -> ss://xxx@1.2.3.4:1234
    NODE_WITHOUT_REMARK=$(echo "$node_line" | sed 's/#.*//')

    # 提取备注名（仅用于显示）
    NODE_REMARK=""
    if [[ "$node_line" =~ \#(.+)$ ]]; then
        NODE_REMARK="${BASH_REMATCH[1]}"
    fi

    # 检查当前订阅中是否已存在相同的节点（不包括备注名）
    # 通过匹配节点URL的核心部分（去除备注后的部分）
    if echo "$CURRENT_CONTENT" | grep -qF "$NODE_WITHOUT_REMARK"; then
        echo -e "  ${yellow}⊗${none} 跳过重复: $NODE_REMARK"
        DUPLICATE_COUNT=$((DUPLICATE_COUNT + 1))
        continue
    fi

    # 不重复，添加到新节点列表
    NEW_NODES="${NEW_NODES}${node_line}
"
    ADDED_COUNT=$((ADDED_COUNT + 1))
    echo -e "  ${cyan}+${none} 新增: $NODE_REMARK"
done <<< "$ALL_NODES"

echo ""
echo "去重结果："
echo "  - 本地节点: $EXTRACTED_COUNT 个"
echo "  - 跳过重复: $DUPLICATE_COUNT 个"
echo "  - 将新增: $ADDED_COUNT 个"

# 如果没有新节点需要添加
if [ $ADDED_COUNT -eq 0 ]; then
    echo ""
    echo -e "${green}✓ 所有节点已存在，无需更新${none}"
    echo ""
    echo "提示: 订阅中已包含所有本地节点，保持现状"
    exit 0
fi

# 5. 追加新节点到订阅
echo ""
echo "[5/5] 更新订阅..."

# 合并内容：现有内容 + 新节点
# 确保节点之间有换行分隔
if [ -n "$CURRENT_CONTENT" ]; then
    # 检查 CURRENT_CONTENT 是否以换行结尾
    case "$CURRENT_CONTENT" in
        *$'\n') FINAL_CONTENT="${CURRENT_CONTENT}${NEW_NODES}" ;;
        *) FINAL_CONTENT="${CURRENT_CONTENT}
${NEW_NODES}" ;;
    esac
else
    FINAL_CONTENT="${NEW_NODES}"
fi

UPDATE_PAYLOAD=$(jq -n --arg content "$FINAL_CONTENT" '{content: $content}')

UPDATE_RESULT=$(curl -s -X PATCH "${SUBSTORE_API_BASE}/api/sub/${SUB_NAME}" \
    -H 'Content-Type: application/json' \
    -d "$UPDATE_PAYLOAD")

# 检查更新结果
if echo "$UPDATE_RESULT" | jq -e '.status == "success"' > /dev/null 2>&1; then
    echo -e "${green}✓ 同步成功${none}"
    echo ""
    echo "=================================================="
    echo "✓ 节点已成功同步到 Sub-Store"
    echo "=================================================="

    # 显示统计信息
    FINAL_NODE_COUNT=$(echo "$UPDATE_RESULT" | jq -r '.data.content' | grep -c "^[^[:space:]]" || echo "0")
    echo ""
    echo "统计信息:"
    echo "  - 同步前: $CURRENT_NODE_COUNT 个节点"
    echo "  - 新增: $ADDED_COUNT 个节点"
    echo "  - 跳过重复: $DUPLICATE_COUNT 个节点"
    echo "  - 同步后: $FINAL_NODE_COUNT 个节点"

    # 显示订阅链接
    echo ""
    echo "订阅链接:"
    echo "  ${SUBSTORE_API_BASE%/api}/subs"

    # 记录日志
    echo "$(date '+%Y-%m-%d %H:%M:%S') - 同步成功 - 新增:${ADDED_COUNT} 跳过:${DUPLICATE_COUNT} 总数:${FINAL_NODE_COUNT}" >> /var/log/substore-sync.log
else
    echo -e "${red}✗ 同步失败${none}"
    echo ""
    echo "错误信息:"
    echo "$UPDATE_RESULT" | jq '.'

    # 记录错误日志
    echo "$(date '+%Y-%m-%d %H:%M:%S') - 同步失败" >> /var/log/substore-sync.log
    exit 1
fi
