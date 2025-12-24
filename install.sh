#!/bin/bash

# ==========================================================
# Jrohy/trojan 增强安装脚本 (Fixed Edition v1.2.3)
# 功能：极简回归版，修复 Docker 404、acme.sh 路径及 Docker API 协议
# ==========================================================

set -e

# --- 环境变量与配置 (已本地化到 dujiepeng/trojan_fulll) ---
download_url="https://github.com/dujiepeng/trojan_fulll/releases/download/"
version_check="https://api.github.com/repos/dujiepeng/trojan_fulll/releases/latest"
service_url="https://raw.githubusercontent.com/dujiepeng/trojan_fulll/main/trojan-web.service"
package_manager=""
arch=$(uname -m)

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

colorEcho() {
    color=$1
    echo -e "${color}${@:2}${NC}"
}

# --- 1. 自动处理 APT 锁问题 ---
fix_apt_lock() {
    if [[ `command -v apt-get` ]]; then
        echo -e "${BLUE}>>> 检查并清理 APT 锁定...${NC}"
        sudo killall apt apt-get unattended-upgr 2>/dev/null || true
        sudo rm -f /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/cache/apt/archives/lock /var/lib/apt/lists/lock
        sudo dpkg --configure -a
    fi
}

# --- 2. 核心安装逻辑 (回归原脚本结构) ---
installTrojan() {
    # 功能：回归原脚本结构的 Trojan 安装逻辑 (v1.2.3)
    
    # A. 辅助准备 (非强制，自愈冲突)
    # 物理删除之前版本可能滥用的 Service 文件
    sudo rm -f /etc/systemd/system/docker.service 2>/dev/null || true
    
    if ! docker info >/dev/null 2>&1; then
        colorEcho $BLUE ">>> 正在准备基础 Docker 环境 (原生方式)..."
        if [[ ${package_manager} == 'apt-get' ]]; then
            sudo apt-get update && sudo apt-get install -y docker.io
        elif [[ ${package_manager} == 'yum' || ${package_manager} == 'dnf' ]]; then
            sudo ${package_manager} install -y docker
        fi
        sudo systemctl unmask docker.service 2>/dev/null || true
        sudo systemctl enable --now docker 2>/dev/null || true
        [[ -S /var/run/docker.sock ]] && sudo chmod 666 /var/run/docker.sock
    fi

    # B. 安装管理程序
    colorEcho $BLUE ">>> 正在安装 Trojan 管理程序 (Localized URLs)..."
    
    # 获取最新版本
    latest_version=$(curl -H 'Cache-Control: no-cache' -s "$version_check" | grep 'tag_name' | cut -d\" -f4 || echo "")
    if [ -z "$latest_version" ]; then
        latest_version="v2.15.3"
        colorEcho $YELLOW "提示：执行本地化备份版本 $latest_version"
    fi
    [[ $arch == x86_64 ]] && bin="trojan-linux-amd64" || bin="trojan-linux-arm64" 
    
    # 下载程序 (带双源备份)
    if ! curl -L "$download_url/$latest_version/$bin" -o /usr/local/bin/trojan; then
        colorEcho $YELLOW "尝试官方源备份下载..."
        curl -L "https://github.com/Jrohy/trojan/releases/download/$latest_version/$bin" -o /usr/local/bin/trojan
    fi
    chmod +x /usr/local/bin/trojan
    
    # C. 配置服务
    if [[ ! -e /etc/systemd/system/trojan-web.service ]]; then
        curl -L $service_url -o /etc/systemd/system/trojan-web.service
        systemctl daemon-reload
        systemctl enable trojan-web
    fi
    
    # D. 预装 acme.sh (回归官方源修复版)
    if [[ ! -e ~/.acme.sh/acme.sh ]]; then
        colorEcho $BLUE ">>> 正在预装 acme.sh (原生修复方式)..."
        curl -sL https://get.acme.sh | sh -s -- --install-online --accountemail "my@example.com"
    fi
    
    colorEcho $GREEN "Trojan 管理程序安装成功！"
    echo -e "即将运行管理器进行初始化..."
    sleep 2
    
    # E. 注入环境兼容性并启动
    export DOCKER_API_VERSION=1.35
    /usr/local/bin/trojan
}

# --- 3. 卸载功能 ---
removeTrojan() {
    colorEcho $BLUE "正在进行普通卸载..."
    systemctl stop trojan-web trojan 2>/dev/null || true
    systemctl disable trojan-web trojan 2>/dev/null || true
    rm -f /usr/local/bin/trojan /etc/systemd/system/trojan-web.service 2>/dev/null
    systemctl daemon-reload
    colorEcho $GREEN "普通卸载完成。"
}

fullRemoveTrojan() {
    colorEcho $RED "正在执行全量卸载..."
    removeTrojan
    if command -v docker >/dev/null 2>&1; then
        docker stop $(docker ps -aq) 2>/dev/null || true
        docker rm $(docker ps -aq) 2>/dev/null || true
    fi
    rm -rf /usr/local/etc/trojan ~/.acme.sh 2>/dev/null
    colorEcho $GREEN "全量卸载完成。"
}

# --- 4. 主入口 ---
main() {
    [ $(id -u) != "0" ] && { colorEcho $RED "错误: 必须以 root 权限运行"; exit 1; }
    
    # 确定包管理器
    if [[ `command -v apt-get` ]]; then
        package_manager='apt-get'
    elif [[ `command -v yum` ]]; then
        package_manager='yum'
    fi

    echo -e "
  ${BLUE}Trojan 增强安装脚本 (Fixed Edition v1.2.3)${NC}
  ---------------------------------
  ${GREEN}1.${NC} 安装/更新 Trojan
  ${GREEN}2.${NC} 普通卸载
  ${GREEN}3.${NC} 全量卸载
  ${GREEN}0.${NC} 退出
  ---------------------------------
    "
    read -p "选择 [0-3]: " choice
    case $choice in
        1)
            fix_apt_lock
            if [[ ${package_manager} == 'apt-get' ]]; then
                apt-get update && apt-get install -y socat cron xz-utils curl wget iptables iproute2 mariadb-client
            else
                yum install -y socat crontabs xz curl wget iptables mariadb
            fi
            installTrojan
            ;;
        2) removeTrojan ;;
        3) fullRemoveTrojan ;;
        0) exit 0 ;;
        *) exit 1 ;;
    esac
}

main
