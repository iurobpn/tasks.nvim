
local function set_keymaps()
    vim.api.nvim_set_keymap('n', '<CR>', '<cmd>lua require("tasks").recurrent_done()<CR>', { noremap = true, silent = true, desc = 'Toggle task status' })
end

vim.api.nvim_set_keymap('n', '<F9>', ':Tasks toggle default<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<LocalLeader>tw', ':Tasks toggle work<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<LocalLeader>p', ':Tasks toggle personal<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<LocalLeader>tc', ':Tasks current<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<LocalLeader>tt', ':Tasks #today<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<LocalLeader>tm', ':Tasks #main<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<LocalLeader>ti', ':Tasks #important<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<LocalLeader>tr', ':Tasks #res<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<LocalLeader>tl', ':Tasks last<CR>', { noremap = true, silent = true })
-- create an autocommand to set keymaps when the plugin is loaded
vim.api.nvim_create_autocmd('FileType', {
    pattern = 'markdown',
    callback = function()
        set_keymaps()
    end,
})
