local palette = vim.g.gruvbox_palette
-- Define the highlight group
vim.api.nvim_set_hl(0, 'TaskUUID', { fg = palette.bright_orange, bg = palette.dark1, bold = true })

-- Link the group to the pattern
vim.cmd('syntax region TaskUUID matchgroup=xParen start=/@{/ end=/}/')
print('TaskUUID syntax highlighting enabled')

