---@mod ghostline
---@brief [[
--- ghostline.nvim public Lua API.
---
--- Shows GitHub Copilot-style ghost text after a pause or a manual trigger.
---@brief ]]

local ollama = require("ghostline.ollama")
local suggestion = require("ghostline.suggestion")

local uv = vim.uv or vim.loop

local M = {}

local defaults = {
  enabled = true,
  trigger = {
    mode = "auto", -- "auto", "manual", or "both"
    keymap = "<M-\\>",
    debounce_ms = 400,
  },
  accept_keymap = "<Tab>",
  dismiss_keymap = "<C-]>",
  highlight = "GhostlineText",
}

local config = vim.deepcopy(defaults)
local timer = nil
local mapped_keys = {}

local function stop_timer()
  if timer then
    timer:stop()
    if not timer:is_closing() then
      timer:close()
    end
    timer = nil
  end
end

local function clear_keymaps()
  for _, lhs in ipairs(mapped_keys) do
    pcall(vim.keymap.del, "i", lhs)
  end
  mapped_keys = {}
end

local function set_insert_keymap(lhs, callback)
  vim.keymap.set("i", lhs, callback, {
    expr = true,
    replace_keycodes = true,
    desc = "ghostline.nvim",
  })
  table.insert(mapped_keys, lhs)
end

local function schedule_trigger()
  stop_timer()
  if not config.enabled or (config.trigger.mode ~= "auto" and config.trigger.mode ~= "both") then
    return
  end

  timer = uv.new_timer()
  timer:start(config.trigger.debounce_ms, 0, function()
    stop_timer()
    if vim.fn.mode():sub(1, 1) ~= "i" then
      return
    end
    vim.schedule(function()
      if config.enabled and vim.fn.mode():sub(1, 1) == "i" then
        M.trigger()
      end
    end)
  end)
end

local function validate(opts)
  local valid_modes = { auto = true, manual = true, both = true }
  assert(
    valid_modes[opts.trigger.mode],
    "ghostline: trigger.mode must be 'auto', 'manual', or 'both'"
  )
  assert(
    type(opts.trigger.debounce_ms) == "number" and opts.trigger.debounce_ms >= 0,
    "ghostline: trigger.debounce_ms must be a non-negative number"
  )
  assert(type(opts.trigger.keymap) == "string", "ghostline: trigger.keymap must be a string")
  assert(
    opts.accept_keymap == false or type(opts.accept_keymap) == "string",
    "ghostline: accept_keymap must be a string or false"
  )
  assert(
    opts.dismiss_keymap == false or type(opts.dismiss_keymap) == "string",
    "ghostline: dismiss_keymap must be a string or false"
  )
  assert(type(opts.highlight) == "string", "ghostline: highlight must be a string")
end

local function setup_keymaps()
  if config.accept_keymap then
    set_insert_keymap(config.accept_keymap, function()
      if M.accept() then
        return ""
      end
      return config.accept_keymap
    end)
  end

  if config.dismiss_keymap then
    set_insert_keymap(config.dismiss_keymap, function()
      if M.dismiss() then
        return ""
      end
      return config.dismiss_keymap
    end)
  end

  if config.trigger.mode == "manual" or config.trigger.mode == "both" then
    vim.keymap.set("i", config.trigger.keymap, function()
      M.trigger()
    end, { desc = "ghostline.nvim: trigger suggestion" })
    table.insert(mapped_keys, config.trigger.keymap)
  end
end

local function setup_autocmds(group)
  vim.api.nvim_create_autocmd("InsertEnter", {
    group = group,
    callback = function()
      suggestion.clear()
      schedule_trigger()
    end,
  })

  vim.api.nvim_create_autocmd("TextChangedI", {
    group = group,
    callback = function()
      suggestion.clear()
      schedule_trigger()
    end,
  })

  vim.api.nvim_create_autocmd("CursorMovedI", {
    group = group,
    callback = function()
      if suggestion.is_stale() then
        suggestion.clear()
      end
    end,
  })

  vim.api.nvim_create_autocmd({ "InsertLeave", "BufLeave" }, {
    group = group,
    callback = function()
      stop_timer()
      suggestion.clear()
    end,
  })
end

---Initialize ghostline.nvim.
---
---@param opts? table Configuration overrides.
function M.setup(opts)
  assert(opts == nil or type(opts) == "table", "ghostline.setup expects a table")

  config = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})
  validate(config)

  stop_timer()
  suggestion.clear()
  clear_keymaps()

  vim.api.nvim_set_hl(0, config.highlight, { default = true, link = "Comment" })

  local group = vim.api.nvim_create_augroup("Ghostline", { clear = true })
  if not config.enabled then
    return
  end

  setup_keymaps()
  setup_autocmds(group)
end

---Request a suggestion at the cursor and render it as ghost text.
---@return boolean True when ghost text was displayed.
function M.trigger()
  if not config.enabled then
    return false
  end

  local buf = vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(buf) or not vim.bo[buf].modifiable then
    return false
  end
  local buftype = vim.bo[buf].buftype
  if buftype ~= "" and buftype ~= "acwrite" then
    return false
  end

  local cursor = vim.api.nvim_win_get_cursor(0)
  local row = cursor[1] - 1
  local col = cursor[2]

  suggestion.clear()

  local function show(text)
    if vim.in_fast_event() then
      vim.schedule(function()
        show(text)
      end)
      return
    end
    if not config.enabled or type(text) ~= "string" or text == "" then
      return
    end
    if vim.api.nvim_get_current_buf() ~= buf then
      return
    end
    local current = vim.api.nvim_win_get_cursor(0)
    if current[1] - 1 ~= row or current[2] ~= col then
      return
    end
    suggestion.show(buf, row, col, text, config.highlight)
  end

  ollama.complete({
    buf = buf,
    row = row,
    col = col,
    line = vim.api.nvim_get_current_line(),
    filetype = vim.bo[buf].filetype,
  }, show)

  return suggestion.is_visible()
end

---Accept the visible suggestion by inserting it at the cursor.
---@return boolean True when text was inserted.
function M.accept()
  return suggestion.accept()
end

---Dismiss the visible suggestion.
---@return boolean True when a suggestion was dismissed.
function M.dismiss()
  return suggestion.dismiss()
end

---@return boolean
function M.is_visible()
  return suggestion.is_visible()
end

return M
