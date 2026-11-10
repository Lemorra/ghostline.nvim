---@mod ghostline.ollama
---@brief [[
--- Placeholder Ollama backend.
---
--- The real HTTP integration is not implemented yet. Every request completes
--- with a fixed placeholder so the editor flow can be tried end to end.
---@brief ]]

local M = {}

local PLACEHOLDER = "Waiting for model response"

---Request a completion.
---
---@param _ table Request context (reserved for the Ollama integration).
---@param callback fun(text: string)
function M.complete(_, callback)
  callback(PLACEHOLDER)
end

return M
