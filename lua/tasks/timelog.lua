local M = {}
----------------------------
M.edit = function()
    vim.cmd.e(M.log_file)
end

if vim ~= nil and vim.fn ~= nil then
    local tasks_log_file = vim.fn.expand("~/.config/nvim/tasks.log")
end

M.log_file = tasks_log_file
-- Function to parse the log file and calculate summaries
local function parse_log(period)
    local lines = {}
    if vim.fn.filereadable(tasks_log_file) == 1 then
        lines = vim.fn.readfile(tasks_log_file)
    else
        vim.api.nvim_err_writeln("tasks.log not found.")
        return
    end

    local entries = {}
    local tasks = {}
    local total_task_time = 0
    local total_break_time = 0

    local current_date = os.date("%Y-%m-%d")
    local current_month = os.date("%Y-%m")

    local last_time = nil
    local last_entry = nil
    local first_entry_of_period = true

    for _, line in ipairs(lines) do
        if line ~= "" then
            local date_str, time_str, desc = line:match("^(%d%d%d%d%-%d%d%-%d%d) (%d%d:%d%d): (.+)$")
            if date_str and time_str and desc then
                local entry_time = os.time{
                    year = tonumber(date_str:sub(1,4)),
                    month = tonumber(date_str:sub(6,7)),
                    day = tonumber(date_str:sub(9,10)),
                    hour = tonumber(time_str:sub(1,2)),
                    min = tonumber(time_str:sub(4,5)),
                }
                local is_break = desc:match("%*%* *$")
                local entry_type = is_break and 'break' or 'task'

                local period_match = false
                if period == 'day' and date_str == current_date then
                    period_match = true
                elseif period == 'month' and date_str:sub(1,7) == current_month then
                    period_match = true
                end

                if period_match then
                    local entry = {time = entry_time, desc = desc, type = entry_type}

                    if first_entry_of_period then
                        -- Ignore the first entry of the period for duration calculations
                        first_entry_of_period = false
                    else
                        -- Calculate duration since last entry
                        local duration = entry_time - last_time

                        if entry.type == 'task' then
                            -- Assign duration to last task
                            tasks[#tasks + 1] = {
                                desc = entry.desc,
                                duration = duration,
                                time = {
                                    start = entry_time,
                                    final = last_time,
                                },
                            }
                            total_task_time = total_task_time + duration
                        elseif entry.type == 'break' then
                            -- Add duration to total break time
                            total_break_time = total_break_time + duration
                        end
                    end

                    last_time = entry_time
                    -- last_entry = entry
                else
                    -- Entry not in the specified period, reset for new day/month
                    first_entry_of_period = true
                    last_time = nil
                    -- last_entry = nil
                end
            end
        end
    end
    local current_time
    if last_time == nil then
        current_time = 0
    else
        current_time = os.time() - last_time
    end

    -- -- Handle the last entry if it's within the period
    -- if last_entry then
    --     local now = os.time()
    --     local duration = now - last_time
    --
    --     if last_entry.type == 'task' then
    --         tasks[#tasks + 1] = {desc = last_entry.desc, duration = duration}
    --         total_task_time = total_task_time + duration
    --     elseif last_entry.type == 'break' then
    --         total_break_time = total_break_time + duration
    --     end
    -- end

    return {
        tasks = tasks,
        total_task_time = total_task_time,
        total_break_time = total_break_time,
        current_time = current_time
    }
end

-- Function to display the summary in a floating window
function M.show_summary(args)
    local period = args.fargs[1] or 'day'
    if period ~= 'day' and period ~= 'month' then
        vim.api.nvim_err_writeln("Invalid period. Use 'day' or 'month'.")
        return
    end

    local summary = parse_log(period)
    if not summary then return end

    local function totime(tsec)
        local t = os.date("*t", tsec)
        return t.hour, t.min, t.sec
    end
    local function get_time(seconds)
        local minutes = math.floor(seconds / 60)
        local hours = math.floor(minutes / 60)
        minutes = minutes % 60
        hours = hours % 24
        return hours, minutes
    end
    local function format_time(seconds)
        local hours, minutes = get_time(seconds)
        return string.format("%02d h %02d min", hours, minutes)
    end

    local content = {}

    -- List tasks and their durations
    for _, task in ipairs(summary.tasks) do
        local duration_str = format_time(task.duration)
        local hstart, mstart = totime(task.time.start)
        local hfinal, mfinal = totime(task.time.final)


        local task_line = string.format("%s    (%02d:%02d - %02d:%02d)  %s", duration_str, hstart, mstart, hfinal, mfinal, task.desc)
        table.insert(content, task_line)
    end

    -- Add a blank line
    table.insert(content, "")

    -- Total times
    local total_task_str = format_time(summary.total_task_time)
    local total_break_str = format_time(summary.total_break_time)
    local cur_time = format_time(summary.current_time)

    table.insert(content, "Current task time: " .. cur_time)
    table.insert(content, "Time working: " .. total_task_str)
    table.insert(content, "Time in breaks: " .. total_break_str)

    -- Create a floating window
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, content)

    local width = 60
    local height = #content + 2
    local opts = {
        style = "minimal",
        relative = "editor",
        width = width,
        height = height,
        row = (vim.o.lines - height) / 2,
        col = (vim.o.columns - width) / 2,
        border = "single",
    }

    vim.api.nvim_open_win(buf, true, opts)
    vim.cmd('setlocal signcolumn=no')
    vim.api.nvim_buf_set_keymap(buf, 'n', 'q', ':bd<CR>', {noremap = true, silent = true})
    vim.api.nvim_buf_set_keymap(buf, 'n', '<ESC>', ':bd<CR>', {noremap = true, silent = true})
end

-- Other functions remain the same...
-- Function to log a task
function M.log_task(args)
    local task_description = args.args
    if task_description == nil or task_description == "" then
        vim.notify("No task description provided.")
        return
    end
    local current_time = os.date("%Y-%m-%d %H:%M")
    local new_entry = current_time .. ':  ' .. task_description

    -- Check if last entry was on a different day
    local last_entry = M.get_last_log_entry()
    if last_entry then
        local last_date = last_entry:match("^(%d%d%d%d%-%d%d%-%d%d)")
        local current_date = os.date("%Y-%m-%d")
        if last_date and last_date ~= current_date then
            M.append_log_entry("")  -- Insert empty line for new day
        end
    end

    M.append_log_entry(new_entry)
    print("Task logged: " .. new_entry)
end

-- Helper functions
function M.get_last_log_entry()
    local lines = {}
    if vim.fn.filereadable(tasks_log_file) == 1 then
        lines = vim.fn.readfile(tasks_log_file)
    end
    return lines[#lines]
end

function M.append_log_entry(entry)
    local file = io.open(tasks_log_file, "a")
    if file then
        file:write(entry .. "\n")
        file:close()
    else
        vim.api.nvim_err_writeln("Unable to open tasks.log for writing.")
    end
end

-- Command completion
local function task_complete(arglead, cmdline, cursorpos)
    return {'log', 'summary', 'edit', 'day', 'month'}
end

local function summary_complete(arglead, cmdline, cursorpos)
    return {'day', 'month'}
end

if vim ~= nil and vim.api.nvim_create_user_command ~= nil then
-- Register commands
-- function M.setup()
vim.api.nvim_create_user_command('Tasklog',
    function(args)
        local cmd = args.fargs[1]
        if cmd == 'help' then
            print("Tasklog commands:")
            print(":Tasklog log <task description> - Log a task")
            print(":Tasklog summary [day|month] - Show summary of tasks")
            print(":Tasklog edit - Open the log file")
            return
        end
        argvs = args.fargs
        if cmd == 'log' then
            table.remove(argvs,1)
        end
        local subcmd = args.fargs[1]
        if subcmd == 'edit' then
            M.edit()
        elseif subcmd == 'summary' then
            table.remove(argvs,1)
            if #argvs == 0 then
                argvs[1] = 'day'
            end
            args.fargs = argvs
            M.show_summary(args)
        else
            args.fargs = argvs
            M.log_task(args)
        end
    end, {
        nargs = '+',
        complete = task_complete,
    })
end
-- end
if vim ~= nil and vim.api.nvim_set_keymap ~= nil then
    vim.api.nvim_set_keymap('n', '<localleader>ts', '<cmd>Tasklog summary<CR>', {noremap = true, silent = true})
end

return M
