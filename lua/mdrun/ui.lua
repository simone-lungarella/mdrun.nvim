local state = require("mdrun.state")
local parser = require("mdrun.parser")

local M = {}

local function is_markdown(bufnr)
  local ft = vim.api.nvim_get_option_value("filetype", { buf = bufnr })
  return ft == "markdown" or ft == "md" or ft == "markdown.mdx"
end

-- Virtual button handling ---------------------------------------------------

function M.update_virtual_button()
  local bufnr = vim.api.nvim_get_current_buf()
  if not is_markdown(bufnr) then
    state.clear_virtual_mark(bufnr)
    return
  end

  local row = vim.api.nvim_win_get_cursor(0)[1]
  local block = parser.find_block(bufnr, row)
  if not block then
    state.clear_virtual_mark(bufnr)
    return
  end

  -- Place indicator on opening fence line, at column 0.
  state.clear_virtual_mark(bufnr)

  local text = "▶ Run"
  local id = vim.api.nvim_buf_set_extmark(bufnr, state.ns, block.start_lnum - 1, 0, {
    virt_text = { { text, "Comment" } },
    virt_text_pos = "eol",
  })

  state.set_virtual_mark(id)
end

-- Floating output window ----------------------------------------------------

local function ensure_output_buf()
  if state.output_buf and vim.api.nvim_buf_is_valid(state.output_buf) then
    return state.output_buf
  end
  local buf = vim.api.nvim_create_buf(false, true) -- scratch, listed=false
  vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(buf, "bufhidden", "hide")
  vim.api.nvim_buf_set_option(buf, "swapfile", false)
  vim.api.nvim_buf_set_option(buf, "modifiable", false)
  vim.api.nvim_buf_set_option(buf, "filetype", "mdrun-output")

  -- q to close window
  vim.keymap.set("n", "q", function()
    if state.output_win and vim.api.nvim_win_is_valid(state.output_win) then
      vim.api.nvim_win_close(state.output_win, true)
      state.output_win = nil
    end
  end, { buffer = buf, nowait = true, silent = true })

  state.output_buf = buf
  return buf
end

local function open_output_win()
  local buf = ensure_output_buf()

  -- Reuse window if still valid.
  if state.output_win and vim.api.nvim_win_is_valid(state.output_win) then
    return buf, state.output_win
  end

  local columns = vim.o.columns
  local lines = vim.o.lines - vim.o.cmdheight

  local max_w = math.floor(columns * 0.8)
  local max_h = math.floor(lines * 0.8)

  local width = math.min(120, max_w)
  local height = math.min(40, max_h)

  width = math.max(width, 20)
  height = math.max(height, 5)

  local row = math.floor((lines - height) / 2)
  local col = math.floor((columns - width) / 2)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    row = row,
    col = col,
    width = width,
    height = height,
    style = "minimal",
    border = "rounded",
  })

  state.output_win = win
  return buf, win
end

function M.render_result(result)
  if not result then
    return
  end

  local buf, _ = open_output_win()

  vim.api.nvim_buf_set_option(buf, "modifiable", true)

  local lines = result.lines or {}
  if #lines == 0 then
    lines = { "" }
  end
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  vim.api.nvim_buf_set_option(buf, "modifiable", false)

  -- Set window title via winbar if available, fall back to statusline component.
  if vim.fn.has("nvim-0.8") == 1 then
    pcall(vim.api.nvim_set_option_value, "winbar", " " .. result.title, { win = state.output_win })
  else
    pcall(vim.api.nvim_set_option_value, "statusline", " " .. result.title, { win = state.output_win })
  end
end

function M.show_last()
  local last = state.get_last_result()
  if not last then
    vim.notify("mdrun: no previous result", vim.log.levels.INFO)
    return
  end
  M.render_result(last)
end

return M
