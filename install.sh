#!/bin/bash

# ==========================================================
# Jrohy/trojan 增强安装脚本 (Fixed Edition)
# 功能：完全复现原脚本 logic，修复 Docker 下载 404 及 APT 锁定错误
# ==========================================================

set -e

# --- 环境变量与配置 ---
download_url="https://github.com/Jrohy/trojan/releases/download/"
version_check="https://api.github.com/repos/Jrohy/trojan/releases/latest"
service_url="https://raw.githubusercontent.com/Jrohy/trojan/master/asset/trojan-web.service"
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
    
    # 获取最新版本
    lastest_version=$(curl -H 'Cache-Control: no-cache' -s "$version_check" | grep 'tag_name' | cut -d\" -f4)
    [[ $arch == x86_64 ]] && bin="trojan-linux-amd64" || bin="trojan-linux-arm64" 
    
    # 下载管理程序
    curl -L "$download_url/$lastest_version/$bin" -o /usr/local/bin/trojan
    chmod +x /usr/local/bin/trojan
    
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

main() {
    # 权限检查
    [ $(id -u) != "0" ] && { colorEcho $RED "错误: 必须以 root 权限运行"; exit 1; }
    
    fix_apt_lock
    
    # 安装依赖
    if [[ `command -v apt-get` ]]; then
        apt-get update && apt-get install -y socat cron xz-utils curl wget
    elif [[ `command -v yum` ]]; then
        yum install -y socat crontabs xz curl wget
    fi

    install_docker_fixed
    installTrojanManager
}

main
