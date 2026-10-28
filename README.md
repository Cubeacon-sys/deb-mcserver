# PaperMC Server Installer

An automated, self-contained Bash script designed to provision, configure, and launch a Minecraft server using PaperMC on Debian (or its derivatives) environments

---

## Key Features

* **Zero-Touch Execution:** Fully self-contained logic that installs dependencies, provisions Java, downloads the server, accepts the EULA, and launches the server.
* **PaperMC v3 API Integration:** Automatically queries PaperMC's latest `fill.papermc.io` API endpoint using customized request headers to grab the newest available `1.2x` Minecraft version and build.
* **GraalVM 21 Runtime:** Uses SDKMAN to fetch and set up GraalVM 21 Java runtime automatically.
* **Screen Management:** Automatically handles instance lifecycle management by running the server process inside a detached `screen` session (`mcserver`).

---

## Quick Start

Execute the script directly via `curl`:

```bash
curl -sL https://raw.githubusercontent.com/Cubeacon-sys/deb-mcserver/refs/heads/main/script.sh | bash

```

---

## Requirements

* **Operating System:** Linux (Debian/Ubuntu-based distributions recommended)
* **Access Level:** `root` or a user with `sudo` privileges
* **Core Utilities:** `curl`, `jq`, `screen`, `wget`, `zip`, `unzip` *(installed automatically if missing)*

---

## What the Script Does

1. **System Checks & Base Tools:** Updates system package indices and installs basic utilities (`curl`, `jq`, `screen`, `wget`, `zip`, `unzip`).
2. **Java Runtime Setup:** Installs SDKMAN in `$HOME/.sdkman` if absent, then installs and sets GraalVM 21 (`21.0.2-graalce`) as the active Java runtime.
3. **PaperMC Jar Retrieval:**
* Queries `[https://fill.papermc.io/v3/projects/paper](https://fill.papermc.io/v3/projects/paper)` with a custom `User-Agent`.
* Filters and selects the highest stable `1.2x` release.
* Downloads the latest build `.jar` directly into `~/minecraft-server/paper.jar`.


4. **Initialization & EULA:** Runs an initial dry run of the server to generate configurations and sets `eula=true` in `eula.txt`.
5. **Background Server Launch:** Terminates any existing `mcserver` screen session and starts the Minecraft server in a new detached session with `4GB` of allocated RAM.

---

## Post-Installation & Management

### Managing the Server Session

The server runs inside a detached `screen` session named `mcserver`.

* **Attach to Server Console:**
```bash
screen -r mcserver

```


* **Detach from Console:**
Press `Ctrl + A`, then press `D`.
* **Stop the Server Safely:**
Inside the server console, type:
```text
stop

```

---

## Configuration

To customize allocated memory or target directories, edit the script variables at the top of the file:

```bash
MEMORY_ALLOCATION="4G"                  # Adjust memory allocation (e.g., 2G, 8G)
SERVER_DIR="$HOME/minecraft-server"     # Path where server files are stored

```