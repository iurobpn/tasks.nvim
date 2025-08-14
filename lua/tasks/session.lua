local class = require('katu.utils.class')

local M = {
    id_counter = 0,
    filename = '.session.json',
    path = '~',
    sessions = {},
    works = {},
    current_work = nil,
    tasks = {},

    --types
    Work = nil,
    Task = nil,
    Session = nil,
}

M.to_json = function()
    return {
        sessions = M.sessions,
        works = M.works,
        tasks = M.tasks,
    }
end

M.Task = {
    id = nil,
    name = '',
    description = '',
    project = '',
    time_spent = '',
    estimated_time = '',
    time_remaining = '',
    status = '',
    priority = '',
    time_created = '',
    time_completed = ''
}

M.Session = {
    name = '',
    description = '',
    work_sessions = {},
    tasks = {}
}

M.Work = {
    task_id = nil,
    name = '',
    description = '',
    start_time = '',
    total_time = '',
    end_time = '',
}

Work = class(Work)

M.init = function()
    if not require"fs".file_exists(M.path .. '/' .. M.filename) then
        local file = io.open(M.path .. '/' .. M.filename, 'w')
        file:write('{}')
        file:close()
    end
end

M.load = function()
    local file = io.open(M.path .. '/' .. M.filename, 'r')
    local content = file:read('*a')
    file:close()

    M.sessions = json.decode(content)
end

M.start = function()
    local work = M.Work()
    work.task_id = M.get_id()
    work.start_time = os.date('%Y-%m-%d %H:%M:%S')
    M.current_work = work
    work.status = 'active'
    table.insert(M.works, work)
    -- local json = tbl.to_json(M.to_json())
end

M.stop = function()
    M.current_work.end_time = os.date('%Y-%m-%d %H:%M:%S')
    M.current_work.total_time = os.difftime(M.current_work.end_time, M.current_work.start_time)
    M.current_work.status = 'ended'
end

M.save = function()
    local file = io.open(M.path .. '/' .. M.filename, 'w')
    local tbl = require('dev.lua.tbl')
    file:write(tbl.to_json(M.to_json()))
    file:close()
end

M.get_id = function()
    M.id_counter = M.id_counter + 1
    return M.id_counter
end

-- function to periodically save the session
M.save_session = function()
    local t_period = 30000
    -- save the settings every 30 s
    vim.defer_fn(function()
        M.save()
    end, t_period)
end

--[[
json format

{
    "session": {
        "name": "session",
        "description": "session description",
        "templates": {
            "root": "path/to/templates",
            "files": [
                {
                    "name": "file1",
                    "description": "file1 description",
                    "path": "path/to/file1",
                    "content": "file1 content"
                },
                {
                    "name": "file2",
                    "description": "file2 description",
                    "path": "path/to/file2",
                    "content": "file2 content"
                }
            ]
        }
    }
# task json
{
    "tasks": [
    {
        "name": "task name",
        "description": "task description",
        "project": "project name",
        "time_spent": "timestamp",
        "estimated_time": "timestamp",
        "time_remaining": "timestamp",
        "status": "status",
        "priority": "priority",
        "time_created": "timestamp",
        "time_completed": "timestamp",
    },
    ...
    ]
-- simplified version
    "tasks": [
    {
        "name": "task name",
        "description": "task description",
        "project": "project name",
        "time_spent": "timestamp",
        "estimated_time": "timestamp",
        "time_remaining": "timestamp",
        "status": "status",
        "priority": "priority",
        "time_created": "timestamp",
        "time_completed": "timestamp",
    },
    ...
    ]
}
--]]

