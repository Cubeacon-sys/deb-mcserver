#!/usr/bin/env bash

# Exit immediately on error, unset variables, or pipe failure
set -euo pipefail

MEMORY_ALLOCATION="4G"
SERVER_DIR="$HOME/minecraft-server"
export SDKMAN_DIR="$HOME/.sdkman"

echo "=== 1/5: System Checks & Base Tools ==="
# Install packages. Use sudo only if we aren't root.
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

# Disable strict mode temporarily for SDKMAN
set +u
# shellcheck source=/dev/null
source "$SDKMAN_DIR/bin/sdkman-init.sh"
sdkman_auto_answer=true

if ! sdk list java | grep -q "21.0.2-graalce" 2>/dev/null; then
    sdk install java 21.0.2-graalce || true
fi
sdk use java 21.0.2-graalce
set -u

echo "=== 3/5: Fetching Latest PaperMC Build ==="
mkdir -p "$SERVER_DIR"
cd "$SERVER_DIR"

# Dynamically fetch the absolute latest Minecraft version from PaperMC
MINECRAFT_VERSION=$(curl -sL "https://api.papermc.io/v2/projects/paper" | jq -r '.versions[-1]')
echo "Detected latest Minecraft version: $MINECRAFT_VERSION"

LATEST_BUILD=$(curl -sL "https://api.papermc.io/v2/projects/paper/versions/${MINECRAFT_VERSION}/builds" | jq -r '.builds[-1].build')

if [ -z "$LATEST_BUILD" ] || [ "$LATEST_BUILD" == "null" ]; then
    echo "[!] Error: Failed to fetch the latest build from PaperMC API." >&2
    curl -sL "https://api.papermc.io/v2/projects/paper/versions/${MINECRAFT_VERSION}/builds"
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

# Start server in a background detached screen
screen -dmS mcserver java -Xms${MEMORY_ALLOCATION} -Xmx${MEMORY_ALLOCATION} -jar paper.jar --nogui

echo "=================================================="
echo " Setup Complete!"
echo " PaperMC Server (build #${LATEST_BUILD}) is running."
echo " Server directory: $SERVER_DIR"
echo " Use 'screen -r mcserver' to access the console."
echo "=================================================="
