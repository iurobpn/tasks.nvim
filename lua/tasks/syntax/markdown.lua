local palette = require'katu'.color
-- Define the highlight group
vim.api.nvim_set_hl(0, 'TaskUUID', { fg = palette.bright_orange, bg = palette.dark1, bold = true })
vim.api.nvim_set_hl(0, 'TaskMeta', { fg = palette.faded_orange, bg = palette.dark1, bold = false })
vim.api.nvim_set_hl(0, 'TaskTag', { fg = palette.bright_purple, bold = false })

-- Link the group to the pattern
local M = {}
function M.init_highlights()
    vim.cmd("source " .. vim.fn.stdpath("data") .. "/ggn/tasks.nvim/lua/tasks/syntax/md.vim")
end

return M

