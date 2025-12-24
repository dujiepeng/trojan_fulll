#!/bin/bash

# ==========================================================
# Jrohy/trojan 增强安装脚本 (Fixed Edition)
# 功能：完全复现原脚本 logic，修复 Docker 下载 404 及 APT 锁定错误
# ==========================================================

set -e

# --- 环境变量与配置 ---
# --- 环境变量与配置 (已本地化到 dujiepeng/trojan_fulll) ---
# 注意：二进制文件建议手动上传到您仓库的 Releases 中，以下链接需对应修改
download_url="https://github.com/dujiepeng/trojan_fulll/releases/download/"
version_check="https://api.github.com/repos/dujiepeng/trojan_fulll/releases/latest"
service_url="https://raw.githubusercontent.com/dujiepeng/trojan_fulll/main/trojan-web.service"
acme_url="https://raw.githubusercontent.com/dujiepeng/trojan_fulll/main/acme.sh"
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

# --- 2. 增强型 Docker 预安装 (解决 404 错误) ---
# 原脚本在安装 Trojan 管理器后会自动调用 docker 安装逻辑，
# 如果我们提前以正确的方式安装好 Docker，管理器就不会再尝试下载那个失效的 404 链接。
install_docker_fixed() {
    if command -v docker >/dev/null 2>&1; then
        colorEcho $GREEN "Docker 已存在，跳过安装。"
        return
    fi

    colorEcho $BLUE ">>> 正在通过稳定的静态二进制方式预装 Docker..."
    DOCKER_VERSION="27.3.1"
    DOCKER_URL="https://download.docker.com/linux/static/stable/x86_64/docker-${DOCKER_VERSION}.tgz"
    
    # 根据架构调整下载地址 (原脚本支持 arm64)
    if [[ $arch == "aarch64" ]]; then
        DOCKER_URL="https://download.docker.com/linux/static/stable/aarch64/docker-${DOCKER_VERSION}.tgz"
    fi

    wget -qO- ${DOCKER_URL} | tar xvfz - --strip-components=1 -C /tmp/
    sudo mv /tmp/docker* /usr/local/bin/ 2>/dev/null || true
    sudo mv /tmp/containerd* /usr/local/bin/ 2>/dev/null || true
    sudo mv /tmp/runc /usr/local/bin/ 2>/dev/null || true
    sudo mv /tmp/ctr /usr/local/bin/ 2>/dev/null || true
    
    # 启动 Docker 服务
    if [[ `command -v systemctl` ]]; then
        # 创建一个简单的 docker service 如果没有的话
        if [[ ! -f /etc/systemd/system/docker.service ]]; then
            cat <<EOF | sudo tee /etc/systemd/system/docker.service
[Unit]
Description=Docker Application Container Engine
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/dockerd
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
            sudo systemctl daemon-reload
            sudo systemctl enable docker
            sudo systemctl start docker
        fi
    else
        sudo /usr/local/bin/dockerd > /var/log/dockerd.log 2>&1 &
    fi
    colorEcho $GREEN "Docker 预装完成并已启动。"
}

# --- 3. 复刻 Jrohy 原脚本核心逻辑 ---
installTrojanManager() {
    colorEcho $BLUE ">>> 正在按原脚本逻辑安装 Trojan 管理程序..."
    
    # 停止可能正在运行的服务，防止二进制文件忙
    systemctl stop trojan-web 2>/dev/null || true
    systemctl stop trojan 2>/dev/null || true
    
    # 彻底清理可能占用该文件的进程
    if command -v fuser >/dev/null 2>&1; then
        fuser -k /usr/local/bin/trojan 2>/dev/null || true
    fi
    
    # 预装 acme.sh (防止管理器在运行时从失效的源下载)
    if [[ ! -e ~/.acme.sh/acme.sh ]]; then
        colorEcho $BLUE ">>> 正在预装 acme.sh..."
        # 修复安装失败问题：使用官方推荐的 pipe-to-shell 配合 --install-online 模式
        # 这会自动处理源码下载和路径定位，彻底解决 "cannot stat 'acme.sh'" 报错
        curl -sL $acme_url | sh -s -- --install-online --accountemail "my@example.com"
    fi

    # 获取最新版本 (增加容错逻辑)
    latest_version=$(curl -H 'Cache-Control: no-cache' -s "$version_check" | grep 'tag_name' | cut -d\" -f4 || echo "")
    if [ -z "$latest_version" ]; then
        latest_version="v2.15.3"
        colorEcho $YELLOW "提示：无法通过 API 获取版本，将执行本地化备份版本 $latest_version"
    fi
    [[ $arch == x86_64 ]] && bin="trojan-linux-amd64" || bin="trojan-linux-arm64" 
    
    # 优先从您的仓库下载，如果下载失败则尝试从原官方仓库下载 (作为双保险)
    colorEcho $BLUE "正在下载管理程序 $latest_version 版本..."
    if ! curl -L "$download_url/$latest_version/$bin" -o /usr/local/bin/trojan.new; then
        colorEcho $YELLOW "警告：从您的仓库下载失败，尝试从原官方源下载..."
        curl -L "https://github.com/Jrohy/trojan/releases/download/$latest_version/$bin" -o /usr/local/bin/trojan.new
    fi
    chmod +x /usr/local/bin/trojan.new
    mv -f /usr/local/bin/trojan.new /usr/local/bin/trojan
    
    # 安装服务
    if [[ ! -e /etc/systemd/system/trojan-web.service ]]; then
        curl -L $service_url -o /etc/systemd/system/trojan-web.service
        systemctl daemon-reload
        systemctl enable trojan-web
    fi
    
    colorEcho $GREEN "Trojan 管理程序安装成功！"
    echo -e "即将运行管理器进行面板初始化..."
    sleep 2
    
    # 运行管理器 (它会检测到 Docker 已安装，从而避免之前的 404 错误路径)
    /usr/local/bin/trojan
}

# --- 4. 卸载功能 ---
removeTrojan() {
    colorEcho $BLUE "正在进行普通卸载..."
    
    # 停止并禁用服务
    systemctl stop trojan-web trojan 2>/dev/null || true
    systemctl disable trojan-web trojan 2>/dev/null || true
    
    # 删除二进制文件和系统服务
    rm -f /usr/local/bin/trojan /usr/local/bin/trojan.new /usr/local/bin/trojan.bak 2>/dev/null
    rm -f /etc/systemd/system/trojan-web.service /etc/systemd/system/trojan.service 2>/dev/null
    systemctl daemon-reload
    
    # 删除配置
    rm -rf /usr/local/etc/trojan 2>/dev/null
    
    colorEcho $GREEN "普通卸载完成。"
}

fullRemoveTrojan() {
    colorEcho $RED "警告：正在进行全量卸载，将删除 Docker 及其所有数据！"
    sleep 2
    
    # 执行普通卸载
    removeTrojan
    
    # 停止并移除所有容器
    if command -v docker >/dev/null 2>&1; then
        colorEcho $BLUE "清理 Docker 容器与数据..."
        docker stop $(docker ps -aq) 2>/dev/null || true
        docker rm $(docker ps -aq) 2>/dev/null || true
        
        # 停止 Docker 服务
        systemctl stop docker 2>/dev/null || true
        systemctl disable docker 2>/dev/null || true
        
        # 删除 Docker 数据和二进制
        rm -rf /var/lib/docker /etc/docker 2>/dev/null
        rm -rf /var/run/docker.sock 2>/dev/null
        rm -f /usr/local/bin/docker* /usr/local/bin/containerd* /usr/local/bin/runc /usr/local/bin/ctr 2>/dev/null
    fi
    
    # 清理 acme.sh
    rm -rf ~/.acme.sh 2>/dev/null
    
    colorEcho $GREEN "全量卸载完成。"
}

main() {
    # 权限检查
    [ $(id -u) != "0" ] && { colorEcho $RED "错误: 必须以 root 权限运行"; exit 1; }
    
    echo -e "
  ${BLUE}Trojan 增强安装脚本 (Fixed Edition)${NC}
  ---------------------------------
  ${GREEN}1.${NC} 安装/更新 Trojan (修复 Docker 404)
  ${GREEN}2.${NC} 普通卸载 (保留 Docker)
  ${GREEN}3.${NC} 全量卸载 (清理 Docker 及所有数据)
  ${GREEN}0.${NC} 退出
  ---------------------------------
    "
    read -p "请输入数字选择 [0-3]: " choice
    case $choice in
        1)
            fix_apt_lock
            if [[ `command -v apt-get` ]]; then
                apt-get update && apt-get install -y socat cron xz-utils curl wget
            elif [[ `command -v yum` ]]; then
                yum install -y socat crontabs xz curl wget
            fi
            install_docker_fixed
            installTrojanManager
            ;;
        2)
            removeTrojan
            ;;
        3)
            fullRemoveTrojan
            ;;
        0)
            exit 0
            ;;
        *)
            colorEcho $RED "无效选择，退出。"
            exit 1
            ;;
    esac
}

main
