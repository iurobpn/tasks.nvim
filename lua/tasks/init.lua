TaskWarrior = require'tasks.taskwarrior'
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

function M.task2line(task)
    local new_line = require'tasks.format'.tostring(task)
    vim.api.nvim_set_current_line(new_line)

    return new_line
end

local function hash2plus(tags)
    if tags == nil or tags == {} then
        return {}
    end
    for i,_ in ipairs(tags) do
        tags[i] = tags[i]:gsub('#', '')
    end
    return tags
end

function M.update()
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
    -- print('old task: ', vim.inspect(old_task))
    if old_task == nil then
        vim.notify('Task not found')
        return
    end
    M.task2line(old_task)

    return old_task.uuid
end
--- export current task to taskwarrior
function M.export()
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
    -- print('old task: ', vim.inspect(old_task))
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

    M.task2line(old_task)

    return old_task.uuid
end
--- complete the current task
function M.complete_task()
    -- get the uuid from the line
    local uuid = M.get_task_uuid()
    TaskWarrior.complete_task(uuid)
    M.update()
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
if vim ~= nil and vim.api.nvim_set_keymap ~= nil then
    vim.api.nvim_create_autocmd("VimEnter", {
        callback = function()
            run_tasks_index_once_per_day()
        end,
    })
end

require"class"
M = _G.class(M, { constructor = function(self, folder, filename)
    self:set_workspace(folder, filename)
end
})

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

--- indexing current workspace   -------------------
function M.get_indexer(folder,filename)
    return require('tasks.indexer').get_indexer(folder, filename)
end

M.index = function()
    local indexer = M.indexer
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

function M.complete(arg_lead, cmd_line, cursor_pos)
    -- { 'add', 'ls', 'rm', 'done', 'import', 'export', 'index', 'context' }
    -- These are the valid completions for the command
    local options = { "ls", "context", "add", "rm", "done", "import",  "update", "export", "parse" }
    -- Return all options that start with the current argument lead
    return vim.tbl_filter(function(option)
        return vim.startswith(option, arg_lead)
    end, options)
end

if vim ~= nil and vim.api.nvim_create_user_command ~= nil then
-- Add a command to run index function
vim.api.nvim_create_user_command('Task',
        function(args)
            M.cmd(args)
        end,
        {--<add|ls|context|rm|done|import|export|index>
            nargs = '*',
            complete = M.complete,
            desc = 'Task management command'
        }
)
end

function M.remove()
    local line = vim.api.nvim_get_current_line()
    local task = require'Parser'.parse(line)
    if task == nil then
        return
    end
    if task.uuid == nil then
        vim.notify('No task found')
        return
    end
    TaskWarrior.delete_task(task.uuid)
end

-- Define the autocommand to trigger on saving a markdown file
-- vim.api.nvim_create_autocmd("BufWritePost", {
--     pattern = "*.md",     -- Only apply to markdown files
--     callback = function()
--         vim.cmd("TasksIndex")  -- Execute the 'TasksIndex' command
--     end,
-- })

-- Task command handler
function M.cmd(args)
    local subcommand = args.fargs[1]
    if not subcommand then
        print("Usage: :Task <add|ls|context|mtwd|rm|done|update|update_all|index> [arguments]")
        return
    end

    local nargs = ''
    if args.fargs[2] ~= nil then
        nargs = table.concat(args.fargs, " ", 2)
    end

    if subcommand == 'add' then
        if nargs == '' then
            local line = vim.api.nvim_get_current_line()
            local task = require'tasks.parser'.parse(line)
            if task == nil then
                print("Usage: :Task add <description>")
            else
                M.add(task);
            end
        else
            M.add(nargs)
        end
    elseif subcommand == 'context' then
        if nargs == '' then
            print('context: ' .. TaskWarrior._context)
        else
            M.context(nargs)
        end
    elseif subcommand == 'ls' then
        M.list(nargs)
    elseif subcommand == 'rm' then
        local task_id_str = args.fargs[2]
        if task_id_str == nil then
            print("Usage: :Task rm <task_id>")
            return
        end
        local task_id = tonumber(task_id_str)
        M.rm(task_id)
    elseif subcommand == 'done' then
        local task_id_str = args.fargs[2]
        if task_id_str == nil then
            print("Usage: :Task done <task_id>")
            return
        end
        local task_id = tonumber(task_id_str)
        M.done(task_id)
    elseif subcommand == 'rm' then
        M.remove()
    elseif subcommand == 'update' then
        M.update()
    elseif subcommand == 'import' then
        M.import()
    elseif subcommand == 'export' then
        M.export()
    elseif subcommand == 'index' then
        M.index()
    elseif subcommand == 'parse' then
        -- get current line
        local line = vim.api.nvim_get_current_line()
        -- parse the line
        local task = M.parser.parse(line)
        -- check if the task is nil
        if task == nil then
            print('No task found')
            return
        end
        -- print the task
        print('Task: ' .. require'inspect'.inspect(task))
        local uuid = M.parser.get_uuid(line)
        print('UUID: ' .. uuid)
    else
        print("Invalid Task command. Usage: :Task <new|list|del|done|add|import|export> [arguments]")
    end
end

-- Task management functions
function M.add(raw_task)
    if raw_task ==nil or raw_task == '' then
        raw_task = vim.cmd('input("add a task:")')
    end

    -- local current_line = vim.api.nvim_get_current_line()
    --
    -- local task = require'parser'.parse(raw_task)
    local task = {}
    if raw_task ~= '' then
        local out = TaskWarrior.add_task(raw_task)
        local id = out[1]:match('([0-9a-f]+%-[0-9a-f%-]+).')
        if not id then
            print('Error: ' .. out)
            return
        end
        out = require'tasks.util'.run('task ' .. id .. ' export')
        print('out ' .. out)
        task = require'cjson'.decode(out)
        task = task[1]
        M.tasks[task.uuid] = task
        -- append uuid at the end of the current line
        local current_line = vim.api.nvim_get_current_line()
        local new_line = current_line .. ' @{' .. task.uuid .. '}'
        vim.api.nvim_set_current_line(new_line)
        -- print('task: ' .. require'inspect'.inspect(task))
        M.update()
    end

    return task
end

function M.context(str)
    if str == nil or str == "" then
        M.context = "none"
    else
        M.context = str
        TaskWarrior.context(str)
    end
end


function M.get_task_uuid()
    -- get current line from buffer
    local line = vim.api.nvim_get_current_line()
    local uuid = line:match("@{(.*)}")
    if uuid == nil then
        return nil
    end
    return uuid
end

-- fetch tasks from tawk warrior with a giver filter
-- @param filter string
-- @return table
function M.list(filter)
    filter = filter or ''
    local filterObj = require'tasks.filter'()
    filterObj:add(filter)
    local raw_tasks = filterObj:get_tasks()
    local tasks = require'cjson'.decode(raw_tasks)
    local str_tasks = {}
    if type(tasks[1]) == 'table' then
        for _, task in ipairs(tasks) do
            table.insert(str_tasks, "- [ ] " .. task.description .. " @{" .. task.uuid .. "}")
        end
    end

    M.select_tasks(str_tasks)
end

function M.select_tasks(tasks,action)
    if action == nil then
        action = function(selected)
            for _, raw_task in ipairs(selected) do
                local uuid = raw_task:match("@{(.*)}")
                if uuid then
                    task = TaskWarrior.get_task(uuid)
                    M.task2line(task)
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
            ["--preview"] = "task $(echo {} | sed 's/\\(.*\\)@{\\(.*\\)}/\\2/')",
            -- ["--preview"] = "echo {} | cut -d' ' -f3- | task show",
        },
        actions = {
            ["default"] =  action,
        },
    })
end

function M.rm(task_id)
    TaskWarrior.delete_task(task_id)
    -- parse current line
    -- get uuid
    -- check if the uuid and/or description represent oine task in TW
    -- launch tasks.rm(task(uuid)
    -- fetch whole task from TW
    -- show task to the user
    -- ask if he is sure he wants to delete via vim.ui.input
    -- delete if he is sure via util.run('yes | task delete uuid')
end

function M.done(task_id)
    TaskWarrior.task_done(task_id)
end

_G.tasks = M

return M
