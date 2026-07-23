# opencode-sandbox

Minimal, isolated, persistent setup for running [opencode](https://opencode.ai) on Ubuntu via Docker.

## Setup

```bash
# 1. Build the image
docker build -t local:opencode .

# 2. Put the wrapper on your PATH
mkdir -p ~/bin
cp opencode ~/bin/opencode
chmod +x ~/bin/opencode
# make sure ~/bin is on your PATH (add to ~/.bashrc if not):
#   export PATH="$HOME/bin:$PATH"
```

## Usage

From inside any project directory:

```bash
cd ~/code/my-repo
opencode
```

The current directory is bind-mounted into the container at `/home/dev/workspace`,
so opencode reads and writes your actual files — no copy-in/copy-out.

## What persists vs. what doesn't

- **Persists** (named Docker volumes): `~/.config/opencode` (settings, plugins) and
  `~/.local/share/opencode` (auth tokens, session data). These survive container
  restarts and `docker rm`, so you authenticate once and install plugins once.
- **Does not persist**: anything installed at the OS level inside a running
  container (e.g. `apt install foo` during a session) — the container is `--rm`,
  so that's gone when it exits. Add it to the `Dockerfile` and rebuild instead;
  rebuilds are fast since the apt layer is cached until you change it.

## Isolation model

- Container only sees: the current project directory (bind mount) + the two
  named volumes. Not your home directory, not other repos, not host processes.
- Runs as a non-root user (`dev`) with **no sudo** — see below for why.
- Default Docker networking (bridge) — opencode can reach the internet
  (needed for the LLM API calls) but nothing on the host is exposed.

### Why no sudo

An earlier version of this setup gave `dev` passwordless sudo "for convenience."
That mostly defeats the point of a non-root user: if the user can `sudo` with no
password, it can become root instantly, so on privilege alone it's equivalent to
just running as root. The value of non-root only shows up when the process
*can't* trivially escalate. If you find opencode needs a package mid-session,
that's a signal to add it to the Dockerfile and rebuild, not to hand out live
root.

## Adding dependencies later

Common case: a plugin or MCP server needs Node.js. Add to the Dockerfile before
the `USER dev` line:

```dockerfile
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - \
    && apt-get install -y nodejs
```

Then `docker build -t local:opencode .` again — cached layers make this quick.

## Installing plugins / skill packs

Plugins that opencode installs itself (via its own commands, or by fetching
instructions and writing config) land under `~/.config/opencode`, which is a
persisted volume — so they survive container restarts without extra work.

Example: [superpowers](https://github.com/obra/superpowers), installed from
inside opencode with:

```
Fetch and follow instructions from https://raw.githubusercontent.com/obra/superpowers/refs/heads/main/.opencode/INSTALL.md
```

Confirmed working in this setup — it persists across the restart the installer
requires, no rebuild needed.

Caveat: this only covers what the plugin writes into `~/.config/opencode` or
`~/.local/share/opencode`. If a plugin's install step also needs an OS-level
package (apt, a system binary), that part won't survive — add it to the
Dockerfile per "Adding dependencies later" above.

## Tightening further (optional)

- **Rootless Podman** instead of Docker: same commands (`podman build`,
  `podman run`), removes the root-daemon-on-host concern entirely.
- **Read-only SSH key** for git over SSH:
  `-v ~/.ssh/id_ed25519:/home/dev/.ssh/id_ed25519:ro` added to the wrapper script.
- **Network egress restriction**: put the container on a custom Docker network
  with firewall rules limiting it to your LLM provider's API, if you want to be
  strict about what the sandbox can reach.