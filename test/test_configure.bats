setup() {
    export TEST_CONFIG_DIR="$BATS_TEST_TMPDIR/config"
    export TEST_TEMPLATE_DIR="$BATS_TEST_TMPDIR/preconfig"
    mkdir -p "$TEST_TEMPLATE_DIR/agents"
    cp preconfig/opencode.json "$TEST_TEMPLATE_DIR/"
    for f in preconfig/agents/*.md; do
        [ -f "$f" ] && cp "$f" "$TEST_TEMPLATE_DIR/agents/"
    done
}

# ── Basic output ─────────────────────────────────────────────

@test "creates config directory" {
    run bash scripts/configure-opencode.sh "$TEST_CONFIG_DIR" "$TEST_TEMPLATE_DIR"
    [ "$status" -eq 0 ]
    [ -d "$TEST_CONFIG_DIR" ]
}

@test "generates valid JSON with no plugins or MCP" {
    run bash scripts/configure-opencode.sh "$TEST_CONFIG_DIR" "$TEST_TEMPLATE_DIR"
    [ "$status" -eq 0 ]
    [ -f "$TEST_CONFIG_DIR/opencode.json" ]
    jq empty "$TEST_CONFIG_DIR/opencode.json"
}

@test "minimal output matches golden file" {
    run bash scripts/configure-opencode.sh "$TEST_CONFIG_DIR" "$TEST_TEMPLATE_DIR"
    run diff <(jq -S . "$TEST_CONFIG_DIR/opencode.json") test/fixtures/golden_minimal.json
    [ "$status" -eq 0 ]
}

# ── Plugin injection ─────────────────────────────────────────

@test "injects superpowers plugin" {
    export OPCODE_PLUGINS="superpowers"
    run bash scripts/configure-opencode.sh "$TEST_CONFIG_DIR" "$TEST_TEMPLATE_DIR"
    [ "$status" -eq 0 ]
    run jq -r '.plugin[]' "$TEST_CONFIG_DIR/opencode.json"
    [[ "$output" == *"superpowers"* ]]
}

@test "injects multiple plugins" {
    export OPCODE_PLUGINS="superpowers,pty,notify"
    run bash scripts/configure-opencode.sh "$TEST_CONFIG_DIR" "$TEST_TEMPLATE_DIR"
    [ "$status" -eq 0 ]
    run jq '.plugin | length' "$TEST_CONFIG_DIR/opencode.json"
    [ "$output" -eq 3 ]
}

@test "handles whitespace in plugin list" {
    export OPCODE_PLUGINS=" superpowers , pty "
    run bash scripts/configure-opencode.sh "$TEST_CONFIG_DIR" "$TEST_TEMPLATE_DIR"
    [ "$status" -eq 0 ]
    run jq '.plugin | length' "$TEST_CONFIG_DIR/opencode.json"
    [ "$output" -eq 2 ]
}

# ── MCP injection ────────────────────────────────────────────

@test "injects filesystem MCP" {
    export OPCODE_MCP="filesystem"
    run bash scripts/configure-opencode.sh "$TEST_CONFIG_DIR" "$TEST_TEMPLATE_DIR"
    [ "$status" -eq 0 ]
    run jq -e '.mcp.filesystem' "$TEST_CONFIG_DIR/opencode.json"
    [ "$status" -eq 0 ]
}

@test "injects multiple MCP servers" {
    export OPCODE_MCP="filesystem,context7"
    run bash scripts/configure-opencode.sh "$TEST_CONFIG_DIR" "$TEST_TEMPLATE_DIR"
    [ "$status" -eq 0 ]
    run jq -e '.mcp.filesystem and .mcp.context7' "$TEST_CONFIG_DIR/opencode.json"
    [ "$status" -eq 0 ]
}

# ── Agent seeding ────────────────────────────────────────────

@test "seeds all 6 agent files when OPCODE_AGENTS=true" {
    export OPCODE_AGENTS="true"
    run bash scripts/configure-opencode.sh "$TEST_CONFIG_DIR" "$TEST_TEMPLATE_DIR"
    [ "$status" -eq 0 ]
    [ -d "$TEST_CONFIG_DIR/agents" ]
    run ls "$TEST_CONFIG_DIR/agents/"*.md 2>/dev/null
    [[ "$output" == *"planner.md"* ]]
    [[ "$output" == *"code-reviewer.md"* ]]
    [[ "$output" == *"security-analyst.md"* ]]
    [[ "$output" == *"debugger.md"* ]]
    [[ "$output" == *"documenter.md"* ]]
    [[ "$output" == *"tester.md"* ]]
    run ls "$TEST_CONFIG_DIR/agents/"*.md 2>/dev/null | wc -l
    [ "${output// /}" -eq 6 ]
}

@test "does NOT seed agents when OPCODE_AGENTS=false" {
    export OPCODE_AGENTS="false"
    run bash scripts/configure-opencode.sh "$TEST_CONFIG_DIR" "$TEST_TEMPLATE_DIR"
    [ "$status" -eq 0 ]
    [ ! -d "$TEST_CONFIG_DIR/agents" ] || [ -z "$(ls -A "$TEST_CONFIG_DIR/agents/"*.md 2>/dev/null)" ]
}

@test "recommended output matches golden file" {
    export OPCODE_PLUGINS="superpowers,pty,notify,websearch"
    export OPCODE_MCP="filesystem,context7"
    export OPCODE_AGENTS="true"
    run bash scripts/configure-opencode.sh "$TEST_CONFIG_DIR" "$TEST_TEMPLATE_DIR"
    [ "$status" -eq 0 ]
    run diff <(jq -S '.plugin, .mcp' "$TEST_CONFIG_DIR/opencode.json") \
             <(jq -S '.plugin, .mcp' test/fixtures/golden_recommended.json)
    [ "$status" -eq 0 ]
}
