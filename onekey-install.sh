#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

echo -e ""
echo -e "${green}==============================================================${plain}"
echo -e "${green}推荐系统:Debian 10+${plain}"
echo -e "${green}作者：StriveMoring${plain}"
echo -e "${green}本脚本是用于对接v2board面板的后端ws+tls模式的一键安装脚本${plain}"
echo -e "${green}祝君食用愉快！${plain}"
echo -e "${green}==============================================================${plain}"
echo -e ""

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}错误：${plain} 必须使用root用户运行此脚本！\n" && exit 1

#remove v2ray
echo -e ""
echo -e "${green}---------------------------${plain}"
echo -e "${green}正在删除旧版v2ray及服务...${plain}"
echo -e "${green}---------------------------${plain}"
set -x

systemctl stop v2ray
systemctl disable v2ray

service v2ray stop
update-rc.d -f v2ray remove

rm -rf /usr/bin/v2ray /etc/init.d/v2ray /lib/systemd/system/v2ray.service

set -

echo "Logs and configurations are preserved, you can remove these manually"
echo "logs directory: /var/log/v2ray"
echo "configuration directory: /etc/v2ray"

#remove acme.sh
echo -e ""
echo -e "${green}---------------------------${plain}"
echo -e "${green}正在删除旧版acme.sh及服务...${plain}"
echo -e "${green}---------------------------${plain}"

rm -rf /root/.acme.sh

# check os
echo -e ""
echo -e "${green}---------------------------${plain}"
echo -e "${green}正在检查系统版本...${plain}"
echo -e "${green}---------------------------${plain}"

if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
else
    echo -e "${red}未检测到系统版本，请联系脚本作者！${plain}\n" && exit 1
fi

arch=$(arch)

if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
  arch="64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
  arch="arm64-v8a"
else
  arch="64"
  echo -e "${red}检测架构失败，使用默认架构: ${arch}${plain}"
fi

echo "架构: ${arch}"

if [ "$(getconf WORD_BIT)" != '32' ] && [ "$(getconf LONG_BIT)" != '64' ] ; then
    echo "本软件不支持 32 位系统(x86)，请使用 64 位系统(x86_64)，如果检测有误，请联系作者"
    exit 2
fi

os_version=""

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}请使用 CentOS 7 或更高版本的系统！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}请使用 Ubuntu 16 或更高版本的系统！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}请使用 Debian 8 或更高版本的系统！${plain}\n" && exit 1
    fi
fi

install_base() {
echo -e ""
echo -e "${green}---------------------------${plain}"
echo -e "${green}正在更新系统及安装依赖...${plain}"
echo -e "${green}---------------------------${plain}"

    if [[ x"${release}" == x"centos" ]]; then
        yum install epel-release -y
        yum install wget curl unzip tar crontabs socat nano netcat -y
    else
        apt update -y
        apt install wget curl unzip tar cron socat nano netcat -y
    fi
}

# 0: running, 1: not running, 2: not installed
check_status() {
    if [[ ! -f /etc/systemd/system/v2ray.service ]]; then
        return 2
    fi
    temp=$(systemctl status v2ray | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
    if [[ x"${temp}" == x"running" ]]; then
        return 0
    else
        return 1
    fi
}

install_v2ray() {
echo -e ""
echo -e "${green}---------------------------${plain}"
echo -e "${green}正在安装v2ray及服务...${plain}"
echo -e "${green}---------------------------${plain}"

    if [[ -e /etc/v2ray/ ]]; then
        rm /etc/v2ray/ -rf
    fi

    curl -L -s https://raw.githubusercontent.com/StriveMoring/BEtov2board/main/install-release.sh | sudo bash
    cd /etc/v2ray/
    
    read -p "请输入v2board面板nodeId > " nodeId
    sed -i "s|66666|$nodeId|g"  config.json
    read -p "请输入v2board面板URL > " webapi
    sed -i "s|mydomain.com|$webapi|g"  config.json
    read -p "请输入v2board通信密钥 > " token
    sed -i "s|mytoken|$token|g"  config.json

}

install_acme() {
echo -e ""
echo -e "${green}---------------------------${plain}"
echo -e "${green}正在安装acme.sh及服务...${plain}"
echo -e "${green}---------------------------${plain}"

    curl  https://get.acme.sh | sh
    source ~/.bashrc
    echo "请输入需要申请证书的域名："
    read domain
    sudo ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
    sudo ~/.acme.sh/acme.sh --issue -d ${domain} --standalone -k ec-256
    sudo ~/.acme.sh/acme.sh --installcert -d ${domain} --fullchainpath /etc/v2ray/v2ray.crt --keypath /etc/v2ray/v2ray.key --ecc
    mkdir -p /root/.cert
    cp /etc/v2ray/v2ray.crt /root/.cert/server.crt
    cp /etc/v2ray/v2ray.key /root/.cert/server.key
    
}

main(){
install_base
install_v2ray
install_acme

service v2ray restart
sleep 2
check_status
echo -e ""
if [[ $? == 0 ]]; then
    echo -e ""
    echo -e "${green}-------------------------${plain}"
    echo -e "${green}v2ray重启成功!!${plain}"
    echo -e "${green}-------------------------${plain}"
else
    echo -e ""
    echo -e "${green}---------------------------${plain}"
    echo -e "${red}v2ray 可能启动失败，请稍后使用 tail -f /access.log /error.log 查看日志信息"
    echo -e "报错信息如下："
    tail -f /access.log /error.log
    echo -e "${green}---------------------------${plain}"

fi

echo -e ""
echo -e "${green}------------------------------------------${plain}"
echo -e "${green}已完成全部安装过程，祝君使用愉快！${plain}"
echo -e "${green}------------------------------------------${plain}"
}

main
