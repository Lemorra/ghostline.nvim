.PHONY: test lint format format-check check

test:
	nvim --headless --clean -u tests/minimal_init.lua -c "luafile tests/smoke.lua" -c "luafile tests/mvp.lua" -c "qa!"
	@# Runs its own insert-mode session and quits itself, so no trailing qa!.
	nvim --headless --clean -u tests/minimal_init.lua -c "luafile tests/regressions.lua"

lint:
	luacheck lua tests

format:
	stylua lua tests

format-check:
	stylua --check lua tests

check: format-check lint test
