# Helper functions for bats tests

# Check if the test environment has Docker available
has_docker() {
    command -v docker >/dev/null 2>&1
}


