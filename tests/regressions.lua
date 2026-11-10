-- Regression tests for editor-loop integration.
--
-- 1. libuv timer callbacks run as fast events. Calling VimL functions there
--    raises E5560 for the first call and aborts the automatic trigger before
--    any ghost text is shown. Editor work must be deferred with vim.schedule.
-- 2. Insert-mode <expr> mappings are textlocked. Changing buffer text while
--    the expression is evaluated fails ("Failed to save undo information"), so
--    accepting a suggestion must be deferred until after the expression returns.
--
-- These need a real insert-mode session and the main loop, so the stages run
-- from deferred callbacks: `startinsert` only takes effect after the sourcing
-- command returns. The Makefile runs this file in its own Neovim invocation;
-- the final stage quits.

local ghostline = require("ghostline")
local ollama = require("ghostline.ollama")

local PLACEHOLDER = "Waiting for model response"

-- The regression tests exercise the editor loop, not the network. Resolve
-- completion requests synchronously with fixed text.
ollama._set_transport(function(_, callback)
  callback(PLACEHOLDER)
end)

local function finish(message, code)
  if message then
    print(message)
  end
  if code == 0 then
    vim.cmd("qa!")
  else
    vim.cmd("cquit " .. code)
  end
end

local function fail(err)
  finish("ghostline regression tests failed: " .. tostring(err), 1)
end

local function new_buffer(lines, col)
  local buf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_set_current_buf(buf)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.o.virtualedit = "all"
  vim.api.nvim_win_set_cursor(0, { 1, col or #lines[1] })
  return buf
end

local function first_line(buf)
  return vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1]
end

local function messages()
  return vim.api.nvim_exec2("messages", { output = true }).output
end

local buffer
local stages = {}

stages[1] = function()
  assert(vim.fn.mode():sub(1, 1) == "i", "regression tests need insert mode")

  -- Automatic trigger: fire InsertEnter so the debounce timer is scheduled.
  ghostline.setup({ trigger = { mode = "auto", debounce_ms = 10 } })
  buffer = new_buffer({ "local x = " })
  vim.api.nvim_exec_autocmds("InsertEnter", {})
end

stages[2] = function()
  -- E5560 aborts the timer callback, so no suggestion would ever appear.
  assert(
    vim.wait(2000, function()
      return ghostline.is_visible()
    end, 10),
    "automatic trigger did not show ghost text after the debounce"
  )
  assert(not messages():find("E5560"), "a fast-event VimL call was made:\n" .. messages())

  -- Accept: <Tab> is an <expr> mapping, so the insert must be deferred.
  -- Populate the buffer now and let its TextChangedI autocmds settle before
  -- triggering, because those autocmds intentionally clear suggestions.
  ghostline.setup({ trigger = { mode = "manual" } })
  buffer = new_buffer({ "local x = " })
end

stages[3] = function()
  assert(ghostline.trigger(), "manual trigger did not show ghost text")
  assert(ghostline.is_visible(), "manual trigger did not make ghost text visible")
  vim.api.nvim_input("<Tab>")
end

stages[4] = function()
  local line = first_line(buffer)
  assert(
    line == "local x = " .. PLACEHOLDER,
    "accepting with <Tab> did not insert the suggestion: [" .. line .. "]"
  )
  assert(not ghostline.is_visible(), "accepting should clear the ghost text")

  local output = messages()
  assert(not output:find("E5560"), "a fast-event VimL call was made:\n" .. output)
  -- Neovim 0.9 reports the textlock failure this way; newer versions may also
  -- raise a dedicated error, so cover both.
  assert(
    not output:find("Failed to save undo"),
    "accept is not deferred out of the <expr> mapping:\n" .. output
  )
  assert(not output:find("E523"), "accept changed text inside an <expr> mapping:\n" .. output)
end

-- Watchdog so a stuck stage fails CI instead of hanging.
vim.defer_fn(function()
  finish("ghostline regression tests timed out", 1)
end, 15000)

local function run(index)
  if not stages[index] then
    finish("ghostline regression tests passed", 0)
    return
  end
  -- A short delay lets the main loop enter insert mode and process timers,
  -- autocmds, and keys triggered by the previous stage.
  vim.defer_fn(function()
    local ok, err = pcall(stages[index])
    if not ok then
      fail(err)
      return
    end
    run(index + 1)
  end, 100)
end

vim.cmd("startinsert")
run(1)
