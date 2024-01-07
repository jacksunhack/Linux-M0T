#!/bin/bash

# 函数：检测操作系统类型
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        # 检查操作系统名称中是否包含 "CentOS"
        if [[ $NAME == *"CentOS"* ]]; then
            OS="CentOS"
        else
            OS=$NAME
        fi
        VER=$VERSION_ID
    elif type lsb_release >/dev/null 2>&1; then
        OS=$(lsb_release -si)
        VER=$(lsb_release -sr)
    else
        echo "无法检测到操作系统类型。"
        exit 1
    fi
}


# 函数：根据操作系统更新软件包
update_packages() {
    case $OS in
        Ubuntu|Debian)
            sudo apt-get update -y && sudo apt-get upgrade -y && sudo apt-get dist-upgrade -y && sudo apt autoremove -y
            ;;
        CentOS)
            sudo yum update -y && sudo yum upgrade -y
            ;;
        *)
            echo "不支持的操作系统。"
            exit 1
            ;;
    esac
}

# 函数：根据操作系统安装Coturn
install_coturn() {
    case $OS in
        Ubuntu|Debian)
            sudo apt-get install coturn -y
            ;;
        CentOS)
            sudo yum install epel-release -y
            sudo yum install coturn -y
            ;;
        *)
            echo "不支持的操作系统。"
            exit 1
            ;;
    esac
}

# 函数：配置Coturn
configure_coturn() {
    # 获取服务器的公网IP地址
    IP_ADDR=$(curl -4 ip.sb)

    # 生成复杂的static-auth-secret
    AUTH_SECRET=$(< /dev/urandom tr -dc 'A-Za-z0-9+,#*' | head -c 48; echo)

    # 让用户输入realm值
    read -p "请输入realm值(您的Turn域名): " REALM

    # 尝试自动检测用于公网连接的网络接口
    NET_INTERFACE=$(ip route get 1.1.1.1 | grep -oP 'dev \K\S+')

    # 根据操作系统类型选择配置文件路径
    if [ "$OS" = "CentOS" ]; then
        COTURN_CONFIG="/etc/coturn/turnserver.conf"
        # 如果文件不存在，创建它
        if [ ! -f "$COTURN_CONFIG" ]; then
            sudo touch "$COTURN_CONFIG"
        fi
    else
        # Ubuntu或Debian
        COTURN_CONFIG="/etc/turnserver.conf"
    fi

    # 备份原始配置文件
    sudo cp $COTURN_CONFIG ${COTURN_CONFIG}.backup

    # 清空现有配置文件（如果需要保留原文件的某些特定配置，请谨慎使用此命令）
    sudo echo "" > $COTURN_CONFIG

    # 写入配置
    {
        echo "listening-device=$NET_INTERFACE"
        echo "syslog"
        echo "user=test:password"
        echo "cli-password=123456"
        echo "external-ip=$IP_ADDR"
        echo "listening-ip=$IP_ADDR"
        echo "relay-ip=$IP_ADDR"
        echo "listening-port=3478"
        echo "lt-cred-mech"
        echo "use-auth-secret"
        echo "static-auth-secret=$AUTH_SECRET"
        echo "realm=$REALM"
        echo "total-quota=100"
        echo "bps-capacity=0"
        echo "stale-nonce"
        echo "log-file=/var/log/turnserver.log"
    } | sudo tee -a $COTURN_CONFIG

    # 重启Coturn服务以使配置生效
    sudo systemctl restart coturn
    echo "Coturn 配置完成并已重启。"
}

# 主执行流程
detect_os
update_packages
install_coturn
configure_coturn

echo "Coturn 安装和配置完成。"
echo "----------------------------------------"
echo "---------------配置文件-----------------"
# ANSI 背景颜色代码
BG_GREEN='\e[42m'
BG_BLUE='\e[44m'
BG_CYAN='\e[46m'
NO_COLOR='\e[0m' # 用于重置颜色

echo -e "Coturn的秘钥为：${BG_GREEN}$AUTH_SECRET${NO_COLOR}"
echo -e "realm域名为：${BG_BLUE}$REALM${NO_COLOR}"
echo -e "用户密码为：${BG_CYAN}user=test:password${NO_COLOR}"
