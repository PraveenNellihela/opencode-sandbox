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

@test "opencode binary is in PATH" {
    if ! has_docker; then skip "Docker not available"; fi
    run docker run --rm --entrypoint /bin/sh test-minimal:latest -c "which opencode"
    [ "$status" -eq 0 ]
}

@test "opencode.json is valid JSON" {
    if ! has_docker; then skip "Docker not available"; fi
    run docker run --rm --entrypoint /bin/sh test-minimal:latest \
        -c "jq . /home/dev/.config/opencode/opencode.json"
    [ "$status" -eq 0 ]
}

@test "image builds with recommended config" {
    if ! has_docker; then skip "Docker not available"; fi
    run docker build -t test-recommended:latest \
        --build-arg INSTALL_NODE=true \
        --build-arg INSTALL_PYTHON=true \
        --build-arg INSTALL_CLI_TOOLS=true \
        --build-arg OPCODE_PLUGINS="superpowers,pty,notify,websearch" \
        --build-arg OPCODE_MCP="filesystem,context7" \
        --build-arg OPCODE_AGENTS=true \
        -f Dockerfile .
    [ "$status" -eq 0 ]
}

@test "recommended image has agent files" {
    if ! has_docker; then skip "Docker not available"; fi
    run docker run --rm --entrypoint /bin/sh test-recommended:latest \
        -c "ls /home/dev/.config/opencode/agents/*.md 2>/dev/null | wc -l"
    [ "$status" -eq 0 ]
    [[ "${output// /}" -eq 6 ]]
}

@test "recommended image has CLI tools" {
    if ! has_docker; then skip "Docker not available"; fi
    run docker run --rm --entrypoint /bin/sh test-recommended:latest -c "which rg"
    [ "$status" -eq 0 ]
    run docker run --rm --entrypoint /bin/sh test-recommended:latest -c "which jq"
    [ "$status" -eq 0 ]
}
