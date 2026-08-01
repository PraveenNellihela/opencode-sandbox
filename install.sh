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
INSTALL_CLI_TOOLS=false
OPCODE_PLUGINS=""
OPCODE_MCP=""
OPCODE_AGENTS=false
RECOMMENDED=false
EXPLICIT_FLAGS=false
INTERACTIVE=false
UPDATE_FLAG=false
BUILD_FLAG=false

IMAGE_REPO="ghcr.io/praveennellihela/opencode-sandbox"
STATE_DIR="$HOME/.config/opencode-sandbox"

# ── Help ─────────────────────────────────────────────────────
show_help() {
    cat <<EOF
Usage: install.sh [options]

Install opencode-sandbox: fetches a prebuilt image (fast) or builds one
locally, seeds the opencode configuration, and installs the wrapper script.

Options:
  -R, --recommended     Full power-up (Node.js + Python + CLI tools +
                          superpowers + pty + notify + websearch + impeccable + emil +
                          filesystem MCP + Context7 MCP + agents)
  -t, --toolchain LIST  Comma-separated toolchains: node,python,cli
  -p, --plugin LIST     Comma-separated plugins/skills:
                          superpowers,pty,notify,websearch,mcp-tool-search,impeccable,emil
  -m, --mcp LIST        Comma-separated MCP servers:
                          filesystem,context7,brave-search,github
  -a, --agents          Include pre-built agent files (code-reviewer,
                          security-analyst, debugger, documenter, tester, planner)
  -i, --interactive     Interactive prompts for selections
  -u, --update          Re-pull the previously installed variant and re-seed
  -b, --build           Force building the image locally instead of pulling
  -h, --help            Show this help message

Default behavior:
  ./install.sh                  Pulls the prebuilt minimal image
  ./install.sh --recommended    Pulls the prebuilt recommended image
  ./install.sh <custom flags>   Builds locally with your selections

Examples:
  ./install.sh --recommended
  ./install.sh -t node,cli -p superpowers -a   # custom build
  ./install.sh --update                        # refresh to the latest image

EOF
    exit 0
}

# ── Parse flags ──────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        -R|--recommended)
            RECOMMENDED=true
            INSTALL_NODE=true
            INSTALL_PYTHON=true
            INSTALL_CLI_TOOLS=true
            OPCODE_PLUGINS="superpowers,pty,notify,websearch,impeccable,emil"
            OPCODE_MCP="filesystem,context7"
            OPCODE_AGENTS=true
            shift
            ;;
        -t|--toolchain)
            EXPLICIT_FLAGS=true
            if [ -z "${2:-}" ]; then error "--toolchain requires a value"; fi
            IFS=',' read -ra items <<< "$2"
            for item in "${items[@]}"; do
                case "$item" in
                    node)   INSTALL_NODE=true ;;
                    python) INSTALL_PYTHON=true ;;
                    cli)    INSTALL_CLI_TOOLS=true ;;
                    *)      warn "Unknown toolchain: $item (valid: node,python,cli)" ;;
                esac
            done
            shift 2
            ;;
        -p|--plugin)
            EXPLICIT_FLAGS=true
            if [ -z "${2:-}" ]; then error "--plugin requires a value"; fi
            OPCODE_PLUGINS="$2"
            shift 2
            ;;
        -m|--mcp)
            EXPLICIT_FLAGS=true
            if [ -z "${2:-}" ]; then error "--mcp requires a value"; fi
            OPCODE_MCP="$2"
            shift 2
            ;;
        -a|--agents)
            EXPLICIT_FLAGS=true
            OPCODE_AGENTS=true
            shift
            ;;
        -i|--interactive)
            EXPLICIT_FLAGS=true
            INTERACTIVE=true
            shift
            ;;
        -u|--update)
            UPDATE_FLAG=true
            shift
            ;;
        -b|--build)
            BUILD_FLAG=true
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
    echo "  node python cli"
    echo "  (leave empty for none — any other language can be added later with mise)"
    read -r -a toolchain_choices
    for item in "${toolchain_choices[@]}"; do
        case "$item" in
            node)   INSTALL_NODE=true ;;
            python) INSTALL_PYTHON=true ;;
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
   [ "$INSTALL_NODE" = true ] || [ "$INSTALL_PYTHON" = true ] || [ "$INSTALL_CLI_TOOLS" = true ]; then
    echo "Build configuration:"
    [ "$INSTALL_NODE" = true ]       && echo "  Toolchains: Node.js"
    [ "$INSTALL_PYTHON" = true ]     && echo "  Toolchains: Python 3"
    [ "$INSTALL_CLI_TOOLS" = true ]  && echo "  Toolchains: ripgrep, fd-find, tmux"
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

# ── Create ~/bin if needed ───────────────────────────────────
echo ""
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

# ── Acquire the image (pull prebuilt or build locally) ───────
VARIANT=""
IMG_VERSION=""

pull_image() {
    local variant="$1"
    header "Fetching prebuilt image ($variant)..."
    if ! $CONTAINER_CMD pull "$IMAGE_REPO:$variant"; then
        warn "Pull failed. Falling back to building locally."
        build_image
        return
    fi
    $CONTAINER_CMD tag "$IMAGE_REPO:$variant" local:opencode
    $CONTAINER_CMD rmi "$IMAGE_REPO:$variant" >/dev/null 2>&1 || true
    info "Image pulled and tagged as local:opencode"
    VARIANT="$variant"
    IMG_VERSION="$($CONTAINER_CMD image inspect --format '{{index .Config.Labels "org.opencontainers.image.version"}}' local:opencode 2>/dev/null || echo "dev")"
    if [ -z "$IMG_VERSION" ]; then
        IMG_VERSION="dev"
    fi
}

build_image() {
    header "Building Docker image locally (this may take a few minutes)..."
    local version
    version="$(git -C "$SCRIPT_DIR" rev-parse --short HEAD 2>/dev/null || echo "dev")"
    if ! $CONTAINER_CMD build \
        --build-arg "INSTALL_NODE=$INSTALL_NODE" \
        --build-arg "INSTALL_PYTHON=$INSTALL_PYTHON" \
        --build-arg "INSTALL_CLI_TOOLS=$INSTALL_CLI_TOOLS" \
        --build-arg "OPCODE_PLUGINS=$OPCODE_PLUGINS" \
        --build-arg "SANDBOX_VERSION=$version" \
        --label "org.opencontainers.image.version=$version" \
        -t local:opencode "$SCRIPT_DIR"; then
        error "Docker image build failed"
    fi
    info "Docker image built successfully"
    VARIANT="built"
    IMG_VERSION="$version"
}

if [ "$UPDATE_FLAG" = true ]; then
    # Re-pull the previously installed variant and re-seed.
    if [ "$EXPLICIT_FLAGS" = true ]; then
        warn "--update ignores custom flags; re-run without --update to apply them."
    fi
    UPDATE_VARIANT="$(cat "$STATE_DIR/variant" 2>/dev/null || echo "recommended")"
    if [ "$UPDATE_VARIANT" = "built" ]; then
        warn "Previous install was built locally; --update cannot refresh it."
        warn "Re-run install.sh with your original flags (add --build) to rebuild."
        UPDATE_VARIANT="recommended"
    fi
    pull_image "$UPDATE_VARIANT"
elif [ "$BUILD_FLAG" = true ] || [ "$EXPLICIT_FLAGS" = true ]; then
    build_image
elif [ "$RECOMMENDED" = true ]; then
    pull_image "recommended"
else
    pull_image "minimal"
fi

# ── Seed the config volume ───────────────────────────────────
header "Seeding opencode configuration..."
merge_args=()
if $CONTAINER_CMD run --rm -v opencode-config:/home/dev/.config/opencode \
    --entrypoint test local:opencode -f /home/dev/.config/opencode/opencode.json >/dev/null 2>&1; then
    merge_args=(merge)
fi
$CONTAINER_CMD run --rm \
    -v opencode-config:/home/dev/.config/opencode \
    -e "OPCODE_PLUGINS=$OPCODE_PLUGINS" \
    -e "OPCODE_MCP=$OPCODE_MCP" \
    -e "OPCODE_AGENTS=$OPCODE_AGENTS" \
    -e "SANDBOX_VERSION=$IMG_VERSION" \
    --entrypoint bash local:opencode -c \
    "bash /opt/opencode-sandbox/configure-opencode.sh /home/dev/.config/opencode /opt/opencode-sandbox/preconfig ${merge_args[*]:-}" \
    || error "Config seeding failed"
mkdir -p "$STATE_DIR"
printf '%s\n' "$IMG_VERSION" > "$STATE_DIR/seed-version"
printf '%s\n' "${VARIANT:-minimal}" > "$STATE_DIR/variant"
info "Config seeded (version: $IMG_VERSION)"

# ── Install wrapper ──────────────────────────────────────────
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

echo "First session:"
echo "  cd ~/code/my-project"
echo "  opencode"
echo "  Inside opencode run /connect to pick a provider (free models available"
echo "  via OpenCode Zen), then /help to get started."
echo ""
