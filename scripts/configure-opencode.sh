#!/usr/bin/env bash
# configure-opencode.sh — Generates opencode.json and seeds agent files
# based on environment variables passed at Docker build time.
set -euo pipefail

CONFIG_DIR="${1:-/home/dev/.config/opencode}"
TEMPLATE_DIR="${2:-/preconfig}"

OPCODE_PLUGINS="${OPCODE_PLUGINS:-}"
OPCODE_MCP="${OPCODE_MCP:-}"
OPCODE_AGENTS="${OPCODE_AGENTS:-false}"

mkdir -p "$CONFIG_DIR"

# ── Build opencode.json ──────────────────────────────────────
JSON_FILE="$CONFIG_DIR/opencode.json"

# Start with the template
cp "$TEMPLATE_DIR/opencode.json" "$JSON_FILE"

# Inject plugins
if [ -n "$OPCODE_PLUGINS" ]; then
    IFS=',' read -ra PLUGINS <<< "$OPCODE_PLUGINS"
    PLUGIN_JSON=""
    for p in "${PLUGINS[@]}"; do
        p="$(echo "$p" | xargs)"  # trim
        case "$p" in
            superpowers)
                PLUGIN_JSON="${PLUGIN_JSON}${PLUGIN_JSON:+,}\"superpowers@git+https://github.com/obra/superpowers.git\""
                ;;
            pty)
                PLUGIN_JSON="${PLUGIN_JSON}${PLUGIN_JSON:+,}\"opencode-pty\""
                ;;
            notify)
                PLUGIN_JSON="${PLUGIN_JSON}${PLUGIN_JSON:+,}\"opencode-notify\""
                ;;
            websearch)
                PLUGIN_JSON="${PLUGIN_JSON}${PLUGIN_JSON:+,}\"opencode-websearch-cited\""
                ;;
            mcp-tool-search)
                PLUGIN_JSON="${PLUGIN_JSON}${PLUGIN_JSON:+,}\"opencode-mcp-tool-search\""
                ;;
            impeccable)
                # Design skill, not an opencode.json plugin — installed
                # separately by the Dockerfile into the skills directory.
                ;;
            emil)
                # Design skills (emilkowalski/skills), not opencode.json
                # plugins — installed by the Dockerfile into the skills
                # directory.
                ;;
        esac
    done
    # Use jq if available, otherwise sed
    if command -v jq &>/dev/null; then
        tmp=$(mktemp)
        # shellcheck disable=SC2015
        jq --argjson plugins "[$PLUGIN_JSON]" '.plugin = $plugins' "$JSON_FILE" > "$tmp" \
            && mv "$tmp" "$JSON_FILE" \
            || rm -f "$tmp"
    else
        # Fallback: replace the empty plugin array
        sed -i "s|\"plugin\": \[\]|\"plugin\": [$PLUGIN_JSON]|" "$JSON_FILE"
    fi
fi

# Inject MCP servers
if [ -n "$OPCODE_MCP" ]; then
    IFS=',' read -ra MCPS <<< "$OPCODE_MCP"
    MCP_JSON=""
    for m in "${MCPS[@]}"; do
        m="$(echo "$m" | xargs)"
        case "$m" in
            filesystem)
                MCP_JSON="${MCP_JSON}${MCP_JSON:+,}\"filesystem\": {\"type\": \"local\", \"command\": [\"npx\", \"-y\", \"@modelcontextprotocol/server-filesystem\", \"/home/dev/workspace\"], \"enabled\": true}"
                ;;
            context7)
                MCP_JSON="${MCP_JSON}${MCP_JSON:+,}\"context7\": {\"type\": \"local\", \"command\": [\"npx\", \"-y\", \"context7\"], \"enabled\": false}"
                ;;
            brave-search)
                MCP_JSON="${MCP_JSON}${MCP_JSON:+,}\"brave-search\": {\"type\": \"local\", \"command\": [\"npx\", \"-y\", \"@modelcontextprotocol/server-brave-search\"], \"env\": {\"BRAVE_API_KEY\": \"\${env:BRAVE_API_KEY}\"}, \"enabled\": false}"
                ;;
            github)
                MCP_JSON="${MCP_JSON}${MCP_JSON:+,}\"github\": {\"type\": \"local\", \"command\": [\"npx\", \"-y\", \"@modelcontextprotocol/server-github\"], \"env\": {\"GITHUB_TOKEN\": \"\${env:GITHUB_TOKEN}\"}, \"enabled\": false}"
                ;;
        esac
    done
    if command -v jq &>/dev/null; then
        tmp=$(mktemp)
        # shellcheck disable=SC2015
        jq --argjson mcp "{$MCP_JSON}" '.mcp = $mcp' "$JSON_FILE" > "$tmp" \
            && mv "$tmp" "$JSON_FILE" \
            || rm -f "$tmp"
    else
        sed -i "s|\"mcp\": {}|\"mcp\": {$MCP_JSON}|" "$JSON_FILE"
    fi
fi

# ── Seed agent files ─────────────────────────────────────────
if [ "$OPCODE_AGENTS" = "true" ] && [ -d "$TEMPLATE_DIR/agents" ]; then
    mkdir -p "$CONFIG_DIR/agents"
    for agent_file in "$TEMPLATE_DIR/agents"/*.md; do
        [ -f "$agent_file" ] && cp "$agent_file" "$CONFIG_DIR/agents/"
    done
fi
