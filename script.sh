#!/usr/bin/env bash

# Exit immediately on error or pipe failure, treat unset variables as an error
set -euo pipefail

MINECRAFT_VERSION="1.21"
SERVER_DIR="$HOME/minecraft-server"
MEMORY_ALLOCATION="3G"

echo "=== 1/5: Updating System & Installing Base Tools ==="
sudo apt-get update
sudo apt-get install -y curl zip unzip wget screen jq

echo "=== 2/5: Installing GraalVM 21 via SDKMAN ==="
export SDKMAN_DIR="$HOME/.sdkman"

if [ ! -d "$SDKMAN_DIR" ]; then
    curl -s "https://get.sdkman.io" | bash
fi

# Disable 'unset variables' check temporarily because SDKMAN violates it
set +u
# shellcheck source=/dev/null
source "$SDKMAN_DIR/bin/sdkman-init.sh"
set -u

# Set SDKMAN to non-interactive mode
sdkman_auto_answer=true

# Install GraalVM Java 21 (SDKMAN safely skips if already installed)
sdk install java 21.0.2-graalce
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
# Run Java to trigger initial folder/EULA generation
java -jar paper.jar --nogui || true

# Force EULA to true regardless of previous state
if [ -f "eula.txt" ]; then
    sed -i 's/eula=false/eula=true/' eula.txt
else
    echo "eula=true" > eula.txt
fi

echo "=== 5/5: Launching PaperMC Server in Screen ==="
# Stop any existing screen session with the same name to prevent overlaps
screen -X -S mcserver quit 2>/dev/null || true

# Start server in a background detached screen
screen -dmS mcserver java -Xms${MEMORY_ALLOCATION} -Xmx${MEMORY_ALLOCATION} -jar paper.jar --nogui

echo "=================================================="
echo " Setup Complete!"
echo " PaperMC Server (build #${LATEST_BUILD}) is running."
echo " Use 'screen -r mcserver' to access the console."
echo " Use 'Ctrl+A' followed by 'D' to detach."
echo "=================================================="
