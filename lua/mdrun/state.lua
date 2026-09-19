local M = {}

-- Simple in-memory state. No persistence.

M.last_result = nil -- { title = string, lines = {string} }

M.ns = vim.api.nvim_create_namespace("mdrun")

M.output_buf = nil
M.output_win = nil

-- Cached block positions per buffer so we can cheaply refresh virtual
-- indicators and hover state without rescanning the whole buffer on every
-- cursor move.
M.blocks_by_buf = {}

function M.set_last_result(result)
  M.last_result = result
end

function M.get_last_result()
  return M.last_result
end

function M.clear_virtual_marks(bufnr)
  -- Clear all extmarks for this plugin in the given buffer.
  if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_clear_namespace(bufnr, M.ns, 0, -1)
  end
end

function M.set_blocks(bufnr, blocks)
  M.blocks_by_buf[bufnr] = blocks or {}
end

function M.get_blocks(bufnr)
  return M.blocks_by_buf[bufnr] or {}
end

function M.debug(msg)
  if not vim.g.mdrun_debug then
    return
  end
  local level = vim.log and vim.log.levels and vim.log.levels.DEBUG or vim.log.levels.INFO
  vim.notify("mdrun: " .. msg, level)
end

return M
