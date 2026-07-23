# Cross-Platform Setup & Teardown Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create install.sh, uninstall.sh, improve the wrapper script, and rewrite README.md for cross-platform use with safe PATH handling.

**Architecture:** Two shell scripts (install/uninstall) handle setup and teardown. Wrapper script gets --help and safety checks. README rewritten for clarity. No auto-editing of shell rc files — all PATH changes are manual instructions.

**Tech Stack:** POSIX shell, Docker

## Global Constraints

- Never auto-edit shell rc files (bash, zsh, fish) — print instructions only
- Never remove `~/bin/` directory itself
- Never remove Docker volumes without explicit user confirmation
- Wrapper must handle directories with spaces
- Scripts must be POSIX-compatible (no bashisms in install/uninstall)

---

## File Structure

| File | Action | Purpose |
|------|--------|---------|
| `install.sh` | Create | One-command setup: detect env, create ~/bin, copy wrapper, build image, print PATH instructions |
| `uninstall.sh` | Create | Full teardown: remove wrapper, prompt about volumes/image, print PATH removal instructions |
| `opencode` | Modify | Add --help, Docker checks, image build fallback, --uninstall flag |
| `README.md` | Rewrite | Quick start, cross-platform, shell support, troubleshooting |

---

### Task 1: Create `install.sh`

**Files:**
- Create: `install.sh`

**Interfaces:**
- Consumes: `opencode` wrapper script in same directory, `Dockerfile` in same directory
- Produces: `~/bin/opencode` (copy of wrapper), Docker image `local:opencode`, printed PATH instructions

- [ ] **Step 1: Create install.sh with environment detection**

```bash
#!/usr/bin/env bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

info() { echo -e "${GREEN}✓${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC} $1"; }
error() { echo -e "${RED}✗${NC} $1"; exit 1; }

# Detect OS
detect_os() {
    case "$(uname -s)" in
        Linux*)
            # Check for WSL
            if grep -qi microsoft /proc/version 2>/dev/null; then
                echo "wsl"
            else
                echo "linux"
            fi
            ;;
        Darwin*)    echo "macos";;
        MINGW*|MSYS*|CYGWIN*) echo "windows";;
        *)          echo "unknown";;
    esac
}

# Detect shell and config file
detect_shell() {
    local shell_name=$(basename "${SHELL:-/bin/bash}")
    case "$shell_name" in
        bash) echo "bash ~/.bashrc";;
        zsh)  echo "zsh ~/.zshrc";;
        fish) echo "fish ~/.config/fish/config.fish";;
        *)    echo "bash ~/.bashrc";;
    esac
}

OS=$(detect_os)
SHELL_INFO=$(detect_shell)
SHELL_NAME=$(echo "$SHELL_INFO" | cut -d' ' -f1)
CONFIG_FILE=$(echo "$SHELL_INFO" | cut -d' ' -f2)

echo "opencode-sandbox installer"
echo "=========================="
echo "OS:    $OS"
echo "Shell: $SHELL_NAME"
echo "Config: $CONFIG_FILE"
echo "Container: ${CONTAINER_CMD:-none}"
echo ""
```

- [ ] **Step 2: Add Docker check**

```bash
# Check for Docker or Podman
CONTAINER_CMD=""
if command -v docker >/dev/null 2>&1; then
    CONTAINER_CMD="docker"
    info "Docker found: $(docker --version)"
elif command -v podman >/dev/null 2>&1; then
    CONTAINER_CMD="podman"
    info "Podman found: $(podman --version)"
else
    error "Neither Docker nor Podman found."
    echo "Install Docker: https://docs.docker.com/get-docker/"
    echo "Or install Podman: https://podman.io/getting-started/installation"
    exit 1
fi

# Check if container runtime is running
if ! $CONTAINER_CMD info >/dev/null 2>&1; then
    error "$CONTAINER_CMD daemon not running. Start it and try again."
fi
```

- [ ] **Step 3: Add wrapper installation**

```bash
# Create ~/bin if needed
if [ ! -d "$HOME/bin" ]; then
    mkdir -p "$HOME/bin"
    info "Created ~/bin"
else
    info "~/bin already exists"
fi

# Copy wrapper script
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cp "$SCRIPT_DIR/opencode" "$HOME/bin/opencode"
chmod +x "$HOME/bin/opencode"
info "Installed wrapper to ~/bin/opencode"
```

- [ ] **Step 4: Add PATH instructions**

```bash
# Check if ~/bin is already on PATH
case ":$PATH:" in
    *":$HOME/bin:"*)
        info "~/bin is already on PATH"
        ;;
    *)
        echo ""
        echo "Add this line to your $CONFIG_FILE:"
        echo ""
        if [ "$SHELL_NAME" = "fish" ]; then
            echo "  fish_add_path ~/bin"
        else
            echo "  export PATH=\"\$HOME/bin:\$PATH\""
        fi
        echo ""
        echo "Then restart your shell or run: source $CONFIG_FILE"
        ;;
esac
```

- [ ] **Step 5: Add Docker image build**

```bash
# Build Docker image
echo ""
info "Building Docker image..."
if $CONTAINER_CMD build -t local:opencode "$SCRIPT_DIR"; then
    info "Docker image built successfully"
else
    error "Docker image build failed"
fi
```

- [ ] **Step 6: Add success message**

```bash
echo ""
echo "=========================="
info "Installation complete!"
echo ""
echo "Usage:"
echo "  cd ~/code/my-project"
echo "  opencode"
echo ""
```

- [ ] **Step 7: Make install.sh executable and test**

```bash
chmod +x install.sh
./install.sh
```

Expected: Script runs, detects shell, installs wrapper, builds image, prints PATH instructions.

- [ ] **Step 8: Commit**

```bash
git add install.sh
git commit -m "feat: add install.sh for cross-platform setup"
```

---

### Task 2: Create `uninstall.sh`

**Files:**
- Create: `uninstall.sh`

**Interfaces:**
- Consumes: Nothing (standalone script)
- Produces: Removes ~/bin/opencode, prompts about Docker volumes/image, prints PATH removal instructions

- [ ] **Step 1: Create uninstall.sh with header and wrapper removal**

```bash
#!/usr/bin/env bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

info() { echo -e "${GREEN}✓${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC} $1"; }

# Detect shell for PATH instructions
detect_shell() {
    local shell_name=$(basename "${SHELL:-/bin/bash}")
    case "$shell_name" in
        bash|zsh) echo "$shell_name";;
        fish)     echo "fish";;
        *)        echo "bash";;
    esac
}

SHELL_NAME=$(detect_shell)

echo "opencode-sandbox uninstaller"
echo "============================"
echo ""

# Remove wrapper
if [ -f "$HOME/bin/opencode" ]; then
    rm "$HOME/bin/opencode"
    info "Removed ~/bin/opencode"
else
    warn "~/bin/opencode not found (already removed?)"
fi
```

- [ ] **Step 2: Add PATH removal instructions**

```bash
# Print PATH removal instructions (never auto-edit rc files)
echo ""
echo "Manual step — remove this from your shell config:"
echo ""
if [ "$SHELL_NAME" = "fish" ]; then
    echo "  Run: fish_remove_path ~/bin"
else
    echo "  export PATH=\"\$HOME/bin:\$PATH\""
fi
echo ""
```

- [ ] **Step 3: Add Docker volume prompt**

```bash
# Check for Docker or Podman
CONTAINER_CMD=""
if command -v docker >/dev/null 2>&1; then
    CONTAINER_CMD="docker"
elif command -v podman >/dev/null 2>&1; then
    CONTAINER_CMD="podman"
fi

# Check for container volumes
if [ -n "$CONTAINER_CMD" ]; then
    VOLUMES=$($CONTAINER_CMD volume ls --format '{{.Name}}' 2>/dev/null | grep -E "opencode-config|opencode-data" || true)
else
    VOLUMES=""
fi

if [ -n "$VOLUMES" ]; then
    echo "Found opencode data volumes:"
    echo "$VOLUMES" | while read vol; do
        case "$vol" in
            opencode-config) echo "  - $vol (settings, plugins)";;
            opencode-data)   echo "  - $vol (auth tokens, sessions)";;
        esac
    done
    echo ""
    read -p "Remove these volumes? This cannot be undone. [y/N] " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "$VOLUMES" | xargs $CONTAINER_CMD volume rm
        info "Removed container volumes"
    else
        warn "Volumes kept. Remove later with: $CONTAINER_CMD volume rm opencode-config opencode-data"
    fi
else
    info "No opencode volumes found"
fi
```

- [ ] **Step 4: Add Docker image prompt**

```bash
# Check for container image
if [ -n "$CONTAINER_CMD" ] && $CONTAINER_CMD image inspect local:opencode >/dev/null 2>&1; then
    echo ""
    read -p "Remove container image local:opencode? [y/N] " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        $CONTAINER_CMD rmi local:opencode
        info "Removed container image"
    else
        warn "Image kept. Remove later with: $CONTAINER_CMD rmi local:opencode"
    fi
else
    info "Container image not found (already removed?)"
fi
```

- [ ] **Step 5: Add summary**

```bash
echo ""
echo "=========================="
info "Uninstall complete!"
echo ""
echo "Remember to remove the PATH entry from your shell config (see above)."
echo ""
```

- [ ] **Step 6: Make uninstall.sh executable and test**

```bash
chmod +x uninstall.sh
./uninstall.sh
```

Expected: Script runs, removes wrapper, prompts about volumes/image, prints PATH instructions.

- [ ] **Step 7: Commit**

```bash
git add uninstall.sh
git commit -m "feat: add uninstall.sh for safe teardown"
```

---

### Task 3: Improve `opencode` wrapper script

**Files:**
- Modify: `opencode`

**Interfaces:**
- Consumes: Docker, local:opencode image
- Produces: Runs opencode in container, or prints help/uninstall info

- [ ] **Step 1: Read current opencode script**

Read `opencode` to understand current structure.

- [ ] **Step 2: Add --help flag and safety checks**

Replace the entire `opencode` file with:

```bash
#!/usr/bin/env bash
# Wrapper to run opencode inside its sandbox container.
# Install: run ./install.sh from the repo directory.
set -euo pipefail

# Usage/help
if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    cat <<EOF
opencode-sandbox wrapper

Usage: opencode [args...]

Runs opencode inside an isolated Docker container with your current
directory mounted at /home/dev/workspace.

Options:
  --help, -h       Show this help message
  --uninstall      Run the uninstall script

The container only sees your current project directory. Settings and
auth tokens persist via Docker volumes.

Install: ./install.sh
Uninstall: ./uninstall.sh
EOF
    exit 0
fi

# Uninstall
if [ "${1:-}" = "--uninstall" ]; then
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    if [ -f "$SCRIPT_DIR/uninstall.sh" ]; then
        exec "$SCRIPT_DIR/uninstall.sh"
    else
        echo "Error: uninstall.sh not found in $SCRIPT_DIR"
        exit 1
    fi
fi

# Check for Docker or Podman
CONTAINER_CMD=""
if command -v docker >/dev/null 2>&1; then
    CONTAINER_CMD="docker"
elif command -v podman >/dev/null 2>&1; then
    CONTAINER_CMD="podman"
else
    echo "Error: Neither Docker nor Podman found."
    echo "Install Docker: https://docs.docker.com/get-docker/"
    echo "Or install Podman: https://podman.io/getting-started/installation"
    exit 1
fi

# Check if container runtime is running
if ! $CONTAINER_CMD info >/dev/null 2>&1; then
    echo "Error: $CONTAINER_CMD daemon not running."
    echo "Start it and try again."
    exit 1
fi

# Check if image exists, build if not
if ! $CONTAINER_CMD image inspect local:opencode >/dev/null 2>&1; then
    echo "Image not found. Building..."
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    $CONTAINER_CMD build -t local:opencode "$SCRIPT_DIR"
fi

CWD="$(pwd)"

$CONTAINER_CMD run --rm -it \
  --name "opencode-$(basename "$CWD")-$$" \
  -v opencode-config:/home/dev/.config/opencode \
  -v opencode-data:/home/dev/.local/share/opencode \
  -v "$CWD":/home/dev/workspace \
  -w /home/dev/workspace \
  local:opencode "$@"
```

- [ ] **Step 3: Test --help flag**

```bash
./opencode --help
```

Expected: Prints usage information and exits.

- [ ] **Step 4: Test Docker check (if Docker is running)**

```bash
./opencode
```

Expected: Runs opencode in container (or builds image if missing).

- [ ] **Step 5: Commit**

```bash
git add opencode
git commit -m "feat: improve wrapper with --help, Docker checks, --uninstall"
```

---

### Task 4: Rewrite `README.md`

**Files:**
- Modify: `README.md`

**Interfaces:**
- Consumes: install.sh, uninstall.sh, opencode wrapper, Dockerfile
- Produces: Complete documentation for users

- [ ] **Step 1: Write new README.md**

Replace the entire `README.md` file with:

```markdown
# opencode-sandbox

Minimal, isolated, persistent setup for running [opencode](https://opencode.ai) on any OS via Docker.

## Quick Start

```bash
# 1. Clone and enter the repo
git clone <repo-url> opencode-sandbox
cd opencode-sandbox

# 2. Run the installer
./install.sh

# 3. Use opencode from any project
cd ~/code/my-project
opencode
```

The installer detects your OS and shell, copies the wrapper to `~/bin/`, builds the Docker image, and prints the PATH command you need to add to your shell config.

## How It Works

- **Isolated:** Container only sees the current project directory (bind mount). Not your home directory, not other repos, not host processes.
- **Persistent:** Settings and auth tokens survive container restarts via Docker volumes.
- **Secure:** Runs as non-root user with no sudo. Docker networking only.

## What Persists vs. What Doesn't

**Persists** (Docker volumes):
- `~/.config/opencode` — settings, plugins
- `~/.local/share/opencode` — auth tokens, session data

**Does not persist** (lost when container exits):
- OS-level packages installed during a session
- Any changes outside the above directories

If you need a package (e.g., Node.js for a plugin), add it to the `Dockerfile` and rebuild.

## Cross-Platform

### Linux

Works out of the box with Docker Engine installed.

### macOS

Install Docker Desktop first: https://docs.docker.com/desktop/install/mac-install/

Apple Silicon and Intel both supported.

### Windows (WSL2)

1. Install WSL2: `wsl --install`
2. Install Docker Desktop with WSL2 backend
3. Run `install.sh` from inside WSL

## Shell Support

The installer detects your shell and prints the appropriate PATH command:

| Shell | Command to add | Config file |
|-------|----------------|-------------|
| bash | `export PATH="$HOME/bin:$PATH"` | `~/.bashrc` |
| zsh | `export PATH="$HOME/bin:$PATH"` | `~/.zshrc` |
| fish | `fish_add_path ~/bin` | `~/.config/fish/config.fish` |

The installer does **not** auto-edit your shell config. You add the line manually for safety.

## Adding Dependencies

If a plugin or MCP server needs a system package (e.g., Node.js), add to the `Dockerfile` before the `USER dev` line:

```dockerfile
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - \
    && apt-get install -y nodejs
```

Then rebuild: `docker build -t local:opencode .`

Cached layers make this fast.

## Installing Plugins

Plugins that opencode installs itself land under `~/.config/opencode` (a persisted volume), so they survive container restarts.

Example: [superpowers](https://github.com/obra/superpowers), installed from inside opencode with:

```
Fetch and follow instructions from https://raw.githubusercontent.com/obra/superpowers/refs/heads/main/.opencode/INSTALL.md
```

## Security Model

- **Non-root:** Container runs as `dev` user with no sudo.
- **Minimal access:** Only sees current project directory via bind mount.
- **Network:** Default bridge networking — can reach internet (for LLM APIs) but nothing on host is exposed.

If you need live root for something, that's a signal to add it to the Dockerfile and rebuild, not to grant privilege escalation.

### Using Podman instead of Docker

The scripts support Podman as a Docker alternative. Install Podman:

- Linux: `sudo apt install podman` or `sudo dnf install podman`
- macOS: `brew install podman`

Podman removes the root-daemon-on-host concern entirely. See https://podman.io for details.

## Uninstalling

```bash
./uninstall.sh
```

This removes:
- `~/bin/opencode` (wrapper script)
- Docker image (optional, prompted)
- Docker volumes (optional, prompted — won't delete without confirmation)

It does **not** auto-edit your shell config. You remove the PATH line manually.

## Troubleshooting

**"Docker: command not found" / "Podman: command not found"**
→ Install Docker: https://docs.docker.com/get-docker/
→ Or install Podman: https://podman.io/getting-started/installation

**"Cannot connect to the Docker daemon" / "Cannot connect to Podman socket"**
→ Start Docker Desktop or: `sudo systemctl start docker`
→ For Podman: `podman machine start` (macOS) or check system service

**"opencode: command not found" after install**
→ Restart your shell, or: `source ~/.bashrc` (or `~/.zshrc`)

**"Image not found" error**
→ Run: `./install.sh` (rebuilds the image)

**Permission denied on ~/bin**
→ Check ownership: `ls -la ~/bin`
→ Fix: `chown -R $(whoami) ~/bin`
```

- [ ] **Step 2: Review the new README**

Read the file back to verify formatting and content.

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: rewrite README for cross-platform use and safety"
```

---

### Task 5: Final verification

- [ ] **Step 1: Test install.sh**

```bash
./install.sh
```

Expected: Detects environment, installs wrapper, builds image, prints PATH instructions.

- [ ] **Step 2: Test opencode --help**

```bash
~/bin/opencode --help
```

Expected: Prints usage and exits.

- [ ] **Step 3: Test uninstall.sh**

```bash
./uninstall.sh
```

Expected: Removes wrapper, prompts about volumes/image, prints PATH removal instructions.

- [ ] **Step 4: Verify no rc file changes**

```bash
# Check that .bashrc was not modified
git diff ~/.bashrc 2>/dev/null || echo "No changes to .bashrc"
```

Expected: No changes to shell config files.

- [ ] **Step 5: Commit all changes**

```bash
git add -A
git commit -m "feat: complete cross-platform setup and teardown"
```

---

## Summary

After completing all tasks:
- `install.sh` — one-command setup with printed PATH instructions
- `uninstall.sh` — safe teardown with volume prompts
- `opencode` — improved wrapper with --help, Docker checks, --uninstall
- `README.md` — cross-platform documentation with troubleshooting

No shell rc files are auto-edited. Docker volumes require confirmation before removal.
