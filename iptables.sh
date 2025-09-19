#!/bin/bash

# iptables端口转发管理脚本（支持动态域名解析）
# 功能：1. 添加新的端口转发规则 2. 修改现有规则 3. 导出导入规则 4. 动态域名解析

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置文件路径
RULES_FILE="/etc/iptables/port_forward_rules.txt"
BACKUP_DIR="/etc/iptables/backups"
PID_FILE="/var/run/iptables_manager.pid"
LOG_FILE="/var/log/iptables_manager.log"
CHECK_INTERVAL=60  # 域名解析检查间隔（秒）

# 确保目录存在
mkdir -p /etc/iptables
mkdir -p "$BACKUP_DIR"

# 检查是否为root用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}错误: 此脚本需要root权限运行${NC}"
        exit 1
    fi
}

# 输入验证函数
validate_port() {
    local port=$1
    if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        return 1
    fi
    return 0
}

validate_ip() {
    local ip=$1
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        IFS='.' read -ra ADDR <<< "$ip"
        for i in "${ADDR[@]}"; do
            if [ "$i" -gt 255 ]; then
                return 1
            fi
        done
        return 0
    fi
    return 1
}

# 验证域名格式
validate_domain() {
    local domain=$1
    # 基本域名格式验证：字母、数字、点、连字符，不能以点或连字符开头结尾
    if [[ $domain =~ ^[a-zA-Z0-9]([a-zA-Z0-9\.-]*[a-zA-Z0-9])?$ ]] && [[ ${#domain} -le 253 ]]; then
        # 检查是否包含至少一个点（除非是localhost这样的特殊情况）
        if [[ $domain == "localhost" ]] || [[ $domain =~ \. ]]; then
            return 0
        fi
    fi
    return 1
}

# 验证IP地址或域名
validate_ip_or_domain() {
    local target=$1
    if validate_ip "$target" || validate_domain "$target"; then
        return 0
    fi
    return 1
}

# 解析域名为IP地址
resolve_domain() {
    local domain=$1
    local resolved_ip

    # 如果已经是IP地址，直接返回
    if validate_ip "$domain"; then
        echo "$domain"
        return 0
    fi

    # 尝试解析域名
    resolved_ip=$(nslookup "$domain" 2>/dev/null | grep -A1 "Name:" | grep "Address:" | awk '{print $2}' | head -n1)

    # 如果nslookup失败，尝试使用dig
    if [ -z "$resolved_ip" ] || ! validate_ip "$resolved_ip"; then
        resolved_ip=$(dig +short "$domain" 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -n1)
    fi

    # 如果dig也失败，尝试使用host
    if [ -z "$resolved_ip" ] || ! validate_ip "$resolved_ip"; then
        resolved_ip=$(host "$domain" 2>/dev/null | grep "has address" | awk '{print $4}' | head -n1)
    fi

    # 验证解析结果
    if [ -n "$resolved_ip" ] && validate_ip "$resolved_ip"; then
        echo "$resolved_ip"
        return 0
    else
        return 1
    fi
}

# 启用IP转发
enable_ip_forward() {
    echo 1 > /proc/sys/net/ipv4/ip_forward
    if ! grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf; then
        echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    fi
    echo -e "${GREEN}IP转发已启用${NC}"
}

# 日志记录函数
log_message() {
    local message="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$LOG_FILE"
}

# 保存规则到文件（新格式：支持域名标记）
save_rule() {
    local src_port=$1
    local dst_target=$2
    local dst_port=$3
    local protocol=$4
    local rule_type=$5  # "ip" 或 "domain"
    local current_ip=$6

    echo "${src_port}:${dst_target}:${dst_port}:${protocol}:${rule_type}:${current_ip}" >> "$RULES_FILE"
}

# 从文件删除规则（兼容新格式）
remove_rule_from_file() {
    local src_port=$1
    local dst_target=$2
    local protocol=$3

    if [ -f "$RULES_FILE" ]; then
        sed -i "/^${src_port}:${dst_target}:.*:${protocol}:/d" "$RULES_FILE"
    fi
}

# 添加iptables规则
add_iptables_rule() {
    local src_port=$1
    local dst_ip=$2
    local dst_port=$3
    local protocol=$4

    # 添加PREROUTING规则（DNAT）
    iptables -t nat -A PREROUTING -p "$protocol" --dport "$src_port" -j DNAT --to-destination "${dst_ip}:${dst_port}"

    # 添加FORWARD规则
    iptables -A FORWARD -p "$protocol" -d "$dst_ip" --dport "$dst_port" -j ACCEPT

    # 添加POSTROUTING规则（SNAT）- 如果需要
    iptables -t nat -A POSTROUTING -p "$protocol" -d "$dst_ip" --dport "$dst_port" -j MASQUERADE
}

# 删除iptables规则
remove_iptables_rule() {
    local src_port=$1
    local dst_ip=$2
    local dst_port=$3
    local protocol=$4

    # 删除PREROUTING规则
    iptables -t nat -D PREROUTING -p "$protocol" --dport "$src_port" -j DNAT --to-destination "${dst_ip}:${dst_port}" 2>/dev/null || true

    # 删除FORWARD规则
    iptables -D FORWARD -p "$protocol" -d "$dst_ip" --dport "$dst_port" -j ACCEPT 2>/dev/null || true

    # 删除POSTROUTING规则
    iptables -t nat -D POSTROUTING -p "$protocol" -d "$dst_ip" --dport "$dst_port" -j MASQUERADE 2>/dev/null || true
}

# 更新iptables规则
update_iptables_rule() {
    local src_port=$1
    local old_ip=$2
    local new_ip=$3
    local dst_port=$4
    local protocol=$5
    local domain=$6

    log_message "更新规则: $domain ($old_ip -> $new_ip), 端口: $src_port -> $dst_port ($protocol)"

    # 删除旧规则
    remove_iptables_rule "$src_port" "$old_ip" "$dst_port" "$protocol"

    # 添加新规则
    add_iptables_rule "$src_port" "$new_ip" "$dst_port" "$protocol"

    log_message "规则更新完成"
}

# 检查并更新域名解析
check_and_update_domain_rules() {
    if [ ! -f "$RULES_FILE" ]; then
        return
    fi

    local temp_file=$(mktemp)
    local updated=false

    while IFS=':' read -r src_port dst_target dst_port protocol rule_type current_ip; do
        # 跳过空行和格式不正确的行
        if [ -z "$src_port" ] || [ -z "$dst_target" ]; then
            continue
        fi

        # 兼容旧格式（4个字段）
        if [ -z "$rule_type" ]; then
            if validate_ip "$dst_target"; then
                rule_type="ip"
                current_ip="$dst_target"
            else
                rule_type="domain"
                current_ip=$(resolve_domain "$dst_target" 2>/dev/null || echo "")
            fi
        fi

        if [ "$rule_type" = "domain" ]; then
            # 重新解析域名
            new_ip=$(resolve_domain "$dst_target")
            if [ $? -eq 0 ] && [ "$new_ip" != "$current_ip" ]; then
                echo -e "${YELLOW}检测到域名 $dst_target IP变化: $current_ip -> $new_ip${NC}"
                log_message "域名 $dst_target IP变化: $current_ip -> $new_ip"

                # 更新iptables规则
                update_iptables_rule "$src_port" "$current_ip" "$new_ip" "$dst_port" "$protocol" "$dst_target"

                # 更新规则文件中的IP
                echo "${src_port}:${dst_target}:${dst_port}:${protocol}:${rule_type}:${new_ip}" >> "$temp_file"
                updated=true
            elif [ $? -eq 0 ]; then
                # IP没有变化，保持原样
                echo "${src_port}:${dst_target}:${dst_port}:${protocol}:${rule_type}:${current_ip}" >> "$temp_file"
            else
                log_message "警告: 无法解析域名 $dst_target"
                echo "${src_port}:${dst_target}:${dst_port}:${protocol}:${rule_type}:${current_ip}" >> "$temp_file"
            fi
        else
            # IP规则，直接保持
            echo "${src_port}:${dst_target}:${dst_port}:${protocol}:${rule_type}:${current_ip}" >> "$temp_file"
        fi
    done < "$RULES_FILE"

    # 如果有更新，替换原文件
    if [ "$updated" = true ]; then
        mv "$temp_file" "$RULES_FILE"
        log_message "规则文件已更新"
    else
        rm -f "$temp_file"
    fi
}

# 守护进程模式
daemon_mode() {
    echo -e "${GREEN}启动域名监控守护进程...${NC}"
    log_message "域名监控守护进程启动"

    # 检查是否已有守护进程运行
    if [ -f "$PID_FILE" ]; then
        local old_pid=$(cat "$PID_FILE")
        if kill -0 "$old_pid" 2>/dev/null; then
            echo -e "${YELLOW}守护进程已在运行 (PID: $old_pid)${NC}"
            exit 1
        else
            rm -f "$PID_FILE"
        fi
    fi

    # 创建PID文件
    echo $$ > "$PID_FILE"

    # 设置信号处理
    trap 'cleanup_daemon' SIGTERM SIGINT

    echo -e "${GREEN}守护进程已启动 (PID: $$)，检查间隔: ${CHECK_INTERVAL}秒${NC}"

    while true; do
        check_and_update_domain_rules
        sleep "$CHECK_INTERVAL"
    done
}

# 清理守护进程
cleanup_daemon() {
    log_message "守护进程正在退出"
    rm -f "$PID_FILE"
    echo -e "${GREEN}守护进程已停止${NC}"
    exit 0
}

# 停止守护进程
stop_daemon() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
            echo -e "${GREEN}守护进程已停止 (PID: $pid)${NC}"
            rm -f "$PID_FILE"
        else
            echo -e "${YELLOW}守护进程未运行${NC}"
            rm -f "$PID_FILE"
        fi
    else
        echo -e "${YELLOW}未找到守护进程PID文件${NC}"
    fi
}

# 检查守护进程状态
status_daemon() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            echo -e "${GREEN}守护进程正在运行 (PID: $pid)${NC}"
            echo "检查间隔: ${CHECK_INTERVAL}秒"
            echo "日志文件: $LOG_FILE"
        else
            echo -e "${RED}守护进程未运行（PID文件存在但进程不存在）${NC}"
            rm -f "$PID_FILE"
        fi
    else
        echo -e "${YELLOW}守护进程未运行${NC}"
    fi
}

# 创建systemd服务文件
create_systemd_service() {
    local service_file="/etc/systemd/system/iptables-manager.service"
    local script_path="$(realpath "$0")"

    echo -e "${BLUE}=== 创建systemd服务 ===${NC}"

    if [ -f "$service_file" ]; then
        echo -e "${YELLOW}systemd服务文件已存在${NC}"
        read -p "是否覆盖？(y/N): " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            echo "取消操作"
            return
        fi
    fi

    cat > "$service_file" << EOF
[Unit]
Description=Iptables Port Forward Manager Daemon
Documentation=Dynamic domain resolution monitoring for iptables port forwarding
After=network.target iptables.service
Wants=network.target

[Service]
Type=forking
User=root
Group=root
ExecStart=$script_path daemon
ExecStop=$script_path stop
ExecReload=/bin/kill -HUP \$MAINPID
PIDFile=$PID_FILE
Restart=on-failure
RestartSec=5
KillMode=process

# 安全配置
NoNewPrivileges=false
ProtectSystem=false
ProtectHome=false

# 日志配置
StandardOutput=journal
StandardError=journal
SyslogIdentifier=iptables-manager

[Install]
WantedBy=multi-user.target
EOF

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}systemd服务文件已创建: $service_file${NC}"
        echo -e "${BLUE}使用以下命令管理服务:${NC}"
        echo "  启动服务: systemctl start iptables-manager"
        echo "  停止服务: systemctl stop iptables-manager"
        echo "  启用开机自启: systemctl enable iptables-manager"
        echo "  查看服务状态: systemctl status iptables-manager"
        echo "  查看日志: journalctl -u iptables-manager -f"

        # 重载systemd配置
        systemctl daemon-reload
        echo -e "${GREEN}systemd配置已重载${NC}"
    else
        echo -e "${RED}创建systemd服务文件失败${NC}"
    fi
}

# 删除systemd服务文件
remove_systemd_service() {
    local service_file="/etc/systemd/system/iptables-manager.service"

    echo -e "${BLUE}=== 删除systemd服务 ===${NC}"

    if [ ! -f "$service_file" ]; then
        echo -e "${YELLOW}systemd服务文件不存在${NC}"
        return
    fi

    # 停止服务
    if systemctl is-active --quiet iptables-manager; then
        echo -e "${YELLOW}正在停止服务...${NC}"
        systemctl stop iptables-manager
    fi

    # 禁用服务
    if systemctl is-enabled --quiet iptables-manager; then
        echo -e "${YELLOW}正在禁用服务...${NC}"
        systemctl disable iptables-manager
    fi

    # 删除服务文件
    rm -f "$service_file"

    # 重载systemd配置
    systemctl daemon-reload

    echo -e "${GREEN}systemd服务已删除${NC}"
}

# 添加新的端口转发规则
add_port_forward() {
    echo -e "${BLUE}=== 添加新的端口转发规则 ===${NC}"

    # 输入来源端口
    while true; do
        read -p "请输入来源端口 (1-65535): " src_port
        if validate_port "$src_port"; then
            break
        else
            echo -e "${RED}无效的端口号，请输入1-65535之间的数字${NC}"
        fi
    done

    # 输入目的IP或域名
    while true; do
        read -p "请输入目的IP地址或域名: " dst_target
        if validate_ip_or_domain "$dst_target"; then
            # 如果是域名，尝试解析为IP
            if ! validate_ip "$dst_target"; then
                echo -e "${YELLOW}检测到域名，正在解析...${NC}"
                resolved_ip=$(resolve_domain "$dst_target")
                if [ $? -eq 0 ]; then
                    echo -e "${GREEN}域名 $dst_target 解析为: $resolved_ip${NC}"
                    dst_ip="$resolved_ip"
                    dst_display="$dst_target ($resolved_ip)"
                else
                    echo -e "${RED}无法解析域名: $dst_target${NC}"
                    continue
                fi
            else
                dst_ip="$dst_target"
                dst_display="$dst_target"
            fi
            break
        else
            echo -e "${RED}无效的IP地址或域名格式${NC}"
        fi
    done

    # 输入目的端口
    while true; do
        read -p "请输入目的端口 (1-65535): " dst_port
        if validate_port "$dst_port"; then
            break
        else
            echo -e "${RED}无效的端口号，请输入1-65535之间的数字${NC}"
        fi
    done

    # 选择协议
    echo "请选择协议:"
    echo "1) TCP"
    echo "2) UDP"
    echo "3) TCP和UDP都要"
    read -p "请选择 (1-3): " protocol_choice

    case $protocol_choice in
        1)
            protocols=("tcp")
            ;;
        2)
            protocols=("udp")
            ;;
        3)
            protocols=("tcp" "udp")
            ;;
        *)
            echo -e "${RED}无效选择，默认使用TCP和UDP${NC}"
            protocols=("tcp" "udp")
            ;;
    esac

    # 启用IP转发
    enable_ip_forward

    # 添加规则
    for protocol in "${protocols[@]}"; do
        add_iptables_rule "$src_port" "$dst_ip" "$dst_port" "$protocol"

        # 确定规则类型
        if validate_ip "$dst_target"; then
            rule_type="ip"
        else
            rule_type="domain"
        fi

        save_rule "$src_port" "$dst_target" "$dst_port" "$protocol" "$rule_type" "$dst_ip"
        echo -e "${GREEN}已添加 ${protocol} 转发规则: ${src_port} -> ${dst_display}:${dst_port}${NC}"
    done

    echo -e "${GREEN}端口转发规则添加完成！${NC}"
    if [ "$rule_type" = "domain" ]; then
        echo -e "${BLUE}提示: 域名规则已添加，建议启动守护进程以自动监控域名解析变化${NC}"
        echo -e "${BLUE}命令: $0 daemon${NC}"
    fi
}

# 显示现有规则（兼容新格式）
show_rules() {
    echo -e "${BLUE}=== 当前端口转发规则 ===${NC}"

    if [ ! -f "$RULES_FILE" ] || [ ! -s "$RULES_FILE" ]; then
        echo "暂无端口转发规则"
        return
    fi

    echo "序号 | 来源端口 | 目的地址 | 目的端口 | 协议 | 类型 | 当前IP"
    echo "-----|----------|----------|----------|------|------|--------"

    local index=1
    while IFS=':' read -r src_port dst_target dst_port protocol rule_type current_ip; do
        # 跳过空行
        if [ -z "$src_port" ]; then
            continue
        fi

        # 兼容旧格式
        if [ -z "$rule_type" ]; then
            if validate_ip "$dst_target"; then
                rule_type="IP"
                current_ip="$dst_target"
            else
                rule_type="域名"
                current_ip="$(resolve_domain "$dst_target" 2>/dev/null || echo "未知")"
            fi
        else
            if [ "$rule_type" = "ip" ]; then
                rule_type="IP"
            else
                rule_type="域名"
            fi
        fi

        printf "%-4s | %-8s | %-8s | %-8s | %-4s | %-4s | %s\n" "$index" "$src_port" "$dst_target" "$dst_port" "$protocol" "$rule_type" "$current_ip"
        ((index++))
    done < "$RULES_FILE"
}

# 修改现有规则
modify_rule() {
    echo -e "${BLUE}=== 修改现有端口转发规则 ===${NC}"

    if [ ! -f "$RULES_FILE" ] || [ ! -s "$RULES_FILE" ]; then
        echo -e "${YELLOW}暂无端口转发规则可修改${NC}"
        return
    fi

    show_rules

    local total_rules=$(wc -l < "$RULES_FILE")
    echo
    read -p "请选择要修改的规则序号 (1-$total_rules): " rule_num

    if ! [[ "$rule_num" =~ ^[0-9]+$ ]] || [ "$rule_num" -lt 1 ] || [ "$rule_num" -gt "$total_rules" ]; then
        echo -e "${RED}无效的规则序号${NC}"
        return
    fi

    # 获取原规则（兼容新格式）
    local old_rule=$(sed -n "${rule_num}p" "$RULES_FILE")
    local field_count=$(echo "$old_rule" | tr ':' '\n' | wc -l)

    if [ "$field_count" -eq 6 ]; then
        # 新格式
        IFS=':' read -r old_src_port old_dst_target old_dst_port old_protocol old_rule_type old_current_ip <<< "$old_rule"
    else
        # 旧格式，兼容处理
        IFS=':' read -r old_src_port old_dst_target old_dst_port old_protocol <<< "$old_rule"
        if validate_ip "$old_dst_target"; then
            old_rule_type="ip"
            old_current_ip="$old_dst_target"
        else
            old_rule_type="domain"
            old_current_ip=$(resolve_domain "$old_dst_target" 2>/dev/null || echo "未知")
        fi
    fi

    echo -e "${YELLOW}当前规则: ${old_src_port} -> ${old_dst_target}:${old_dst_port} (${old_protocol}) [${old_rule_type}]${NC}"
    echo

    # 输入新的参数
    read -p "新的来源端口 (当前: $old_src_port, 回车保持不变): " new_src_port
    if [ -z "$new_src_port" ]; then
        new_src_port="$old_src_port"
    elif ! validate_port "$new_src_port"; then
        echo -e "${RED}无效的端口号${NC}"
        return
    fi

    read -p "新的目的IP或域名 (当前: $old_dst_target, 回车保持不变): " new_dst_target
    if [ -z "$new_dst_target" ]; then
        new_dst_target="$old_dst_target"
        new_dst_ip="$old_current_ip"
        new_dst_display="$old_dst_target"
        new_rule_type="$old_rule_type"
    elif validate_ip_or_domain "$new_dst_target"; then
        if ! validate_ip "$new_dst_target"; then
            echo -e "${YELLOW}检测到域名，正在解析...${NC}"
            resolved_ip=$(resolve_domain "$new_dst_target")
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}域名 $new_dst_target 解析为: $resolved_ip${NC}"
                new_dst_ip="$resolved_ip"
                new_dst_display="$new_dst_target ($resolved_ip)"
                new_rule_type="domain"
            else
                echo -e "${RED}无法解析域名: $new_dst_target${NC}"
                return
            fi
        else
            new_dst_ip="$new_dst_target"
            new_dst_display="$new_dst_target"
            new_rule_type="ip"
        fi
    else
        echo -e "${RED}无效的IP地址或域名格式${NC}"
        return
    fi

    read -p "新的目的端口 (当前: $old_dst_port, 回车保持不变): " new_dst_port
    if [ -z "$new_dst_port" ]; then
        new_dst_port="$old_dst_port"
    elif ! validate_port "$new_dst_port"; then
        echo -e "${RED}无效的端口号${NC}"
        return
    fi

    # 删除旧规则
    remove_iptables_rule "$old_src_port" "$old_current_ip" "$old_dst_port" "$old_protocol"

    # 添加新规则
    add_iptables_rule "$new_src_port" "$new_dst_ip" "$new_dst_port" "$old_protocol"

    # 更新文件中的规则
    sed -i "${rule_num}s/.*/${new_src_port}:${new_dst_target}:${new_dst_port}:${old_protocol}:${new_rule_type}:${new_dst_ip}/" "$RULES_FILE"

    echo -e "${GREEN}规则修改完成: ${new_src_port} -> ${new_dst_display}:${new_dst_port} (${old_protocol})${NC}"
}

# 删除规则
delete_rule() {
    echo -e "${BLUE}=== 删除端口转发规则 ===${NC}"

    if [ ! -f "$RULES_FILE" ] || [ ! -s "$RULES_FILE" ]; then
        echo -e "${YELLOW}暂无端口转发规则可删除${NC}"
        return
    fi

    show_rules

    local total_rules=$(wc -l < "$RULES_FILE")
    echo
    read -p "请选择要删除的规则序号 (1-$total_rules): " rule_num

    if ! [[ "$rule_num" =~ ^[0-9]+$ ]] || [ "$rule_num" -lt 1 ] || [ "$rule_num" -gt "$total_rules" ]; then
        echo -e "${RED}无效的规则序号${NC}"
        return
    fi

    # 获取要删除的规则（兼容新格式）
    local rule_to_delete=$(sed -n "${rule_num}p" "$RULES_FILE")
    local field_count=$(echo "$rule_to_delete" | tr ':' '\n' | wc -l)

    if [ "$field_count" -eq 6 ]; then
        # 新格式
        IFS=':' read -r src_port dst_target dst_port protocol rule_type current_ip <<< "$rule_to_delete"
        display_target="$dst_target"
        actual_ip="$current_ip"
    else
        # 旧格式
        IFS=':' read -r src_port dst_target dst_port protocol <<< "$rule_to_delete"
        display_target="$dst_target"
        actual_ip="$dst_target"
    fi

    # 确认删除
    echo -e "${YELLOW}将要删除规则: ${src_port} -> ${display_target}:${dst_port} (${protocol})${NC}"
    read -p "确认删除？(y/N): " confirm

    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        # 删除iptables规则
        remove_iptables_rule "$src_port" "$actual_ip" "$dst_port" "$protocol"

        # 从文件中删除规则
        sed -i "${rule_num}d" "$RULES_FILE"

        echo -e "${GREEN}规则删除完成${NC}"
    else
        echo "取消删除"
    fi
}

# 导出iptables规则
export_rules() {
    echo -e "${BLUE}=== 导出iptables规则 ===${NC}"

    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local export_file="${BACKUP_DIR}/iptables_backup_${timestamp}.txt"

    # 导出所有iptables规则
    iptables-save > "$export_file"

    # 同时备份端口转发规则文件
    if [ -f "$RULES_FILE" ]; then
        cp "$RULES_FILE" "${BACKUP_DIR}/port_forward_rules_${timestamp}.txt"
    fi

    echo -e "${GREEN}iptables规则已导出到: $export_file${NC}"
    echo -e "${GREEN}端口转发规则已备份到: ${BACKUP_DIR}/port_forward_rules_${timestamp}.txt${NC}"
}

# 导入iptables规则
import_rules() {
    echo -e "${BLUE}=== 导入iptables规则 ===${NC}"

    # 列出可用的备份文件
    if [ ! -d "$BACKUP_DIR" ] || [ -z "$(ls -A "$BACKUP_DIR"/iptables_backup_*.txt 2>/dev/null)" ]; then
        echo -e "${YELLOW}未找到备份文件${NC}"
        return
    fi

    echo "可用的备份文件:"
    local index=1
    for file in "$BACKUP_DIR"/iptables_backup_*.txt; do
        if [ -f "$file" ]; then
            local filename=$(basename "$file")
            local filedate=$(echo "$filename" | sed 's/iptables_backup_\(.*\)\.txt/\1/' | sed 's/_/ /')
            echo "$index) $filename (创建时间: $filedate)"
            ((index++))
        fi
    done

    echo
    read -p "请选择要导入的备份文件序号: " file_num

    local selected_file=$(ls "$BACKUP_DIR"/iptables_backup_*.txt | sed -n "${file_num}p")

    if [ ! -f "$selected_file" ]; then
        echo -e "${RED}无效的文件选择${NC}"
        return
    fi

    echo -e "${YELLOW}警告: 导入规则将覆盖当前的iptables配置${NC}"
    read -p "确认导入？(y/N): " confirm

    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        # 备份当前规则
        local backup_current="${BACKUP_DIR}/iptables_before_import_$(date +"%Y%m%d_%H%M%S").txt"
        iptables-save > "$backup_current"
        echo -e "${GREEN}当前规则已备份到: $backup_current${NC}"

        # 导入规则
        iptables-restore < "$selected_file"

        # 恢复端口转发规则文件
        local port_rules_file="${selected_file/iptables_backup_/port_forward_rules_}"
        if [ -f "$port_rules_file" ]; then
            cp "$port_rules_file" "$RULES_FILE"
            echo -e "${GREEN}端口转发规则文件已恢复${NC}"
        fi

        echo -e "${GREEN}iptables规则导入完成${NC}"
    else
        echo "取消导入"
    fi
}

# 清除所有端口转发规则（兼容新格式）
clear_all_rules() {
    echo -e "${BLUE}=== 清除所有端口转发规则 ===${NC}"

    if [ ! -f "$RULES_FILE" ] || [ ! -s "$RULES_FILE" ]; then
        echo -e "${YELLOW}暂无端口转发规则可清除${NC}"
        return
    fi

    echo -e "${YELLOW}警告: 这将删除所有端口转发规则${NC}"
    read -p "确认清除所有规则？(y/N): " confirm

    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        # 读取并删除所有规则
        while IFS=':' read -r src_port dst_target dst_port protocol rule_type current_ip; do
            if [ -z "$src_port" ]; then
                continue
            fi

            # 兼容旧格式
            if [ -z "$current_ip" ]; then
                current_ip="$dst_target"
            fi

            remove_iptables_rule "$src_port" "$current_ip" "$dst_port" "$protocol"
        done < "$RULES_FILE"

        # 清空规则文件
        > "$RULES_FILE"

        echo -e "${GREEN}所有端口转发规则已清除${NC}"
    else
        echo "取消操作"
    fi
}

# 主菜单
show_menu() {
    echo
    echo -e "${BLUE}=====================================${NC}"
    echo -e "${BLUE}     iptables端口转发管理工具        ${NC}"
    echo -e "${BLUE}=====================================${NC}"
    echo "1) 添加新的端口转发规则"
    echo "2) 显示现有规则"
    echo "3) 修改现有规则"
    echo "4) 删除规则"
    echo "5) 导出iptables规则"
    echo "6) 导入iptables规则"
    echo "7) 清除所有端口转发规则"
    echo "8) 手动检查域名解析"
    echo "9) 启动域名监控守护进程"
    echo "10) 停止域名监控守护进程"
    echo "11) 查看守护进程状态"
    echo "12) 创建systemd服务"
    echo "13) 删除systemd服务"
    echo "0) 退出"
    echo -e "${BLUE}=====================================${NC}"
}

# 主程序
main() {
    check_root

    # 处理命令行参数
    case "${1:-}" in
        "daemon")
            daemon_mode
            ;;
        "stop")
            stop_daemon
            exit 0
            ;;
        "status")
            status_daemon
            exit 0
            ;;
        "check")
            echo -e "${BLUE}手动检查域名解析...${NC}"
            check_and_update_domain_rules
            echo -e "${GREEN}检查完成${NC}"
            exit 0
            ;;
        "help"|"--help"|"h")
            echo "用法: $0 [选项]"
            echo "选项:"
            echo "  daemon    启动域名监控守护进程"
            echo "  stop      停止域名监控守护进程"
            echo "  status    查看守护进程状态"
            echo "  check     手动检查域名解析"
            echo "  help      显示此帮助信息"
            echo "  (无参数)   启动交互式菜单"
            exit 0
            ;;
    esac

    while true; do
        show_menu
        read -p "请选择操作 (0-13): " choice

        case $choice in
            1)
                add_port_forward
                ;;
            2)
                show_rules
                ;;
            3)
                modify_rule
                ;;
            4)
                delete_rule
                ;;
            5)
                export_rules
                ;;
            6)
                import_rules
                ;;
            7)
                clear_all_rules
                ;;
            8)
                echo -e "${BLUE}手动检查域名解析...${NC}"
                check_and_update_domain_rules
                echo -e "${GREEN}检查完成${NC}"
                ;;
            9)
                daemon_mode &
                echo -e "${GREEN}守护进程已在后台启动${NC}"
                ;;
            10)
                stop_daemon
                ;;
            11)
                status_daemon
                ;;
            12)
                create_systemd_service
                ;;
            13)
                remove_systemd_service
                ;;
            0)
                echo -e "${GREEN}感谢使用！${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}无效选择，请重新输入${NC}"
                ;;
        esac

        echo
        read -p "按回车键继续..."
    done
}

# 如果脚本被直接执行
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
