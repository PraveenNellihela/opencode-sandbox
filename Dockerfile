# syntax=docker/dockerfile:1
# Requires BuildKit (default in Docker 23+/Desktop, Podman, and CI's buildx).
# The apt cache mounts share package indexes across layers so each build
# downloads the apt index only once.

FROM ubuntu:26.04@sha256:3131b4cc82a783df6c9df078f86e01819a13594b865c2cad47bd1bca2b7063bb
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ENV DEBIAN_FRONTEND=noninteractive

# ── Build arguments (all optional, default to no extras) ─────
ARG INSTALL_NODE=false
ARG INSTALL_PYTHON=false
ARG INSTALL_CLI_TOOLS=false
ARG OPCODE_PLUGINS=""
ARG SANDBOX_VERSION="dev"
ARG NODE_VERSION=24.18.1
ARG MISE_VERSION=2026.7.18

# ── Base deps ────────────────────────────────────────────────
# Single apt update per build (cache mount shared by later apt layers).
# Fail-fast options stop a slow/flaky mirror from retrying for minutes.
# jq/xz-utils: needed by the config seeder and tarball installs.
RUN --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    --mount=type=cache,target=/var/cache/apt,sharing=locked \
    apt-get -o Acquire::Retries=3 \
            -o Acquire::http::Timeout=30 \
            -o Acquire::https::Timeout=30 update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        ncurses-term \
        locales \
        jq \
        xz-utils

# Enable UTF-8 locale
RUN sed -i 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && locale-gen
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# ── Optional: CLI productivity tools ─────────────────────────
# Mounts the same apt caches as the base layer: the index written by the
# base layer's apt-get update lives in the cache mount, not the layer, so
# installs must mount it too or the lists are empty.
RUN --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    --mount=type=cache,target=/var/cache/apt,sharing=locked \
    if [ "$INSTALL_CLI_TOOLS" = "true" ]; then \
      apt-get install -y --no-install-recommends \
        ripgrep \
        fd-find \
        tmux \
        unzip \
      && ln -s /usr/bin/fdfind /usr/local/bin/fd; \
    fi

# ── Optional: Node.js (pinned LTS, official tarball) ─────────
# Direct tarball instead of the nodesource apt repo: one download,
# no extra apt update, deterministic version.
RUN if [ "$INSTALL_NODE" = "true" ]; then \
      case "$(uname -m)" in \
        aarch64|arm64) arch="arm64" ;; \
        *)             arch="x64" ;; \
      esac; \
      curl -fsSL -o /tmp/node.tar.xz \
        "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${arch}.tar.xz" \
      && tar -xJf /tmp/node.tar.xz -C /usr/local --strip-components=1 \
      && rm -f /tmp/node.tar.xz; \
    fi

# ── Optional: Python 3 ───────────────────────────────────────
RUN --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    --mount=type=cache,target=/var/cache/apt,sharing=locked \
    if [ "$INSTALL_PYTHON" = "true" ]; then \
      apt-get install -y --no-install-recommends \
        python3 \
        python3-pip \
        python3-venv \
        build-essential; \
    fi

# ── mise (universal version manager) ─────────────────────────
# The runtime escape hatch: `mise use -g rust@latest` installs any
# language in user space (persisted via the opencode-tools volume).
# MIT licensed (jdx/mise); see README "Third-party licenses".
RUN case "$(uname -m)" in \
      aarch64|arm64) arch="arm64" ;; \
      *)             arch="x64" ;; \
    esac; \
    curl -fsSL -o /tmp/mise.tgz \
      "https://github.com/jdx/mise/releases/download/v${MISE_VERSION}/mise-v${MISE_VERSION}-linux-${arch}.tar.gz" \
    && tar -xzf /tmp/mise.tgz -C /usr/local/bin mise \
    && rm -f /tmp/mise.tgz

# ── Non-root user ────────────────────────────────────────────
RUN useradd -m -s /bin/bash dev
USER dev
WORKDIR /home/dev

# Pre-create volume mount points (so Docker copies ownership into empty volumes)
RUN mkdir -p /home/dev/.config/opencode /home/dev/.local/share/opencode \
    /home/dev/.mise/data /home/dev/.mise/config

# ── Config seeder (runs at install time against the config volume) ──
COPY --chown=dev:dev preconfig/ /opt/opencode-sandbox/preconfig/
COPY --chown=dev:dev scripts/configure-opencode.sh /opt/opencode-sandbox/configure-opencode.sh
RUN echo "$SANDBOX_VERSION" > /opt/opencode-sandbox/VERSION

LABEL org.opencontainers.image.version="$SANDBOX_VERSION"

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
ENV PATH="/home/dev/.opencode/bin:/home/dev/.mise/data/shims:/home/dev/.local/bin:${PATH}"

ENTRYPOINT ["opencode"]
