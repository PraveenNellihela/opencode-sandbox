setup() {
    load 'helper'
}

@test "image builds with minimal config" {
    if ! has_docker; then skip "Docker not available"; fi
    run docker build -t test-minimal:latest \
        -f Dockerfile .
    [ "$status" -eq 0 ]
}

@test "non-root user exists" {
    if ! has_docker; then skip "Docker not available"; fi
    run docker run --rm --entrypoint /bin/sh test-minimal:latest -c "whoami"
    [ "$status" -eq 0 ]
    [[ "$output" == "dev" ]]
}

@test "opencode binary runs" {
    if ! has_docker; then skip "Docker not available"; fi
    run docker run --rm test-minimal:latest --version
    [ "$status" -eq 0 ]
}

@test "config seeder and templates present in image" {
    if ! has_docker; then skip "Docker not available"; fi
    run docker run --rm --entrypoint /bin/sh test-minimal:latest -c \
        "test -f /opt/opencode-sandbox/configure-opencode.sh && test -f /opt/opencode-sandbox/preconfig/opencode.json && test -s /opt/opencode-sandbox/VERSION && test -x /usr/local/bin/mise"
    [ "$status" -eq 0 ]
}

@test "jq available in base image" {
    if ! has_docker; then skip "Docker not available"; fi
    run docker run --rm --entrypoint /bin/sh test-minimal:latest -c "which jq"
    [ "$status" -eq 0 ]
}

@test "image builds with recommended config" {
    if ! has_docker; then skip "Docker not available"; fi
    run docker build -t test-recommended:latest \
        --build-arg INSTALL_NODE=true \
        --build-arg INSTALL_PYTHON=true \
        --build-arg INSTALL_CLI_TOOLS=true \
        --build-arg OPCODE_PLUGINS="superpowers,pty,notify,websearch,impeccable,emil" \
        -f Dockerfile .
    [ "$status" -eq 0 ]
}

@test "recommended image has impeccable skill" {
    if ! has_docker; then skip "Docker not available"; fi
    run docker run --rm --entrypoint /bin/sh test-recommended:latest \
        -c "test -f /home/dev/.config/opencode/skills/impeccable/SKILL.md"
    [ "$status" -eq 0 ]
}

@test "recommended image has emil skills" {
    if ! has_docker; then skip "Docker not available"; fi
    run docker run --rm --entrypoint /bin/sh test-recommended:latest \
        -c "test -f /home/dev/.config/opencode/skills/emil-design-eng/SKILL.md"
    [ "$status" -eq 0 ]
}

@test "recommended image has Node.js and Python" {
    if ! has_docker; then skip "Docker not available"; fi
    run docker run --rm --entrypoint /bin/sh test-recommended:latest -c "node --version"
    [ "$status" -eq 0 ]
    run docker run --rm --entrypoint /bin/sh test-recommended:latest -c "python3 --version"
    [ "$status" -eq 0 ]
}

@test "recommended image has CLI tools" {
    if ! has_docker; then skip "Docker not available"; fi
    run docker run --rm --entrypoint /bin/sh test-recommended:latest -c "which rg"
    [ "$status" -eq 0 ]
    run docker run --rm --entrypoint /bin/sh test-recommended:latest -c "which tmux"
    [ "$status" -eq 0 ]
}

# ── Config seeding (install-time behavior against the volume) ─

@test "seeding writes config with plugins, MCP and agents to the volume" {
    if ! has_docker; then skip "Docker not available"; fi
    docker volume rm e2e-config >/dev/null 2>&1 || true
    run docker run --rm \
        -v e2e-config:/home/dev/.config/opencode \
        -e OPCODE_PLUGINS=superpowers,pty \
        -e OPCODE_MCP=filesystem \
        -e OPCODE_AGENTS=true \
        -e SANDBOX_VERSION=test123 \
        --entrypoint bash test-minimal:latest -c \
        "bash /opt/opencode-sandbox/configure-opencode.sh /home/dev/.config/opencode /opt/opencode-sandbox/preconfig"
    [ "$status" -eq 0 ]
    run docker run --rm \
        -v e2e-config:/home/dev/.config/opencode \
        --entrypoint bash test-minimal:latest -c \
        "jq -e '.plugin | length == 2' /home/dev/.config/opencode/opencode.json \
         && jq -e '.mcp.filesystem' /home/dev/.config/opencode/opencode.json \
         && test \"\$(cat /home/dev/.config/opencode/.sandbox-seed-version)\" = test123 \
         && ls /home/dev/.config/opencode/agents/*.md | wc -l | grep -q 6"
    [ "$status" -eq 0 ]
    docker volume rm e2e-config >/dev/null 2>&1 || true
}

@test "re-seeding merges without clobbering user config" {
    if ! has_docker; then skip "Docker not available"; fi
    docker volume rm e2e-config >/dev/null 2>&1 || true
    docker run --rm \
        -v e2e-config:/home/dev/.config/opencode \
        -e OPCODE_PLUGINS=pty \
        -e SANDBOX_VERSION=v1 \
        --entrypoint bash test-minimal:latest -c \
        "bash /opt/opencode-sandbox/configure-opencode.sh /home/dev/.config/opencode /opt/opencode-sandbox/preconfig" >/dev/null 2>&1
    # user adds their own plugin
    docker run --rm \
        -v e2e-config:/home/dev/.config/opencode \
        --entrypoint bash test-minimal:latest -c \
        "jq '.plugin += [\"my-plugin\"]' /home/dev/.config/opencode/opencode.json > /tmp/c && mv /tmp/c /home/dev/.config/opencode/opencode.json" >/dev/null 2>&1
    # re-seed with a new default plugin
    run docker run --rm \
        -v e2e-config:/home/dev/.config/opencode \
        -e OPCODE_PLUGINS=superpowers \
        -e SANDBOX_VERSION=v2 \
        --entrypoint bash test-minimal:latest -c \
        "bash /opt/opencode-sandbox/configure-opencode.sh /home/dev/.config/opencode /opt/opencode-sandbox/preconfig merge"
    [ "$status" -eq 0 ]
    run docker run --rm \
        -v e2e-config:/home/dev/.config/opencode \
        --entrypoint bash test-minimal:latest -c \
        "jq -e '.plugin | index(\"my-plugin\")' /home/dev/.config/opencode/opencode.json \
         && jq -e '.plugin | index(\"superpowers@git+https://github.com/obra/superpowers.git\")' /home/dev/.config/opencode/opencode.json"
    [ "$status" -eq 0 ]
    docker volume rm e2e-config >/dev/null 2>&1 || true
}
