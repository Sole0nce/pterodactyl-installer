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

# ------------------ Variables ----------------- #

# Versioning
export GITHUB_SOURCE=${GITHUB_SOURCE:-master}
export SCRIPT_RELEASE=${SCRIPT_RELEASE:-canary}

# Pterodactyl versions
export PTERODACTYL_PANEL_VERSION=""
export PTERODACTYL_WINGS_VERSION=""

# Path (export everything that is possible, doesn't matter that it exists already)
export PATH="$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin"

# OS
export OS=""
export OS_VER_MAJOR=""
export CPU_ARCHITECTURE=""
export ARCH=""
export SUPPORTED=false

# download URLs
# If --china flag is set, use pterodactyl-china repositories for localized version
if [ "$PTERODACTYL_CHINA" == true ]; then
  export PANEL_DL_URL="https://github.com/pterodactyl-china/panel/releases/latest/download/panel.tar.gz"
  export WINGS_DL_BASE_URL="https://github.com/pterodactyl-china/wings/releases/latest/download/wings_linux_"
else
  export PANEL_DL_URL="https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz"
  export WINGS_DL_BASE_URL="https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_"
fi
export MARIADB_URL="https://downloads.mariadb.com/MariaDB/mariadb_repo_setup"
export GITHUB_BASE_URL=${GITHUB_BASE_URL:-"https://raw.githubusercontent.com/pterodactyl-installer/pterodactyl-installer"}
export GITHUB_URL="$GITHUB_BASE_URL/$GITHUB_SOURCE"

# Colors
COLOR_YELLOW='\033[1;33m'
COLOR_GREEN='\033[0;32m'
COLOR_RED='\033[0;31m'
COLOR_NC='\033[0m'

# email input validation regex
email_regex="^(([A-Za-z0-9]+((\.|\-|\_|\+)?[A-Za-z0-9]?)*[A-Za-z0-9]+)|[A-Za-z0-9]+)@(([A-Za-z0-9]+)+((\.|\-|\_)?([A-Za-z0-9]+)+)*)+\.([A-Za-z]{2,})+$"

# Charset used to generate random passwords
password_charset='A-Za-z0-9!"#%&()*+,-./:;<=>?@[\]^_`{|}~'

# --------------------- Lib -------------------- #

lib_loaded() {
  return 0
}

# -------------- Visual functions -------------- #

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

print_list() {
  print_brake 30
  for word in $1; do
    output "$word"
  done
  print_brake 30
  echo ""
}

hyperlink() {
  echo -e "\e]8;;${1}\a${1}\e]8;;\a"
}

# First argument is wings / panel / neither
welcome() {
  get_latest_versions

  print_brake 70
  if [ "$PTERODACTYL_CHINA" == true ]; then
    output "翼龙面板安装脚本 @ $SCRIPT_RELEASE"
    output ""
    output "版权所有 (C) 2018 - 2026, Vilhelm Prytz, <vilhelm@prytznet.se>"
    output "https://github.com/pterodactyl-installer/pterodactyl-installer"
    output ""
    output "本脚本与翼龙官方项目无关。"
    output ""
    output "当前运行系统：$OS $OS_VER"
    if [ "$1" == "panel" ]; then
      output "最新面板版本：$PTERODACTYL_PANEL_VERSION"
      output "(翼龙面板汉化版 https://github.com/pterodactyl-china/panel)"
    elif [ "$1" == "wings" ]; then
      output "最新 Wings 版本：$PTERODACTYL_WINGS_VERSION"
      output "(Wings 汉化版 https://github.com/pterodactyl-china/wings)"
    fi
  else
    output "Pterodactyl panel installation script @ $SCRIPT_RELEASE"
    output ""
    output "Copyright (C) 2018 - 2026, Vilhelm Prytz, <vilhelm@prytznet.se>"
    output "https://github.com/pterodactyl-installer/pterodactyl-installer"
    output ""
    output "This script is not associated with the official Pterodactyl Project."
    output ""
    output "Running $OS version $OS_VER."
    if [ "$1" == "panel" ]; then
      output "Latest pterodactyl/panel is $PTERODACTYL_PANEL_VERSION"
    elif [ "$1" == "wings" ]; then
      output "Latest pterodactyl/wings is $PTERODACTYL_WINGS_VERSION"
    fi
  fi
  print_brake 70
}

# ---------------- Lib functions --------------- #

get_latest_release() {
  curl -sL "https://api.github.com/repos/$1/releases/latest" | # Get latest release from GitHub api
    grep '"tag_name":' |                                       # Get tag line
    sed -E 's/.*"([^"]+)".*/\1/'                               # Pluck JSON value
}

get_latest_versions() {
  if [ "$PTERODACTYL_CHINA" == false ]; then
    output "正在获取版本信息..."
  fi
  if [ "$PTERODACTYL_CHINA" == true ]; then
    PTERODACTYL_PANEL_VERSION=$(get_latest_release "pterodactyl-china/panel")
    PTERODACTYL_WINGS_VERSION=$(get_latest_release "pterodactyl-china/wings")
  else
    PTERODACTYL_PANEL_VERSION=$(get_latest_release "pterodactyl/panel")
    PTERODACTYL_WINGS_VERSION=$(get_latest_release "pterodactyl/wings")
  fi
}

update_lib_source() {
  GITHUB_URL="$GITHUB_BASE_URL/$GITHUB_SOURCE"
  rm -rf /tmp/lib.sh
  curl -sSL -o /tmp/lib.sh "$GITHUB_URL"/lib/lib.sh
  # shellcheck source=lib/lib.sh
  source /tmp/lib.sh
}

run_installer() {
  if [ "$PTERODACTYL_CHINA" == true ]; then
    bash "$PTERODACTYL_INSTALLER_DIR/installers/$1.sh"
  else
    bash <(curl -sSL "$GITHUB_URL/installers/$1.sh")
  fi
}

run_ui() {
  if [ "$PTERODACTYL_CHINA" == true ]; then
    bash "$PTERODACTYL_INSTALLER_DIR/ui/$1.sh"
  else
    bash <(curl -sSL "$GITHUB_URL/ui/$1.sh")
  fi
}

array_contains_element() {
  local e match="$1"
  shift
  for e; do [[ "$e" == "$match" ]] && return 0; done
  return 1
}

valid_email() {
  [[ $1 =~ ${email_regex} ]]
}

invalid_ip() {
  ip route get "$1" >/dev/null 2>&1
  echo $?
}

gen_passwd() {
  local length=$1
  local password=""
  while [ ${#password} -lt "$length" ]; do
    password=$(echo "$password""$(head -c 100 /dev/urandom | LC_ALL=C tr -dc "$password_charset")" | fold -w "$length" | head -n 1)
  done
  echo "$password"
}

# -------------------- MYSQL ------------------- #

create_db_user() {
  local db_user_name="$1"
  local db_user_password="$2"
  local db_host="${3:-127.0.0.1}"

  if [ "$PTERODACTYL_CHINA" == true ]; then
    output "正在创建数据库用户 $db_user_name..."
  else
    output "Creating database user $db_user_name..."
  fi

  mariadb -u root -e "CREATE USER '$db_user_name'@'$db_host' IDENTIFIED BY '$db_user_password';"
  mariadb -u root -e "FLUSH PRIVILEGES;"

  if [ "$PTERODACTYL_CHINA" == true ]; then
    output "数据库用户 $db_user_name 创建成功"
  else
    output "Database user $db_user_name created"
  fi
}

grant_all_privileges() {
  local db_name="$1"
  local db_user_name="$2"
  local db_host="${3:-127.0.0.1}"

  if [ "$PTERODACTYL_CHINA" == true ]; then
    output "正在授予 $db_name 的所有权限给 $db_user_name..."
  else
    output "Granting all privileges on $db_name to $db_user_name..."
  fi

  mariadb -u root -e "GRANT ALL PRIVILEGES ON $db_name.* TO '$db_user_name'@'$db_host' WITH GRANT OPTION;"
  mariadb -u root -e "FLUSH PRIVILEGES;"

  if [ "$PTERODACTYL_CHINA" == true ]; then
    output "权限授予完成"
  else
    output "Privileges granted"
  fi
}

create_db() {
  local db_name="$1"
  local db_user_name="$2"
  local db_host="${3:-127.0.0.1}"

  if [ "$PTERODACTYL_CHINA" == true ]; then
    output "正在创建数据库 $db_name..."
  else
    output "Creating database $db_name..."
  fi

  mariadb -u root -e "CREATE DATABASE $db_name;"
  grant_all_privileges "$db_name" "$db_user_name" "$db_host"

  if [ "$PTERODACTYL_CHINA" == true ]; then
    output "数据库 $db_name 创建成功"
  else
    output "Database $db_name created"
  fi
}

# --------------- Package Manager -------------- #

update_repos() {
  local args=""
  
  [[ "$1" == true ]] && args="-qq"

  case "$OS" in
    ubuntu | debian)
      if [ "$PTERODACTYL_CHINA" == true ]; then
        output "正在更新软件包仓库..."
      else
        output "Updating package repositories..."
      fi
      if ! apt-get update -y $args; then
        if [ "$PTERODACTYL_CHINA" == true ]; then
          error "更新软件包仓库失败。"
        else
          error "Failed to update repositories."
        fi
        return 1
      fi
      ;;
    centos | almalinux | rockylinux)
      if [ "$PTERODACTYL_CHINA" == true ]; then
        output "跳过仓库更新($OS 自动处理)"
      else
        output "Skipping repository update (handled automatically on $OS)."
      fi
      ;;
    *)
      if [ "$PTERODACTYL_CHINA" == true ]; then
        warning "不支持的操作系统: $OS — 跳过仓库更新。"
      else
        warning "Unsupported OS: $OS — skipping repository update."
      fi
      ;;
  esac
}


# First argument list of packages to install, second argument for quite mode
install_packages() {
  local args=""
  if [[ $2 == true ]]; then
    case "$OS" in
    ubuntu | debian) args="-qq" ;;
    *) args="-q" ;;
    esac
  fi

  # Eval needed for proper expansion of arguments
  case "$OS" in
  ubuntu | debian)
    eval apt-get -y $args install "$1"
    ;;
  rocky | almalinux)
    eval dnf -y $args install "$1"
    ;;
  esac
}

# ------------ User input functions ------------ #

required_input() {
  local __resultvar=$1
  local result=''

  while [ -z "$result" ]; do
    echo -n "* ${2}"
    read -r result

    if [ -z "${3}" ]; then
      [ -z "$result" ] && result="${4}"
    else
      [ -z "$result" ] && error "${3}"
    fi
  done

  eval "$__resultvar="'$result'"
}

email_input() {
  local __resultvar=$1
  local result=''

  while ! valid_email "$result"; do
    echo -n "* ${2}"
    read -r result

    valid_email "$result" || error "${3}"
  done

  eval "$__resultvar="'$result'"
}

password_input() {
  local __resultvar=$1
  local result=''
  local default="$4"

  while [ -z "$result" ]; do
    echo -n "* ${2}"

    # modified from https://stackoverflow.com/a/22940001
    while IFS= read -r -s -n1 char; do
      [[ -z $char ]] && {
        printf '\n'
        break
      }                               # ENTER pressed; output \n and break.
      if [[ $char == $'\x7f' ]]; then # backspace was pressed
        # Only if variable is not empty
        if [ -n "$result" ]; then
          # Remove last char from output variable.
          [[ -n $result ]] && result=${result%?}
          # Erase '*' to the left.
          printf '\b \b'
        fi
      else
        # Add typed char to output variable.  [ -z "$result" ] && [ -n "
        result+=$char
        # Print '*' in its stead.
        printf '*'
      fi
    done
    [ -z "$result" ] && [ -n "$default" ] && result="$default"
    [ -z "$result" ] && error "${3}"
  done

  eval "$__resultvar="'$result'"
}

# ------------------ Firewall ------------------ #

ask_firewall() {
  local __resultvar=$1

  case "$OS" in
  ubuntu | debian)
    if [ "$PTERODACTYL_CHINA" == true ]; then
      echo -e -n "* 是否要自动配置 UFW 防火墙? (y/N): "
    else
      echo -e -n "* Do you want to automatically configure UFW (firewall)? (y/N): "
    fi
    read -r CONFIRM_UFW

    if [[ "$CONFIRM_UFW" =~ [Yy] ]]; then
      eval "$__resultvar="'true'"
    fi
    ;;
  rocky | almalinux)
    if [ "$PTERODACTYL_CHINA" == true ]; then
      echo -e -n "* 是否要自动配置 firewall-cmd 防火墙? (y/N): "
    else
      echo -e -n "* Do you want to automatically configure firewall-cmd (firewall)? (y/N): "
    fi
    read -r CONFIRM_FIREWALL_CMD

    if [[ "$CONFIRM_FIREWALL_CMD" =~ [Yy] ]]; then
      eval "$__resultvar="'true'"
    fi
    ;;
  esac
}

install_firewall() {
  case "$OS" in
  ubuntu | debian)
    output ""

    if [ "$PTERODACTYL_CHINA" == true ]; then
      output "正在安装 Uncomplicated Firewall (UFW)..."
    else
      output "Installing Uncomplicated Firewall (UFW)"
    fi

    if ! [ -x "$(command -v ufw)" ]; then
      update_repos true
      install_packages "ufw" true
    fi

    ufw --force enable

    if [ "$PTERODACTYL_CHINA" == true ]; then
      success "Uncomplicated Firewall (UFW) 已启用"
    else
      success "Enabled Uncomplicated Firewall (UFW)"
    fi

    ;;
  rocky | almalinux)

    output ""

    if [ "$PTERODACTYL_CHINA" == true ]; then
      output "正在安装 FirewallD..."
    else
      output "Installing FirewallD"
    fi

    if ! [ -x "$(command -v firewall-cmd)" ]; then
      install_packages "firewalld" true
    fi

    systemctl --now enable firewalld >/dev/null

    if [ "$PTERODACTYL_CHINA" == true ]; then
      success "FirewallD 已启用"
    else
      success "Enabled FirewallD"
    fi

    ;;
  esac
}

firewall_allow_ports() {
  case "$OS" in
  ubuntu | debian)
    for port in $1; do
      ufw allow "$port"
    done
    ufw --force reload
    ;;
  rocky | almalinux)
    for port in $1; do
      firewall-cmd --zone=public --add-port="$port"/tcp --permanent
    done
    firewall-cmd --reload -q
    ;;
  esac
}

# ---------------- System checks --------------- #

# panel x86_64 check
check_os_x86_64() {
  if [ "${ARCH}" != "amd64" ]; then
    if [ "$PTERODACTYL_CHINA" == true ]; then
      warning "检测到 CPU 架构为 $CPU_ARCHITECTURE"
      warning "使用非 64 位(x86_64)架构可能会导致问题。"
      echo -e -n "* 是否确定要继续？(y/N):"
    else
      warning "Detected CPU architecture $CPU_ARCHITECTURE"
      warning "Using any other architecture than 64 bit (x86_64) will cause problems."
      echo -e -n "* Are you sure you want to proceed? (y/N):"
    fi
    read -r choice

    if [[ ! "$choice" =~ [Yy] ]]; then
      if [ "$PTERODACTYL_CHINA" == true ]; then
        error "安装已中止！"
      else
        error "Installation aborted!"
      fi
      exit 1
    fi
  fi
}

# wings virtualization check
check_virt() {
  if [ "$PTERODACTYL_CHINA" == true ]; then
    output "正在安装 virt-what..."
  else
    output "Installing virt-what..."
  fi

  update_repos true
  install_packages "virt-what" true

  # Export sbin for virt-what
  export PATH="$PATH:/sbin:/usr/sbin"

  virt_serv=$(virt-what)

  case "$virt_serv" in
  *openvz* | *lxc*)
    if [ "$PTERODACTYL_CHINA" == true ]; then
      warning "检测到不支持的虚拟化类型。请咨询您的托管商是否支持 Docker。请自行承担风险。"
      echo -e -n "* 是否确定要继续？(y/N): "
    else
      warning "Unsupported type of virtualization detected. Please consult with your hosting provider whether your server can run Docker or not. Proceed at your own risk."
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
    ;;
  *)
    [ "$virt_serv" != "" ] && warning "检测到虚拟化环境: $virt_serv"
    ;;
  esac

  if uname -r | grep -q "xxxx"; then
    if [ "$PTERODACTYL_CHINA" == true ]; then
      error "检测到不支持的内核。"
    else
      error "Unsupported kernel detected."
    fi
    exit 1
  fi

  if [ "$PTERODACTYL_CHINA" == true ]; then
    success "系统与 Docker 兼容"
  else
    success "System is compatible with docker"
  fi
}

# Exit with error status code if user is not root
if [[ $EUID -ne 0 ]]; then
  error "This script must be executed with root privileges."
  exit 1
fi

# Detect OS
if [ -f /etc/os-release ]; then
  # freedesktop.org and systemd
  . /etc/os-release
  OS=$(echo "$ID" | awk '{print tolower($0)}')
  OS_VER=$VERSION_ID
elif type lsb_release >/dev/null 2>&1; then
  # linuxbase.org
  OS=$(lsb_release -si | awk '{print tolower($0)}')
  OS_VER=$(lsb_release -sr)
elif [ -f /etc/lsb-release ]; then
  # For some versions of Debian/Ubuntu without lsb_release command
  . /etc/lsb-release
  OS=$(echo "$DISTRIB_ID" | awk '{print tolower($0)}')
  OS_VER=$DISTRIB_RELEASE
elif [ -f /etc/debian_version ]; then
  # Older Debian/Ubuntu/etc.
  OS="debian"
  OS_VER=$(cat /etc/debian_version)
elif [ -f /etc/SuSe-release ]; then
  # Older SuSE/etc.
  OS="SuSE"
  OS_VER="?"
elif [ -f /etc/redhat-release ]; then
  # Older Red Hat, CentOS, etc.
  OS="Red Hat/CentOS"
  OS_VER="?"
else
  # Fall back to uname, e.g. "Linux <version>", also works for BSD, etc.
  OS=$(uname -s)
  OS_VER=$(uname -r)
fi

OS=$(echo "$OS" | awk '{print tolower($0)}')
OS_VER_MAJOR=$(echo "$OS_VER" | cut -d. -f1)
CPU_ARCHITECTURE=$(uname -m)

case "$CPU_ARCHITECTURE" in
x86_64)
  ARCH=amd64
  ;;
arm64 | aarch64)
  ARCH=arm64
  ;;
*)
  if [ "$PTERODACTYL_CHINA" == true ]; then
    error "仅支持 x86_64 和 arm64 架构！"
  else
    error "Only x86_64 and arm64 are supported!"
  fi
  exit 1
  ;;
esac

case "$OS" in
ubuntu)
  [ "$OS_VER_MAJOR" == "22" ] && SUPPORTED=true
  [ "$OS_VER_MAJOR" == "24" ] && SUPPORTED=true
  export DEBIAN_FRONTEND=noninteractive
  ;;
debian)
  [ "$OS_VER_MAJOR" == "10" ] && SUPPORTED=true
  [ "$OS_VER_MAJOR" == "11" ] && SUPPORTED=true
  [ "$OS_VER_MAJOR" == "12" ] && SUPPORTED=true
  [ "$OS_VER_MAJOR" == "13" ] && SUPPORTED=true
  export DEBIAN_FRONTEND=noninteractive
  ;;
rocky | almalinux)
  [ "$OS_VER_MAJOR" == "8" ] && SUPPORTED=true
  [ "$OS_VER_MAJOR" == "9" ] && SUPPORTED=true
  ;;
*)
  SUPPORTED=false
  ;;
esac

# exit if not supported
if [ "$SUPPORTED" == false ]; then
  output "$OS $OS_VER is not supported"
  error "Unsupported OS"
  exit 1
fi