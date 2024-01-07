#!/bin/bash
Green_font_prefix="\033[32m"
Red_font_prefix="\033[31m"
Font_color_suffix="\033[0m"
Info="${Green_font_prefix}[信息]${Font_color_suffix}"
Error="${Red_font_prefix}[错误]${Font_color_suffix}"
Tip="${Green_font_prefix}[注意]${Font_color_suffix}"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
SKYBLUE='\033[0;36m'
PLAIN='\033[0m'

copyright(){
    clear
echo "\
╔╗┬ ┬  ╔═┌┐┌─┌┐┬ ┬ ┌─┌┬┌─┌─┌─┐
╠╩└┬┘  ╠═│││ ││└┬┘ ├┤ │┌─│ ├┤ 
╚═╝┴   ╩ ┘└└─┘└┘───└  ┴└─└─└  
"
}
# Check if curl and jq is installed
if ! [ -x "$(command -v curl)" ]; then
  echo 'Error: curl is not installed.' >&2
  echo 'Installing curl...'
  # Install curl
  if [ "$(uname)" == "Darwin" ]; then
    # MacOS
    brew install curl
  elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
    # Ubuntu/Debian
    apt-get update -y && sudo apt-get install curl -y
  elif [ "$(cat /etc/*release | grep -oP '^ID=\K.+')" == "centos" ]; then
    # CentOS
    yum update -y && yum install curl -y
  elif [ "$(expr substr $(uname -s) 1 10)" == "MINGW32_NT" ]; then
    # Windows Git Bash
    echo 'Curl installation on Windows is not supported by this script.'
  fi
fi

if ! [ -x "$(command -v jq)" ]; then
  echo 'Error: jq is not installed.' >&2
  echo 'Installing jq...'
  # Install jq
  if [ "$(uname)" == "Darwin" ]; then
    # MacOS
    brew install jq
  elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
    # Ubuntu/Debian
    apt-get update -y && apt-get install jq -y
  elif [ "$(cat /etc/*release | grep -oP '^ID=\K.+')" == "centos" ]; then
    # CentOS
    yum update -y && yum install jq -y
  elif [ "$(expr substr $(uname -s) 1 10)" == "MINGW32_NT" ]; then
    # Windows Git Bash
    echo 'jq installation on Windows is not supported by this script.'
  fi
fi

tcp_tune(){ # 优化TCP窗口
sed -i '/net.ipv4.tcp_no_metrics_save/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_ecn/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_frto/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_mtu_probing/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_rfc1337/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_sack/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_fack/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_window_scaling/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_adv_win_scale/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_moderate_rcvbuf/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_rmem/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_wmem/d' /etc/sysctl.conf
sed -i '/net.core.rmem_max/d' /etc/sysctl.conf
sed -i '/net.core.wmem_max/d' /etc/sysctl.conf
sed -i '/net.ipv4.udp_rmem_min/d' /etc/sysctl.conf
sed -i '/net.ipv4.udp_wmem_min/d' /etc/sysctl.conf
sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
cat >> /etc/sysctl.conf << EOF
net.ipv4.tcp_no_metrics_save=1
net.ipv4.tcp_ecn=0
net.ipv4.tcp_frto=0
net.ipv4.tcp_mtu_probing=0
net.ipv4.tcp_rfc1337=0
net.ipv4.tcp_sack=1
net.ipv4.tcp_fack=1
net.ipv4.tcp_window_scaling=1
net.ipv4.tcp_adv_win_scale=1
net.ipv4.tcp_moderate_rcvbuf=1
net.core.rmem_max=33554432
net.core.wmem_max=33554432
net.ipv4.tcp_rmem=4096 87380 33554432
net.ipv4.tcp_wmem=4096 16384 33554432
net.ipv4.udp_rmem_min=8192
net.ipv4.udp_wmem_min=8192
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF
sysctl -p && sysctl --system
}

enable_forwarding(){ #开启内核转发
sed -i '/net.ipv4.conf.all.route_localnet/d' /etc/sysctl.conf
sed -i '/net.ipv4.ip_forward/d' /etc/sysctl.conf
sed -i '/net.ipv4.conf.all.forwarding/d' /etc/sysctl.conf
sed -i '/net.ipv4.conf.default.forwarding/d' /etc/sysctl.conf
cat >> '/etc/sysctl.conf' << EOF
net.ipv4.conf.all.route_localnet=1
net.ipv4.ip_forward=1
net.ipv4.conf.all.forwarding=1
net.ipv4.conf.default.forwarding=1
EOF
sysctl -p && sysctl --system
}

banping(){
sed -i '/net.ipv4.icmp_echo_ignore_all/d' /etc/sysctl.conf
sed -i '/net.ipv4.icmp_echo_ignore_broadcasts/d' /etc/sysctl.conf
cat >> '/etc/sysctl.conf' << EOF
net.ipv4.icmp_echo_ignore_all=1
net.ipv4.icmp_echo_ignore_broadcasts=1
EOF
sysctl -p && sysctl --system
}

unbanping(){
sed -i "s/net.ipv4.icmp_echo_ignore_all=1/net.ipv4.icmp_echo_ignore_all=0/g" /etc/sysctl.conf
sed -i "s/net.ipv4.icmp_echo_ignore_broadcasts=1/net.ipv4.icmp_echo_ignore_broadcasts=0/g" /etc/sysctl.conf
sysctl -p && sysctl --system
}

ulimit_tune(){

echo "1000000" > /proc/sys/fs/file-max
sed -i '/fs.file-max/d' /etc/sysctl.conf
cat >> '/etc/sysctl.conf' << EOF
fs.file-max=1000000
EOF

ulimit -SHn 1000000 && ulimit -c unlimited
echo "root     soft   nofile    1000000
root     hard   nofile    1000000
root     soft   nproc     1000000
root     hard   nproc     1000000
root     soft   core      1000000
root     hard   core      1000000
root     hard   memlock   unlimited
root     soft   memlock   unlimited

*     soft   nofile    1000000
*     hard   nofile    1000000
*     soft   nproc     1000000
*     hard   nproc     1000000
*     soft   core      1000000
*     hard   core      1000000
*     hard   memlock   unlimited
*     soft   memlock   unlimited
">/etc/security/limits.conf
if grep -q "ulimit" /etc/profile; then
  :
else
  sed -i '/ulimit -SHn/d' /etc/profile
  echo "ulimit -SHn 1000000" >>/etc/profile
fi
if grep -q "pam_limits.so" /etc/pam.d/common-session; then
  :
else
  sed -i '/required pam_limits.so/d' /etc/pam.d/common-session
  echo "session required pam_limits.so" >>/etc/pam.d/common-session
fi

sed -i '/DefaultTimeoutStartSec/d' /etc/systemd/system.conf
sed -i '/DefaultTimeoutStopSec/d' /etc/systemd/system.conf
sed -i '/DefaultRestartSec/d' /etc/systemd/system.conf
sed -i '/DefaultLimitCORE/d' /etc/systemd/system.conf
sed -i '/DefaultLimitNOFILE/d' /etc/systemd/system.conf
sed -i '/DefaultLimitNPROC/d' /etc/systemd/system.conf

cat >>'/etc/systemd/system.conf' <<EOF
[Manager]
#DefaultTimeoutStartSec=90s
DefaultTimeoutStopSec=30s
#DefaultRestartSec=100ms
DefaultLimitCORE=infinity
DefaultLimitNOFILE=65535
DefaultLimitNPROC=65535
EOF

systemctl daemon-reload

}

get_ipinfo() {
# Get the public IPv4 and IPv6 address
PUBLIC_IPV4=$(curl -4 ip.sb)
PUBLIC_IPV6=$(curl -6 ip.sb)
if [ -z "$PUBLIC_IPV6" ]; then
    PUBLIC_IPV6=""
fi

# Get the IPv4 information
IP_INFO=$(curl -s https://ipapi.co/$PUBLIC_IPV4/json/)
COUNTRY=$(echo $IP_INFO | jq -r '.country')
CITY=$(echo $IP_INFO | jq -r '.city')
CURRENCY=$(echo $IP_INFO | jq -r '.currency')
ASN=$(echo $IP_INFO | jq -r '.asn')
ORGANIZATION=$(echo $IP_INFO | jq -r '.org')

IP_INFO6=$(curl -s https://ipapi.co/$PUBLIC_IPV6/json/)
COUNTRY6=$(echo $IP_INFO6 | jq -r '.country')
CITY6=$(echo $IP_INFO6 | jq -r '.city')
CURRENCY6=$(echo $IP_INFO6 | jq -r '.currency')
ASN6=$(echo $IP_INFO6 | jq -r '.asn')
ORGANIZATION6=$(echo $IP_INFO6 | jq -r '.org')

echo "IPv4 Address: $PUBLIC_IPV4"
echo "IPV4 Imformation:"
echo "国家: $COUNTRY"
echo "城市: $CITY"
echo "货币: $CURRENCY"
echo "ASN: $ASN"
echo "供应商: $ORGANIZATION"

echo "IPV6 Address: $PUBLIC_IPV6"
echo "IPV6 Imformation:"
echo "国家: $COUNTRY6"
echo "城市: $CITY6"
echo "货币: $CURRENCY6"
echo "ASN: $ASN6"
echo "供应商: $ORGANIZATION6"

}

get_system_info() {
  cname=$(awk -F: '/model name/ {name=$2} END {print name}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//')
  #cores=$(awk -F: '/model name/ {core++} END {print core}' /proc/cpuinfo)
  #freq=$(awk -F: '/cpu MHz/ {freq=$2} END {print freq}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//')
  #corescache=$(awk -F: '/cache size/ {cache=$2} END {print cache}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//')
  #tram=$(free -m | awk '/Mem/ {print $2}')
  #uram=$(free -m | awk '/Mem/ {print $3}')
  #bram=$(free -m | awk '/Mem/ {print $6}')
  #swap=$(free -m | awk '/Swap/ {print $2}')
  #uswap=$(free -m | awk '/Swap/ {print $3}')
  #up=$(awk '{a=$1/86400;b=($1%86400)/3600;c=($1%3600)/60} {printf("%d days %d hour %d min\n",a,b,c)}' /proc/uptime)
  #load=$(w | head -1 | awk -F'load average:' '{print $2}' | sed 's/^[ \t]*//;s/[ \t]*$//')
  opsy=$(get_opsy)
  arch=$(uname -m)
  #lbit=$(getconf LONG_BIT)
  kern=$(uname -r)
  # disk_size1=$( LANG=C df -hPl | grep -wvE '\-|none|tmpfs|overlay|shm|udev|devtmpfs|by-uuid|chroot|Filesystem' | awk '{print $2}' )
  # disk_size2=$( LANG=C df -hPl | grep -wvE '\-|none|tmpfs|overlay|shm|udev|devtmpfs|by-uuid|chroot|Filesystem' | awk '{print $3}' )
  # disk_total_size=$( calc_disk ${disk_size1[@]} )
  # disk_used_size=$( calc_disk ${disk_size2[@]} )
  #tcpctrl=$(sysctl net.ipv4.tcp_congestion_control | awk -F ' ' '{print $3}')
  virt_check
}

# 脚本当天及累计运行次数统计
statistics_of_run-times() {
  COUNT=$(curl -ksm1 "https://hits.seeyoufarm.com/api/count/incr/badge.svg?url=https://bit.ly/ip-tool/&count_bg=%2379C83D&title_bg=%23555555&icon=&icon_color=%23E7E7E7&title=hits&edge_flat=false" 2>&1) &&
  TODAY=$(expr "$COUNT" : '.*\s\([0-9]\{1,\}\)\s/.*') && TOTAL=$(expr "$COUNT" : '.*/\s\([0-9]\{1,\}\)\s.*')
}

menu() {
  echo -e "\
${Green_font_prefix}0.${Font_color_suffix} 查看IP信息        ${Green_font_prefix}1.${Font_color_suffix} 安装BBR原版内核(已经是5.x的不需要) (待添加)
${Green_font_prefix}2.${Font_color_suffix} TCP窗口调优       ${Green_font_prefix}3.${Font_color_suffix} 开启内核转发
${Green_font_prefix}4.${Font_color_suffix} 系统资源限制调优  ${Green_font_prefix}5.${Font_color_suffix} 屏蔽ICMP          
${Green_font_prefix}6.${Font_color_suffix} 开放ICMP          ${Green_font_prefix}7.${Font_color_suffix} 修改当前DNS为Google与CF
${Green_font_prefix}7.${Font_color_suffix} coturn一键安装配置

The script runs on today: $TODAY Total runs: ${YELLOW}$TOTAL
"

Change_DNS() {
  rm -rf /etc/resolv.conf
  touch /etc/resolv.conf
  cat >> '/etc/resolv.conf' << EOF
#Google Public DNS
nameserver 8.8.8.8
nameserver 8.8.4.4
nameserver 2001:4860:4860::8888
nameserver 2001:4860:4860::8844 
 
#Cloudflare DNS
nameserver 1.1.1.1
nameserver 1.0.0.1
nameserver 2606:4700:4700::1111
nameserver 2606:4700:4700::1001
EOF
echo "修改成功！"
echo "当前DNS如下"
cat /etc/resolv.conf
}

get_opsy() {
  [ -f /etc/redhat-release ] && awk '{print ($1,$3~/^[0-9]/?$3:$4)}' /etc/redhat-release && return
  [ -f /etc/os-release ] && awk -F'[= "]' '/PRETTY_NAME/{print $3,$4,$5}' /etc/os-release && return
  [ -f /etc/lsb-release ] && awk -F'[="]+' '/DESCRIPTION/{print $2}' /etc/lsb-release && return
}

virt_check() {
  # if hash ifconfig 2>/dev/null; then
  # eth=$(ifconfig)
  # fi

  virtualx=$(dmesg) 2>/dev/null

  if [[ $(which dmidecode) ]]; then
    sys_manu=$(dmidecode -s system-manufacturer) 2>/dev/null
    sys_product=$(dmidecode -s system-product-name) 2>/dev/null
    sys_ver=$(dmidecode -s system-version) 2>/dev/null
  else
    sys_manu=""
    sys_product=""
    sys_ver=""
  fi

  if grep docker /proc/1/cgroup -qa; then
    virtual="Docker"
  elif grep lxc /proc/1/cgroup -qa; then
    virtual="Lxc"
  elif grep -qa container=lxc /proc/1/environ; then
    virtual="Lxc"
  elif [[ -f /proc/user_beancounters ]]; then
    virtual="OpenVZ"
  elif [[ "$virtualx" == *kvm-clock* ]]; then
    virtual="KVM"
  elif [[ "$cname" == *KVM* ]]; then
    virtual="KVM"
  elif [[ "$cname" == *QEMU* ]]; then
    virtual="KVM"
  elif [[ "$virtualx" == *"VMware Virtual Platform"* ]]; then
    virtual="VMware"
  elif [[ "$virtualx" == *"Parallels Software International"* ]]; then
    virtual="Parallels"
  elif [[ "$virtualx" == *VirtualBox* ]]; then
    virtual="VirtualBox"
  elif [[ -e /proc/xen ]]; then
    virtual="Xen"
  elif [[ "$sys_manu" == *"Microsoft Corporation"* ]]; then
    if [[ "$sys_product" == *"Virtual Machine"* ]]; then
      if [[ "$sys_ver" == *"7.0"* || "$sys_ver" == *"Hyper-V" ]]; then
        virtual="Hyper-V"
      else
        virtual="Microsoft Virtual Machine"
      fi
    fi
  else
    virtual="Dedicated Server"
  fi
}

get_system_info
echo -e "Current system information: ${Font_color_suffix}$opsy ${Green_font_prefix}$virtual${Font_color_suffix} $arch ${Green_font_prefix}$kern${Font_color_suffix}
"
  read -p "Pls input key in num: " num
  case "$num" in
  0)
    get_ipinfo
    ;;
  1)
    bbr
    ;;
  2)
    tcp_tune
    ;;
  3)
    enable_forwarding
    ;;
  4)
    ulimit_tune
    ;;
  5)
    banping
    ;;
  6)
    unbanping
    ;;
  7)
    Change_DNS
    ;;
  8)
    Install_Coturn
    ;;
  *)
  clear
    echo -e "${Error}:请输入正确数字 [0-99]"
    sleep 5s
    start_menu
    ;;
  esac
}

copyright

statistics_of_run-times

menu

