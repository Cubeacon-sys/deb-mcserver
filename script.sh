#!/usr/bin/env bash

# Exit immediately on error, unset variables, or pipe failure
set -euo pipefail

MEMORY_ALLOCATION="4G"
MC_USER="minecraft"
ALLOW_ROOT=false # Set to true ONLY if running inside a Docker container

echo "=== 1/5: System Checks & Base Tools ==="

if [ "$(id -u)" -eq 0 ]; then
    if [ "$ALLOW_ROOT" = true ]; then
        echo "WARNING: ALLOW_ROOT is true. Proceeding as root..."
        apt-get update
        apt-get install -y curl zip unzip wget screen jq
        TARGET_USER="root"
        RUN_CMD="bash"
    else
        echo "Script run as root. Installing base packages..."
        apt-get update
        apt-get install -y curl zip unzip wget screen jq sudo

        if ! id -u "$MC_USER" >/dev/null 2>&1; then
            echo "Creating dedicated '$MC_USER' user for security..."
            useradd -m -s /bin/bash "$MC_USER"
        fi
        TARGET_USER="$MC_USER"
        # Setup the command to run a clean login shell as the minecraft user
        RUN_CMD="sudo -i -u $MC_USER bash"
    fi
else
    echo "Running as normal user. Checking sudo..."
    if ! command -v jq >/dev/null 2>&1; then
        sudo apt-get update
        sudo apt-get install -y curl zip unzip wget screen jq
    fi
    TARGET_USER="$(whoami)"
    RUN_CMD="bash"
fi

echo "=== Transitioning Execution to $TARGET_USER ==="

# Stream the rest of the script directly into the target user's shell.
# This prevents ALL file permission and curl-piping issues.
$RUN_CMD << EOF
set -euo pipefail

# Inner variables must be escaped (\$) so they run inside the new user's shell
MINECRAFT_VERSION=\$(curl -sL "https://api.papermc.io/v2/projects/paper" | jq -r '.versions[-1]')
SERVER_DIR="\$HOME/minecraft-server"
SDKMAN_DIR="\$HOME/.sdkman"

echo "=== 2/5: Installing GraalVM 21 via SDKMAN ==="
if [ ! -d "\$SDKMAN_DIR" ]; then
    curl -s "https://get.sdkman.io" | bash
fi

# Disable strict mode temporarily for SDKMAN
set +u
source "\$SDKMAN_DIR/bin/sdkman-init.sh"
sdkman_auto_answer=true

if ! sdk list java | grep -q "21.0.2-graalce" 2>/dev/null; then
    sdk install java 21.0.2-graalce || true
fi
sdk use java 21.0.2-graalce
set -u

echo "=== 3/5: Fetching Latest PaperMC \${MINECRAFT_VERSION} Build ==="
mkdir -p "\$SERVER_DIR"
cd "\$SERVER_DIR"

LATEST_BUILD=\$(curl -sL "https://api.papermc.io/v2/projects/paper/versions/\${MINECRAFT_VERSION}/builds" | jq -r '.builds[-1].build')

if [ -z "\$LATEST_BUILD" ] || [ "\$LATEST_BUILD" == "null" ]; then
    echo "[!] Error: Failed to fetch the latest build from PaperMC API." >&2
    curl -sL "https://api.papermc.io/v2/projects/paper/versions/\${MINECRAFT_VERSION}/builds"
    exit 1
fi

DOWNLOAD_URL="https://api.papermc.io/v2/projects/paper/versions/\${MINECRAFT_VERSION}/builds/\${LATEST_BUILD}/downloads/paper-\${MINECRAFT_VERSION}-\${LATEST_BUILD}.jar"

echo "Downloading PaperMC build #\${LATEST_BUILD}..."
wget -q -O paper.jar "\$DOWNLOAD_URL"

echo "=== 4/5: Initializing Server & Accepting EULA ==="
java -jar paper.jar --nogui || true

if [ -f "eula.txt" ]; then
    sed -i 's/eula=false/eula=true/' eula.txt
else
    echo "eula=true" > eula.txt
fi

echo "=== 5/5: Launching PaperMC Server in Screen ==="
screen -X -S mcserver quit 2>/dev/null || true

# Notice MEMORY_ALLOCATION is unescaped so the outer shell passes the value in
screen -dmS mcserver java -Xms${MEMORY_ALLOCATION} -Xmx${MEMORY_ALLOCATION} -jar paper.jar --nogui

echo "=================================================="
echo " Setup Complete!"
echo " PaperMC Server (build #\${LATEST_BUILD}) is running securely as user: \$(whoami)"
echo " Server directory: \$SERVER_DIR"
echo "=================================================="
EOF

echo "To access the server console, run the following:"
if [ "$TARGET_USER" = "root" ] || [ "$(whoami)" = "$TARGET_USER" ]; then
    echo "  screen -r mcserver"
else
    echo "  su - $TARGET_USER"
    echo "  screen -r mcserver"
fi
