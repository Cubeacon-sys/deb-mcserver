# db-mcserver A script to make installing minecraft server easy in debian based environments
# Copyright (C) 2026  Cubeacon-sys

# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

#!/usr/bin/env bash

# Exit immediately on error, unset variables, or pipe failure
set -euo pipefail

MEMORY_ALLOCATION="4G"
SERVER_DIR="$HOME/minecraft-server"
export SDKMAN_DIR="$HOME/.sdkman"
USER_AGENT="MinecraftServerScript/1.0 (admin@local.host)"

echo "=== 1/5: System Checks & Base Tools ==="
if [ "$(id -u)" -eq 0 ]; then
    apt-get update
    apt-get install -y curl zip unzip wget screen jq
else
    sudo apt-get update
    sudo apt-get install -y curl zip unzip wget screen jq
fi

echo "=== 2/5: Installing GraalVM 21 via SDKMAN ==="
if [ ! -d "$SDKMAN_DIR" ]; then
    curl -s "https://get.sdkman.io" | bash
fi

# Disable strict mode temporarily for SDKMAN initialization and setup
set +u
# shellcheck source=/dev/null
source "$SDKMAN_DIR/bin/sdkman-init.sh"
sdkman_auto_answer=true

if ! sdk list java | grep -q "21.0.2-graalce" 2>/dev/null; then
    sdk install java 21.0.2-graalce || true
fi
sdk use java 21.0.2-graalce
set -u

echo "=== 3/5: Fetching Latest PaperMC Server Build ==="
mkdir -p "$SERVER_DIR"
cd "$SERVER_DIR"

echo "Querying PaperMC v3 API..."
PROJECT_DATA=$(curl -sL -H "User-Agent: $USER_AGENT" "https://fill.papermc.io/v3/projects/paper")

# Extract the newest modern 1.2x Minecraft version
MINECRAFT_VERSION=$(echo "$PROJECT_DATA" | jq -r '.versions | to_entries[] | .value[]' | grep '^1\.2' | sort -V | tail -n 1)

if [ -z "$MINECRAFT_VERSION" ] || [ "$MINECRAFT_VERSION" == "null" ]; then
    echo "[!] Error: Failed to determine target Minecraft version from API." >&2
    exit 1
fi

echo "Selected Minecraft Version: $MINECRAFT_VERSION"

# Fetch build list array
BUILDS_DATA=$(curl -sL -H "User-Agent: $USER_AGENT" "https://fill.papermc.io/v3/projects/paper/versions/${MINECRAFT_VERSION}/builds")

DOWNLOAD_URL=$(echo "$BUILDS_DATA" | jq -r '.[-1].downloads["server:default"].url // "null"')
LATEST_BUILD=$(echo "$BUILDS_DATA" | jq -r '.[-1].id // "unknown"')

if [ "$DOWNLOAD_URL" == "null" ] || [ -z "$DOWNLOAD_URL" ]; then
    echo "[!] Error: Failed to retrieve server download URL." >&2
    exit 1
fi

echo "Downloading PaperMC build #${LATEST_BUILD} for version ${MINECRAFT_VERSION}..."
wget -q -O paper.jar "$DOWNLOAD_URL"

echo "=== 4/5: Initializing Server & Accepting EULA ==="
java -jar paper.jar --nogui || true

if [ -f "eula.txt" ]; then
    sed -i 's/eula=false/eula=true/' eula.txt
else
    echo "eula=true" > eula.txt
fi

echo "=== 5/5: Launching PaperMC Server in Screen ==="
screen -X -S mcserver quit 2>/dev/null || true

# Start server in a background detached screen session
screen -dmS mcserver java -Xms${MEMORY_ALLOCATION} -Xmx${MEMORY_ALLOCATION} -jar paper.jar --nogui

echo "=================================================="
echo " Setup Complete!"
echo " PaperMC Server (Version: ${MINECRAFT_VERSION}, Build: #${LATEST_BUILD}) is running."
echo " Server directory: $SERVER_DIR"
echo " Use 'screen -r mcserver' to access the console."
echo "=================================================="
