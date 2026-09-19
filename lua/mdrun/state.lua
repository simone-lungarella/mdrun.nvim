local M = {}

-- Simple in-memory state. No persistence.

M.last_result = nil -- { title = string, lines = {string} }

M.ns = vim.api.nvim_create_namespace("mdrun")
M.virtual_mark = nil -- extmark id for virtual button

M.output_buf = nil
M.output_win = nil

function M.set_last_result(result)
  M.last_result = result
end

function M.get_last_result()
  return M.last_result
end

function M.clear_virtual_mark(bufnr)
  if M.virtual_mark ~= nil then
    pcall(vim.api.nvim_buf_del_extmark, bufnr, M.ns, M.virtual_mark)
    M.virtual_mark = nil
  end
end

function M.set_virtual_mark(id)
  M.virtual_mark = id
end

return M
