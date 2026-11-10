# ghostline.nvim

An experimental Neovim plugin aiming to provide GitHub Copilot-style inline
code completions.

> **Status:** early scaffold. Completion, authentication, and provider
> integrations are not implemented yet.

## Requirements

- Neovim 0.9.0 or newer

## Installation

Install with your preferred plugin manager. For example, with `lazy.nvim`:

```lua
{
  "Lemorra/ghostline.nvim",
  opts = {},
}
```

## Configuration

The setup entry point is reserved for future configuration. At present it
accepts an optional table and does not enable completion functionality:

```lua
require("ghostline").setup({})
```

## Development

See [docs/development.md](docs/development.md) for environment setup and local
test instructions, and [CONTRIBUTING.md](CONTRIBUTING.md) for contribution
guidelines. The project uses `make test`, `make lint`, and `make format-check`.

The repository also includes an optional, project-local OpenCode developer
agent. See [docs/development.md](docs/development.md#opencode-assisted-development)
for details and approval behavior.

## License

MIT. See [LICENSE](LICENSE).
