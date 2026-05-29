#!/bin/bash

set -e

######################################################################################
#                                                                                    #
# Project 'pterodactyl-installer'                                                    #
#   Pterodactyl China Edition - One-click Install Script                             #
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
# This script installs Pterodactyl Panel China Edition                               #
# (https://github.com/pterodactyl-china/panel) and Wings                            #
# (https://github.com/pterodactyl-china/wings) using the                            #
# pterodactyl-installer with --china flag.                                          #
#                                                                                    #
# Repository: https://github.com/pterodactyl-installer/pterodactyl-installer         #
# Branch: china-support                                                              #
#                                                                                    #
######################################################################################

# Color codes
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
  output "${COLOR_GREEN}SUCCESS${COLOR_NC}: $1"
  echo ""
}

error() {
  echo ""
  echo -e "* ${COLOR_RED}ERROR${COLOR_NC}: $1" 1>&2
  echo ""
}

warning() {
  echo ""
  output "${COLOR_YELLOW}WARNING${COLOR_NC}: $1"
  echo ""
}

print_brake() {
  for ((n = 0; n < $1; n++)); do
    echo -n "#"
  done
  echo ""
}

# Check root
if [[ $EUID -ne 0 ]]; then
  error "This script must be executed with root privileges."
  exit 1
fi

# Check required commands
for cmd in git curl; do
  if ! [ -x "$(command -v $cmd)" ]; then
    error "$cmd is required but not installed."
    exit 1
  fi
done

# Welcome message
print_brake 60
output "${COLOR_CYAN}Pterodactyl Panel China Edition - One-click Install Script${COLOR_NC}"
output ""
output "This script will install:"
output "  - Pterodactyl Panel (China Edition)"
output "    https://github.com/pterodactyl-china/panel"
output "  - Pterodactyl Wings (China Edition)"
output "    https://github.com/pterodactyl-china/wings"
output ""
output "Copyright (C) 2018 - 2026, Vilhelm Prytz"
output "https://github.com/pterodactyl-installer/pterodactyl-installer"
print_brake 60
echo ""

# Step 1: Determine install directory
INSTALL_DIR="/opt/pterodactyl-installer"

# Step 2: Clone or update the installer repository
if [ -d "$INSTALL_DIR" ]; then
  output "Updating existing installer in $INSTALL_DIR..."
  cd "$INSTALL_DIR"
  git fetch origin
  git checkout china-support
  git pull origin china-support
else
  output "Cloning installer to $INSTALL_DIR..."
  git clone -b china-support https://github.com/pterodactyl-installer/pterodactyl-installer.git "$INSTALL_DIR"
  cd "$INSTALL_DIR"
fi

success "Installer files ready!"

# Step 3: Run the installer with --china flag
echo ""
output "Starting the Pterodactyl China Edition installer..."
output "Follow the interactive prompts to complete the installation."
echo ""

cd "$INSTALL_DIR"
bash install.sh --china

# Cleanup
echo ""
print_brake 60
success "Pterodactyl China Edition installation script completed!"
output "If you installed the panel, it should be accessible via your configured domain/IP."
output "If you installed Wings, it should be running as a systemd service."
print_brake 60