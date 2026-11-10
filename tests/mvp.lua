local ghostline = require("ghostline")
local ollama = require("ghostline.ollama")

local function new_buffer(lines, cursor_col)
  local buf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_set_current_buf(buf)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  -- Allow the normal-mode test cursor to sit after the last character, as it
  -- would in insert mode.
  vim.wo.virtualedit = "all"
  vim.api.nvim_win_set_cursor(0, { 1, cursor_col or #lines[1] })
  return buf
end

local function first_line(buf)
  return vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1]
end

local captured
ollama._set_transport(function(payload, callback)
  captured = payload
  callback("Waiting for model response")
end)

ghostline.setup({
  trigger = { mode = "manual" },
  ollama = {
    model = "test-model",
    context_lines = 5,
    options = { num_predict = 16 },
  },
})

local payload = ollama.build_payload({ prefix = "local x = ", suffix = "\nend" })
assert(payload.model == "test-model", "build_payload should use the configured model")
assert(payload.prompt == "local x = ", "build_payload should send the prefix as prompt")
assert(payload.suffix == "\nend", "build_payload should send the suffix for FIM")
assert(payload.stream == false, "build_payload should request a non-streaming response")
assert(payload.options.num_predict == 16, "build_payload should forward options")
assert(payload.options.temperature == 0.1, "default options should be preserved")

assert(not pcall(ollama.setup, { port = 0 }), "invalid ports should be rejected")
assert(not pcall(ollama.setup, { model = "" }), "empty models should be rejected")
assert(not pcall(ollama.setup, { timeout_ms = 0 }), "non-positive timeouts should be rejected")

local buf = new_buffer({ "local x = " }, 10)
assert(ghostline.trigger(), "trigger should start a suggestion request")
assert(ghostline.is_visible(), "trigger should make ghost text visible")
assert(first_line(buf) == "local x = ", "ghost text should not modify the buffer before accepting")
assert(captured.prompt == "local x = ", "trigger should send the text before the cursor")
assert(captured.suffix == "", "trigger should send the text after the cursor")
assert(ghostline.accept(), "accept should insert the visible suggestion")
assert(
  first_line(buf) == "local x = Waiting for model response",
  "accept should insert the ghost text"
)
assert(not ghostline.is_visible(), "accept should clear the ghost text")
local cursor = vim.api.nvim_win_get_cursor(0)
assert(
  cursor[1] == 1 and cursor[2] == #"local x = Waiting for model response",
  "cursor should follow accepted text"
)

buf = new_buffer({ "before", "local x = ", "after" }, 10)
vim.api.nvim_win_set_cursor(0, { 2, 10 })
assert(ghostline.trigger(), "trigger should start a suggestion request")
assert(captured.prompt == "before\nlocal x = ", "trigger should include preceding context")
assert(captured.suffix == "\nafter", "trigger should include following context")
assert(ghostline.dismiss(), "dismiss should clear a visible suggestion")
assert(not ghostline.is_visible(), "dismiss should hide the ghost text")
assert(first_line(buf) == "before", "dismiss should leave the buffer unchanged")

buf = new_buffer({ "abc" }, 3)
assert(ghostline.trigger(), "trigger should start a suggestion request")
vim.api.nvim_win_set_cursor(0, { 1, 1 })
assert(not ghostline.accept(), "accept should reject a stale suggestion")
assert(first_line(buf) == "abc", "a stale suggestion should not modify the buffer")
assert(not ghostline.is_visible(), "a stale suggestion should be cleared")

buf = vim.api.nvim_create_buf(false, true)
vim.api.nvim_set_current_buf(buf)
vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "" })
vim.api.nvim_win_set_cursor(0, { 1, 0 })
assert(not ghostline.trigger(), "trigger should ignore special buffers")

assert(
  not pcall(ghostline.setup, { trigger = { mode = "sometimes" } }),
  "invalid trigger modes should be rejected"
)
assert(
  not pcall(ghostline.setup, { trigger = { debounce_ms = -1 } }),
  "negative debounce values should be rejected"
)

ghostline.setup({})
print("ghostline mvp tests passed")
