local Workspace = require 'tasks.ws'
local M = {
    folder = os.getenv("HOME") .. '/git/my/home/pkm/',
    current_ws='pkm',
    ws = {},
    indexer = require'tasks.indexer',
    parser = require'tasks.parser',
    views = require'tasks.views',
    find = require'tasks.find',
    workspace = require'tasks.ws',
    fzf = require'tasks.fzf',


    backend = 'jq',
    query = require('tasks.jq'),

    -- Indexer = require('tasks.indexer').Indexer,
    tasks = {
        json = nil,
        tab = nil,
        ns_id = nil,
        jq_line = nil,
        inserted_lines = nil
    },
    jq_fix = {
        ns_id = nil,
        vid = nil,  -- Variable to store the floating window ID,
        bufnr = nil,   -- Variable to store the buffer number for the floating window,
        line = nil,          -- Variable to store the line number with the jq command,
    },
    jq = {
        ns_id = nil,
        vid = nil,  -- Variable to store the floating window ID,
        bufnr = nil,   -- Variable to store the buffer number for the floating window,
        line = nil,          -- Variable to store the line number with the jq command,
    },
}


local nonmtags = {
    'description',
    'status',
    'due',
    'tags',
    'filename',
    'line_number',
}

M.ws['pkm'] = Workspace('pkm', os.getenv("HOME") .. '/git/my/home/pkm')
-- M.query = require('tasks.' .. M.backend)

--- Toggle the plugin by calling the `enable`/`disable` methods respectively.
function M.toggle()
    local main = require("tasks.main")
    local config = require("tasks.config")
    if M.config == nil then
        M.config = config.options
    end

    main.toggle("public_api_toggle")
end

--- Initializes the plugin, sets event listeners and internal state.
function M.enable(scope)
    local main = require("tasks.main")
    local config = require("tasks.config")
    if M.config == nil then
        M.config = config.options
    end

    main.toggle(scope or "public_api_enable")
end

--- Disables the plugin, clear highlight groups and autocmds, closes side buffers and resets the internal state.
function M.disable()
    local main = require("tasks.main")
    main.toggle("public_api_disable")
end

-- setup tasks options and merge them with user provided ones.
function M.setup(opts)
    local config = require("tasks.config")
    M.config = config.setup(opts)
end


function M:add_workspace(name, folder)
    self.ws[name] = Workspace(name, folder)
end


-- make recurrent tasks done and add completion date
function M.recurrent_done()
    local cursor_orig = vim.api.nvim_win_get_cursor(0)
    -- get current line from buffer
    local line = vim.api.nvim_get_current_line()
    local is_recurring = M.parser.get_param_value(line, 'repeat')
    if not is_recurring then
        vim.notify('Task is not recurring')
        return false
    end
    local line_next
    if is_recurring == 'every month' then
        local due_date = M.parser.get_param_value(line, 'due')
        if not due_date then
            vim.notify('Task is not due')
            return false
        end

        local year, month = string.match(line, '(%d+)%-(%d+)%-%d+')
        month = tonumber(month)
        if month == nil then
            vim.notify('No month found in due date')
            return false
        end
        month = month + 1
        if month > 12 then
            month = 1
            year = year + 1
        end
        local y_month = string.format('%s-%02d', year, month)
        line_next = line:gsub('(%[due::%s*)%d+%-%d%d(%-%d+[^%]]*%])', string.format('%s%s%s', '%1', y_month, '%2'))

        vim.notify('Task is recurring every month')
    end
    --
    line = string.gsub(line, '(%- %[.?%])', '- [x]')
    local cursor = vim.api.nvim_win_get_cursor(0)
    local line_number = cursor[1]
    -- write the new line to the buffer
    vim.api.nvim_set_current_line(line .. ' [completion:: ' .. os.date('%Y-%m-%d %H:%M:%S') .. ']')
    if line_next then
        if line_number > -1 then
            line_number = line_number - 1
        end
        line_next = string.gsub(line_next, '(%- %[.?%])', '- [ ]')
        vim.api.nvim_buf_set_lines(0, line_number, line_number, false, {line_next})
    end
    -- set the cursor back to the original line
    vim.api.nvim_win_set_cursor(0, cursor_orig)
    vim.notify('Task marked as done')

    return true
end

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

---convert task to a short string
---@param task table 
---@return string
function M.toshortstring(task)
    local mtags = ''
    utils = require'utils'
    for k,v in pairs(task) do
        if not utils.contains(nonmtags,k) then
            mtags = mtags .. string.format('[%s:: %s]', k, v)
        end
    end

    local tags = table.concat(task.tags,' ')
    -- local filename = fs.basename(task.filename)
    local file = '' -- '| ' .. filename .. ':' .. task.line_number
    local line = string.format('%s %s %s', task.description, tags, file)
    return line
end

---convert a task to a string
---@param task table
---@return string
function M.tostring(task)
    local status
    if task.status == 'not started' then
        status = ' '
    elseif task.status == 'in progress' then
        status = '.'
    elseif task.status == 'done' then
        status = 'x'
    end

    local due = ''
    if task.due ~= nil then
        due = string.format('[%s:: %s]', 'due', task.due)
    end
    local tags = table.concat(task.tags,' ')
    local file = '| ' .. task.filename .. ':' .. task.line_number

    local mtags = ''
    if task then
        for k,v in pairs(task) do
            if not utils.contains(nonmtags,k) then
                mtags = mtags .. string.format(' [%s:: %s]', k, v)
            end
        end
    end
    local line = string.format('- [%s] %s %s %s %s %s', status, task.description, tags, due, mtags, file)
    return line
end

--- convert a metatag to a string
---@param mtag string
---@param val any
---@return string
function M.mtag_to_string(mtag,val)
    return string.format('[%s:: %s]', mtag, val)
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
            local taskss = require"cjson".decode(lines)
            local tasks_str = {}

            if lines ~= nil then
                for _, task  in ipairs(taskss) do
                    table.insert(tasks_str,M.tostring(task))
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

function M.check_completion()
    local line = vim.api.nvim_get_current_line()
    if string.match(line, '%- %[x%]') then
        M.insert_completed_tag()
    end
end

function M.insert_completed_tag()
    local line = vim.api.nvim_get_current_line()
    if not string.match(line, '%[completion:: .*%]') then
        vim.api.nvim_set_current_line(line .. ' [completion:: ' .. os.date('%Y-%m-%d %H:%M:%S') .. ']')
        vim.notify('Task marked as done')
    end
end

function M.CloseJqFloat()
    if M.jq.vid and vim.api.nvim_win_is_valid(M.jq.vid) then
        vim.api.nvim_win_close(M.jq.vid, true)
        M.jq.vid = nil
        M.jq.bufnr = nil
        M.jq.line = nil
    end
end

if vim ~= nil and vim.api.nvim_create_user_command ~= nil then
-- Create the :JqFix command
    vim.api.nvim_create_user_command('JqCurrent', M.run_jq_cmd_from_current_line, {})


-- Helper function to get today's date in "YYYY-MM-DD" format
local function get_current_date()
    return os.date("%Y-%m-%d")
end

-- Function to check and run TasksIndex only once per day
local function run_tasks_index_once_per_day()
    local today = get_current_date()
    local last_run_file = vim.fn.stdpath("data") .. "/.last_tasks_index_run.txt"

    -- Check if the file exists
    local last_run_date = ""
    if vim.fn.filereadable(last_run_file) == 1 then
        last_run_date = vim.fn.readfile(last_run_file)[1]
    end

    -- If the last run date is different from today, run TasksIndex and update the file
    if last_run_date ~= today then
        vim.cmd("TasksIndex")
        vim.fn.writefile({today}, last_run_file)
    end
end

-- Autocommand to run on VimEnter
if vim ~= nil and vim.api.nvim_set_keymap ~= nil then
    vim.api.nvim_create_autocmd("VimEnter", {
        callback = function()
            run_tasks_index_once_per_day()
        end,
    })
end

require"class"
M = class(M, { constructor = function(self, folder, filename)
    self:set_workspace(folder, filename)
end
})

function M.get_indexer(folder,filename)
    return require('tasks.indexer').get_indexer(folder, filename)
end
_G.tasks = M

_G.tasks.index = function()
    local indexer = _G.tasks.indexer
    local ws = _G.tasks.ws[_G.tasks.current_ws]
    if ws == nil then
        print('No workspace found')
        return
    end
    if ws.folder == nil then
        print('No folder found')
        return
    end
    indexer.index(ws.folder)
end
_G.tasks.get_filename = function()
    local ws = _G.tasks.ws[_G.tasks.current_ws]
    if ws == nil then
        print('No workspace found')
        return
    end
    if ws.folder == nil then
        print('No folder found')
        return
    end
    return ws:get_filename()
end

-- Or map to a keybinding (e.g., pressing <leader>jr runs the function)
vim.api.nvim_set_keymap('n', '<LocalLeader>j', ':JqCurrent<CR>', { noremap = true, silent = true })
-- Add a command to run index function
vim.api.nvim_create_user_command('TasksIndex', 'lua _G.tasks.index()',
    {
        nargs = 0,
        desc = 'Index note tasks  and save into json file'
    }
)
end
-- Define the autocommand to trigger on saving a markdown file
-- vim.api.nvim_create_autocmd("BufWritePost", {
--     pattern = "*.md",     -- Only apply to markdown files
--     callback = function()
--         vim.cmd("TasksIndex")  -- Execute the 'TasksIndex' command
--     end,
-- })
-- Set up autocommands
-- vim.cmd([[
--   augroup JqFloatAutocmd
--     autocmd!
--     autocmd CursorMoved *.md lua require'tasks'.UpdateJqFloat()
--     autocmd BufLeave *md lua require'tasks'.CloseJqFloat()
--   augroup END
-- ]])
return _G.tasks
