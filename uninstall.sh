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
        $CONTAINER_CMD volume rm opencode-config opencode-data 2>/dev/null || true
        info "Removed container volumes"
    else
        warn "Volumes kept. Remove later with: $CONTAINER_CMD volume rm opencode-config opencode-data"
    fi
else
    info "No opencode volumes found"
fi

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

echo ""
echo "=========================="
info "Uninstall complete!"
echo ""
echo "Remember to remove the PATH entry from your shell config (see above)."
echo ""
