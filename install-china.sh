#!/bin/bash

set -e

######################################################################################
#                                                                                    #
# Project 'pterodactyl-installer'                                                    #
#   翼龙面板汉化版 - 一键安装脚本                                                     #
#                                                                                    #
# Copyright (C) 2018 - 2026, Vilhelm Prytz, <vilhelm@prytznet.se>                    #
#                                                                                    #
#   This program is free software: you can redistribute it and/or modify             #
#   it under the terms of the GNU General Public License as published by             #
#   the Free Software Foundation, either version 3 of the License, or                #
#   (at your option) any later version.                                              #
#                                                                                    #
#   This program is distributed in the hope that it will be useful,                  #
#   but WITHOUT ANY WARRANTY; without even the implied warranty of                   #
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the                    #
#   GNU General Public License for more details.                                     #
#                                                                                    #
#   You should have received a copy of the GNU General Public License                #
#   along with this program.  If not, see <https://www.gnu.org/licenses/>.           #
#                                                                                    #
# 本脚本安装翼龙面板汉化版 (https://github.com/pterodactyl-china/panel)             #
# 和 Wings 汉化版 (https://github.com/pterodactyl-china/wings)                     #
# 基于 pterodactyl-installer 添加 --china 参数实现                                 #
#                                                                                    #
# 仓库地址: https://github.com/pterodactyl-installer/pterodactyl-installer           #
# 分支: china-support                                                                #
#                                                                                    #
######################################################################################

# 颜色代码
COLOR_YELLOW='\033[1;33m'
COLOR_GREEN='\033[0;32m'
COLOR_RED='\033[0;31m'
COLOR_NC='\033[0m'
COLOR_CYAN='\033[0;36m'

output() {
  echo -e "* $1"
}

success() {
  echo ""
  output "${COLOR_GREEN}成功${COLOR_NC}: $1"
  echo ""
}

error() {
  echo ""
  echo -e "* ${COLOR_RED}错误${COLOR_NC}: $1" 1>&2
  echo ""
}

warning() {
  echo ""
  output "${COLOR_YELLOW}警告${COLOR_NC}: $1"
  echo ""
}

print_brake() {
  for ((n = 0; n < $1; n++)); do
    echo -n "#"
  done
  echo ""
}

# 检查是否为 root 用户
if [[ $EUID -ne 0 ]]; then
  error "请使用 root 权限运行此脚本(使用 sudo)"
  exit 1
fi

# 检查必需的命令
for cmd in git curl; do
  if ! [ -x "$(command -v $cmd)" ]; then
    error "缺少必需的命令: $cmd"
    exit 1
  fi
done

# 欢迎信息
print_brake 60
output "${COLOR_CYAN}翼龙面板汉化版 - 一键安装脚本${COLOR_NC}"
output ""
output "本脚本将安装以下组件："
output "  · 翼龙面板(汉化版)"
output "    https://github.com/pterodactyl-china/panel"
output "  · 翼龙 Wings 守护进程(汉化版)"
output "    https://github.com/pterodactyl-china/wings"
output ""
output "Copyright (C) 2018 - 2026, Vilhelm Prytz"
output "https://github.com/pterodactyl-installer/pterodactyl-installer"
output ""
output "使用说明：安装过程中请根据提示输入域名、数据库等信息"
output "如需帮助请访问：https://github.com/pterodactyl-china/documentation"
print_brake 60
echo ""

# 第1步：确定安装目录(优先使用空间较大的分区)
INSTALL_DIR=""
for dir in "/mnt/data/pterodactyl-installer" "/opt/pterodactyl-installer" "$HOME/pterodactyl-installer"; do
  parent_dir=$(dirname "$dir")
  if [ -d "$parent_dir" ]; then
    available=$(df "$parent_dir" | awk 'NR==2 {print $4}')
    if [ "$available" -gt 100000 ]; then
      INSTALL_DIR="$dir"
      break
    fi
  fi
done

if [ -z "$INSTALL_DIR" ]; then
  INSTALL_DIR="/opt/pterodactyl-installer"
fi

# 第2步：克隆或更新安装脚本
if [ -d "$INSTALL_DIR" ]; then
  output "检测到已有安装脚本，正在更新到 $INSTALL_DIR..."
  cd "$INSTALL_DIR"
  git fetch origin
  git checkout china-support
  git pull origin china-support
else
  output "正在下载安装脚本到 $INSTALL_DIR ..."
  mkdir -p "$(dirname "$INSTALL_DIR")"
  git clone -b china-support https://github.com/Sole0nce/pterodactyl-installer.git "$INSTALL_DIR"
  cd "$INSTALL_DIR"
fi

success "安装脚本下载完成！"

# 第3步：以 --china 参数启动安装程序
echo ""
output "${COLOR_CYAN}========================================${COLOR_NC}"
output "${COLOR_CYAN}  即将启动翼龙面板汉化版安装程序        ${COLOR_NC}"
output "${COLOR_CYAN}  请根据提示完成交互式安装              ${COLOR_NC}"
output "${COLOR_CYAN}========================================${COLOR_NC}"
echo ""
output "安装选项说明："
output "  [0] 仅安装面板(推荐先安装面板)"
output "  [1] 仅安装 Wings 守护进程"
output "  [2] 同时安装面板和 Wings"
echo ""

cd "$INSTALL_DIR"
bash install.sh --china

# 安装完成
echo ""
print_brake 60
success "翼龙面板汉化版安装脚本执行完毕！"
output ""
output "后续操作提示："
output "  1. 如果安装了面板，请通过配置的域名或 IP 地址访问"
output "  2. 如果安装了 Wings，它已作为 systemd 服务运行"
output "  3. 面板配置文件位于 /var/www/pterodactyl/.env"
output "  4. Wings 配置文件位于 /etc/pterodactyl/config.yml"
output ""
output "更多帮助：https://github.com/pterodactyl-china/documentation"
print_brake 60