setup() {
    load 'helper'
}

@test "--help shows usage and exits 0" {
    run ./opencode --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage: opencode [args...]"* ]]
}

@test "-h shows usage" {
    run ./opencode -h
    [ "$status" -eq 0 ]
    [[ "$output" == *"opencode-sandbox wrapper"* ]]
}

@test "errors when docker/podman not available" {
    run env PATH="/usr/bin:/bin" ./opencode 2>&1
    [ "$status" -eq 1 ]
    [[ "$output" == *"Neither Docker nor Podman found"* ]]
}

@test "errors when image not found" {
    run ./opencode 2>&1 || true
    # If docker IS available but image doesn't exist, should show link to install.sh
    if command -v docker >/dev/null 2>&1; then
        [[ "$output" == *"install.sh"* ]]
    fi
}
