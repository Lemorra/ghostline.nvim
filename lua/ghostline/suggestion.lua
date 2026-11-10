---@mod ghostline.suggestion
---@brief [[
--- Tracks and renders the current inline suggestion.
---@brief ]]

local M = {}

local namespace = vim.api.nvim_create_namespace("ghostline")

local state = {
  buf = nil,
  row = nil,
  col = nil,
  text = nil,
  extmark = nil,
}

local function delete_extmark()
  if state.buf and state.extmark and vim.api.nvim_buf_is_valid(state.buf) then
    pcall(vim.api.nvim_buf_del_extmark, state.buf, namespace, state.extmark)
  end
  state.extmark = nil
end

---Remove the active suggestion, if any.
function M.clear()
  delete_extmark()
  state.buf = nil
  state.row = nil
  state.col = nil
  state.text = nil
end

---@return boolean
function M.is_visible()
  return state.buf ~= nil
end

---Whether the cursor has moved away from an active suggestion's anchor.
---@return boolean
function M.is_stale()
  if not state.buf then
    return false
  end
  if vim.api.nvim_get_current_buf() ~= state.buf then
    return true
  end
  local cursor = vim.api.nvim_win_get_cursor(0)
  return cursor[1] - 1 ~= state.row or cursor[2] ~= state.col
end

---Render ghost text at a buffer position.
---@param buf integer
---@param row integer Zero-based row.
---@param col integer Zero-based byte column.
---@param text string
---@param highlight string
---@return boolean
function M.show(buf, row, col, text, highlight)
  M.clear()
  if not vim.api.nvim_buf_is_valid(buf) then
    return false
  end

  -- Virtual text cannot contain newlines; Neovim renders them as `^@`.
  -- Show the first line after the cursor and the remaining lines below it.
  local lines = vim.split(text, "\n", { plain = true })
  local opts = {
    virt_text = { { lines[1], highlight } },
    virt_text_pos = "inline",
    hl_mode = "combine",
  }
  if #lines > 1 then
    local virt_lines = {}
    for i = 2, #lines do
      virt_lines[#virt_lines + 1] = { { lines[i], highlight } }
    end
    opts.virt_lines = virt_lines
  end

  local ok, extmark = pcall(vim.api.nvim_buf_set_extmark, buf, namespace, row, col, opts)
  if not ok then
    -- Neovim 0.9 does not support inline virtual text.
    opts.virt_text_pos = "eol"
    ok, extmark = pcall(vim.api.nvim_buf_set_extmark, buf, namespace, row, col, opts)
  end
  if not ok then
    return false
  end

  state.buf = buf
  state.row = row
  state.col = col
  state.text = text
  state.extmark = extmark
  return true
end

---Insert the active suggestion at its anchor and clear it.
---Returns false when there is no suggestion or the cursor has moved.
---@return boolean
function M.accept()
  if not state.buf then
    return false
  end
  if M.is_stale() then
    M.clear()
    return false
  end

  local buf = state.buf
  local row = state.row
  local col = state.col
  local lines = vim.split(state.text, "\n", { plain = true })
  M.clear()

  vim.api.nvim_buf_set_text(buf, row, col, row, col, lines)

  local last_line = lines[#lines]
  local cursor_row = row + #lines - 1
  local cursor_col = #lines == 1 and col + #last_line or #last_line
  vim.api.nvim_win_set_cursor(0, { cursor_row + 1, cursor_col })
  return true
end

---Clear the active suggestion.
---@return boolean True when a suggestion was dismissed.
function M.dismiss()
  if not state.buf then
    return false
  end
  M.clear()
  return true
end

return M
