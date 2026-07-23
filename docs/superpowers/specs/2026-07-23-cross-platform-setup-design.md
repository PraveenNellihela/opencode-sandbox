# Design: Cross-Platform Setup & Teardown for opencode-sandbox

**Date:** 2026-07-23
**Status:** Approved
**Goal:** Make opencode-sandbox easy to install, use, and fully uninstall across Linux, macOS, and Windows (WSL), for users of any skill level.

---

## Problem

The current setup requires manual steps (create `~/bin`, copy wrapper, edit shell config) that are bash-specific and fragile. The PATH export doesn't persist across shell sessions for zsh/fish users. There is no uninstall path, and no troubleshooting guidance for common issues.

## Target Audience

Mixed — developers comfortable with Docker and those new to containers. The setup should be one command for everyone.

---

## Component 1: `install.sh`

A single POSIX-compatible shell script that handles full setup.

### Behavior

1. **Detect environment:**
   - OS via `uname -s` (Linux, Darwin, or WSL via `/proc/version` check)
   - Shell via `$SHELL` env var, fallback to `/etc/passwd`
   - Config file: `~/.bashrc` (bash), `~/.zshrc` (zsh), `~/.config/fish/config.fish` (fish)

2. **Check prerequisites:**
   - Docker or Podman installed and running
   - If neither found → print install instructions, exit 1

3. **Install wrapper:**
   - Create `~/bin` if it doesn't exist
   - Copy `opencode` script to `~/bin/opencode`
   - `chmod +x ~/bin/opencode`

4. **Update PATH (idempotent):**
   - For bash/zsh: grep config file for the PATH line; if missing, append:
     ```
     # opencode-sandbox
     export PATH="$HOME/bin:$PATH"
     ```
   - For fish: use `fish_add_path ~/bin` (idempotent by design)
   - If `~/bin` already on PATH (check via `case ":$PATH:"`) → skip modification

5. **Build Docker image:**
   - `docker build -t local:opencode .`
   - If build fails → print error, exit 1

6. **Print success:**
   ```
   ✓ Installed opencode-sandbox
   ✓ Wrapper: ~/bin/opencode
   ✓ PATH: updated in ~/.bashrc
   ✓ Image: local:opencode

   Restart your shell, then: cd ~/code/my-project && opencode
   ```

### Edge Cases

- Script run from outside the repo directory → detect and warn
- Fish shell → use `fish_add_path` not `export PATH`
- WSL → treat as Linux, note Docker Desktop must be running
- `~/bin` already exists and on PATH → skip creation and PATH modification

---

## Component 2: `uninstall.sh`

A single script that reverses everything `install.sh` did, with safety prompts for destructive actions.

### Behavior

1. **Remove wrapper:**
   - Delete `~/bin/opencode` if it exists

2. **Remove PATH entry:**
   - Detect shell and config file (same logic as install)
   - Remove the `# opencode-sandbox` block and `export PATH` line
   - For fish: `fish_remove_path ~/bin`

3. **Prompt about Docker volumes:**
   - List opencode-related volumes: `docker volume ls --format '{{.Name}}' | grep opencode`
   - If volumes found, prompt:
     ```
     Found opencode data volumes:
       - opencode-config  (settings, plugins)
       - opencode-data    (auth tokens, sessions)

     These persist your opencode settings across sessions.
     Remove them? This cannot be undone. [y/N]
     ```
   - Only remove volumes if user confirms with `y` or `Y`

4. **Prompt about Docker image:**
   ```
   Remove Docker image local:opencode? [y/N]
   ```
   - Only remove if confirmed

5. **Print summary:**
   ```
   ✓ Removed: ~/bin/opencode
   ✓ Removed: PATH entry from ~/.bashrc
   ✓ Removed: Docker image (if confirmed)
   ✓ Removed: Docker volumes (if confirmed)

   opencode-sandbox has been uninstalled.
   ```

### Safety Guarantees

- **Never** removes `~/bin/` directory itself (may contain other files)
- **Never** removes the project directory or any user code
- **Never** removes Docker volumes without explicit confirmation
- Lists all actions before executing, asks for final confirmation
- If user declines volume removal, prints: "Volumes kept. Remove later with: docker volume rm opencode-config opencode-data"

---

## Component 3: Wrapper script improvements (`opencode`)

Modifications to the existing wrapper script.

### New flags

- `--help` → print usage and exit
- `--uninstall` → detect and run `uninstall.sh` from the repo directory

### Checks before running

1. **Docker check:** `command -v docker >/dev/null 2>&1 || { echo "Error: Docker not found. Install from https://docs.docker.com/get-docker/"; exit 1; }`
2. **Docker running:** `docker info >/dev/null 2>&1 || { echo "Error: Docker daemon not running. Start Docker and try again."; exit 1; }`
3. **Image exists:** `docker image inspect local:opencode >/dev/null 2>&1 || { echo "Image not found. Building..."; docker build -t local:opencode "$(dirname "$0")"; }`

### Quoting fix

Current: `-v "$CWD":/home/dev/workspace`
This already handles spaces correctly. Verify no other unquoted expansions exist.

---

## Component 4: README rewrite

### Structure

```
# opencode-sandbox
One-line description.

## Quick Start
  1. git clone <repo> && cd opencode-sandbox
  2. ./install.sh
  3. cd ~/code/my-project && opencode

## How It Works
  - Container sees only current project dir (bind mount)
  - Settings and auth persist via Docker volumes
  - Non-root user, no sudo, no host exposure

## What Persists vs. What Doesn't
  (Keep existing content, minor rewording)

## Cross-Platform
  ### Linux
    Works out of the box with Docker Engine.

  ### macOS
    Install Docker Desktop first: https://docs.docker.com/desktop/install/mac-install/
    Apple Silicon and Intel both supported.

  ### Windows (WSL2)
    1. Install WSL2: wsl --install
    2. Install Docker Desktop with WSL2 backend
    3. Run install.sh from inside WSL

## Shell Support
  install.sh auto-detects your shell:
  - bash: modifies ~/.bashrc
  - zsh: modifies ~/.zshrc
  - fish: uses fish_add_path

## Adding Dependencies
  (Keep existing Dockerfile content)

## Security Model
  (Keep existing non-root, no-sudo content)

## Uninstalling
  ./uninstall.sh
  Removes wrapper, PATH entry, and optionally Docker image/volumes.

## Troubleshooting
  "Docker: command not found"
    → Install Docker: https://docs.docker.com/get-docker/

  "Cannot connect to the Docker daemon"
    → Start Docker Desktop or: sudo systemctl start docker

  "opencode: command not found" after install
    → Restart your shell, or: source ~/.bashrc

  "Image not found" error
    → Run: ./install.sh (rebuilds the image)

  Permission denied on ~/bin
    → Check ownership: ls -la ~/bin
    → Fix: chown -R $(whoami) ~/bin
```

---

## Out of Scope (Future Work)

- Java/Mise runtime persistence (separate ticket)
- Podman-specific installation path
- Automatic SSH key forwarding setup
- Shell completions for the wrapper

---

## Files to Create/Modify

| File | Action |
|------|--------|
| `install.sh` | Create (new) |
| `uninstall.sh` | Create (new) |
| `opencode` | Modify (add --help, checks, --uninstall) |
| `README.md` | Rewrite (cross-platform, troubleshooting) |

## Verification

1. Run `./install.sh` on a fresh system — should complete without manual steps
2. Run `opencode --help` — should print usage
3. Run `./uninstall.sh` — should prompt about volumes, remove wrapper and PATH
4. After uninstall, `opencode` should not be found
5. Test on: bash, zsh, fish (at least two shells)
6. Test on: Linux, macOS (or confirm WSL notes are accurate)
