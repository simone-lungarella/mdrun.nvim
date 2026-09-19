local state = require("mdrun.state")
local parser = require("mdrun.parser")

local M = {}

local function run_script(script, cb)
  -- Use vim.system to execute bash with strict flags.
  vim.system({
    "bash",
    "-euo",
    "pipefail",
    "-c",
    script,
  }, { text = true }, function(result)
    -- Normalize into simple lines and status.
    local code = result.code or 0
    local ok = code == 0
    local combined
    if result.stderr and result.stderr ~= "" then
      if result.stdout and result.stdout ~= "" then
        combined = result.stdout .. "\n" .. result.stderr
      else
        combined = result.stderr
      end
    else
      combined = result.stdout or ""
    end

    local lines = {}
    for line in (combined .. "\n"):gmatch("(.-)\n") do
      table.insert(lines, line)
    end

    local title
    if ok then
      title = "✓ Exit " .. tostring(code)
    else
      title = "✗ Exit " .. tostring(code)
    end

    local res = { ok = ok, code = code, title = title, lines = lines }
    state.set_last_result(res)

    if cb then
      cb(res)
    end
  end)
end

function M.run_current(bufnr, cursor_lnum, cb)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local block = parser.find_block(bufnr, cursor_lnum)
  if not block then
    return nil, "No bash block under cursor"
  end
  local script = parser.extract_body(bufnr, block)
  if not script or script == "" then
    return nil, "Block is empty"
  end

  -- Immediate running status result for UI.
  state.set_last_result({
    ok = false,
    code = nil,
    title = "⟳ Running...",
    lines = {},
  })

  run_script(script, cb)
  return true
end

return M
