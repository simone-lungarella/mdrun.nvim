local M = {}

-- Simple in-memory state. No persistence.

M.last_result = nil -- { title = string, lines = {string} }

M.ns = vim.api.nvim_create_namespace("mdrun")

M.output_buf = nil
M.output_win = nil

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

return M
