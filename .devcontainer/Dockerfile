FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

ARG DEBIAN_FRONTEND=noninteractive
ARG USER_UID=1000
ARG USER_GID=1000

RUN apt-get update \
    && apt-get install --yes --no-install-recommends \
      build-essential \
      ca-certificates \
      curl \
      lua5.1 \
      luarocks \
      make \
      neovim \
    && luarocks --lua-version=5.1 install luacheck \
    && mkdir -p /etc/opencode \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY .devcontainer/opencode-container.json /etc/opencode/opencode.json

RUN groupmod --non-unique --gid "${USER_GID}" vscode \
    && usermod --non-unique --uid "${USER_UID}" --gid "${USER_GID}" vscode \
    && mkdir -p /home/vscode/.local/share/opencode \
    && chown -R vscode:vscode /home/vscode/.local

USER vscode
ENV PATH="/home/vscode/.cargo/bin:/home/vscode/.opencode/bin:${PATH}"

RUN curl -fsSL https://sh.rustup.rs -o /tmp/rustup.sh \
    && sh /tmp/rustup.sh -y --profile minimal \
    && rm /tmp/rustup.sh \
    && cargo install stylua --version 2.3.1 --locked \
    && curl -fsSL https://opencode.ai/v2/install -o /tmp/opencode-install.sh \
    && bash /tmp/opencode-install.sh --no-modify-path \
    && rm /tmp/opencode-install.sh
