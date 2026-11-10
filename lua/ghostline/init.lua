---@mod ghostline
---@brief [[
--- ghostline.nvim public Lua API.
--- This module is an initial scaffold; completion functionality is not yet
--- implemented.
---@brief ]]

local M = {}

---Initialize ghostline.nvim.
---
---@param opts? table Reserved for future configuration options.
function M.setup(opts)
  assert(opts == nil or type(opts) == "table", "ghostline.setup expects a table")
end

return M
