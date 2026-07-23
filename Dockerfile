FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive

# Minimal deps: ca-certificates+curl to fetch the installer, git for repo work.
# ncurses-term: full terminfo database (xterm-256color etc.) for TUI rendering
# locales: UTF-8 support for unicode box-drawing characters in the TUI
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    ncurses-term \
    locales \
    && rm -rf /var/lib/apt/lists/*

# Enable UTF-8 locale so the TUI can render unicode correctly
RUN sed -i 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && locale-gen
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

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
