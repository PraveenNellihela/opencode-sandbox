#!/usr/bin/env bash
# configure-opencode.sh — Generates/merges opencode.json and seeds agent files.
#
# Usage: configure-opencode.sh [CONFIG_DIR] [TEMPLATE_DIR] [write|merge]
#
#   write (default): generate a fresh opencode.json from the template plus
#                    the plugins/MCP/agents requested via env vars.
#   merge:           preserve an existing opencode.json (user edits win),
#                    add any new defaults (plugins, MCP servers, template
#                    keys such as a default model). Agent files are copied
#                    without clobbering (cp -n).
#
# Runs against the config volume at install time; the version stamp
# (.sandbox-seed-version) lets install.sh detect stale seeds.
set -euo pipefail

CONFIG_DIR="${1:-/home/dev/.config/opencode}"
TEMPLATE_DIR="${2:-/opt/opencode-sandbox/preconfig}"
MODE="${3:-write}"

OPCODE_PLUGINS="${OPCODE_PLUGINS:-}"
OPCODE_MCP="${OPCODE_MCP:-}"
OPCODE_AGENTS="${OPCODE_AGENTS:-false}"

# Version stamp: env var wins, then the image's VERSION file, then "dev".
STAMP="${SANDBOX_VERSION:-}"
if [ -z "$STAMP" ] && [ -f "/opt/opencode-sandbox/VERSION" ]; then
    STAMP="$(cat /opt/opencode-sandbox/VERSION)"
fi
[ -z "$STAMP" ] && STAMP="dev"

if ! command -v jq >/dev/null 2>&1; then
    echo "Error: jq is required (it is included in the sandbox image base deps)." >&2
    exit 1
fi

mkdir -p "$CONFIG_DIR"
JSON_FILE="$CONFIG_DIR/opencode.json"

# ── Build plugin/MCP JSON fragments from the env lists ───────

plugin_json() {
    local out="" p
    if [ -n "$OPCODE_PLUGINS" ]; then
        IFS=',' read -ra plugins <<< "$OPCODE_PLUGINS"
        for p in "${plugins[@]}"; do
            p="$(echo "$p" | xargs)"  # trim
            case "$p" in
                superpowers)
                    out="${out}${out:+,}\"superpowers@git+https://github.com/obra/superpowers.git\""
                    ;;
                pty)
                    out="${out}${out:+,}\"opencode-pty\""
                    ;;
                notify)
                    out="${out}${out:+,}\"opencode-notify\""
                    ;;
                websearch)
                    out="${out}${out:+,}\"opencode-websearch-cited\""
                    ;;
                mcp-tool-search)
                    out="${out}${out:+,}\"opencode-mcp-tool-search\""
                    ;;
                impeccable|emil)
                    # Design skills, not opencode.json plugins — installed by
                    # the Dockerfile into the skills directory.
                    ;;
            esac
        done
    fi
    printf '%s' "$out"
}

mcp_json() {
    local out="" m
    if [ -n "$OPCODE_MCP" ]; then
        IFS=',' read -ra mcps <<< "$OPCODE_MCP"
        for m in "${mcps[@]}"; do
            m="$(echo "$m" | xargs)"  # trim
            case "$m" in
                filesystem)
                    out="${out}${out:+,}\"filesystem\": {\"type\": \"local\", \"command\": [\"npx\", \"-y\", \"@modelcontextprotocol/server-filesystem\", \"/home/dev/workspace\"], \"enabled\": true}"
                    ;;
                context7)
                    out="${out}${out:+,}\"context7\": {\"type\": \"local\", \"command\": [\"npx\", \"-y\", \"context7\"], \"enabled\": false}"
                    ;;
                brave-search)
                    out="${out}${out:+,}\"brave-search\": {\"type\": \"local\", \"command\": [\"npx\", \"-y\", \"@modelcontextprotocol/server-brave-search\"], \"env\": {\"BRAVE_API_KEY\": \"\${env:BRAVE_API_KEY}\"}, \"enabled\": false}"
                    ;;
                github)
                    out="${out}${out:+,}\"github\": {\"type\": \"local\", \"command\": [\"npx\", \"-y\", \"@modelcontextprotocol/server-github\"], \"env\": {\"GITHUB_TOKEN\": \"\${env:GITHUB_TOKEN}\"}, \"enabled\": false}"
                    ;;
            esac
        done
    fi
    printf '%s' "$out"
}

PLUGIN_JSON="$(plugin_json)"
MCP_JSON="$(mcp_json)"

# ── Generate the config ──────────────────────────────────────

if [ "$MODE" = "merge" ] && [ -f "$JSON_FILE" ]; then
    # Merge: the user's config is the base; template scalar defaults (e.g. a
    # default model) fill gaps; requested plugins/MCP are unioned in.
    tmp=$(mktemp)
    jq --argjson plugins "[$PLUGIN_JSON]" \
       --argjson mcp "{$MCP_JSON}" \
       -s '
         .[0] as $template
         | .[1] as $user
         | (($template | del(.plugin, .mcp, .agent)) * $user)
           | .plugin = ((($user.plugin // []) + $plugins) | unique_by(.))
           | .mcp = ($mcp * ($user.mcp // {}))
       ' "$TEMPLATE_DIR/opencode.json" "$JSON_FILE" > "$tmp" \
        && mv "$tmp" "$JSON_FILE"
else
    # Write: fresh config from the template.
    cp "$TEMPLATE_DIR/opencode.json" "$JSON_FILE"
    tmp=$(mktemp)
    jq --argjson plugins "[$PLUGIN_JSON]" '.plugin = $plugins' "$JSON_FILE" > "$tmp" \
        && mv "$tmp" "$JSON_FILE"
    tmp=$(mktemp)
    jq --argjson mcp "{$MCP_JSON}" '.mcp = $mcp' "$JSON_FILE" > "$tmp" \
        && mv "$tmp" "$JSON_FILE"
fi

# ── Seed agent files ─────────────────────────────────────────
if [ "$OPCODE_AGENTS" = "true" ] && [ -d "$TEMPLATE_DIR/agents" ]; then
    mkdir -p "$CONFIG_DIR/agents"
    for agent_file in "$TEMPLATE_DIR/agents"/*.md; do
        [ -f "$agent_file" ] || continue
        if [ "$MODE" = "merge" ]; then
            # Never clobber user-edited agent files (cp -n is not portable)
            target="$CONFIG_DIR/agents/$(basename "$agent_file")"
            [ -f "$target" ] || cp "$agent_file" "$target"
        else
            cp "$agent_file" "$CONFIG_DIR/agents/"
        fi
    done
fi

# ── Version stamp ────────────────────────────────────────────
echo "$STAMP" > "$CONFIG_DIR/.sandbox-seed-version"
echo "opencode-sandbox config seeded (version: $STAMP, mode: $MODE)"
