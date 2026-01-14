#!/bin/bash
# Sub-Store 统一管理脚本
# 功能：自动同步（去重）和删除节点
#
# 用法：
#   ./manage_substore.sh sync              - 同步本地节点到 Sub-Store（自动去重）
#   ./manage_substore.sh delete <节点URL>  - 删除指定节点（精确匹配）
#
# 集成方式：
#   - 添加节点后调用：./manage_substore.sh sync
#   - 删除节点后调用：./manage_substore.sh delete <节点URL或关键信息>

set -e

# ============================================================
# 配置区域
# ============================================================

# Sub-Store API 基础地址
SUBSTORE_API_BASE="https://dy.rar.li/c63dc7a823f46c070369df9bbff370812f1948d3e86af1fecc452dc397f2d06f"

# 目标订阅名称
SUB_NAME="backet"

# sing-box 配置目录
SING_BOX_CONF_DIR="/etc/sing-box/conf"

# Snell 配置目录
SNELL_CONF_DIR="/etc/snell/users"

# 节点前缀（自动从 hostname 获取）
NODE_PREFIX=$(hostname)

# ============================================================
# 颜色定义
# ============================================================

red='\e[31m'
green='\e[92m'
yellow='\e[33m'
cyan='\e[96m'
none='\e[0m'

# ============================================================
# 工具函数
# ============================================================

# 检查依赖
check_dependencies() {
    local missing_deps=""

    for cmd in jq curl; do
        if ! command -v $cmd &> /dev/null; then
            missing_deps="$missing_deps $cmd"
        fi
    done

    if [ -n "$missing_deps" ]; then
        echo -e "${red}错误: 缺少依赖工具:$missing_deps${none}"
        echo -e "${yellow}安装: apt install -y$missing_deps 或 yum install -y$missing_deps${none}"
        exit 1
    fi
}

# 获取当前订阅
get_current_subscription() {
    curl -s "${SUBSTORE_API_BASE}/api/subs" 2>/dev/null | \
        jq --arg name "$SUB_NAME" '.data[] | select(.name==$name)' || echo ""
}

# 更新订阅
update_subscription() {
    local new_content="$1"
    local payload=$(jq -n --arg content "$new_content" '{content: $content}')

    curl -s -X PATCH "${SUBSTORE_API_BASE}/api/sub/${SUB_NAME}" \
        -H 'Content-Type: application/json' \
        -d "$payload" 2>/dev/null
}

# ============================================================
# 提取节点函数
# ============================================================

# 提取 sing-box 节点
extract_singbox_nodes() {
    local all_nodes=""
    local count=0

    if [ ! -d "$SING_BOX_CONF_DIR" ] || ! command -v sing-box &> /dev/null; then
        echo "$count|"
        return 0
    fi

    local config_files
    config_files=$(ls "$SING_BOX_CONF_DIR"/*.json 2>/dev/null || true)

    for config_file in $config_files; do
        [ ! -f "$config_file" ] && continue

        local config_name=$(basename "$config_file" .json)
        local node_url
        # sing-box url 输出包含很多额外信息，需要过滤
        node_url=$(sing-box url "$config_name" 2>&1 | \
            sed 's/\x1b\[[0-9;]*m//g' | \
            grep -oE '(ss|vless|vmess|trojan|hysteria|hysteria2)://[^[:space:]]+' | \
            head -1 || echo "")

        if [ -n "$node_url" ]; then
            # 修改备注名，添加前缀
            if [[ "$node_url" =~ \# ]]; then
                local old_remark=$(echo "$node_url" | sed 's/.*#//')
                local new_remark="${NODE_PREFIX}-${old_remark}"
                node_url=$(echo "$node_url" | sed "s/#.*/#${new_remark}/")
            fi

            all_nodes="${all_nodes}${node_url}
"
            count=$((count + 1))
        fi
    done

    echo "$count|$all_nodes"
}

# 提取 Snell 节点
extract_snell_nodes() {
    local all_nodes=""
    local count=0

    if [ ! -d "$SNELL_CONF_DIR" ]; then
        echo "$count|"
        return 0
    fi

    # 获取服务器 IP
    local server_ip=$(curl -s4 --max-time 3 https://api.ipify.org 2>/dev/null || echo "")

    if [ -z "$server_ip" ]; then
        echo "$count|"
        return 0
    fi

    local snell_files
    snell_files=$(ls "$SNELL_CONF_DIR"/*.conf 2>/dev/null || true)

    for snell_conf in $snell_files; do
        [ ! -f "$snell_conf" ] && continue

        local snell_name=$(basename "$snell_conf" .conf)
        local port
        local psk
        port=$(grep "^listen" "$snell_conf" | awk -F':' '{print $NF}')
        psk=$(grep "^psk" "$snell_conf" | awk '{print $NF}')

        if [ -n "$port" ] && [ -n "$psk" ]; then
            # 生成 Surge 格式的 Snell 节点（v4 和 v5）
            local node_v4="${NODE_PREFIX}-snell-${snell_name}-v4 = snell, ${server_ip}, ${port}, psk = ${psk}, version = 4, reuse = true, tfo = true"
            local node_v5="${NODE_PREFIX}-snell-${snell_name}-v5 = snell, ${server_ip}, ${port}, psk = ${psk}, version = 5, reuse = true, tfo = true"

            all_nodes="${all_nodes}${node_v4}
${node_v5}
"
            count=$((count + 2))
        fi
    done

    echo "$count|$all_nodes"
}

# ============================================================
# 主功能函数
# ============================================================

# 同步功能（双向同步：添加 + 删除 + 去重）
sync_nodes() {
    echo ""
    echo -e "${cyan}=================================================${none}"
    echo -e "${cyan}Sub-Store 节点双向同步（自动去重）${none}"
    echo -e "${cyan}=================================================${none}"
    echo -e "订阅名称: ${green}$SUB_NAME${none}"
    echo -e "节点前缀: ${green}$NODE_PREFIX${none}"
    echo ""

    # 1. 获取当前订阅
    echo -e "${cyan}[1/5] 获取当前订阅...${none}"
    local current_sub=$(get_current_subscription)

    if [ -z "$current_sub" ]; then
        echo -e "${yellow}⚠ 未找到订阅 '$SUB_NAME'，跳过同步${none}"
        return 0
    fi

    local current_content=$(echo "$current_sub" | jq -r '.content')
    local current_count=$(echo "$current_content" | grep -c "^" 2>/dev/null || echo "0")
    echo -e "${green}✓ 找到订阅，当前有 $current_count 个节点${none}"

    # 2. 提取本地节点
    echo ""
    echo -e "${cyan}[2/5] 提取本地节点...${none}"

    local singbox_result=$(extract_singbox_nodes)
    local singbox_count=$(echo "$singbox_result" | head -1 | cut -d'|' -f1)
    local singbox_nodes=$(echo "$singbox_result" | cut -d'|' -f2-)

    local snell_result=$(extract_snell_nodes)
    local snell_count=$(echo "$snell_result" | head -1 | cut -d'|' -f1)
    local snell_nodes=$(echo "$snell_result" | cut -d'|' -f2-)

    # 合并节点，确保正确换行
    local all_local_nodes=""
    if [ -n "$singbox_nodes" ] && [ -n "$snell_nodes" ]; then
        # 确保 singbox_nodes 末尾有换行符，然后再拼接 snell_nodes
        all_local_nodes=$(printf "%s\n%s" "$singbox_nodes" "$snell_nodes")
    elif [ -n "$singbox_nodes" ]; then
        all_local_nodes="$singbox_nodes"
    elif [ -n "$snell_nodes" ]; then
        all_local_nodes="$snell_nodes"
    fi

    local total_local=$((singbox_count + snell_count))

    echo -e "${green}✓ Sing-box: $singbox_count 个节点${none}"
    echo -e "${green}✓ Snell: $snell_count 个节点${none}"
    echo -e "${green}✓ 总计: $total_local 个节点${none}"

    # 3. 清理订阅中本地已删除的节点
    echo ""
    echo -e "${cyan}[3/5] 清理订阅中已删除的节点...${none}"

    local cleaned_content=""
    local removed_count=0
    local kept_count=0

    while IFS= read -r line; do
        [ -z "$line" ] && continue

        # 检查是否是当前主机的节点（通过前缀识别）
        local is_local_node=false
        # 匹配 Surge 格式：以 NODE_PREFIX- 开头
        # 匹配 URL 格式：备注部分以 #NODE_PREFIX- 开头
        if [[ "$line" =~ ^${NODE_PREFIX}- ]] || [[ "$line" =~ \#${NODE_PREFIX}- ]]; then
            is_local_node=true
        fi

        # 如果不是当前主机的节点，保留
        if [ "$is_local_node" = false ]; then
            cleaned_content="${cleaned_content}${line}
"
            kept_count=$((kept_count + 1))
            continue
        fi

        # 如果是当前主机的节点，检查是否在本地存在
        local node_core=$(echo "$line" | sed 's/#.*//')
        local node_exists=false

        while IFS= read -r local_node; do
            [ -z "$local_node" ] && continue
            local local_core=$(echo "$local_node" | sed 's/#.*//')
            if [[ "$node_core" == "$local_core" ]]; then
                node_exists=true
                break
            fi
        done <<< "$all_local_nodes"

        if [ "$node_exists" = true ]; then
            # 本地存在，保留
            cleaned_content="${cleaned_content}${line}
"
            kept_count=$((kept_count + 1))
        else
            # 本地不存在，删除
            local node_remark=""
            if [[ "$line" =~ \#(.+)$ ]]; then
                node_remark="${BASH_REMATCH[1]}"
            elif [[ "$line" =~ ^([^=]+)\ = ]]; then
                node_remark="${BASH_REMATCH[1]}"
            fi
            echo -e "  ${red}-${none} 删除: $node_remark"
            removed_count=$((removed_count + 1))
        fi
    done <<< "$current_content"

    echo -e "${green}✓ 保留: $kept_count 个节点${none}"
    echo -e "${red}✓ 删除: $removed_count 个节点${none}"

    # 4. 添加新节点（去重）
    echo ""
    echo -e "${cyan}[4/5] 添加新节点（去重检查）...${none}"

    local new_nodes=""
    local duplicate_count=0
    local added_count=0

    while IFS= read -r node_line; do
        [ -z "$node_line" ] && continue

        # 提取节点核心信息（去除备注）
        local node_core=$(echo "$node_line" | sed 's/#.*//')

        # 提取备注名（仅用于显示）
        local node_remark=""
        if [[ "$node_line" =~ \#(.+)$ ]]; then
            node_remark="${BASH_REMATCH[1]}"
        elif [[ "$node_line" =~ ^([^=]+)\ = ]]; then
            node_remark="${BASH_REMATCH[1]}"
        fi

        # 检查是否已存在于清理后的内容中
        if echo "$cleaned_content" | grep -qF "$node_core"; then
            echo -e "  ${yellow}⊗${none} 跳过: $node_remark"
            duplicate_count=$((duplicate_count + 1))
            continue
        fi

        # 不重复，添加到新节点列表
        new_nodes="${new_nodes}${node_line}
"
        added_count=$((added_count + 1))
        echo -e "  ${cyan}+${none} 新增: $node_remark"
    done <<< "$all_local_nodes"

    echo ""
    echo "同步结果："
    echo -e "  - 本地节点: ${yellow}$total_local${none} 个"
    echo -e "  - 删除节点: ${red}$removed_count${none} 个"
    echo -e "  - 跳过重复: ${yellow}$duplicate_count${none} 个"
    echo -e "  - 新增节点: ${green}$added_count${none} 个"

    # 如果没有任何变化
    if [ $removed_count -eq 0 ] && [ $added_count -eq 0 ]; then
        echo ""
        echo -e "${green}✓ 订阅已是最新状态，无需更新${none}"
        return 0
    fi

    # 5. 更新订阅
    echo ""
    echo -e "${cyan}[5/5] 更新订阅...${none}"

    # 合并内容
    local final_content
    if [ -n "$cleaned_content" ]; then
        if [ -n "$new_nodes" ]; then
            case "$cleaned_content" in
                *$'\n') final_content="${cleaned_content}${new_nodes}" ;;
                *) final_content="${cleaned_content}
${new_nodes}" ;;
            esac
        else
            final_content="${cleaned_content}"
        fi
    else
        final_content="${new_nodes}"
    fi

    local update_result=$(update_subscription "$final_content")

    if echo "$update_result" | jq -e '.status == "success"' > /dev/null 2>&1; then
        local final_count=$(echo "$update_result" | jq -r '.data.content' | grep -c "^" 2>/dev/null || echo "0")

        echo -e "${green}✓ 同步成功${none}"
        echo ""
        echo -e "${cyan}=================================================${none}"
        echo -e "${green}✓ 节点已成功同步到 Sub-Store${none}"
        echo -e "${cyan}=================================================${none}"
        echo ""
        echo "统计信息:"
        echo -e "  - 同步前: ${yellow}$current_count${none} 个节点"
        echo -e "  - 删除: ${red}$removed_count${none} 个节点"
        echo -e "  - 新增: ${green}$added_count${none} 个节点"
        echo -e "  - 同步后: ${green}$final_count${none} 个节点"
        echo ""
    else
        echo -e "${yellow}⚠ 同步失败（可能网络问题）${none}"
        return 1
    fi
}

# 删除功能（精确匹配）
delete_node() {
    local delete_keyword="$1"

    if [ -z "$delete_keyword" ]; then
        echo -e "${red}错误: 请提供要删除的节点关键字${none}"
        echo -e "${yellow}用法: $0 delete <节点URL或关键字>${none}"
        return 1
    fi

    echo ""
    echo -e "${cyan}=================================================${none}"
    echo -e "${cyan}Sub-Store 节点删除（精确匹配）${none}"
    echo -e "${cyan}=================================================${none}"
    echo -e "订阅名称: ${green}$SUB_NAME${none}"
    echo -e "删除关键字: ${yellow}$delete_keyword${none}"
    echo ""

    # 1. 获取当前订阅
    echo -e "${cyan}[1/3] 获取当前订阅...${none}"
    local current_sub=$(get_current_subscription)

    if [ -z "$current_sub" ]; then
        echo -e "${yellow}⚠ 未找到订阅 '$SUB_NAME'，跳过删除${none}"
        return 0
    fi

    local current_content=$(echo "$current_sub" | jq -r '.content')
    local total_lines=$(echo "$current_content" | grep -c "^" 2>/dev/null || echo "0")
    echo -e "${green}✓ 找到订阅，当前有 $total_lines 个节点${none}"

    # 2. 查找匹配的节点
    echo ""
    echo -e "${cyan}[2/3] 查找匹配的节点...${none}"

    local matched_lines=$(echo "$current_content" | grep -n "$delete_keyword" || echo "")

    if [ -z "$matched_lines" ]; then
        echo -e "${yellow}⚠ 未找到包含 '$delete_keyword' 的节点${none}"
        return 0
    fi

    local match_count=$(echo "$matched_lines" | wc -l)
    echo -e "${yellow}找到 $match_count 个匹配的节点:${none}"
    echo "$matched_lines" | while IFS=: read -r line_num line_content; do
        echo -e "  ${yellow}[$line_num]${none} ${line_content:0:80}..."
    done

    # 3. 删除匹配的节点
    echo ""
    echo -e "${cyan}[3/3] 删除匹配的节点...${none}"

    local new_content=$(echo "$current_content" | grep -v "$delete_keyword" || echo "")
    local update_result=$(update_subscription "$new_content")

    if echo "$update_result" | jq -e '.status == "success"' > /dev/null 2>&1; then
        local new_count=$(echo "$update_result" | jq -r '.data.content' | grep -c "^" 2>/dev/null || echo "0")

        echo -e "${green}✓ 删除成功${none}"
        echo ""
        echo -e "${cyan}=================================================${none}"
        echo -e "${green}✓ 节点已从 Sub-Store 删除${none}"
        echo -e "${cyan}=================================================${none}"
        echo ""
        echo "统计信息:"
        echo -e "  - 删除前: ${yellow}$total_lines${none} 个节点"
        echo -e "  - 删除数量: ${red}$match_count${none} 个节点"
        echo -e "  - 删除后: ${green}$new_count${none} 个节点"
        echo ""
    else
        echo -e "${yellow}⚠ 删除失败（可能网络问题）${none}"
        return 1
    fi
}

# ============================================================
# 主入口
# ============================================================

main() {
    # 检查依赖
    check_dependencies

    # 解析命令
    local command="${1:-sync}"

    case "$command" in
        sync|add)
            sync_nodes
            ;;
        delete|del|remove|rm)
            delete_node "$2"
            ;;
        help|-h|--help)
            echo "用法: $0 <命令> [参数]"
            echo ""
            echo "命令:"
            echo "  sync                同步本地节点到 Sub-Store（自动去重）"
            echo "  delete <关键字>     删除匹配的节点"
            echo ""
            echo "示例:"
            echo "  $0 sync"
            echo "  $0 delete \"${NODE_PREFIX}-8388\""
            echo "  $0 delete \"${NODE_PREFIX}-snell\""
            ;;
        *)
            echo -e "${red}错误: 未知命令 '$command'${none}"
            echo -e "${yellow}运行 '$0 help' 查看帮助${none}"
            exit 1
            ;;
    esac
}

# 运行主函数
main "$@"
