if vim.g.loaded_mdrun then
  return
end
vim.g.loaded_mdrun = true

local mdrun = require("mdrun")

mdrun.setup()

vim.api.nvim_create_user_command("Mdrun", function()
  mdrun.run()
end, {})

vim.api.nvim_create_user_command("MdrunLast", function()
  mdrun.show_last()
end, {})
