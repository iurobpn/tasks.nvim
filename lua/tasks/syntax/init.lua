-- vim.cmd([[
-- " Add to your vimrc (or create a plugin file)
-- augroup custom_markdown_syntax
--   autocmd!
--   autocmd Syntax markdown ~/.vim/after/syntax/markdown.vim
-- augroup END
-- ]])


-- autogroup command in lua
vim.api.nvim_create_augroup("custom_markdown_syntax", { clear = true })
-- vim.api.nvim_create_autocmd("Syntax", {
--     pattern = "markdown",
--     callback = function()
--         require"tasks.syntax.markdown".init_highlights()
--     end,
--     group = "custom_markdown_syntax",
-- })

vim.api.nvim_create_autocmd({'BufEnter', 'BufWinEnter'}, {
    pattern = {'*.md'},
    callback = function(ev)
        require"tasks.syntax.markdown".init_highlights()
    end,
    group = "custom_markdown_syntax",
})
