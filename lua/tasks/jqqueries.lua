
------------------- jq queries -------------------
--- Search for tasks in the json file
--- @param tag string or nil
--- @param ... table
M.search = function(tag, ...)
    local opts = {...}
    opts = opts[1] or {}
    opts.tag = tag
    M.views.search(opts)
end

--- Check a line for a jq command to run
--- @param linenr integer
--- @return string
function M.get_cmd_from_line(linenr)
    if linenr == nil then
        linenr = vim.fn.line('.')
    end
    local line = vim.fn.getline(linenr)
    local cmd = line:match('%{%{%s*jq.?: (.*)%}%}')
    if not cmd then
        return ''
    end
    cmd = 'jq ' .. cmd
    return cmd
end


-- Function to run the jq command from the current line
function M.get_jq_lines()
    local cmd = M.get_cmd_from_line()
    if cmd == nil then
        return
    end
    local q = M.query.Query()
    local lines = q:run(cmd)
    -- M.jq.line = vim.api.nvim_win_get_cursor(0)[1]
    return lines
end

function M.ShowJqResult()
    -- Create a namespace for your extmarks
    if not M.ns_id then
        M.ns_id = vim.api.nvim_create_namespace('JqResultNs')
    end
    local lines = M.get_jq_lines()
    if lines == nil then
        return
    end
    -- Get the current buffer number
    local bufnr = vim.api.nvim_get_current_buf()

    -- Get the current cursor position (line and column)
    local cursor_pos = vim.api.nvim_win_get_cursor(0)
    local start_line = cursor_pos[1] - 1  -- Adjust for Lua's 0-indexing

    -- Iterate over the output lines and set virtual text
    for i, line in ipairs(lines) do
        if line ~= '' then
            vim.api.nvim_buf_set_extmark(bufnr, M.ns_id, start_line + i - 1, 0, {
                virt_text = { { line, 'Comment' } },  -- You can choose a different highlight group
                virt_text_pos = 'eol',
            })
        end
    end
end

function M.UpdateJqFloat()
    if not vim.api.nvim_buf_is_valid(0) then return end

    local bufnr = vim.api.nvim_get_current_buf()
    local cursor_pos = vim.api.nvim_win_get_cursor(0)
    local current_line = cursor_pos[1]  -- Lua uses 1-indexing for lines



    -- create hl group for current line
    -- Get the content of the current line
    local line_content = vim.api.nvim_buf_get_lines(bufnr, current_line - 1, current_line, false)[1]


    local current_jfile = M.query.Query.jsonfiles.current
    local jsonfile = nil
    for _, val in pairs(M.query.Query.jsonfiles) do
        if line_content ~= nil and line_content:match('{{' .. val.prefix .. ':%s.*}}') then
            M.query.Query.jsonfiles.current = val
            jsonfile=val
            break
        end
    end
    if jsonfile == nil then
        M.CloseJqFloat()
        return
    end
    -- Check if the line contains your jq command
    if line_content and line_content:match('{{' .. jsonfile.prefix .. ':%s.*}}') then
        -- Extract the command from the line starting from 'jq'
        local cmd_start_col = line_content:find(jsonfile.prefix) + 5
        -- If we are on the jq line and haven't already shown the float
        if M.jq.line ~= current_line then
            -- Close previous floating window if any
            M.CloseJqFloat()

            local old_line = M.jq.line
            -- Update jq.line
            M.jq.line = current_line


            -- Extract the command from the line (adjust as needed)
            local lines = M.get_jq_lines()
            if lines == nil or lines == '' then
                return
            end
            local taskss = require"tasks.util".json_decode(lines)
            local tasks_str = {}

            if lines ~= nil then
                local format = require'tasks.format'
                for _, task  in ipairs(taskss) do
                    table.insert(tasks_str,format.tostring(task))
                end
                -- Create a new buffer for the floating window
               M.jq.bufnr = vim.api.nvim_create_buf(false, true)  -- Create a scratch buffer

                -- Set buffer options
                vim.api.nvim_set_option_value('bufhidden', 'wipe', {buf = M.jq.bufnr})

                -- Set the lines of the buffer to the output
                vim.api.nvim_buf_set_lines(M.jq.bufnr, 0, -1, false, tasks_str)

                -- Optionally set syntax highlighting if the output is JSON
                vim.api.nvim_set_option_value('filetype', 'markdown', {buf = M.jq.bufnr})
                -- Calculate the maximum line length from the output
                local max_line_length = 0
                for _, line in ipairs(tasks_str) do
                    local line_length = vim.fn.strdisplaywidth(line)
                    if line_length > max_line_length then
                        max_line_length = line_length
                    end
                end

                -- Get the window width and height
                local width = vim.o.columns
                local height = vim.o.lines

                -- Calculate the width and height of the floating window
                local float_width = max_line_length + 2  -- Add padding
                local float_height = #taskss

                -- Ensure the floating window doesn't exceed the window boundaries
                if float_width > width - cmd_start_col then
                    float_width = width - cmd_start_col
                end
                if float_height > height - current_line - 2 then  -- Subtract 2 for padding
                    float_height = height - current_line - 2
                end
                if float_height < 1 then
                    float_height = 1
                end
                if float_width < 5 then
                    float_width = 5
                end

                -- Configure floating window options
                local opts = {
                    style = 'minimal',
                    relative = 'cursor',
                    width = float_width,
                    height = float_height,
                    row = 1,
                    col = cmd_start_col - 1,  -- Adjust for 0-indexing
                    border = nil,
                    noautocmd = true,
                }

                -- create a name space for highlightinh current line
                if M.jq.ns_line_id == nil then
                    M.jq.ns_line_id = vim.api.nvim_create_namespace('JqFloatCur')
                    vim.api.nvim_set_hl(0, 'ClearCmd', { fg = "#282828" }) -- dark0_hard
                    vim.api.nvim_set_hl(0, 'FadeJqLine', { fg = "#fb4934" }) -- bright_red
                end
                local ns_l_id = M.jq.ns_line_id
                -- clear namespace highlights
                vim.api.nvim_buf_clear_namespace(bufnr, ns_l_id, 0, -1)
                vim.api.nvim_buf_add_highlight(bufnr, ns_l_id, 'ClearCmd', current_line-1, 0, -1)
                if old_line ~= nil then
                    vim.api.nvim_buf_add_highlight(bufnr, ns_l_id, 'FadeJqLine', old_line-1, 0, -1)
                end

                -- Open the floating window
                M.jq.vid = vim.api.nvim_open_win(M.jq.bufnr, false, opts)

                -- Set window options to remove line numbers, signcolumn, etc.
                vim.api.nvim_set_option_value('number', false, { scope = "local", win = M.jq.vid })
                vim.api.nvim_set_option_value('relativenumber', false, { scope = "local", win = M.jq.vid })
                vim.api.nvim_set_option_value('signcolumn', 'no', { scope = "local", win = M.jq.vid })
                vim.api.nvim_set_option_value('foldcolumn', '0', { scope = "local", win = M.jq.vid })
                vim.api.nvim_set_option_value('cursorline', false, { scope = "local", win = M.jq.vid })
                vim.api.nvim_set_option_value('winhl', 'NormalFloat:Normal', { scope = "local", win = M.jq.vid })
                vim.api.nvim_set_option_value('wrap', false, { scope = "local", win = M.jq.vid })
                -- call matchadd to set the highlight group for the line number for the jq window
                vim.fn.matchadd('LineNr', "| .*$", 1, -1, { window = M.jq.vid})
            else
                -- Handle error (optional)
                print("Error executing command: " .. line_content)
            end
        end

        M.query.Query.jsonfiles.current = current_jfile
    else
        -- If we move away from the jq line, close the floating window
        --
        M.CloseJqFloat()
    end
end

function M.run_jq_cmd_from_current_line()
    vim.notify('Running jq command from current line')
    if M.jq.vid then
        vim.notify('Jq window is open')
        M.CloseJqFloat()
    end
    local cmd = M.get_cmd_from_line()
    if not cmd then
        vim.notify('No jq command found in current line')
        return
    end
    local taskss, title = M.views.search(cmd)
    if not taskss then
        print('No tasks found')
        return
    end
    M.views.open_window(taskss, title)
end

function M.CloseJqFloat()
    if M.jq.vid and vim.api.nvim_win_is_valid(M.jq.vid) then
        vim.api.nvim_win_close(M.jq.vid, true)
        M.jq.vid = nil
        M.jq.bufnr = nil
        M.jq.line = nil
    end
end

-- Create the :JqFix command
    vim.api.nvim_create_user_command('JqCurrent', M.run_jq_cmd_from_current_line, {})
-- Or map to a keybinding (e.g., pressing <leader>jr runs the function)
vim.api.nvim_set_keymap('n', '<LocalLeader>j', ':JqCurrent<CR>', { noremap = true, silent = true })

-- Set up autocommands
-- vim.cmd([[
--   augroup JqFloatAutocmd
--     autocmd!
--     autocmd CursorMoved *.md lua require'tasks'.UpdateJqFloat()
--     autocmd BufLeave *md lua require'tasks'.CloseJqFloat()
--   augroup END
-- ]])

------------------- jq queries ------------------------------
