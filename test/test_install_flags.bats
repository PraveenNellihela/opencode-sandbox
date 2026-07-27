setup() {
    load 'helper'
}

@test "--help shows usage and exits 0" {
    run ./install.sh --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "-h shows usage" {
    run ./install.sh -h
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "--unknown-flag exits with error" {
    run ./install.sh --bogus-flag
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown option"* ]]
}

@test "errors when docker/podman not available" {
    local restricted_path
    restricted_path="$(mktemp -d)"
    for cmd in bash env uname basename cut; do
        ln -sf "$(command -v "$cmd")" "$restricted_path/"
    done
    run env PATH="$restricted_path" ./install.sh 2>&1
    [ "$status" -eq 1 ]
    [[ "$output" == *"Neither Docker nor Podman found"* ]]
    rm -rf "$restricted_path"
}

@test "-R prints recommended build configuration" {
    run ./install.sh -R 2>&1 || true
    # Should show build config even if docker is missing (docker check is after config print)
    [[ "$output" == *"Node.js"* ]]
    [[ "$output" == *"Python"* ]]
}

@test "--toolchain flag appears in help" {
    run ./install.sh --help
    [[ "$output" == *"--toolchain"* ]]
}

@test "--plugin flag appears in help" {
    run ./install.sh --help
    [[ "$output" == *"--plugin"* ]]
}

@test "--agents flag appears in help" {
    run ./install.sh --help
    [[ "$output" == *"--agents"* ]]
}
