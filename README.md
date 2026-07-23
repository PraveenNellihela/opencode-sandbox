# opencode-sandbox

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Docker](https://img.shields.io/badge/docker-%3E%3D20.10-blue?logo=docker)](https://docs.docker.com/get-docker/)

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="opencode-sandbox-light.png">
  <source media="(prefers-color-scheme: light)" srcset="opencode-sandbox-dark.png">
  <img alt="opencode-sandbox" src="opencode-sandbox-dark.png">
</picture>

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

The installer detects your OS and shell, copies the wrapper to `~/bin/`, builds the Docker image, and prints the PATH command you need to add to your shell config.

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

The installer detects your shell and prints a copy-pasteable command to add `~/bin` to your PATH:

| Shell | Command to run | Config file |
|-------|----------------|-------------|
| bash | `echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc` | `~/.bashrc` |
| zsh | `echo 'export PATH="$HOME/bin:$PATH"' >> ~/.zshrc` | `~/.zshrc` |
| fish | `fish_add_path ~/bin` | `~/.config/fish/config.fish` |

To remove after uninstalling:

| Shell | Command to run |
|-------|----------------|
| bash | `sed -i '/export PATH="\$HOME\/bin:\$PATH"/d' ~/.bashrc` |
| zsh | `sed -i '/export PATH="\$HOME\/bin:\$PATH"/d' ~/.zshrc` |
| fish | `fish_remove_path ~/bin` |

The installer does **not** auto-edit your shell config. You run the command yourself for safety.

## Adding Dependencies

If a plugin or MCP server needs a system package (e.g., Node.js), add to the `Dockerfile` before the `USER dev` line:

```dockerfile
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - \
    && apt-get install -y nodejs
```

Then rebuild:

```sh-session
$ docker build -t local:opencode .
```

Cached layers make this fast.

## Installing Plugins

Plugins that opencode installs itself land under `~/.config/opencode` (a persisted volume), so they survive container restarts.

Example: [superpowers](https://github.com/obra/superpowers), installed from inside opencode with:

```
Fetch and follow instructions from https://raw.githubusercontent.com/obra/superpowers/refs/heads/main/.opencode/INSTALL.md
```

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
→ Run: `./install.sh` (rebuilds the image)

**Permission denied on ~/bin**
→ Check ownership: `ls -la ~/bin`
→ Fix: `chown -R $(whoami) ~/bin`

<!-- TODO: Add demo video after recording on Mac
## Demo

[![demo](./docs/demo.gif)](https://github.com/PraveenNellihela/opencode-sandbox)
-->

## Contributing

PRs welcome. Open an issue first for discussion on anything non-trivial.
