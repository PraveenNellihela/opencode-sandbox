# End-to-end tests — require Docker, skip if not available
setup() {
    if ! command -v docker >/dev/null 2>&1; then
        skip "Docker not available"
    fi
    export IMAGE_NAME="opencode-test:latest"
}

teardown() {
    docker rmi "$IMAGE_NAME" 2>/dev/null || true
}

@test "image builds successfully with default args" {
    docker build -t "$IMAGE_NAME" .
    [ "$?" -eq 0 ]
}

@test "container runs as non-root user 'dev'" {
    docker build -t "$IMAGE_NAME" .
    run docker run --rm "$IMAGE_NAME" whoami
    [ "$status" -eq 0 ]
    [[ "$output" == "dev" ]]
}

@test "opencode binary is in PATH" {
    docker build -t "$IMAGE_NAME" .
    run docker run --rm "$IMAGE_NAME" which opencode
    [ "$status" -eq 0 ]
}

@test "opencode.json exists and is valid JSON" {
    docker build -t "$IMAGE_NAME" .
    run docker run --rm "$IMAGE_NAME" jq . /home/dev/.config/opencode/opencode.json
    [ "$status" -eq 0 ]
}

@test "image with recommended build arg succeeds" {
    docker build \
        --build-arg INSTALL_NODE=true \
        --build-arg INSTALL_PYTHON=true \
        --build-arg INSTALL_CLI_TOOLS=true \
        --build-arg OPCODE_PLUGINS="superpowers,pty" \
        --build-arg OPCODE_MCP="filesystem" \
        --build-arg OPCODE_AGENTS=true \
        -t "$IMAGE_NAME" .
    [ "$?" -eq 0 ]
}

@test "recommended build has all 6 agent files" {
    docker build \
        --build-arg OPCODE_AGENTS=true \
        -t "$IMAGE_NAME" .
    run docker run --rm "$IMAGE_NAME" ls /home/dev/.config/opencode/agents/
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 6 ]
}

@test "CLI tools present when INSTALL_CLI_TOOLS=true" {
    docker build \
        --build-arg INSTALL_CLI_TOOLS=true \
        -t "$IMAGE_NAME" .
    run docker run --rm "$IMAGE_NAME" jq --version
    [ "$status" -eq 0 ]
    run docker run --rm "$IMAGE_NAME" rg --version
    [ "$status" -eq 0 ]
}
