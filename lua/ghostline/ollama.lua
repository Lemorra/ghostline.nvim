---@mod ghostline.ollama
---@brief [[
--- Ollama completion backend.
---
--- Requests are sent to Ollama's `POST /api/generate` endpoint with a
--- non-streaming response. The text before the cursor is sent as `prompt` and
--- the text after the cursor as `suffix`, which enables fill-in-the-middle
--- completion for models that support Ollama's insert mode.
---@brief ]]

local uv = vim.uv or vim.loop

local M = {}

---Default backend configuration.
---@type table
M.defaults = {
  host = "127.0.0.1",
  port = 11434,
  model = "qwen2.5-coder:1.5b",
  context_lines = 40,
  timeout_ms = 15000,
  options = {
    temperature = 0.1,
    num_predict = 128,
  },
}

local config = vim.deepcopy(M.defaults)

-- The transport is replaceable so tests can run without a server. It receives
-- the generate payload and calls back with (text, err).
local transport = nil

local last_error = nil

local function report_error(err)
  if err == last_error then
    return
  end

  if vim.in_fast_event() then
    vim.schedule(function()
      report_error(err)
    end)
    return
  end

  last_error = err
  vim.notify("ghostline: " .. err, vim.log.levels.WARN)
end

local function validate(opts)
  assert(type(opts) == "table", "ghostline: ollama options must be a table")
  assert(
    type(opts.host) == "string" and opts.host ~= "",
    "ghostline: ollama.host must be a non-empty string"
  )
  assert(
    type(opts.port) == "number" and opts.port % 1 == 0 and opts.port >= 1 and opts.port <= 65535,
    "ghostline: ollama.port must be an integer between 1 and 65535"
  )
  assert(
    type(opts.model) == "string" and opts.model ~= "",
    "ghostline: ollama.model must be a non-empty string"
  )
  assert(
    type(opts.context_lines) == "number" and opts.context_lines % 1 == 0 and opts.context_lines >= 0,
    "ghostline: ollama.context_lines must be a non-negative integer"
  )
  assert(
    type(opts.timeout_ms) == "number" and opts.timeout_ms > 0,
    "ghostline: ollama.timeout_ms must be a positive number"
  )
  assert(type(opts.options) == "table", "ghostline: ollama.options must be a table")
end

---Configure the backend. Called by `ghostline.setup`.
---@param opts? table Backend configuration overrides.
function M.setup(opts)
  local next_config = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
  validate(next_config)
  config = next_config
end

---Build the Ollama generate payload for a request context.
---@param ctx table With `prefix` and `suffix` strings around the cursor.
---@return table
function M.build_payload(ctx)
  ctx = ctx or {}
  return {
    model = config.model,
    prompt = ctx.prefix or "",
    suffix = ctx.suffix or "",
    stream = false,
    options = vim.deepcopy(config.options),
  }
end

local function decode_chunked(body)
  local parts = {}
  local pos = 1
  while pos <= #body do
    local line_end = body:find("\r\n", pos, true)
    if not line_end then
      break
    end

    local size = tonumber(body:sub(pos, line_end - 1), 16)
    if not size or size == 0 then
      break
    end

    local data_start = line_end + 2
    parts[#parts + 1] = body:sub(data_start, data_start + size - 1)
    pos = data_start + size + 2
  end
  return table.concat(parts)
end

---Parse an HTTP/1.1 response and extract the Ollama completion text.
---@param raw string
---@return string? text
---@return string? err
local function parse_response(raw)
  local header_end = raw:find("\r\n\r\n", 1, true)
  local separator_length = 4
  if not header_end then
    header_end = raw:find("\n\n", 1, true)
    separator_length = 2
  end
  if not header_end then
    return nil, "malformed HTTP response"
  end

  local head = raw:sub(1, header_end - 1)
  local body = raw:sub(header_end + separator_length)
  local status = head:match("^HTTP/%d%.%d%s+(%d+)")

  local headers = {}
  for line in head:gmatch("[^\r\n]+") do
    local name, value = line:match("^([^:]+):%s*(.*)$")
    if name then
      headers[name:lower()] = value
    end
  end

  local transfer_encoding = headers["transfer-encoding"]
  if transfer_encoding and transfer_encoding:lower():find("chunked", 1, true) then
    body = decode_chunked(body)
  end

  local ok, data = pcall(vim.json.decode, body)
  if not ok or type(data) ~= "table" then
    if status and status ~= "200" then
      return nil, "HTTP " .. status .. ": " .. body
    end
    return nil, "invalid JSON response from Ollama"
  end

  if status ~= "200" then
    return nil, "HTTP " .. tostring(status) .. ": " .. tostring(data.error or body)
  end
  if data.error then
    return nil, tostring(data.error)
  end
  if type(data.response) ~= "string" then
    return nil, "Ollama response did not contain completion text"
  end

  return data.response
end

local function request(payload, callback)
  local host = config.host
  local port = config.port
  local timeout_ms = config.timeout_ms
  local body = vim.json.encode(payload)

  local host_header = host
  if host_header:find(":", 1, true) then
    host_header = "[" .. host_header .. "]"
  end
  host_header = host_header .. ":" .. port

  local raw_request = table.concat({
    "POST /api/generate HTTP/1.1",
    "Host: " .. host_header,
    "Content-Type: application/json",
    "Content-Length: " .. #body,
    "Connection: close",
    "",
    body,
  }, "\r\n")

  local ok, resolve_err = pcall(uv.getaddrinfo, host, tostring(port), {}, function(err, addresses)
    if err or not addresses or not addresses[1] then
      callback(nil, "could not resolve " .. host .. ": " .. tostring(err))
      return
    end

    local address = addresses[1]
    for _, candidate in ipairs(addresses) do
      if candidate.socktype == "stream" then
        address = candidate
        break
      end
    end

    local tcp = uv.new_tcp()
    local timer = uv.new_timer()
    local done = false

    local function finish(text, finish_err)
      if done then
        return
      end
      done = true
      if timer and not timer:is_closing() then
        timer:stop()
        timer:close()
      end
      if tcp and not tcp:is_closing() then
        tcp:close()
      end
      callback(text, finish_err)
    end

    timer:start(timeout_ms, 0, function()
      finish(nil, "request timed out after " .. timeout_ms .. "ms")
    end)

    local connect_ok, connect_err = tcp:connect(address.addr, tonumber(address.port), function(err2)
      if err2 then
        finish(nil, "could not connect to " .. host .. ":" .. port .. ": " .. err2)
        return
      end

      local chunks = {}
      local read_ok, read_err = tcp:read_start(function(err3, data)
        if err3 then
          finish(nil, "could not read Ollama response: " .. err3)
          return
        end
        if data then
          chunks[#chunks + 1] = data
          return
        end

        local text, parse_err = parse_response(table.concat(chunks))
        finish(text, parse_err)
      end)
      if not read_ok then
        finish(nil, "could not read Ollama response: " .. tostring(read_err))
        return
      end

      local write_ok, write_err = tcp:write(raw_request, function(err4)
        if err4 then
          finish(nil, "could not send Ollama request: " .. err4)
        end
      end)
      if not write_ok then
        finish(nil, "could not send Ollama request: " .. tostring(write_err))
      end
    end)
    if not connect_ok then
      finish(nil, "could not connect to " .. host .. ":" .. port .. ": " .. tostring(connect_err))
    end
  end)
  if not ok then
    callback(nil, "could not resolve " .. host .. ": " .. tostring(resolve_err))
  end
end

---Request a completion.
---
---The callback receives an empty string when the request fails. Errors are
---reported with `vim.notify` once until a later request succeeds.
---
---@param ctx table With `prefix` and `suffix` strings around the cursor.
---@param callback fun(text: string)
function M.complete(ctx, callback)
  assert(type(callback) == "function", "ghostline: complete requires a callback")

  local payload = M.build_payload(ctx or {})
  local function done(text, err)
    if err then
      report_error(err)
      callback("")
      return
    end
    last_error = nil
    callback(text or "")
  end

  if transport then
    transport(payload, done)
  else
    request(payload, done)
  end
end

---Replace the HTTP transport. Intended for tests.
---@param fn? fun(payload: table, callback: fun(text: string?, err: string?))
function M._set_transport(fn)
  transport = fn
end

return M
