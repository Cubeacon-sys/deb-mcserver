#!/usr/bin/env bash

# Exit immediately on error or pipe failure, treat unset variables as an error
set -euo pipefail

MINECRAFT_VERSION="1.21"
MEMORY_ALLOCATION="4G"
MC_USER="minecraft"

echo "=== 1/5: System Checks & Base Tools ==="

# Check if script is running as root
if [ "$(id -u)" -eq 0 ]; then
    echo "Script run as root. Installing base packages..."
    apt-get update
    apt-get install -y curl zip unzip wget screen jq sudo

    # Create a dedicated minecraft user if it doesn't exist
    if ! id -u "$MC_USER" >/dev/null 2>&1; then
        echo "Creating dedicated '$MC_USER' user for security..."
        useradd -m -s /bin/bash "$MC_USER"
    fi

    echo "Dropping root privileges and switching to '$MC_USER'..."
    # Re-execute this exact script as the minecraft user
    exec sudo -u "$MC_USER" "$0" "$@"
fi

# From this point forward, the script is guaranteed to be running as a standard user.
# If a normal user ran the script initially, install the tools via sudo.
if ! command -v jq >/dev/null 2>&1; then
    sudo apt-get update
    sudo apt-get install -y curl zip unzip wget screen jq
fi

# Set directories dynamically based on the current executing user
SERVER_DIR="$HOME/minecraft-server"
export SDKMAN_DIR="$HOME/.sdkman"

echo "=== 2/5: Installing GraalVM 21 via SDKMAN ==="
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

# Install GraalVM Java 21
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
echo " Use 'su - $(whoami)' then 'screen -r mcserver' to access the console."
echo "=================================================="
