FROM ubuntu:24.04
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ENV DEBIAN_FRONTEND=noninteractive

# ── Build arguments (all optional, default to no extras) ─────
ARG INSTALL_NODE=false
ARG INSTALL_PYTHON=false
ARG INSTALL_GO=false
ARG INSTALL_CLI_TOOLS=false
ARG OPCODE_PLUGINS=""
ARG OPCODE_MCP=""
ARG OPCODE_AGENTS=false

# ── Base deps ────────────────────────────────────────────────
# ca-certificates+curl to fetch opencode installer, git for repo work.
# ncurses-term: full terminfo database (xterm-256color etc.) for TUI rendering
# locales: UTF-8 support for unicode box-drawing characters in the TUI
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    ncurses-term \
    locales \
    && rm -rf /var/lib/apt/lists/*

# Enable UTF-8 locale
RUN sed -i 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && locale-gen
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# ── Optional: CLI productivity tools ─────────────────────────
RUN if [ "$INSTALL_CLI_TOOLS" = "true" ]; then \
      apt-get update && apt-get install -y --no-install-recommends \
        ripgrep \
        fd-find \
        jq \
        unzip \
        tmux \
      && rm -rf /var/lib/apt/lists/* \
      && ln -s /usr/bin/fdfind /usr/local/bin/fd; \
    fi

# ── Optional: Node.js (LTS) ──────────────────────────────────
RUN if [ "$INSTALL_NODE" = "true" ]; then \
      curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - \
      && apt-get install -y --no-install-recommends nodejs; \
    fi

# ── Optional: Python 3 ───────────────────────────────────────
RUN if [ "$INSTALL_PYTHON" = "true" ]; then \
      apt-get update && apt-get install -y --no-install-recommends \
        python3 \
        python3-pip \
        python3-venv \
        build-essential \
      && rm -rf /var/lib/apt/lists/*; \
    fi

# ── Optional: Go ─────────────────────────────────────────────
RUN if [ "$INSTALL_GO" = "true" ]; then \
      apt-get update && apt-get install -y --no-install-recommends \
        golang \
      && rm -rf /var/lib/apt/lists/*; \
    fi

# ── Non-root user ────────────────────────────────────────────
RUN useradd -m -s /bin/bash dev
USER dev
WORKDIR /home/dev

# Pre-create volume mount points (so Docker copies ownership into empty volumes)
RUN mkdir -p /home/dev/.config/opencode /home/dev/.local/share/opencode

# ── Seed opencode config template and configure script ───────
COPY --chown=dev:dev preconfig/ /home/dev/.tmp/preconfig/
COPY --chown=dev:dev scripts/configure-opencode.sh /home/dev/.tmp/configure-opencode.sh

# Pass build args as env vars for the configure script, then generate config
ENV OPCODE_PLUGINS=$OPCODE_PLUGINS
ENV OPCODE_MCP=$OPCODE_MCP
ENV OPCODE_AGENTS=$OPCODE_AGENTS
RUN bash /home/dev/.tmp/configure-opencode.sh /home/dev/.config/opencode /home/dev/.tmp/preconfig && rm -rf /home/dev/.tmp

# ── Install impeccable design skill (optional) ───────────────
# Seeded as a global opencode skill (~/.config/opencode/skills/) when
# requested via OPCODE_PLUGINS=impeccable. Sparse checkout with blob
# filtering keeps this layer small (upstream repo is ~340MB).
RUN if [[ "$OPCODE_PLUGINS" == *impeccable* ]]; then \
      for i in 1 2 3; do \
        if git clone --depth 1 --filter=blob:none --sparse \
            https://github.com/pbakaus/impeccable.git /tmp/impeccable; then \
          break; \
        fi; \
        echo "impeccable clone attempt $i failed, retrying in 5s..." >&2; \
        sleep 5; \
        rm -rf /tmp/impeccable; \
      done; \
      git -C /tmp/impeccable sparse-checkout set .opencode LICENSE NOTICE.md --skip-checks \
      && mkdir -p /home/dev/.config/opencode/skills \
      && cp -r /tmp/impeccable/.opencode/skills/impeccable /home/dev/.config/opencode/skills/ \
      && cp /tmp/impeccable/LICENSE /tmp/impeccable/NOTICE.md /home/dev/.config/opencode/skills/impeccable/ \
      && rm -rf /tmp/impeccable; \
    fi

# ── Install Emil Kowalski's design skills (optional) ─────────
# Seeded as global opencode skills when requested via
# OPCODE_PLUGINS=emil. Pure markdown, tiny repo (~60KB), so a
# plain shallow clone suffices.
RUN if [[ "$OPCODE_PLUGINS" == *emil* ]]; then \
      for i in 1 2 3; do \
        if git clone --depth 1 \
            https://github.com/emilkowalski/skills.git /tmp/emil-skills; then \
          break; \
        fi; \
        echo "emil skills clone attempt $i failed, retrying in 5s..." >&2; \
        sleep 5; \
        rm -rf /tmp/emil-skills; \
      done; \
      mkdir -p /home/dev/.config/opencode/skills \
      && cp -r /tmp/emil-skills/skills/* /home/dev/.config/opencode/skills/ \
      && cp /tmp/emil-skills/LICENSE /home/dev/.config/opencode/skills/LICENSE-emil-skills \
      && rm -rf /tmp/emil-skills; \
    fi

# ── Install opencode ─────────────────────────────────────────
# The release binary download from GitHub occasionally fails with a
# transient "connection reset" (curl exit 35) in CI, so retry the
# whole install (which is idempotent via its version check).
RUN for i in 1 2 3 4 5; do \
      if curl -fsSL https://opencode.ai/install | bash; then \
        exit 0; \
      fi; \
      echo "opencode install attempt $i failed, retrying in 10s..." >&2; \
      sleep 10; \
    done; \
    echo "opencode install failed after 5 attempts" >&2; \
    exit 1
ENV PATH="/home/dev/.opencode/bin:${PATH}"

ENTRYPOINT ["opencode"]