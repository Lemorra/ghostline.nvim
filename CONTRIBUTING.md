# Contributing

Thanks for helping develop ghostline.nvim. The project is at an early MVP
stage, so proposals that establish a clear and maintainable direction are
welcome. Please avoid presenting unimplemented behavior as available.

## Development setup

Install Neovim 0.9 or newer, Lua/LuaJIT, [StyLua](https://github.com/JohnnyMorganz/StyLua),
and [Luacheck](https://github.com/lunarmodules/luacheck). From the repository
root, run:

```sh
make check
```

Individual checks are available as `make test`, `make lint`, and
`make format-check`; use `make format` to apply formatting.

## Pull requests

- Keep changes focused and explain the user-facing motivation.
- Add or update tests and documentation when behavior changes.
- Run `make check` before opening a pull request.
- Do not commit credentials, tokens, or generated artifacts.

## Reporting issues

Use the issue templates and include your Neovim version, reproduction steps,
and relevant error output. Never include API keys or other secrets.
