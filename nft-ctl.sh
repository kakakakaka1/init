#!/bin/bash
# nftables 防火墙管理脚本
set -e

CONF="/etc/nftables.conf"
CONF_BAK="/etc/nftables.conf.bak.$(date +%Y%m%d%H%M%S)"
EXPORT_FILE="./nftables-whitelist-export.txt"

# 检查/安装 nftables
check_nft() {
    if ! command -v nft &>/dev/null; then
        echo "📦 nftables 未安装，正在安装..."
        apt update -qq && apt install -y nftables
        echo "✅ 安装完成"
    fi
}

# 首次初始化配置
init_conf() {
    [ -f "$CONF" ] && return
    cat > "$CONF" << 'EOF'
#!/usr/sbin/nft -f
flush ruleset

define WHITELIST = {
}

define WHITELIST_PORTS = {
    5000,
}

table inet filter {
    chain input {
        type filter hook input priority 0; policy drop;
        ct state established,related accept
        iif "lo" accept
        ip saddr $WHITELIST accept
        tcp dport $WHITELIST_PORTS accept
        ip protocol icmp accept
        ip6 nexthdr icmpv6 accept
    }

    chain forward {
        type filter hook forward priority 0; policy drop;
        ct state established,related accept
        ip saddr $WHITELIST accept
        tcp dport $WHITELIST_PORTS accept
    }

    chain output {
        type filter hook output priority 0; policy accept;
    }
}
EOF
    echo "✅ 已生成默认配置"
}

# 验证+生效+开机自启
apply() {
    if nft -c -f "$CONF" 2>/dev/null; then
        nft -f "$CONF"
        systemctl enable nftables &>/dev/null
        systemctl restart nftables
        echo "✅ 配置验证通过，已生效，开机自启已开启"
    else
        echo "❌ 配置语法错误，未生效"
        nft -c -f "$CONF"
    fi
}

backup_conf() { cp "$CONF" "$CONF_BAK" 2>/dev/null; }

get_ips() {
    sed -n '/^define WHITELIST = {/,/^}/p' "$CONF" | grep -v 'define\|}' | sed 's/[ ,]//g' | grep -v '^$'
}

get_ports() {
    sed -n '/^define WHITELIST_PORTS = {/,/^}/p' "$CONF" | grep -E '\b[0-9]+,' | sed 's/[ ,]//g' | grep -v '^$'
}

classify_input() {
    local item="$1"
    if [[ "$item" =~ ^[0-9]+$ ]] && (( item >= 1 && item <= 65535 )); then
        echo "port"
    elif [[ "$item" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$ ]]; then
        echo "cidr"
    elif [[ "$item" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "ip"
    else
        echo "unknown"
    fi
}

# 1. 添加白名单
add_items() {
    echo ""
    echo "添加白名单（逗号分隔，混合 IP/网段/端口）"
    echo "示例: 1.2.3.4,10.0.0.0/8,8080,443"
    echo ""
    read -p "请输入: " input
    [ -z "$input" ] && { echo "⚠️ 未输入"; return; }

    backup_conf
    IFS=',' read -ra items <<< "$input"

    local added_ips=() added_ports=() skipped=()

    for item in "${items[@]}"; do
        item=$(echo "$item" | xargs)
        [ -z "$item" ] && continue
        local type=$(classify_input "$item")

        case "$type" in
            ip|cidr)
                grep -q "$item" "$CONF" 2>/dev/null && { skipped+=("$item(已存在)"); continue; }
                sed -i "/^define WHITELIST = {$/a\\    ${item}," "$CONF"
                added_ips+=("$item")
                ;;
            port)
                grep -q "^\s*${item}," "$CONF" 2>/dev/null && { skipped+=("$item(已存在)"); continue; }
                sed -i "/^define WHITELIST_PORTS = {$/a\\    ${item}," "$CONF"
                added_ports+=("$item")
                ;;
            *) skipped+=("$item(格式错误)") ;;
        esac
    done

    [ ${#added_ips[@]} -gt 0 ] && echo "✅ 已添加 IP/网段: ${added_ips[*]}"
    [ ${#added_ports[@]} -gt 0 ] && echo "✅ 已添加端口: ${added_ports[*]}"
    [ ${#skipped[@]} -gt 0 ] && echo "⚠️ 跳过: ${skipped[*]}"

    apply
}

# 2. 删除白名单
del_items() {
    echo ""
    echo "=== 当前白名单 ==="

    local all_items=() idx=1

    local ips=$(get_ips)
    if [ -n "$ips" ]; then
        echo ""
        echo "--- IP/网段 ---"
        while IFS= read -r line; do
            [ -z "$line" ] && continue
            printf "  [%d] %s\n" "$idx" "$line"
            all_items+=("$line")
            ((idx++))
        done <<< "$ips"
    fi

    local ports=$(get_ports)
    if [ -n "$ports" ]; then
        echo ""
        echo "--- 端口 ---"
        while IFS= read -r line; do
            [ -z "$line" ] && continue
            printf "  [%d] %s\n" "$idx" "$line"
            all_items+=("$line")
            ((idx++))
        done <<< "$ports"
    fi

    if [ ${#all_items[@]} -eq 0 ]; then
        echo "  (空)"
        return
    fi

    echo ""
    read -p "输入要删除的序号（逗号分隔，如 1,3,5）: " selection
    [ -z "$selection" ] && { echo "⚠️ 未选择"; return; }

    backup_conf
    IFS=',' read -ra indices <<< "$selection"
    local removed=()

    for idx in "${indices[@]}"; do
        idx=$(echo "$idx" | xargs)
        if ! [[ "$idx" =~ ^[0-9]+$ ]] || (( idx < 1 || idx > ${#all_items[@]} )); then
            echo "⚠️ 无效序号: $idx"
            continue
        fi
        local target="${all_items[$((idx-1))]}"
        sed -i "/${target}/d" "$CONF"
        removed+=("$target")
    done

    [ ${#removed[@]} -gt 0 ] && { echo "✅ 已删除: ${removed[*]}"; apply; }
}

# 3. 查看状态
show_status() {
    echo ""
    echo "=== 防火墙状态 ==="
    systemctl is-active nftables &>/dev/null && echo "  服务: 运行中 ✅" || echo "  服务: 未运行 ❌"
    systemctl is-enabled nftables &>/dev/null && echo "  自启: 已开启 ✅" || echo "  自启: 未开启 ❌"

    echo ""
    echo "=== 白名单 IP/网段 ==="
    local ips=$(get_ips)
    [ -n "$ips" ] && echo "$ips" | while read -r l; do echo "  $l"; done || echo "  (空)"

    echo ""
    echo "=== 白名单端口 ==="
    local ports=$(get_ports)
    [ -n "$ports" ] && echo "$ports" | while read -r l; do echo "  $l"; done || echo "  (空)"
    echo ""
}

# 4. 重新加载
reload_conf() { apply; }

# 5. 导出当前白名单
export_whitelist() {
    {
        echo "# nftables 白名单导出"
        echo "# 主机: $(hostname)"
        echo "# 时间: $(date '+%Y-%m-%d %H:%M:%S')"
        echo ""
        echo "=== IP/网段白名单 ==="
        local ips=$(get_ips)
        [ -n "$ips" ] && echo "$ips" || echo "(空)"
        echo ""
        echo "=== 端口白名单 ==="
        local ports=$(get_ports)
        [ -n "$ports" ] && echo "$ports" || echo "(空)"
        echo ""
        echo "=== 完整配置文件 ==="
        cat "$CONF"
    } > "$EXPORT_FILE"

    echo "✅ 已导出到: $EXPORT_FILE"
}

# 主菜单
main() {
    check_nft
    init_conf

    while true; do
        echo ""
        echo "╔══════════════════════════════════╗"
        echo "║   nftables 防火墙管理            ║"
        echo "╠══════════════════════════════════╣"
        echo "║  1. 添加白名单（IP/网段/端口）   ║"
        echo "║  2. 删除白名单                   ║"
        echo "║  3. 查看当前配置                 ║"
        echo "║  4. 重新加载配置                 ║"
        echo "║  5. 导出白名单到文件             ║"
        echo "║  6. 关闭防火墙                   ║"
        echo "║  0. 退出                         ║"
        echo "╚══════════════════════════════════╝"
        echo ""
        read -p "请选择: " choice

        case "$choice" in
            1) add_items ;;
            2) del_items ;;
            3) show_status ;;
            4) reload_conf ;;
            5) export_whitelist ;;
            6) nft flush ruleset && echo "✅ 防火墙已关闭" ;;
            0) echo "👋 退出"; exit 0 ;;
            *) echo "⚠️ 无效选项" ;;
        esac
    done
}

main
