.PHONY: test lint format format-check check

test:
	nvim --headless --clean -u tests/minimal_init.lua -c "luafile tests/smoke.lua" -c "qa!"

lint:
	luacheck lua tests

format:
	stylua lua tests

format-check:
	stylua --check lua tests

check: format-check lint test
