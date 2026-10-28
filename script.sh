#!/usr/bin/env bash

set -euo pipefail

MINECRAFT_VERSION="1.21"
MEMORY_ALLOCATION="4G"
MC_USER="minecraft"
ALLOW_ROOT=false # Set to true ONLY if running inside a Docker container

echo "=== 1/5: System Checks & Base Tools ==="

# Check if script is running as root (UID 0)
if [ "$(id -u)" -eq 0 ]; then
    if [ "$ALLOW_ROOT" = true ]; then
        echo "WARNING: ALLOW_ROOT is true. Proceeding with installation as root..."
        apt-get update
        apt-get install -y curl zip unzip wget screen jq
    else
        echo "Script run as root. Installing base packages..."
        apt-get update
        apt-get install -y curl zip unzip wget screen jq sudo

        if ! id -u "$MC_USER" >/dev/null 2>&1; then
            echo "Creating dedicated '$MC_USER' user for security..."
            useradd -m -s /bin/bash "$MC_USER"
        fi

        echo "Dropping root privileges and switching to '$MC_USER'..."
        exec sudo -u "$MC_USER" "$0" "$@"
    fi
else
    # Running as a normal user, use sudo for packages
    if ! command -v jq >/dev/null 2>&1; then
        sudo apt-get update
        sudo apt-get install -y curl zip unzip wget screen jq
    fi
fi

# Set directories
SERVER_DIR="$HOME/minecraft-server"
export SDKMAN_DIR="$HOME/.sdkman"

echo "=== 2/5: Installing GraalVM 21 via SDKMAN ==="
if [ ! -d "$SDKMAN_DIR" ]; then
    curl -s "https://get.sdkman.io" | bash
fi

set +u
# shellcheck source=/dev/null
source "$SDKMAN_DIR/bin/sdkman-init.sh"
set -u

sdkman_auto_answer=true

if ! sdk list java | grep -q "21.0.2-graalce" 2>/dev/null; then
    sdk install java 21.0.2-graalce || true
fi
sdk use java 21.0.2-graalce

echo "=== 3/5: Fetching Latest PaperMC ${MINECRAFT_VERSION} Build ==="
mkdir -p "$SERVER_DIR"
cd "$SERVER_DIR"

LATEST_BUILD=$(curl -s "https://api.papermc.io/v2/projects/paper/versions/${MINECRAFT_VERSION}/builds" | jq -r '.builds[-1].build')

if [ -z "$LATEST_BUILD" ] || [ "$LATEST_BUILD" == "null" ]; then
    echo "[!] Error: Failed to fetch the latest build from PaperMC API." >&2
    exit 1
fi

DOWNLOAD_URL="https://api.papermc.io/v2/projects/paper/versions/${MINECRAFT_VERSION}/builds/${LATEST_BUILD}/downloads/paper-${MINECRAFT_VERSION}-${LATEST_BUILD}.jar"

echo "Downloading PaperMC build #${LATEST_BUILD}..."
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
screen -dmS mcserver java -Xms${MEMORY_ALLOCATION} -Xmx${MEMORY_ALLOCATION} -jar paper.jar --nogui

echo "=================================================="
echo " Setup Complete!"
echo " PaperMC Server (build #${LATEST_BUILD}) is running securely as user: $(whoami)"
echo " Server directory: $SERVER_DIR"
if [ "$(id -u)" -eq 0 ]; then
    echo " Use 'screen -r mcserver' to access the console."
else
    echo " Use 'su - $(whoami)' then 'screen -r mcserver' to access the console."
fi
echo "=================================================="
