# ghostline.nvim

An experimental Neovim plugin aiming to provide GitHub Copilot-style inline
code completions.

> **Status:** MVP. Ghost text, automatic and manual triggers, accept/dismiss,
> and Ollama completions work end to end.

## Requirements

- Neovim 0.9.0 or newer. Neovim 0.10+ is recommended because it renders ghost
  text at the cursor; on 0.9 the text is shown at the end of the line.
- An Ollama server reachable over plain HTTP and a model that supports
  fill-in-the-middle completion (Ollama's insert mode, driven by `suffix`).
  Models such as the Qwen coder and CodeLlama families are typical choices.
  Official Ollama library models normally include a FIM template. A custom
  GGUF import may not, in which case its Modelfile template must use
  `{{ .Suffix }}` and the model's FIM tokens. Verify FIM support before relying
  on the plugin; Ollama rejects requests for models without it.

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
  ollama = {
    host = "127.0.0.1",
    port = 11434,
    model = "qwen2.5-coder:1.5b",
    context_lines = 40,
    timeout_ms = 15000,
    options = {
      temperature = 0.1,
      num_predict = 128,
    },
  },
})
```

The `ollama` section configures the backend connection:

- `host` and `port` locate the Ollama server. The default port is Ollama's
  `11434`.
- `model` is the model name as shown by `ollama list`. It must support
  fill-in-the-middle completion.
- `context_lines` is how many lines before and after the cursor are sent as
  context.
- `timeout_ms` bounds a request, including connection time.
- `options` is passed through to Ollama's generate API. The defaults keep
  completions short and low-temperature; increase `num_predict` for longer
  suggestions.

The backend sends the text before the cursor as `prompt` and the text after it
as `suffix` to Ollama's `POST /api/generate` endpoint, with streaming disabled.
That combination enables the model's FIM behavior. Failures are reported with
`vim.notify` once per distinct error until a request succeeds.

The trigger modes are:

- `auto`: request a suggestion after typing pauses in insert mode.
- `manual`: request a suggestion only when `trigger.keymap` is pressed.
- `both`: use both the automatic pause and the trigger keymap.

The keymaps are insert-mode mappings. `<Tab>` accepts the visible suggestion
and otherwise behaves like the normal Tab key. `<C-]>` dismisses the suggestion
when one is visible and otherwise falls through. Set `accept_keymap` or
`dismiss_keymap` to `false` to leave that key alone. The `highlight` group is
linked to `Comment` by default.

For example, with `lazy.nvim`, using Ollama on another machine on the local
network:

```lua
{
  "Lemorra/ghostline.nvim",
  opts = {
    trigger = { mode = "both", debounce_ms = 500 },
    ollama = {
      host = "192.168.18.82",
      model = "qwen2.5-coder:1.5b",
    },
  },
}
```

## Usage

In insert mode, type and pause (in `auto`/`both` mode) or press the trigger key
(in `manual`/`both` mode). Ghost text appears after the cursor. For a multi-line
suggestion, the first line appears after the cursor and the remaining lines
appear below the current line. Press `<Tab>` to insert the full suggestion into
the buffer, or `<C-]>` to dismiss it. Leaving insert mode also clears the
suggestion.

The same actions are available programmatically:

```lua
local ghostline = require("ghostline")
ghostline.trigger()
ghostline.accept()
ghostline.dismiss()
ghostline.is_visible()
```

## Current limitations

- Ollama is the only backend. It is used over plain HTTP; HTTPS endpoints are
  not supported.
- The configured model must support Ollama's insert mode. A model without FIM
  support makes every request fail with an `HTTP 400 ... does not support
  insert` notification.
- Responses are non-streaming and only one suggestion is tracked at a time.
  There is no suggestion cycling.
- Context is limited to `context_lines` before and after the cursor. The whole
  buffer and other open files are not sent.

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
