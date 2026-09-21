FROM vastai/base-image:cuda-12.1.1-cudnn8-devel-ubuntu22.04-py311

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    locales \
    build-essential \
    libclang-dev \
    gcc-aarch64-linux-gnu \
    git \
    wget \
    curl \
    ca-certificates \
    tar \
    unzip \
    micro \
    zsh \
    tmux \
    xclip \
    xauth \
    ripgrep \
    tree \
    lsof \
    psmisc \
    less \
    ncurses-bin \
    ncurses-term \
    kitty-terminfo \
    && rm -rf /var/lib/apt/lists/*

# UTF-8 locales for SSH clients.
RUN locale-gen ko_KR.UTF-8 en_US.UTF-8 \
    && LANG=ko_KR.UTF-8 LC_ALL=ko_KR.UTF-8 locale charmap | grep -Fx 'UTF-8'

# Safe UTF-8 fallback. SSH may override LANG with ko_KR.UTF-8, which now exists.
ENV LANG=C.UTF-8

# GitHub CLI
RUN mkdir -p -m 755 /etc/apt/keyrings \
    && wget -nv -O /etc/apt/keyrings/githubcli-archive-keyring.gpg https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && mkdir -p -m 755 /etc/apt/sources.list.d \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends gh \
    && rm -rf /var/lib/apt/lists/*

ENV RUSTUP_HOME=/root/.rustup \
    CARGO_HOME=/root/.cargo \
    TERMINFO_DIRS=/etc/terminfo:/lib/terminfo:/usr/share/terminfo

# Keep system ncurses tools ahead of Vast's /venv/main tools.
ENV PATH="/root/.cargo/bin:/root/.kilo/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${PATH}"

# Competition Rust toolchain
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
    | sh -s -- -y --profile minimal \
    && rustup toolchain install nightly-2026-05-01 --component rustfmt --component clippy \
    && rustup default nightly-2026-05-01

# cargo-binstall plus MOA/Furiosa tools
RUN curl -L --proto '=https' --tlsv1.2 -sSf \
      https://raw.githubusercontent.com/cargo-bins/cargo-binstall/main/install-from-binstall-release.sh \
    | bash \
    && cargo binstall --no-confirm cargo-furiosa-opt@0.6.0 \
    && cargo install furiosa-schedule-viewer \
    && cargo binstall --no-confirm furiosa-arena-cli \
    && cargo binstall --no-confirm moa-submitter-cli

# Use Vast's default /venv/main so the base-image startup experience stays intact.
RUN /venv/main/bin/python -m pip install --no-cache-dir --upgrade pip \
    && /venv/main/bin/python -m pip install --no-cache-dir numpy safetensors \
    && /venv/main/bin/python -m pip install --no-cache-dir torch --index-url https://download.pytorch.org/whl/cpu
    
RUN ln -sf /usr/bin/infocmp /venv/main/bin/infocmp

ARG KILO_VERSION=7.7.5
RUN curl -fsSL https://kilo.ai/cli/install \
    | bash -s -- --version "$KILO_VERSION" --no-modify-path \
    && kilo --version

RUN mkdir -p /etc/moa /root/.config/kilo

COPY docker/moa-tmux.conf /etc/moa/tmux.conf
COPY docker/moa-shell.sh /etc/moa/shell.sh
COPY docker/kilo.jsonc /root/.config/kilo/kilo.jsonc

RUN touch /etc/tmux.conf \
    && printf '\nsource-file /etc/moa/tmux.conf\n' >> /etc/tmux.conf \
    && printf '\nsource /etc/moa/shell.sh\n' >> /etc/bash.bashrc \
    && printf '\nsource /etc/moa/shell.sh\n' >> /etc/zsh/zshrc

# Build-time smoke checks
RUN test "$(command -v infocmp)" = "/usr/bin/infocmp" \
    && env -u TERMINFO -u LD_LIBRARY_PATH /usr/bin/infocmp alacritty >/dev/null \
    && env -u TERMINFO -u LD_LIBRARY_PATH /usr/bin/infocmp xterm-kitty >/dev/null \
    && ldd /usr/bin/tmux | grep -Eq 'lib(tinfo|ncurses)' \
    && command -v rustc \
    && command -v cargo \
    && command -v cargo-furiosa-opt \
    && command -v furiosa-schedule-viewer \
    && command -v furiosa-arena \
    && command -v moa-submitter \
    && command -v gh \
    && command -v micro \
    && command -v zsh \
    && command -v tmux \
    && command -v kilo \
    && TERM=xterm-256color tmux -L moa-build -f /etc/tmux.conf new-session -d -s smoke \
    && tmux -L moa-build kill-server \
    && /venv/main/bin/python -c 'import numpy, torch, safetensors; print("python refs: OK", numpy.__version__, torch.__version__, safetensors.__version__)' \
    && rustc --version \
    && cargo --version \
    && tmux -V \
    && kilo --version

WORKDIR /workspace
