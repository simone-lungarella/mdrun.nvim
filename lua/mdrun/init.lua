local parser = require("mdrun.parser")
local runner = require("mdrun.runner")
local ui = require("mdrun.ui")

local M = {}

local state = require("mdrun.state")

local function setup_autocmds()
  local group = vim.api.nvim_create_augroup("mdrun", { clear = true })

  -- Refresh virtual Run markers whenever a markdown buffer is shown or written.
  vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter", "BufWritePost" }, {
    group = group,
    callback = function(args)
      ui.refresh_virtual_buttons(args.buf)
    end,
  })
end

local function setup_default_keymap()
  if vim.g.mdrun_no_default_maps then
    return
  end
  vim.keymap.set("n", "<leader>mr", function()
    require("mdrun").run()
  end, { desc = "Run bash block under cursor" })
end

function M.run()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local lnum = cursor[1]

   state.debug("init: run() called at line " .. tostring(lnum))

  local ok, err = runner.run_current(bufnr, lnum, function(result)
    vim.schedule(function()
      require("mdrun.ui").render_result(result)
    end)
  end)

  if ok == nil and err then
    state.debug("init: run() failed - " .. err)
    vim.notify("mdrun: " .. err, vim.log.levels.WARN)
  else
    state.debug("init: run() started runner, showing running state")
    -- show immediate running state
    local state = require("mdrun.state")
    local res = state.get_last_result()
    if res then
      require("mdrun.ui").render_result(res)
    end
  end
end

function M.show_last()
  require("mdrun.ui").show_last()
end

function M.setup()
  setup_autocmds()
  setup_default_keymap()
end

return M
