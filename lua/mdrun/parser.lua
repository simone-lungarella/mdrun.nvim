local M = {}

-- Detect fenced bash/sh block around cursor using simple line scanning.

local function is_fence(line)
  if not line then
    return false
  end
  -- match ```bash or ```sh with optional trailing whitespace
  local lang = line:match("^```%s*(%w+)%s*$")
  if lang == "bash" or lang == "sh" then
    return lang
  end
  return nil
end

local function is_closing_fence(line)
  if not line then
    return false
  end
  return line:match("^```%s*$") ~= nil
end

-- Returns block info or nil.
-- { lang, start_lnum, end_lnum, body_start, body_end }
function M.find_block(bufnr, cursor_lnum)
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  if cursor_lnum < 1 or cursor_lnum > line_count then
    return nil
  end

  -- 1. Search upwards for opening fence
  local open_lnum = nil
  local lang = nil
  for lnum = cursor_lnum, 1, -1 do
    local line = vim.api.nvim_buf_get_lines(bufnr, lnum - 1, lnum, false)[1]
    local detected = is_fence(line)
    if detected then
      open_lnum = lnum
      lang = detected
      break
    end
    -- stop if we hit another generic fence that isn't bash/sh
    if line and line:match("^```") and not detected then
      return nil
    end
  end

  if not open_lnum then
    return nil
  end

  -- 2. Search downwards for closing fence
  local close_lnum = nil
  for lnum = open_lnum + 1, line_count do
    local line = vim.api.nvim_buf_get_lines(bufnr, lnum - 1, lnum, false)[1]
    if is_closing_fence(line) then
      close_lnum = lnum
      break
    end
  end

  if not close_lnum then
    return nil
  end

  -- Ensure cursor is within body
  if cursor_lnum <= open_lnum or cursor_lnum >= close_lnum then
    return nil
  end

  return {
    lang = lang,
    start_lnum = open_lnum,
    end_lnum = close_lnum,
    body_start = open_lnum + 1,
    body_end = close_lnum - 1,
  }
end

-- Find all bash/sh fenced blocks in the buffer.
-- Returns an array of block tables like find_block.
function M.find_all_blocks(bufnr)
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  local blocks = {}

  local lnum = 1
  while lnum <= line_count do
    local line = vim.api.nvim_buf_get_lines(bufnr, lnum - 1, lnum, false)[1]
    local lang = is_fence(line)
    if lang then
      local start_lnum = lnum
      local close_lnum = nil
      for j = lnum + 1, line_count do
        local l = vim.api.nvim_buf_get_lines(bufnr, j - 1, j, false)[1]
        if is_closing_fence(l) then
          close_lnum = j
          break
        end
      end
      if not close_lnum then
        break
      end
      table.insert(blocks, {
        lang = lang,
        start_lnum = start_lnum,
        end_lnum = close_lnum,
        body_start = start_lnum + 1,
        body_end = close_lnum - 1,
      })
      lnum = close_lnum + 1
    else
      lnum = lnum + 1
    end
  end

  return blocks
end

function M.extract_body(bufnr, block)
  if not block then
    return nil
  end
  if block.body_start > block.body_end then
    return ""
  end
  local lines = vim.api.nvim_buf_get_lines(bufnr, block.body_start - 1, block.body_end, false)
  return table.concat(lines, "\n")
end

return M
