FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive

# Minimal deps: ca-certificates+curl to fetch the installer, git for repo work.
# Add more (e.g. nodejs) only when a specific plugin/MCP server needs it.
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# Non-root user, no sudo. If you need to install something inside the
# container, add it to this Dockerfile and rebuild instead of granting
# live privilege escalation.
RUN useradd -m -s /bin/bash dev
USER dev
WORKDIR /home/dev

# Pre-create the dirs the named volumes mount over. Docker only copies
# ownership from the image into an empty volume if the directory already
# exists at build time — otherwise the mount point gets created as root
# and opencode fails with EACCES on first run.
RUN mkdir -p /home/dev/.config/opencode /home/dev/.local/share/opencode

RUN curl -fsSL https://opencode.ai/install | bash
ENV PATH="/home/dev/.opencode/bin:${PATH}"

ENTRYPOINT ["opencode"]
