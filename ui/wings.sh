#!/bin/bash

set -e

######################################################################################
#                                                                                    #
# Project 'pterodactyl-installer'                                                    #
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
# https://github.com/pterodactyl-installer/pterodactyl-installer/blob/master/LICENSE #
#                                                                                    #
# This script is not associated with the official Pterodactyl Project.               #
# https://github.com/pterodactyl-installer/pterodactyl-installer                     #
#                                                                                    #
######################################################################################

# Check if script is loaded, load if not or fail otherwise.
fn_exists() { declare -F "$1" >/dev/null; }
if ! fn_exists lib_loaded; then
  # shellcheck source=lib/lib.sh
  source /tmp/lib.sh || source <(curl -sSL "$GITHUB_BASE_URL/$GITHUB_SOURCE"/lib/lib.sh)
  ! fn_exists lib_loaded && echo "* ERROR: Could not load lib script" && exit 1
fi

# ------------------ Variables ----------------- #

export CONFIGURE_LETSENCRYPT=false

export CONFIGURE_DBHOST=false
export CONFIGURE_DB_FIREWALL=false
export MYSQL_DBHOST_HOST=""
export MYSQL_DBHOST_USER=""
export MYSQL_DBHOST_PASSWORD=""

# ------------ User input functions ------------ #

ask_letsencrypt() {
  if [ "$CONFIGURE_UFW" == false ] && [ "$CONFIGURE_FIREWALL_CMD" == false ]; then
    if [ "$PTERODACTYL_CHINA" == true ]; then
      warning "Let's Encrypt 需要开放 80/443 端口！您已选择不自动配置防火墙。"
    else
      warning "Let's Encrypt requires port 80/443 to be opened! You have opted out of the automatic firewall configuration; use this at your own risk (if port 80/443 is closed, the script will fail)!"
    fi
  fi

  if [ "$PTERODACTYL_CHINA" == true ]; then
    if [ "$FQDN" == "$IP" ]; then
      warning "您的主机名是 IP 地址，无法使用 Let's Encrypt！必须使用 FQDN(例如 node.example.org)。"
    fi
    echo -e -n "* 是否要使用 Let's Encrypt 自动配置 HTTPS？(y/N): "
  else
    if [ "$FQDN" == "$IP" ]; then
      warning "You cannot use Let's Encrypt with your hostname as an IP address! It must be a FQDN (e.g. node.example.org)."
    fi
    echo -e -n "* Do you want to automatically configure HTTPS using Let's Encrypt? (y/N): "
  fi
  read -r CONFIRM_SSL

  if [[ "$CONFIRM_SSL" =~ [Yy] ]]; then
    CONFIGURE_LETSENCRYPT=true
  fi
}

ask_database_host() {
  if [ "$PTERODACTYL_CHINA" == true ]; then
    echo -n "* 是否要自动配置数据库主机用户？(y/N): "
  else
    echo -n "* Do you want to automatically configure a user for database hosts? (y/N): "
  fi
  read -r CONFIRM_DBHOST

  if [[ "$CONFIRM_DBHOST" =~ [Yy] ]]; then
    CONFIGURE_DBHOST=true
    ask_database_external
  fi
}

ask_database_external() {
  if [ "$PTERODACTYL_CHINA" == true ]; then
    echo -n "* 是否要将 MySQL 配置为允许外部访问？(y/N): "
  else
    echo -n "* Do you want to configure MySQL to be accessed externally? (y/N): "
  fi
  read -r CONFIRM_DBEXTERNAL

  if [[ "$CONFIRM_DBEXTERNAL" =~ [Yy] ]]; then
    CONFIGURE_DB_FIREWALL=true
    if [ "$PTERODACTYL_CHINA" == true ]; then
      echo -n "* 输入面板地址(留空表示任意地址): "
    else
      echo -n "* Enter the panel address (blank for any address): "
    fi
    read -r CONFIRM_DBEXTERNAL_HOST
    [ -n "$CONFIRM_DBEXTERNAL_HOST" ] && MYSQL_DBHOST_HOST="$CONFIRM_DBEXTERNAL_HOST"
  fi
}

ask_database_external_firewall() {
  if [ "$PTERODACTYL_CHINA" == true ]; then
    warning "允许来自端口 3306 (MySQL) 的入站流量可能存在安全风险，请确保您了解自己在做什么。"
    echo -n "* 是否允许端口 3306 的入站流量？(y/N): "
  else
    warning "Allow incoming traffic to port 3306 (MySQL) can potentially be a security risk, unless you know what you are doing."
    echo -n "* Would you like to allow incoming traffic to port 3306? (y/N): "
  fi
  read -r CONFIRM_DB_FIREWALL

  [[ ! "$CONFIRM_DB_FIREWALL" =~ [Yy] ]] && CONFIGURE_DB_FIREWALL=false
}

main() {
  # check if we can detect an already existing installation
  if [ -d "/etc/pterodactyl" ]; then
    if [ "$PTERODACTYL_CHINA" == true ]; then
      warning "检测到您的系统上已安装翼龙 Wings！多次运行此脚本将导致失败！"
      echo -e -n "* 是否确定要继续？(y/N): "
    else
      warning "The script has detected that you already have Pterodactyl wings on your system! You cannot run the script multiple times, it will fail!"
      echo -e -n "* Are you sure you want to proceed? (y/N): "
    fi
    read -r CONFIRM_PROCEED
    if [[ ! "$CONFIRM_PROCEED" =~ [Yy] ]]; then
      if [ "$PTERODACTYL_CHINA" == true ]; then
        error "安装已中止！"
      else
        error "Installation aborted!"
      fi
      exit 1
    fi
  fi

  welcome "wings"

  check_virt
  check_os_x86_64

  # Show documentation to the user
  if [ "$PTERODACTYL_CHINA" == true ]; then
    echo "* "
    echo "* 安装程序将安装 Docker、Wings 运行所需的依赖项"
    echo "* 以及 Wings 本身。但仍需在面板上创建节点，并将配置文件"
    echo "* 手动放置到节点上。有关此过程的更多信息，请参阅"
    echo "* 官方文档：$(hyperlink 'https://pterodactyl.io/wings/1.0/installing.html#configure')"
    echo "* "
    echo -e "* ${COLOR_RED}注意${COLOR_NC}: 此脚本不会自动启动 Wings(将安装 systemd 服务，启动需手动执行 systemctl start wings)"
    echo -e "* ${COLOR_RED}注意${COLOR_NC}: 此脚本不会启用 swap(建议为 Docker 启用 swap)"
  else
    echo "* "
    echo "* The installer will install Docker, required dependencies for Wings"
    echo "* as well as Wings itself. But it's still required to create the node"
    echo "* on the panel and then place the configuration file on the node manually after"
    echo "* the installation has finished. Read more about this process on the"
    echo "* official documentation: $(hyperlink 'https://pterodactyl.io/wings/1.0/installing.html#configure')"
    echo "* "
    echo -e "* ${COLOR_RED}Note${COLOR_NC}: this script will not start Wings automatically (will install systemd service, not start it)"
    echo -e "* ${COLOR_RED}Note${COLOR_NC}: this script will not enable swap (for docker)."
  fi

  # Determine if we should ask for database host user
  ask_database_host

  # Determine if we should ask for database external firewall
  [ "$CONFIGURE_DBHOST" == true ] && ask_database_external_firewall

  if [ "$CONFIGURE_DBHOST" == true ]; then
    if [ "$PTERODACTYL_CHINA" == true ]; then
      required_input MYSQL_DBHOST_USER "数据库主机用户名 (pterodactyluser): " "" "pterodactyluser"
      password_input MYSQL_DBHOST_PASSWORD "数据库主机密码: " "密码不能为空"
    else
      required_input MYSQL_DBHOST_USER "Database host username (pterodactyluser): " "" "pterodactyluser"
      password_input MYSQL_DBHOST_PASSWORD "Database host password: " "Password cannot be empty"
    fi
  fi

  # FQDN for Let's Encrypt
  if [ "$CONFIGURE_LETSENCRYPT" == true ]; then
    while [ -z "$FQDN" ]; do
      if [ "$PTERODACTYL_CHINA" == true ]; then
        echo -n "* 设置 Let's Encrypt 的 FQDN(例如 node.example.com): "
      else
        echo -n "* Set the FQDN to use for Let's Encrypt (node.example.com): "
      fi
      read -r FQDN
      [ -z "$FQDN" ] && error "FQDN 不能为空"
    done
  fi

  # Confirm installation
  echo -e -n "\n"
  if [ "$PTERODACTYL_CHINA" == true ]; then
    echo -n "* 是否继续安装？(y/N): "
  else
    echo -n "* Proceed with installation? (y/N): "
  fi
  read -r CONFIRM
  if [[ "$CONFIRM" =~ [Yy] ]]; then
    run_installer "wings"
  else
    if [ "$PTERODACTYL_CHINA" == true ]; then
      error "安装已中止。"
    else
      error "Installation aborted."
    fi
    exit 1
  fi
}

goodbye() {
  echo ""
  if [ "$PTERODACTYL_CHINA" == true ]; then
    echo "* Wings 安装完成"
    echo "*"
    echo "* 接下来，您需要配置 Wings 以连接到您的面板"
    echo "* 请参考官方指南 $(hyperlink 'https://pterodactyl.io/wings/1.0/installing.html#configure')"
    echo "* "
    echo "* 您可以从面板手动复制配置文件到 /etc/pterodactyl/config.yml"
    echo "* 或者使用面板上的\"自动部署\"功能，直接在此终端粘贴命令"
    echo "* "
    echo "* 您可以手动启动 Wings 以验证其工作是否正常"
    echo "*"
    echo "* sudo wings"
    echo "*"
    echo "* 确认工作正常后，按 CTRL+C，然后以服务形式启动 Wings(后台运行)"
    echo "*"
    echo "* systemctl start wings"
    echo "*"
    echo -e "* ${COLOR_RED}注意${COLOR_NC}: 建议启用 swap(有关 Docker 的更多信息，请参阅官方文档)"
  else
    echo "* Wings installation completed"
    echo "*"
    echo "* To continue, you need to configure Wings to run with your panel"
    echo "* Please refer to the official guide, $(hyperlink 'https://pterodactyl.io/wings/1.0/installing.html#configure')"
    echo "* "
    echo "* You can either copy the configuration file from the panel manually to /etc/pterodactyl/config.yml"
    echo "* or, you can use the \"auto deploy\" button from the panel and simply paste the command in this terminal"
    echo "* "
    echo "* You can then start Wings manually to verify that it's working"
    echo "*"
    echo "* sudo wings"
    echo "*"
    echo "* Once you have verified that it is working, use CTRL+C and then start Wings as a service (runs in the background)"
    echo "*"
    echo "* systemctl start wings"
    echo "*"
    echo -e "* ${COLOR_RED}Note${COLOR_NC}: It is recommended to enable swap (for Docker, read more about it in official documentation)"
  fi
  echo ""
}

# run script
main
goodbye