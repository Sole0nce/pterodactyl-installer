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

# Domain name / IP
export FQDN=""

# Default MySQL credentials
export MYSQL_DB=""
export MYSQL_USER=""
export MYSQL_PASSWORD=""

# Environment
export timezone=""
export email=""

# Initial admin account
export user_email=""
export user_username=""
export user_firstname=""
export user_lastname=""
export user_password=""

# Assume SSL, will fetch different config if true
export ASSUME_SSL=false
export CONFIGURE_LETSENCRYPT=false

# Firewall
export CONFIGURE_FIREWALL=false

# ------------ User input functions ------------ #

ask_letsencrypt() {
  if [ "$CONFIGURE_UFW" == false ] && [ "$CONFIGURE_FIREWALL_CMD" == false ]; then
    if [ "$PTERODACTYL_CHINA" == true ]; then
      warning "Let's Encrypt 需要开放 80/443 端口！您已选择不自动配置防火墙，请自行确保端口已开放(否则脚本将失败)！"
    else
      warning "Let's Encrypt requires port 80/443 to be opened! You have opted out of the automatic firewall configuration; use this at your own risk (if port 80/443 is closed, the script will fail)!"
    fi
  fi

  if [ "$PTERODACTYL_CHINA" == true ]; then
    echo -e -n "* 是否要使用 Let's Encrypt 自动配置 HTTPS？(y/N): "
  else
    echo -e -n "* Do you want to automatically configure HTTPS using Let's Encrypt? (y/N): "
  fi
  read -r CONFIRM_SSL

  if [[ "$CONFIRM_SSL" =~ [Yy] ]]; then
    CONFIGURE_LETSENCRYPT=true
    ASSUME_SSL=false
  fi
}

ask_assume_ssl() {
  if [ "$PTERODACTYL_CHINA" == true ]; then
    output "未选择自动配置 Let's Encrypt。"
    output "您可以选择'假定 SSL'，脚本将下载已配置好 Let's Encrypt 证书的 nginx 配置，但不会自动获取证书。"
    output "如果您选择假定 SSL 但没有获取证书，面板将无法正常工作。"
    echo -n "* 是否假定 SSL？(y/N): "
  else
    output "Let's Encrypt is not going to be automatically configured by this script (user opted out)."
    output "You can 'assume' Let's Encrypt, which means the script will download a nginx configuration that is configured to use a Let's Encrypt certificate but the script won't obtain the certificate for you."
    output "If you assume SSL and do not obtain the certificate, your installation will not work."
    echo -n "* Assume SSL or not? (y/N): "
  fi
  read -r ASSUME_SSL_INPUT

  [[ "$ASSUME_SSL_INPUT" =~ [Yy] ]] && ASSUME_SSL=true
  true
}

check_FQDN_SSL() {
  if [[ $(invalid_ip "$FQDN") == 1 && $FQDN != 'localhost' ]]; then
    SSL_AVAILABLE=true
  else
    if [ "$PTERODACTYL_CHINA" == true ]; then
      warning "* IP 地址无法使用 Let's Encrypt。"
      output "要使用 Let's Encrypt，您必须使用有效的域名。"
    else
      warning "* Let's Encrypt will not be available for IP addresses."
      output "To use Let's Encrypt, you must use a valid domain name."
    fi
  fi
}

main() {
  # check if we can detect an already existing installation
  if [ -d "/var/www/pterodactyl" ]; then
    if [ "$PTERODACTYL_CHINA" == true ]; then
      warning "检测到您的系统上已安装翼龙面板！多次运行此脚本将导致失败！"
      echo -e -n "* 是否确定要继续？(y/N): "
    else
      warning "The script has detected that you already have Pterodactyl panel on your system! You cannot run the script multiple times, it will fail!"
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

  welcome "panel"

  check_os_x86_64

  # set database credentials
  if [ "$PTERODACTYL_CHINA" == true ]; then
    output "数据库配置。"
    output ""
    output "这些凭据将用于 MySQL 数据库与面板之间的通信。"
    output "运行此脚本前无需手动创建数据库，脚本会自动为您创建。"
    output ""
  else
    output "Database configuration."
    output ""
    output "This will be the credentials used for communication between the MySQL"
    output "database and the panel. You do not need to create the database"
    output "before running this script, the script will do that for you."
    output ""
  fi

  MYSQL_DB="-"
  while [[ "$MYSQL_DB" == *"-"* ]]; do
    if [ "$PTERODACTYL_CHINA" == true ]; then
      required_input MYSQL_DB "数据库名称 (panel): " "" "panel"
    else
      required_input MYSQL_DB "Database name (panel): " "" "panel"
    fi
    [[ "$MYSQL_DB" == *"-"* ]] && error "数据库名称不能包含连字符"
  done

  MYSQL_USER="-"
  while [[ "$MYSQL_USER" == *"-"* ]]; do
    if [ "$PTERODACTYL_CHINA" == true ]; then
      required_input MYSQL_USER "数据库用户名 (pterodactyl): " "" "pterodactyl"
    else
      required_input MYSQL_USER "Database username (pterodactyl): " "" "pterodactyl"
    fi
    [[ "$MYSQL_USER" == *"-"* ]] && error "数据库用户名不能包含连字符"
  done

  # MySQL password input
  rand_pw=$(gen_passwd 64)
  if [ "$PTERODACTYL_CHINA" == true ]; then
    password_input MYSQL_PASSWORD "密码(按回车使用随机生成的密码): " "密码不能为空" "$rand_pw"
  else
    password_input MYSQL_PASSWORD "Password (press enter to use randomly generated password): " "MySQL password cannot be empty" "$rand_pw"
  fi

  readarray -t valid_timezones <<<"$(curl -s "$GITHUB_URL"/configs/valid_timezones.txt)"
  if [ "$PTERODACTYL_CHINA" == true ]; then
    output "有效时区列表请查看 $(hyperlink "https://www.php.net/manual/en/timezones.php")"
  else
    output "List of valid timezones here $(hyperlink "https://www.php.net/manual/en/timezones.php")"
  fi

  while [ -z "$timezone" ]; do
    if [ "$PTERODACTYL_CHINA" == true ]; then
      echo -n "* 选择时区 [Asia/Shanghai]: "
    else
      echo -n "* Select timezone [Europe/Stockholm]: "
    fi
    read -r timezone_input

    array_contains_element "$timezone_input" "${valid_timezones[@]}" && timezone="$timezone_input"
    if [ "$PTERODACTYL_CHINA" == true ]; then
      [ -z "$timezone_input" ] && timezone="Asia/Shanghai"
    else
      [ -z "$timezone_input" ] && timezone="Europe/Stockholm"
    fi
  done

  if [ "$PTERODACTYL_CHINA" == true ]; then
    email_input email "请输入用于配置 Let's Encrypt 和面板的邮箱地址: " "邮箱不能为空或格式不正确"
    email_input user_email "初始管理员账号的邮箱地址: " "邮箱不能为空或格式不正确"
    required_input user_username "初始管理员账号的用户名: " "用户名不能为空"
    required_input user_firstname "初始管理员账号的名: " "姓名不能为空"
    required_input user_lastname "初始管理员账号的姓: " "姓名不能为空"
    password_input user_password "初始管理员账号的密码: " "密码不能为空"
  else
    email_input email "Provide the email address that will be used to configure Let's Encrypt and Pterodactyl: " "Email cannot be empty or invalid"
    email_input user_email "Email address for the initial admin account: " "Email cannot be empty or invalid"
    required_input user_username "Username for the initial admin account: " "Username cannot be empty"
    required_input user_firstname "First name for the initial admin account: " "Name cannot be empty"
    required_input user_lastname "Last name for the initial admin account: " "Name cannot be empty"
    password_input user_password "Password for the initial admin account: " "Password cannot be empty"
  fi

  print_brake 72

  # set FQDN
  while [ -z "$FQDN" ]; do
    if [ "$PTERODACTYL_CHINA" == true ]; then
      echo -n "* 设置面板的域名(FQDN，例如 panel.example.com): "
    else
      echo -n "* Set the FQDN of this panel (panel.example.com): "
    fi
    read -r FQDN
    if [ -z "$FQDN" ]; then
      if [ "$PTERODACTYL_CHINA" == true ]; then
        error "域名不能为空"
      else
        error "FQDN cannot be empty"
      fi
    fi
  done

  # Check if SSL is available
  check_FQDN_SSL

  # Ask if firewall is needed
  ask_firewall CONFIGURE_FIREWALL

  # Only ask about SSL if it is available
  if [ "$SSL_AVAILABLE" == true ]; then
    ask_letsencrypt
    [ "$CONFIGURE_LETSENCRYPT" == false ] && ask_assume_ssl
  fi

  # verify FQDN if user has selected to assume SSL or configure Let's Encrypt
  [ "$CONFIGURE_LETSENCRYPT" == true ] || [ "$ASSUME_SSL" == true ] && bash <(curl -s "$GITHUB_URL"/lib/verify-fqdn.sh) "$FQDN"

  # summary
  summary

  # confirm installation
  if [ "$PTERODACTYL_CHINA" == true ]; then
    echo -e -n "\n* 初始配置完成。是否继续安装？(y/N): "
  else
    echo -e -n "\n* Initial configuration completed. Continue with installation? (y/N): "
  fi
  read -r CONFIRM
  if [[ "$CONFIRM" =~ [Yy] ]]; then
    run_installer "panel"
  else
    if [ "$PTERODACTYL_CHINA" == true ]; then
      error "安装已中止。"
    else
      error "Installation aborted."
    fi
    exit 1
  fi
}

summary() {
  print_brake 62
  if [ "$PTERODACTYL_CHINA" == true ]; then
    output "翼龙面板 $PTERODACTYL_PANEL_VERSION (nginx / $OS)"
    output "数据库名称: $MYSQL_DB"
    output "数据库用户: $MYSQL_USER"
    output "数据库密码: (已隐藏)"
    output "时区: $timezone"
    output "邮箱: $email"
    output "管理员邮箱: $user_email"
    output "管理员用户名: $user_username"
    output "管理员名: $user_firstname"
    output "管理员姓: $user_lastname"
    output "管理员密码: (已隐藏)"
    output "域名/IP: $FQDN"
    output "配置防火墙? $CONFIGURE_FIREWALL"
    output "配置 Let's Encrypt? $CONFIGURE_LETSENCRYPT"
    output "假定 SSL? $ASSUME_SSL"
  else
    output "Pterodactyl panel $PTERODACTYL_PANEL_VERSION with nginx on $OS"
    output "Database name: $MYSQL_DB"
    output "Database user: $MYSQL_USER"
    output "Database password: (censored)"
    output "Timezone: $timezone"
    output "Email: $email"
    output "User email: $user_email"
    output "Username: $user_username"
    output "First name: $user_firstname"
    output "Last name: $user_lastname"
    output "User password: (censored)"
    output "Hostname/FQDN: $FQDN"
    output "Configure Firewall? $CONFIGURE_FIREWALL"
    output "Configure Let's Encrypt? $CONFIGURE_LETSENCRYPT"
    output "Assume SSL? $ASSUME_SSL"
  fi
  print_brake 62
}

goodbye() {
  print_brake 62
  if [ "$PTERODACTYL_CHINA" == true ]; then
    output "面板安装完成！"
    output ""
  else
    output "Panel installation completed"
    output ""
  fi

  if [ "$CONFIGURE_LETSENCRYPT" == true ]; then
    if [ "$PTERODACTYL_CHINA" == true ]; then
      output "您的面板应可通过以下地址访问：$(hyperlink "$FQDN")"
    else
      output "Your panel should be accessible from $(hyperlink "$FQDN")"
    fi
  fi
  [ "$ASSUME_SSL" == true ] && [ "$CONFIGURE_LETSENCRYPT" == false ] && output "您选择了假定 SSL，但未配置 Let's Encrypt。在配置 SSL 之前，面板将无法正常工作。" 
  [ "$ASSUME_SSL" == false ] && [ "$CONFIGURE_LETSENCRYPT" == false ] && output "您的面板应可通过以下地址访问：$(hyperlink "$FQDN")"

  output ""
  output "安装使用了 nginx / $OS"
  if [ "$PTERODACTYL_CHINA" == true ]; then
    output "感谢您使用此脚本。"
    [ "$CONFIGURE_FIREWALL" == false ] && echo -e "* ${COLOR_RED}注意${COLOR_NC}: 如果未配置防火墙，请确保 80/443 (HTTP/HTTPS) 端口已开放！"
  else
    output "Thank you for using this script."
    [ "$CONFIGURE_FIREWALL" == false ] && echo -e "* ${COLOR_RED}Note${COLOR_NC}: If you haven't configured the firewall: 80/443 (HTTP/HTTPS) is required to be open!"
  fi
  print_brake 62
}

# run script
main
goodbye