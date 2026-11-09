#!/usr/bin/env bash
set -euo pipefail

cargo install stylua --version 2.3.1 --locked
curl -fsSL https://opencode.ai/v2/install | bash -s -- --no-modify-path
