<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/opencode-sandbox-light.png">
  <source media="(prefers-color-scheme: light)" srcset="docs/opencode-sandbox-dark.png">
  <img alt="opencode-sandbox" src="docs/opencode-sandbox-dark.png" width="380" style="margin: -40px 0 -80px 0;">
</picture>

# opencode-sandbox

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Docker](https://img.shields.io/badge/docker-%3E%3D20.10-blue?logo=docker)](https://docs.docker.com/get-docker/)

Isolated, persistent Docker sandbox for running [opencode](https://opencode.ai) on any OS — Linux, macOS, or Windows (WSL2). Install once, use from any project directory.

## Quick Start

```sh-session
# 1. Clone and enter the repo
git clone https://github.com/PraveenNellihela/opencode-sandbox.git
cd opencode-sandbox

# 2. Run the installer (detects OS, builds Docker image, copies wrapper to ~/bin/)
./install.sh

# 3. Use opencode, it runs inside Docker, bind-mounted to current directory
cd ~/code/my-project
opencode
```

The installer detects your OS and shell, copies the wrapper to `~/bin/`, and builds the Docker image. You may need to add `~/bin` to your PATH (the installer will tell you if so).

### Customizing Your Build

Pass flags to `install.sh` to pre-install toolchains, agents, plugins, and MCP servers:

| Flag | Description |
|------|-------------|
| `-R, --recommended` | Full power-up (Node.js + Python + CLI tools + superpowers + plugins + MCP + agents) |
| `-t, --toolchain LIST` | Comma-separated: `node,python,go,cli` |
| `-p, --plugin LIST` | Comma-separated: `superpowers,pty,notify,websearch,mcp-tool-search` |
| `-m, --mcp LIST` | Comma-separated: `filesystem,context7,brave-search,github` |
| `-a, --agents` | Include 6 pre-built subagents (code-reviewer, security-analyst, debugger, documenter, tester, planner) |
| `-i, --interactive` | Interactive prompts for selections |

Examples:

```sh-session
# Minimal (default — same as original)
./install.sh

# Full power-up with all extras
./install.sh --recommended

# Custom: Node.js + CLI tools + superpowers + agents only
./install.sh -t node,cli -p superpowers -a

# Interactive mode
./install.sh -i
```

### What --recommended Includes

```
Toolchains: Node.js + Python 3 + ripgrep + fd-find + jq + tmux
Plugins:    superpowers + opencode-pty + opencode-notify + opencode-websearch-cited
MCP:        filesystem + Context7
Agents:     code-reviewer, security-analyst, debugger, documenter, tester, planner
```

### Pre-Built Subagents

When `-a` or `--recommended` is used, 6 specialist subagents are seeded into `~/.config/opencode/agents/`. Invoke any of them from your conversation with `@name`:

| Agent | Purpose |
|---|---|
| `@code-reviewer` | Code quality, patterns, best practices (read-only) |
| `@security-analyst` | Vulnerability assessment, dependency audit (read-only) |
| `@debugger` | Systematic root cause analysis (full access) |
| `@documenter` | Technical docs, API docs (write + read-only bash) |
| `@tester` | Test generation, coverage analysis (full access) |
| `@planner` | Implementation plans, task breakdown (read-only) |

### Resetting to Defaults

If you want to wipe the seeded config and start fresh:

```sh-session
# Remove the stored volumes (settings, plugins, auth tokens)
docker volume rm opencode-config opencode-data

# Rebuild with your chosen options
./install.sh --recommended
```

Otherwise, existing volume data is preserved on rebuild (only empty volumes get seeded).

## How It Works

- **Isolated:** Container only sees the current project directory (bind mount). Not your home directory, not other repos, not host processes.
- **Persistent:** Settings and auth tokens survive container restarts via Docker volumes.
- **Secure:** Runs as non-root user with no sudo. Docker networking only.

## What Persists vs. What Doesn't

**Persists** (Docker volumes):
- `~/.config/opencode` — settings, plugins
- `~/.local/share/opencode` — auth tokens, session data

**Does not persist** (lost when container exits):
- OS-level packages installed during a session
- Any changes outside the above directories

If you need a package (e.g., Node.js for a plugin), add it to the `Dockerfile` and rebuild.

## Cross-Platform

### Linux

Works out of the box with Docker Engine installed.

### macOS

Install Docker Desktop first: https://docs.docker.com/desktop/install/mac-install/

Apple Silicon and Intel both supported.

### Windows (WSL2)

1. Install WSL2: `wsl --install`
2. Install Docker Desktop with WSL2 backend
3. Run `install.sh` from inside WSL

## Shell Support

The installer detects your shell and checks if `~/bin` is already configured. If not, it prints a command for you to run:

| Shell | Config file | Command to add |
|-------|-------------|----------------|
| bash | `~/.bashrc` | `echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc` |
| zsh | `~/.zshrc` | `echo 'export PATH="$HOME/bin:$PATH"' >> ~/.zshrc` |
| fish | `~/.config/fish/config.fish` | `fish_add_path ~/bin` |

After running the command, restart your shell or run `source ~/.bashrc` (or `~/.zshrc`).

To remove after uninstalling:

| Shell | Command to remove |
|-------|-------------------|
| bash (Linux) | `sed -i '/export PATH="\$HOME\/bin:\$PATH"/d' ~/.bashrc` |
| bash (macOS) | `sed -i '' '/export PATH="\$HOME\/bin:\$PATH"/d' ~/.bashrc` |
| zsh (Linux) | `sed -i '/export PATH="\$HOME\/bin:\$PATH"/d' ~/.zshrc` |
| zsh (macOS) | `sed -i '' '/export PATH="\$HOME\/bin:\$PATH"/d' ~/.zshrc` |
| fish | `fish_remove_path ~/bin` |

## Adding Dependencies

System packages can be added in two ways:

### At build time (recommended)

Use `install.sh` flags to include common toolchains:

```sh-session
./install.sh -t node,python,cli
```

Or use the `--recommended` flag for the full setup.

For packages not covered by the built-in flags, add installation steps to the `Dockerfile` before the `USER dev` line:

```dockerfile
RUN apt-get update && apt-get install -y --no-install-recommends \
    your-package-here \
    && rm -rf /var/lib/apt/lists/*
```

Then rebuild:

```sh-session
$ docker build -t local:opencode .
```

Cached layers make this fast.

### Inside the container (temporary)

Packages installed during a session are lost when the container exits. This is useful for one-off experiments but not production use.

## Installing Plugins

Plugins can be added at build time or at runtime.

### At build time

Use `install.sh -p` to pre-configure plugins so they're available immediately on first launch:

```sh-session
./install.sh -p superpowers,pty,notify,websearch
```

This seeds them into the `opencode.json` that ships with the image. Available plugins:

- `superpowers` — [obra/superpowers](https://github.com/obra/superpowers): agentic skills framework
- `pty` — [opencode-pty](https://github.com/shekohex/opencode-pty): true PTY support for interactive processes
- `notify` — [opencode-notify](https://github.com/opencode-notify): desktop notifications on task completion
- `websearch` — [opencode-websearch-cited](https://github.com/ghoulr/opencode-websearch-cited): web search with citations
- `mcp-tool-search` — [opencode-mcp-tool-search](https://github.com/francisco-m001/opencode-mcp-tool-search): reduces context bloat from MCP servers

### Inside the container (persistent)

Plugins opencode installs itself land under `~/.config/opencode` (a persisted volume), so they survive container restarts. To add a plugin manually after the container is running, edit `opencode.json` via opencode's config UI or directly in the volume.

Example: [superpowers](https://github.com/obra/superpowers), installed from inside opencode with:

```
Fetch and follow instructions from https://raw.githubusercontent.com/obra/superpowers/refs/heads/main/.opencode/INSTALL.md
```

To edit the generated config after the container is running, open the TUI and use opencode's config commands, or edit `~/.config/opencode/opencode.json` directly on the host (it's stored in the Docker volume).

## Security Model

- **Non-root:** Container runs as `dev` user with no sudo.
- **Minimal access:** Only sees current project directory via bind mount.
- **Network:** Default bridge networking — can reach internet (for LLM APIs) but nothing on host is exposed.

If you need live root for something, that's a signal to add it to the Dockerfile and rebuild, not to grant privilege escalation.

### Using Podman instead of Docker

The scripts support Podman as a Docker alternative. Install Podman:

- Linux: `sudo apt install podman` or `sudo dnf install podman`
- macOS: `brew install podman`

Podman removes the root-daemon-on-host concern entirely. See https://podman.io for details.

## Uninstalling

```sh-session
$ ./uninstall.sh
```

This removes:
- `~/bin/opencode` (wrapper script)
- Docker image (optional, prompted)
- Docker volumes (optional, prompted — won't delete without confirmation)

It does **not** auto-edit your shell config. You remove the PATH line manually.

## Troubleshooting

**"Docker: command not found" / "Podman: command not found"**
→ Install Docker: https://docs.docker.com/get-docker/
→ Or install Podman: https://podman.io/getting-started/installation

**"Cannot connect to the Docker daemon" / "Cannot connect to Podman socket"**
→ Start Docker Desktop or: `sudo systemctl start docker`
→ For Podman: `podman machine start` (macOS) or check system service

**"opencode: command not found" after install**
→ Restart your shell, or: `source ~/.bashrc` (or `~/.zshrc`)

**"Image not found" error**
→ The wrapper no longer auto-builds. Run `./install.sh` from the opencode-sandbox repo to build it.
→ If you already installed the wrapper but deleted the image: `cd path/to/opencode-sandbox && ./install.sh`

**Permission denied on ~/bin**
→ Check ownership: `ls -la ~/bin`
→ Fix: `chown -R $(whoami) ~/bin`

**macOS Terminal: Theme fonts and colors render incorrectly**
→ The built-in macOS Terminal app may display incorrect colors or fonts compared to VSCode's integrated terminal or other terminals. This is a known macOS issue — see [#4721](https://github.com/anomalyco/opencode/issues/4721). Upgrading to macOS 26 fixes the issue. Alternatively, use a different terminal (e.g., iTerm2, VSCode terminal, or Kitty).

## Testing

This project includes a testing infrastructure using [bats-core](https://github.com/bats-core/bats-core) for unit tests and GitHub Actions for CI.

### Prerequisites

```sh-session
# Install bats
npm install -g bats

# Install shellcheck (optional, for shell linting)
sudo apt install shellcheck   # Linux
brew install shellcheck       # macOS

# Install hadolint (optional, for Dockerfile linting)
brew install hadolint         # macOS
# or: docker run --rm -i hadolint/hadolint < Dockerfile
```

### Running Tests

```sh-session
# Run all tests
make test

# Run only static analysis (shellcheck, hadolint, syntax checks)
make test-lint

# Run only unit tests (no Docker needed)
make test-unit

# Run only end-to-end tests (requires Docker)
make test-e2e
```

### CI Pipeline

The `.github/workflows/ci.yaml` pipeline runs on every push and PR:

1. **Lint** — ShellCheck, Hadolint, bash syntax, JSON validation, frontmatter validation
2. **Unit tests** — bats tests for `configure-opencode.sh`, wrapper, and install.sh flags
3. **Docker build matrix** — builds and verifies the image with every build-arg combination
4. **E2E tests** — full integration tests against built images

### Pre-commit Hooks

To enable pre-commit hooks locally:

```sh-session
pip install pre-commit   # or: brew install pre-commit
pre-commit install
```

This runs ShellCheck and `shfmt` on every commit. Hooks are configured in `.pre-commit-config.yaml`.

### Test Structure

```
test/
  helper.bats                    # Shared test helper functions
  test_configure.bats            # configure-opencode.sh unit tests
  test_wrapper.bats              # opencode wrapper behavior tests
  test_install_flags.bats        # install.sh flag parsing tests
  test_e2e.bats                  # Docker build + run integration tests
  fixtures/
    golden_minimal.json          # Expected output for default build
    golden_recommended.json      # Expected output for --recommended build
```

<!-- TODO: Add demo video after recording on Mac
## Demo

[![demo](./docs/demo.gif)](https://github.com/PraveenNellihela/opencode-sandbox)
-->

## Contributing

PRs welcome. Open an issue first for discussion on anything non-trivial.
