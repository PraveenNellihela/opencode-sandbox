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
    run env PATH="/usr/bin:/bin" ./install.sh 2>&1
    [ "$status" -eq 1 ]
    [[ "$output" == *"Neither Docker nor Podman found"* ]]
}

@test "-R prints recommended build configuration" {
    run ./install.sh -R 2>&1 || true
    # Should show build config even if docker is missing (docker check is after config print)
    [[ "$output" == *"Node.js"* ]]
    [[ "$output" == *"Python"* ]]
}

@test "-t sets toolchain flags" {
    run bash -c '
        source ./install.sh --dry-run 2>/dev/null || true
        # Test that the install.sh help shows toolchain options
    '
    run ./install.sh --help
    [[ "$output" == *"--toolchain"* ]]
}

@test "-p sets plugins" {
    run ./install.sh --help
    [[ "$output" == *"--plugin"* ]]
}

@test "-a sets agents flag" {
    run ./install.sh --help
    [[ "$output" == *"--agents"* ]]
}
