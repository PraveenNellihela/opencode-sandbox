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
echo ""

# Check for Docker or Podman
CONTAINER_CMD=""
if command -v docker >/dev/null 2>&1; then
    CONTAINER_CMD="docker"
elif command -v podman >/dev/null 2>&1; then
    CONTAINER_CMD="podman"
else
    echo ""
    echo "Neither Docker nor Podman found."
    echo ""
    echo "Install one of the following:"
    echo "  Docker:  https://docs.docker.com/get-docker/"
    echo "  Podman:  https://podman.io/getting-started/installation"
    echo ""
    exit 1
fi

info "Using container runtime: $CONTAINER_CMD"

# Check if container runtime is running
if ! $CONTAINER_CMD info >/dev/null 2>&1; then
    error "$CONTAINER_CMD daemon not running. Start it and try again."
fi

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

# Build Docker image
echo ""
info "Building Docker image..."
if $CONTAINER_CMD build -t local:opencode "$SCRIPT_DIR"; then
    info "Docker image built successfully"
else
    error "Docker image build failed"
fi

echo ""
echo "=========================="
info "Installation complete!"
echo ""
echo "Usage:"
echo "  cd ~/code/my-project"
echo "  opencode"
echo ""
