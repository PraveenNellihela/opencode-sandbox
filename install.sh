#!/usr/bin/env bash
set -euo pipefail

# Colors for output — use bold variants for visibility on dark backgrounds
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
NC='\033[0m' # No Color

info() { echo -e "${GREEN}✓${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC} $1"; }
error() { echo -e "${RED}✗${NC} $1"; exit 1; }
header() { echo -e "${BLUE}==>${NC} $1"; }

# ── Defaults ─────────────────────────────────────────────────
INSTALL_NODE=false
INSTALL_PYTHON=false
INSTALL_GO=false
INSTALL_CLI_TOOLS=false
OPCODE_PLUGINS=""
OPCODE_MCP=""
OPCODE_AGENTS=false

# ── Help ─────────────────────────────────────────────────────
show_help() {
    cat <<EOF
Usage: install.sh [options]

Build and install the opencode-sandbox Docker image + wrapper script.

Options:
  -R, --recommended     Full power-up (Node.js + Python + CLI tools +
                          superpowers + pty + notify + websearch + impeccable + emil +
                          filesystem MCP + Context7 MCP + agents)
  -t, --toolchain LIST  Comma-separated toolchains: node,python,go,cli
  -p, --plugin LIST     Comma-separated plugins/skills:
                          superpowers,pty,notify,websearch,mcp-tool-search,impeccable,emil
  -m, --mcp LIST        Comma-separated MCP servers:
                          filesystem,context7,brave-search,github
  -a, --agents          Include pre-built agent files (code-reviewer,
                          security-analyst, debugger, documenter, tester, planner)
  -i, --interactive     Interactive prompts for selections
  -h, --help            Show this help message

Examples:
  ./install.sh                          # Minimal (same as current default)
  ./install.sh --recommended            # Full power-up
  ./install.sh -t node,cli -p superpowers -a   # Custom setup

EOF
    exit 0
}

# ── Parse flags ──────────────────────────────────────────────
INTERACTIVE=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        -R|--recommended)
            INSTALL_NODE=true
            INSTALL_PYTHON=true
            INSTALL_CLI_TOOLS=true
            OPCODE_PLUGINS="superpowers,pty,notify,websearch,impeccable,emil"
            OPCODE_MCP="filesystem,context7"
            OPCODE_AGENTS=true
            shift
            ;;
        -t|--toolchain)
            if [ -z "${2:-}" ]; then error "--toolchain requires a value"; fi
            IFS=',' read -ra items <<< "$2"
            for item in "${items[@]}"; do
                case "$item" in
                    node)   INSTALL_NODE=true ;;
                    python) INSTALL_PYTHON=true ;;
                    go)     INSTALL_GO=true ;;
                    cli)    INSTALL_CLI_TOOLS=true ;;
                    *)      warn "Unknown toolchain: $item (valid: node,python,go,cli)" ;;
                esac
            done
            shift 2
            ;;
        -p|--plugin)
            if [ -z "${2:-}" ]; then error "--plugin requires a value"; fi
            OPCODE_PLUGINS="$2"
            shift 2
            ;;
        -m|--mcp)
            if [ -z "${2:-}" ]; then error "--mcp requires a value"; fi
            OPCODE_MCP="$2"
            shift 2
            ;;
        -a|--agents)
            OPCODE_AGENTS=true
            shift
            ;;
        -i|--interactive)
            INTERACTIVE=true
            shift
            ;;
        -h|--help)
            show_help
            ;;
        *)
            error "Unknown option: $1. Use --help for usage."
            ;;
    esac
done

# ── Interactive mode ─────────────────────────────────────────
if [ "$INTERACTIVE" = true ]; then
    header "Toolchain selection"
    echo "Which toolchains would you like to install? (space-separated)"
    echo "  node python go cli"
    echo "  (leave empty for none)"
    read -r -a toolchain_choices
    for item in "${toolchain_choices[@]}"; do
        case "$item" in
            node)   INSTALL_NODE=true ;;
            python) INSTALL_PYTHON=true ;;
            go)     INSTALL_GO=true ;;
            cli)    INSTALL_CLI_TOOLS=true ;;
        esac
    done

    header "Plugin selection"
    echo "Which plugins would you like to configure? (comma-separated)"
    echo "  superpowers, pty, notify, websearch, mcp-tool-search, impeccable, emil"
    echo "  (leave empty for none)"
    read -r OPCODE_PLUGINS

    header "MCP server selection"
    echo "Which MCP servers would you like to configure? (comma-separated)"
    echo "  filesystem, context7, brave-search, github"
    echo "  (leave empty for none)"
    read -r OPCODE_MCP

    header "Agent files"
    echo "Include pre-built agent files? (y/N)"
    read -r agent_choice
    if [[ "$agent_choice" =~ ^[Yy] ]]; then
        OPCODE_AGENTS=true
    fi
fi

# ── Impeccable requires Node.js (its scripts run via node) ───
if [[ "$OPCODE_PLUGINS" == *impeccable* ]]; then
    INSTALL_NODE=true
fi

# ── Detect OS & shell ────────────────────────────────────────
detect_os() {
    case "$(uname -s)" in
        Linux*)
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

detect_shell() {
    local shell_name
    shell_name=$(basename "${SHELL:-/bin/bash}")
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

if [ "$OPCODE_PLUGINS" != "" ] || [ "$OPCODE_MCP" != "" ] || [ "$OPCODE_AGENTS" = true ] || \
   [ "$INSTALL_NODE" = true ] || [ "$INSTALL_PYTHON" = true ] || [ "$INSTALL_GO" = true ] || [ "$INSTALL_CLI_TOOLS" = true ]; then
    echo "Build configuration:"
    [ "$INSTALL_NODE" = true ]       && echo "  Toolchains: Node.js"
    [ "$INSTALL_PYTHON" = true ]     && echo "  Toolchains: Python 3"
    [ "$INSTALL_GO" = true ]         && echo "  Toolchains: Go"
    [ "$INSTALL_CLI_TOOLS" = true ]  && echo "  Toolchains: ripgrep, fd-find, jq, tmux"
    [ "$OPCODE_PLUGINS" != "" ]      && echo "  Plugins: $OPCODE_PLUGINS"
    [ "$OPCODE_MCP" != "" ]          && echo "  MCP servers: $OPCODE_MCP"
    [ "$OPCODE_AGENTS" = true ]      && echo "  Agents: code-reviewer, security-analyst, debugger, documenter, tester, planner"
    echo ""
fi

# ── Check container runtime ──────────────────────────────────
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

# WSL-specific guidance
if [ "$OS" = "wsl" ]; then
    echo ""
    echo "Note: On WSL, Docker Desktop must be running with the WSL2 backend enabled."
    echo "See: https://docs.docker.com/desktop/wsl/"
    echo ""
fi

# Check if container runtime is running
if ! $CONTAINER_CMD info >/dev/null 2>&1; then
    error "$CONTAINER_CMD daemon not running. Start it and try again."
fi

# ── Build Docker image with selected features ────────────────
echo ""

# Create ~/bin if needed (we need it after build to install the wrapper)
if [ ! -d "$HOME/bin" ]; then
    mkdir -p "$HOME/bin"
    # shellcheck disable=SC2088
    info "Created ~/bin"
else
    # shellcheck disable=SC2088
    info "~/bin already exists"
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ ! -f "$SCRIPT_DIR/opencode" ]; then
    echo "Error: opencode wrapper not found in $SCRIPT_DIR"
    echo "Run install.sh from the repo directory."
    exit 1
fi

BUILD_ARGS=(
    --build-arg "INSTALL_NODE=$INSTALL_NODE"
    --build-arg "INSTALL_PYTHON=$INSTALL_PYTHON"
    --build-arg "INSTALL_GO=$INSTALL_GO"
    --build-arg "INSTALL_CLI_TOOLS=$INSTALL_CLI_TOOLS"
    --build-arg "OPCODE_PLUGINS=$OPCODE_PLUGINS"
    --build-arg "OPCODE_MCP=$OPCODE_MCP"
    --build-arg "OPCODE_AGENTS=$OPCODE_AGENTS"
)

info "Building Docker image (this may take a few minutes)..."
if $CONTAINER_CMD build "${BUILD_ARGS[@]}" -t local:opencode "$SCRIPT_DIR"; then
    info "Docker image built successfully"
else
    error "Docker image build failed"
fi

# Copy wrapper only after successful build
cp "$SCRIPT_DIR/opencode" "$HOME/bin/opencode"
chmod +x "$HOME/bin/opencode"
info "Installed wrapper to ~/bin/opencode"

# Check if ~/bin is in shell config
if [ "$SHELL_NAME" = "fish" ]; then
    FISH_CONFIG="$HOME/.config/fish/config.fish"
    if grep -q 'fish_add_path ~/bin' "$FISH_CONFIG" 2>/dev/null; then
        # shellcheck disable=SC2088
        info "~/bin already in fish PATH config"
    else
        # shellcheck disable=SC2088
        warn "~/bin not in fish PATH config"
    fi
else
    # shellcheck disable=SC2016
    if grep -q 'export PATH="\$HOME/bin:\$PATH"' "$CONFIG_FILE" 2>/dev/null; then
        # shellcheck disable=SC2088
        info "~/bin already in $CONFIG_FILE"
    else
        # shellcheck disable=SC2088
        warn "~/bin not in $CONFIG_FILE"
    fi
fi

echo ""
echo "=========================="
info "Installation complete!"
echo ""

# Print PATH setup instructions
if [ "$SHELL_NAME" = "fish" ]; then
    if ! grep -q 'fish_add_path ~/bin' "$HOME/.config/fish/config.fish" 2>/dev/null; then
        echo "Run this command to add ~/bin to your PATH:"
        echo ""
        echo "  fish_add_path ~/bin"
        echo ""
    fi
else
        # shellcheck disable=SC2016
        if ! grep -q 'export PATH="\$HOME/bin:\$PATH"' "$CONFIG_FILE" 2>/dev/null; then
            echo "Run this command to add ~/bin to your PATH:"
            echo ""
            echo "  echo 'export PATH=\"\$HOME/bin:\$PATH\"' >> $CONFIG_FILE"
        echo ""
        echo "Then restart your shell or run:"
        echo ""
        echo "  source $CONFIG_FILE"
        echo ""
    fi
fi

echo "Usage:"
echo "  cd ~/code/my-project"
echo "  opencode"
echo ""