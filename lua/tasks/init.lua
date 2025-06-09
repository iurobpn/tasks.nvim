TaskWarrior = require'tasks.taskwarrior'
require"tasks.syntax"
require"tasks.ftplugin"
local Workspace = require 'tasks.ws'

local M = {
    folder = os.getenv("HOME") .. '/git/my/home/pkm/',
    current_ws='pkm',
    ws = {},

    backend = 'jq',

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
    viewable_fields = {
        'description',
        'due',
        'scheduled',
        'tags',
        'priority',
        'start',
        'recur'
    }
}

local function get_uuid()
    -- get current line from buffer
    local line = vim.api.nvim_get_current_line()
    local uuid = line:match("@{(.*)}")
    if uuid == nil then
        return nil
    end
    return uuid
end
local function toggle_status(line)
    if line == nil then
        line = vim.api.nvim_get_current_line()
    end
    if line:match('%- %[x%]') then
        line = string.gsub(line, '(%- %[x%])', '- [ ]')
    elseif line:match('%- %[%s+%]') then
        line = string.gsub(line, '(%- %[%s+%])', '- [x]')
    else
        vim.notify('task has no status')
    end
    return line
end
local function show(content)
    if content == nil then
        vim.notify('tasks.info content is nil')
        return
    end
    local win = dev.nvim.ui.float.Window()
    win.content = content
    lines = require'utils'.split(content,'\n')
    local num_lines = #lines
    -- get current cursor position
    local cursor = vim.api.nvim_win_get_cursor(0)
    local row = cursor[1] - num_lines 
    local col = cursor[2] + 5
    if row < 1 then
        row = 1
    end
    win.position = {
    absolute = {
            row = row,
            col = col,
        }
    }
    if win.option.buffer ~= nil then
        win.option.buffer = {}
    end
    win.option.buffer.buflisted = false
    win.option.buffer.modifiable = false

    win:open()
    win:fit()
    vim.cmd("wincmd w")

    M.infowin = win
    local initial_row = cursor[1]
    -- an autocommand to close window if the cursor change line number
    vim.api.nvim_create_autocmd("CursorMoved", {
        callback = function()
            if M.infowin ~= nil then
                local current_row = vim.api.nvim_win_get_cursor(0)[1]
                if initial_row ~= current_row then
                    -- close the window
                    M.infowin:close()
                    M.infowin = nil
                end
            end
        end,
        group = vim.api.nvim_create_augroup("TaskInfo", { clear = true }),
        buffer = win.bufnr,
    })
end

local function is_valid_raw(task)
    return task ~= nil and not vim.tbl_isempty(task)
end
local function is_valid(task)
    return task ~= nil and not vim.tbl_isempty(task) and task.uuid ~= nil and task.uuid ~= ''
end
-- local date_pattern = '(%d%d%d%d%-?%d%d%-?%d%d)([T ]?%d%d:%d%d:%d%d)?'
local date_pattern = '[%dT :%-]+'

M.ws['pkm'] = Workspace('pkm', os.getenv("HOME") .. '/git/my/home/pkm')
-- M.query = require('tasks.' .. M.backend)

M.get_filename = function()
    local ws = M.ws[M.current_ws]
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

local function task2line(task)
    local new_line = require'tasks.format'.tostring(task)

    return new_line
end

local Task = {}

function Task.update()
    local line = vim.api.nvim_get_current_line()
    local task = require'tasks.parser'.parse(line)
    if task == nil then
        return
    end
    if task.uuid == nil then
        vim.notify('No task in current line')
        return
    end
    local old_task = TaskWarrior.get_task(task.uuid)
    if old_task == nil then
        vim.notify('Task not found')
        return
    end
    line = task2line(old_task)
    vim.api.nvim_set_current_line(line)

    return old_task.uuid
end

function Task.parse()
    local line = vim.api.nvim_get_current_line()
    local task = require'tasks.parser'.parse(line)
    if task == nil then
        print('No task found')
        return
    end
    show(vim.inspect(task))
end

--- export current task to taskwarrior
function Task.export()
    local line = vim.api.nvim_get_current_line()
    local task = require'tasks.parser'.parse(line)
    if task == nil then
        return
    end
    if task.uuid == nil then
        vim.notify('No task in current line')
        return
    end
    local old_task = TaskWarrior.get_task(task.uuid)
    if old_task == nil then
        vim.notify('Task not found')
        return
    end

    -- replace the old_task values with the corrected ones in task
    for k, v in pairs(task) do
        if k ~= 'uuid' then
            old_task[k] = v
        end
    end

    line = task2line(old_task)
    vim.api.nvim_set_current_line(line)

    return old_task.uuid
end

function Task.info()
    local line = vim.api.nvim_get_current_line()
    local task = require'tasks.parser'.parse(line)
    if task == nil then
        return
    end
    if task.uuid == nil then
        vim.notify('No task in current line')
        return
    end
    local old_task = TaskWarrior.get_task(task.uuid)
    show(vim.inspect(old_task))
end

--- complete the current task
function Task.done()
    -- get the uuid from the line
    local uuid = get_uuid()
    if uuid == nil or uuid == '' then
        vim.notify('No task in current line')
        return
    end
    M.done({uuid=uuid})
    Task.update()
end
--- indexing current workspace   -------------------
function Task.index()
    local indexer = require'tasks.indexer'
    local ws = M.ws[M.current_ws]
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
--- indexing current workspace   -------------------
function Task.delete()
    local line = vim.api.nvim_get_current_line()
    local task = require'tasks.parser'.parse(line)
    if task == nil then
        vim.notify('task is nil')
        return
    end
    if task.uuid == nil then
        vim.notify('No task found')
        return
    end
    TaskWarrior.delete_task(task)
end
-- Task management functions
function Task.add(raw_task)
    if raw_task ==nil or raw_task == '' then
        local line = vim.api.nvim_get_current_line()
        raw_task = require'tasks.parser'.parse(line)
        if not is_valid_raw(raw_task) then
            raw_task = vim.cmd('call input("add a task:")')
            Task.add(raw_task)
            return
        end
    end

    -- local current_line = vim.api.nvim_get_current_line()
    --
    -- local task = require'parser'.parse(raw_task)
    local task = {}
    local out = TaskWarrior.add_task(raw_task)
    local uuid = out[1]:match('([0-9a-f]+%-[0-9a-f%-]+).')
    if not uuid then
        print('Error: ' .. out)
        return
    end
    print('uuid: ' .. uuid)
    task = TaskWarrior.get_task(uuid)
    print('task:', vim.inspect(task))
    -- M.tasks[task.uuid] = task
    -- append uuid at the end of the current line
    local current_line = vim.api.nvim_get_current_line()
    local new_line = current_line .. ' @{' .. task.uuid .. '}'
    vim.api.nvim_set_current_line(new_line)
    Task.update()

    return task
end

function Task.context(str)
    if str == nil or str == "" then
        M.context = "none"
    else
        M.context = str
        TaskWarrior.context(str)
    end
end
-- fetch tasks from tawk warrior with a giver filter
-- @param filter string
-- @return table
function Task.ls(filter)
    filter = filter or ''
    local filterObj = require'tasks.filter'()
    filterObj:add(filter)
    local raw_tasks = filterObj:get_tasks()
    if raw_tasks == nil or raw_tasks == '' then
        vim.notify('No tasks found')
        return
    end
    local tasks = require'cjson'.decode(raw_tasks)
    local str_tasks = {}
    if type(tasks[1]) == 'table' then
        for _, task in ipairs(tasks) do
            table.insert(str_tasks, "- [ ] " .. task.description .. " @{" .. task.uuid .. "}")
        end
    end

    M.select_tasks(str_tasks)
end

function Task.debug()
    TaskWarrior.debug = true
    TaskWarrior.mkdebug()
end
function Task.nodebug()
    TaskWarrior.debug = false
    TaskWarrior.mkdebug()
end

-- make recurrent tasks done and add completion date
function M.recurrent_done()
    local cursor_orig = vim.api.nvim_win_get_cursor(0)
    -- get current line from buffer
    local line = vim.api.nvim_get_current_line()
    local is_recurring = require'tasks.parser'.get_param_value(line, 'repeat')
    if not is_recurring then
        vim.notify('Task is not recurring')
        return false
    end
    local line_next
    if is_recurring == 'every month' then
        local due_date = require'tasks.parser'.get_param_value(line, 'due')
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

    line = toggle_status(line)
    if line:match('%- %[x%]') then
        line = line .. ' [end:: ' .. os.date('%Y-%m-%dT%H:%M:%S') .. ']'
    elseif line:match('%- %[ %]') then
        line = string.gsub(line, '(%s*%[end:: +' .. date_pattern .. '%]%s*)', '')
    else
        vim.notify('task has no status')
    end

    -- write the new line to the buffer
    vim.api.nvim_set_current_line(line)

    if line_next then
        if line_number > -1 then
            line_number = line_number - 1
        end
        line_next = string.gsub(line_next, '(%- %[.?%])', '- [ ]')
        vim.api.nvim_put({line_next}, 'l', true, false)
    end
    -- set the cursor back to the original line
    vim.api.nvim_win_set_cursor(0, cursor_orig)

    return true
end

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
        vim.cmd("Task index")
        vim.fn.writefile({today}, last_run_file)
    end
end

-- Autocommand to run on VimEnter
vim.api.nvim_create_autocmd("VimEnter", {
    callback = function()
        run_tasks_index_once_per_day()
    end,
})

require"class"
M = _G.class(M, { constructor = function(folder, filename)
    local obj = {}
    obj:set_workspace(folder, filename)

    return obj
end
})

function M.complete(arg_lead, cmd_line, cursor_pos)
    local options = {}
    for k, _ in pairs(Task) do
        table.insert(options, k)
    end
    return vim.tbl_filter(function(option)
        return vim.startswith(option, arg_lead)
    end, options)
end

vim.api.nvim_create_user_command('Task',
    function(args)
        M.cmd(args)
    end,
    {
        nargs = '*',
        complete = M.complete,
        desc = 'Task management command'
    }
)


-- Define the autocommand to trigger on saving a markdown file
-- vim.api.nvim_create_autocmd("BufWritePost", {
--     pattern = "*.md",     -- Only apply to markdown files
--     callback = function()
--         vim.cmd("TasksIndex")  -- Execute the 'TasksIndex' command
--     end,
-- })

-- Task command handler
function M.cmd(args)
    local usage = "Usage: :Task <add|ls|context|delete|done|update|update_all|index|info|parse> [arguments]"
    local subcommand = args.fargs[1]
    if not subcommand then
        vim.notify(usage)
        return
    end

    local nargs = ''
    if args.fargs[2] ~= nil then
        nargs = table.concat(args.fargs, " ", 2)
    end

    if Task[subcommand] ~= nil  and type(Task[subcommand]) == 'function' then
        Task[subcommand](nargs)
    else
        print("Invalid Task command. " .. usage)
    end
end

function M.select_tasks(tasks,action)
    if action == nil then
        action = function(selected)
            for _, raw_task in ipairs(selected) do
                local uuid = raw_task:match("@{(.*)}")
                if uuid then
                    task = TaskWarrior.get_task(uuid)
                    local line = task2line(task)
                    vim.api.nvim_put({line}, 'l', true, false)
                else
                    print('No task found with uuid ' .. uuid)
                end
            end
        end
    end

    require'fzf-lua'.fzf_exec(tasks, {
        fzf_opts = {
            -- ["--height"] = "50%",
            ["--layout"] = "reverse",
            ["--info"] = "inline",
            ["--multi"] = true,
            ["--preview"] = TaskWarrior.prefix .. "task $(echo {} | sed 's/\\(.*\\)@{\\(.*\\)}/\\2/')",
            -- ["--preview"] = "echo {} | cut -d' ' -f3- | task show",
        },
        actions = {
            ["default"] =  action,
        },
    })
end

function M.delete(task_id)
    -- get current line from buffer
    local line = vim.api.nvim_get_current_line()

    local task = require'tasks.parser'.parse(line)
    local out = TaskWarrior.delete(task.uuid)
    
    if out == nil or out == '' then
        vim.notify('Error deleting task')
        return
    end
end

function M.done(task)
    TaskWarrior.complete_task(task)
end

-- TODO check and debug this function
-- Main function to process the current line and build task hierarchy
function M.process_task_hierarchy()
    local current_line = vim.api.nvim_get_current_line()
    local current_task = require'tasks.parser'.parse(current_line)

    -- Check if current line is a task
    if not is_valid(current_task) then
        vim.notify("Current line is not a task", vim.log.levels.WARN)
        return nil
    end

    local current_indent = string.match(current_line, '^%s*') or ''
    local indent_level = #current_indent
    local parent_task = nil

    -- Get current line number (0-based in Neovim API)
    local current_linenum = vim.api.nvim_win_get_cursor(0)[1] - 1

    -- Search upwards for parent task
    if indent_level > 0 then
        for i = current_linenum - 1, 0, -1 do
            local line = vim.api.nvim_buf_get_lines(0, i, i + 1, false)[1]
            local task = require'tasks.parser'.parse(line)

            if is_valid(task) then
                local task_indent = string.match(line, '^%s*') or ''
                local task_indent_level = #task_indent

                if task_indent_level < indent_level then
                    -- Found parent task
                    parent_task = task

                    -- Initialize depends table if not exists
                    parent_task.depends = parent_task.depends or {}

                    -- Add current task's UUID to parent's depends if not already there
                    if not vim.tbl_contains(parent_task.depends, current_task.uuid) then
                        table.insert(parent_task.depends, current_task.uuid)
                    end

                    -- Now look for parent's parent (recursive hierarchy)
                    local parent_line_indent = string.match(line, '^%s*') or ''
                    if #parent_line_indent > 0 then
                        -- Temporarily move cursor to parent line to find its parent
                        local prev_cursor = vim.api.nvim_win_get_cursor(0)
                        vim.api.nvim_win_set_cursor(0, {i + 1, 0})
                        M.process_task_hierarchy() -- Recursively process parent
                        vim.api.nvim_win_set_cursor(0, prev_cursor)
                    end

                    break
                elseif task_indent_level >= indent_level then
                    -- Task at same or deeper indentation level, keep searching
                end
            end
        end
    end

    -- Return the task hierarchy information
    return {
        task = current_task,
        parent = parent_task
    }
end
M.Task = Task
_G.tasks = M

return M
