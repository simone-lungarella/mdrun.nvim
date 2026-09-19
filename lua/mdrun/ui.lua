local state = require("mdrun.state")
local parser = require("mdrun.parser")

local M = {}

local function is_markdown(bufnr)
  local ft = vim.api.nvim_get_option_value("filetype", { buf = bufnr })
  return ft == "markdown" or ft == "md" or ft == "markdown.mdx"
end

local function run_label()
  -- Prefer the nicer symbol when running with UTF-8 encoding, otherwise
  -- fall back to a plain ASCII label that works everywhere.
  local enc = (vim.o.encoding or ""):lower()
  if enc == "utf-8" or enc == "utf8" then
    return "▶ Run"
  end
  return "> Run"
end

-- Virtual button handling ---------------------------------------------------

-- Scan the buffer and place a virtual "Run" indicator on every bash/sh block.
-- If active_start_lnum is provided, that block gets a hover-style indicator.
function M.refresh_virtual_buttons(bufnr, active_start_lnum)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not is_markdown(bufnr) then
    state.clear_virtual_marks(bufnr)
    return
  end

  state.clear_virtual_marks(bufnr)

  local blocks = state.get_blocks(bufnr)
  if not blocks or #blocks == 0 then
    blocks = parser.find_all_blocks(bufnr)
    state.set_blocks(bufnr, blocks)
  end
  if not blocks or #blocks == 0 then
    state.debug("ui: no runnable blocks found for virtual buttons")
    return
  end

  local text = run_label()
  state.debug("ui: placing Run indicators for " .. tostring(#blocks) .. " blocks")
  for _, block in ipairs(blocks) do
    local virt_line
    if active_start_lnum and block.start_lnum == active_start_lnum then
      virt_line = { { text, "Underlined" } }
    else
      virt_line = { { text, "Comment" } }
    end
    -- Place the label as a virtual line directly above the fenced block.
    vim.api.nvim_buf_set_extmark(bufnr, state.ns, block.start_lnum - 1, 0, {
      virt_lines = { virt_line },
      virt_lines_above = true,
    })
  end
end

-- Update hover indicator when the cursor (keyboard or mouse) moves.
function M.update_hover(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not is_markdown(bufnr) then
    return
  end

  local row = vim.api.nvim_win_get_cursor(0)[1]

  -- Determine the active block based on cursor position.
  -- We treat the block as active when the cursor is either:
  --   - on the opening fence line (hover over the Run label), or
  --   - inside the block body.
  local blocks = state.get_blocks(bufnr)
  if not blocks or #blocks == 0 then
    blocks = parser.find_all_blocks(bufnr)
    state.set_blocks(bufnr, blocks)
  end

  local active_start
  for _, block in ipairs(blocks or {}) do
    if row == block.start_lnum or (row > block.start_lnum and row < block.end_lnum) then
      active_start = block.start_lnum
      break
    end
  end

  M.refresh_virtual_buttons(bufnr, active_start)
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

  -- Bottom-aligned panel that doesn't cover too much of the markdown.
  -- Still respect the design doc's "maximum 80%" guideline vertically.
  local max_w = columns
  local max_h = math.floor(lines * 0.4)

  local width = math.min(columns, max_w)
  local height = math.min(24, max_h)

  width = math.max(width, 20)
  height = math.max(height, 5)

  -- Attach the window to the bottom so the snippet remains visible above.
  local row = lines - height
  local col = math.floor((columns - width) / 2)

  state.debug(string.format("ui: opening output window w=%d h=%d row=%d col=%d", width, height, row, col))

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
