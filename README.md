# ghostline.nvim

An experimental Neovim plugin aiming to provide GitHub Copilot-style inline
code completions.

> **Status:** MVP. Ghost text, automatic and manual triggers, and accept/dismiss
> flows work end to end. Ollama is not wired up yet, so every suggestion is the
> placeholder text `Waiting for model response`.

## Requirements

- Neovim 0.9.0 or newer. Neovim 0.10+ is recommended because it renders ghost
  text at the cursor; on 0.9 the text is shown at the end of the line.

## Installation

Install with your preferred plugin manager. For example, with `lazy.nvim`:

```lua
{
  "Lemorra/ghostline.nvim",
  opts = {},
}
```

## Configuration

The defaults are:

```lua
require("ghostline").setup({
  enabled = true,
  trigger = {
    mode = "auto", -- "auto", "manual", or "both"
    keymap = "<M-\\>", -- insert-mode trigger for manual and both modes
    debounce_ms = 400, -- pause before an automatic request
  },
  accept_keymap = "<Tab>",
  dismiss_keymap = "<C-]>",
  highlight = "GhostlineText",
})
```

The trigger modes are:

- `auto`: request a suggestion after typing pauses in insert mode.
- `manual`: request a suggestion only when `trigger.keymap` is pressed.
- `both`: use both the automatic pause and the trigger keymap.

The keymaps are insert-mode mappings. `<Tab>` accepts the visible suggestion
and otherwise behaves like the normal Tab key. `<C-]>` dismisses the suggestion
when one is visible and otherwise falls through. Set `accept_keymap` or
`dismiss_keymap` to `false` to leave that key alone. The `highlight` group is
linked to `Comment` by default.

For example, with `lazy.nvim`:

```lua
{
  "Lemorra/ghostline.nvim",
  opts = {
    trigger = { mode = "both", debounce_ms = 500 },
  },
}
```

## Usage

In insert mode, type and pause (in `auto`/`both` mode) or press the trigger key
(in `manual`/`both` mode). Ghost text appears after the cursor. Press `<Tab>` to
insert it into the buffer, or `<C-]>` to dismiss it. Leaving insert mode also
clears the suggestion.

The same actions are available programmatically:

```lua
local ghostline = require("ghostline")
ghostline.trigger()
ghostline.accept()
ghostline.dismiss()
ghostline.is_visible()
```

## Current limitations

- Ollama is the intended first backend, but its HTTP integration is not
  implemented. Every request currently returns, and accepting inserts, the
  placeholder `Waiting for model response`.
- Only one single-line suggestion is tracked at a time. There is no suggestion
  cycling or multi-line rendering.
- The placeholder request context contains the current line and filetype;
  surrounding buffer context is not sent yet.

## Development

See [docs/development.md](docs/development.md) for environment setup and local
test instructions, and [CONTRIBUTING.md](CONTRIBUTING.md) for contribution
guidelines. The project uses `make test`, `make lint`, and `make format-check`.
The test suite includes headless regression tests for insert-mode timer and
keymap integration.

The repository also includes an optional, project-local OpenCode developer
agent. See [docs/development.md](docs/development.md#opencode-assisted-development)
for details and approval behavior.

## License

MIT. See [LICENSE](LICENSE).
