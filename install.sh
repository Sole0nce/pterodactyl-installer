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

export GITHUB_SOURCE="v1.2.0"
export SCRIPT_RELEASE="v1.2.0"
export GITHUB_BASE_URL="https://raw.githubusercontent.com/pterodactyl-installer/pterodactyl-installer"

LOG_PATH="/var/log/pterodactyl-installer.log"

# Parse --china argument for pterodactyl-china support
export PTERODACTYL_CHINA=false
for arg in "$@"; do
  case "$arg" in
    --china)
      export PTERODACTYL_CHINA=true
      ;;
  esac
done

# check for curl
if ! [ -x "$(command -v curl)" ]; then
  if [ "$PTERODACTYL_CHINA" == true ]; then
    echo "* curl 是此脚本运行所必需的。"
    echo "* 请使用 apt(Debian 及其衍生版)或 yum/dnf(CentOS)安装 curl"
  else
    echo "* curl is required in order for this script to work."
    echo "* install using apt (Debian and derivatives) or yum/dnf (CentOS)"
  fi
  exit 1
fi

# Detect script directory for local file sourcing
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Always remove lib.sh, before downloading it
[ -f /tmp/lib.sh ] && rm -rf /tmp/lib.sh

if [ "$PTERODACTYL_CHINA" == true ]; then
  # In --china mode, use local files directly (for pterodactyl-china support)
  export PTERODACTYL_INSTALLER_DIR="$SCRIPT_DIR"
  cp "$SCRIPT_DIR/lib/lib.sh" /tmp/lib.sh
else
  # Normal mode: download from remote GitHub repository
  curl -sSL -o /tmp/lib.sh "$GITHUB_BASE_URL"/master/lib/lib.sh
fi
# shellcheck source=lib/lib.sh
source /tmp/lib.sh

execute() {
  echo -e "\n\n* pterodactyl-installer $(date) \n\n" >>$LOG_PATH

  [[ "$1" == *"canary"* ]] && export GITHUB_SOURCE="master" && export SCRIPT_RELEASE="canary"

  if [ "$PTERODACTYL_CHINA" == true ]; then
    # In --china mode, run local UI script directly (preserves environment variables)
    bash "$SCRIPT_DIR/ui/${1//_canary/}.sh" |& tee -a $LOG_PATH
  else
    update_lib_source
    run_ui "${1//_canary/}" |& tee -a $LOG_PATH
  fi

  if [[ -n $2 ]]; then
    if [ "$PTERODACTYL_CHINA" == true ]; then
      echo -e -n "* $1 安装完成。是否继续安装 $2？(y/N): "
    else
      echo -e -n "* $1 installation completed. Do you want to proceed to $2 installation? (y/N): "
    fi
    read -r CONFIRM
    if [[ "$CONFIRM" =~ [Yy] ]]; then
      execute "$2"
    else
      if [ "$PTERODACTYL_CHINA" == true ]; then
        error "$2 安装已取消。"
      else
        error "Installation of $2 aborted."
      fi
      exit 1
    fi
  fi
}

welcome ""

done=false
while [ "$done" == false ]; do
  if [ "$PTERODACTYL_CHINA" == true ]; then
    options=(
      "安装面板"
      "安装 Wings"
      "同时安装面板和 Wings(先装面板后装 Wings)"
      "使用开发版脚本安装面板(master 分支，可能不稳定！)"
      "使用开发版脚本安装 Wings(master 分支，可能不稳定！)"
      "同时安装面板和 Wings(开发版)"
      "使用开发版脚本卸载面板或 Wings"
    )
  else
    options=(
      "Install the panel"
      "Install Wings"
      "Install both [0] and [1] on the same machine (wings script runs after panel)"
      "Install panel with canary version of the script (the versions that lives in master, may be broken!)"
      "Install Wings with canary version of the script (the versions that lives in master, may be broken!)"
      "Install both [3] and [4] on the same machine (wings script runs after panel)"
      "Uninstall panel or wings with canary version of the script (the versions that lives in master, may be broken!)"
    )
  fi

  actions=(
    "panel"
    "wings"
    "panel;wings"
    "panel_canary"
    "wings_canary"
    "panel_canary;wings_canary"
    "uninstall_canary"
  )

  if [ "$PTERODACTYL_CHINA" == true ]; then
    output "请选择要执行的操作："
  else
    output "What would you like to do?"
  fi

  for i in "${!options[@]}"; do
    output "[$i] ${options[$i]}"
  done

  if [ "$PTERODACTYL_CHINA" == true ]; then
    echo -n "* 输入 0-$((${#actions[@]} - 1)): "
  else
    echo -n "* Input 0-$((${#actions[@]} - 1)): "
  fi
  read -r action

  if [ "$PTERODACTYL_CHINA" == true ]; then
    [ -z "$action" ] && error "请输入选项" && continue
  else
    [ -z "$action" ] && error "Input is required" && continue
  fi

  valid_input=("$(for ((i = 0; i <= ${#actions[@]} - 1; i += 1)); do echo "${i}"; done)")
  if [ "$PTERODACTYL_CHINA" == true ]; then
    [[ ! " ${valid_input[*]} " =~ ${action} ]] && error "无效选项"
  else
    [[ ! " ${valid_input[*]} " =~ ${action} ]] && error "Invalid option"
  fi
  [[ " ${valid_input[*]} " =~ ${action} ]] && done=true && IFS=";" read -r i1 i2 <<<"${actions[$action]}" && execute "$i1" "$i2"
done

# Remove lib.sh, so next time the script is run the, newest version is downloaded.
rm -rf /tmp/lib.sh