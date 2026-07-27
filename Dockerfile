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
COPY --chown=dev:dev preconfig/ /preconfig/
COPY --chown=dev:dev scripts/configure-opencode.sh /tmp/configure-opencode.sh

# Pass build args as env vars for the configure script, then generate config
ENV OPCODE_PLUGINS=$OPCODE_PLUGINS
ENV OPCODE_MCP=$OPCODE_MCP
ENV OPCODE_AGENTS=$OPCODE_AGENTS
RUN bash /tmp/configure-opencode.sh /home/dev/.config/opencode /preconfig && rm /tmp/configure-opencode.sh && rm -rf /preconfig

# ── Install opencode ─────────────────────────────────────────
RUN curl -fsSL https://opencode.ai/install | bash
ENV PATH="/home/dev/.opencode/bin:${PATH}"

ENTRYPOINT ["opencode"]