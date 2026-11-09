FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install --yes --no-install-recommends \
      build-essential \
      lua5.1 \
      luarocks \
      make \
      neovim \
    && luarocks --lua-version=5.1 install luacheck \
    && mkdir -p /etc/opencode \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY .devcontainer/opencode-container.json /etc/opencode/opencode.json
