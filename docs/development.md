# Development environment

This guide sets up an isolated environment for developing and testing
ghostline.nvim. The plugin is an early scaffold; its smoke test currently
covers only module loading and the `setup` API contract.

## Recommended: development container

The repository includes a [Dev Container](https://containers.dev/) definition
in `.devcontainer/`. It installs Neovim, Lua/LuaRocks, Luacheck, and StyLua
inside a container, so you do not need to install or configure these tools on
your host.

Requirements on the host:

- Docker or another Dev Container-compatible container runtime
- Visual Studio Code with the Dev Containers extension, or the Dev Container
  CLI
- OpenCode V2 on the host (for the host TUI connection described below)
- Git

In VS Code, open this repository and choose **Reopen in Container** from the
Command Palette. The first open builds the image and installs StyLua; later
opens reuse the container. The workspace checkout is mounted for editing, but
the container has its own home directory and XDG configuration, data, state,
and cache directories. In particular, the host's `~/.config/nvim`, Neovim data
directory, and plugin manager directories are not mounted. Tests run with
Neovim's `--clean` option as an additional guard against loading a user config.

To run the development checks in the container terminal:

```sh
nvim --version
stylua --version
luacheck --version
make check
```

Container changes to installed tools and its home directory do not alter the
host Neovim configuration. Files intentionally created in the mounted project
directory (including edits or generated files) are shared with the host, so
review the Git diff as usual. Do not mount your host home or Neovim config into
the container.

## Alternative: install tools on the host

The checks can also run natively, but this does not isolate tool installation
from your host. Avoid running untrusted setup scripts or replacing your
existing Neovim binary/configuration. `make test` uses `--clean` and a minimal
test init, so it will not load your normal Neovim configuration.

Install Neovim 0.9.0 or newer, Make, Lua/LuaJIT, [StyLua](https://github.com/JohnnyMorganz/StyLua),
and [Luacheck](https://github.com/lunarmodules/luacheck) using their upstream
instructions. For example, with Cargo and LuaRocks available:

```sh
cargo install stylua --version 2.3.1 --locked
luarocks install luacheck
```

Ensure the executables are on `PATH`. The plugin itself has no third-party Lua
dependencies at this stage.

## Run checks

From the repository root:

```sh
make test          # Run Neovim headless smoke tests
make lint          # Run Luacheck on lua/ and tests/
make format-check  # Check Lua formatting with StyLua
make check         # Run formatting, lint, and tests
```

To format Lua files after editing:

```sh
make format
```

The smoke test is `tests/smoke.lua`; `tests/minimal_init.lua` creates a clean
Neovim runtime with the checkout on `runtimepath`. Tests are run without a user
configuration or network access. CI runs the same checks against Neovim 0.9 and
the current stable release.

## Developing the plugin

The public module currently lives in `lua/ghostline/init.lua`. Keep user-facing
setup and configuration behavior documented in `README.md` and add tests in
`tests/` as functionality is introduced. Avoid adding provider credentials or
tokens to the repository; tests should not depend on live completion services.

## OpenCode-assisted development

The repository contains an optional V2 OpenCode configuration under
`.opencode/`. It selects the `developer` agent and defines the `/feature` and
`/review` workflows. The developer agent works autonomously on clear, bounded
tasks but asks you before materially changing completion behavior, public APIs,
architecture, dependencies, compatibility, or security/privacy behavior.
Configuration is provider-neutral; connect a provider in the container's
OpenCode session or provide credentials securely to that container. Do not
copy host OpenCode auth files into the repository or container image.

### Use host OpenCode with the container

When the Dev Container has been created, open a terminal **inside the
container** and start its OpenCode server from the repository root:

```sh
opencode serve --hostname 0.0.0.0 --port 4096
```

Leave that foreground process running. VS Code forwards port `4096` to a local
host port. In a terminal on the host, from this repository, connect the host
OpenCode TUI to the container server:

```sh
opencode --server http://localhost:4096
```

The server owns the project session and executes OpenCode tools in the
container. The checkout is the shared workspace, so edits appear on the host
and in the container. The host TUI remains the place where you see and answer
permission and decision prompts. Stop the server with `Ctrl-C` in the
container terminal when finished.

The forwarded port is intended for local development only. Do not publish port
4096 on a public interface or change forwarding to public visibility. The
container's `/etc/opencode/opencode.json` enables broad shell access for agent
work inside the container, asks before common destructive shell commands, and
hard-denies `git push`, `git reset`, and `git clean`. The repository itself is
still mounted and writable: containerization protects host Neovim and host
tooling, not the checkout. Keep unrelated changes safe and review the diff.

This setup does not add or use host OpenCode's background server. The explicit
`--server` option connects the host TUI to the container's server. If you start
OpenCode without `--server`, it may use your normal host service and execute
tools on the host instead.

Provider authentication is separate from the host TUI connection: connect the
provider to the container's OpenCode server from the connected session. The
container's OpenCode home is isolated and can be reset if the container is
rebuilt, so follow your provider's secure login flow again when needed.

The developer's question-tool requirement is the human gate for major feature
decisions; shell permissions are not a substitute for that discussion.
Review proposed changes before committing or publishing them.

### Feature and review commands

- `/feature <task>` runs the focused implementation workflow: inspect context,
  implement a bounded change, add relevant tests/docs, run `make check`, and
  inspect the final diff. The developer agent asks you before material product
  or design decisions, but does not stop for routine reversible choices.
- `/review [scope]` runs the separate read-only reviewer agent. It returns
  actionable findings and validation gaps to help a maintainer review the diff;
  it cannot edit files and does not approve or merge changes.

The implementation agent performs a self-review, while the reviewer command is
an independent second pass. Neither substitutes for a human developer's final
review. Keep the final change visible in the diff and do not treat a clean
automated review as approval.
