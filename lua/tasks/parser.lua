#!/usr/local/bin/lua
local M = {
    pattern = {
        status = '%- %s*%[%s*([xv ])%s*%]',
        filename = '[/]?[a-zA-ZçÇãõóéá]+.*%.md',
        line_number = ':(%d+):',
        description = '%-%s*%[%s*[a-z ]%s*%]%s*(.*)',
        tag = '(#[a-zA-Z_%-]+)',
        parameter = '%[([a-zA-Z_]+)%s*::%s*([a-zA-Z0-9:%s%-]*)%]',
        metatag = {'%[', '%s*::%s*([a-zA-Z0-9:%- ]*)%]'}, -- a specific metatag
        uuid='@{[a-zA-Z0-9%-]+}',
    },

    fields = {
        Status      = {
            type = 'string',
            pattern = '%- %s*%[%s*([xv ])%s*%]',
        },
        Uuid        = {
            type = 'hex',
            pattern = '@{[a-zA-Z0-9%-]+}',
        },
        Entry       = {
            type = 'date',
            pattern = '',
        },
        Description = {
            type = 'string',
            pattern = '%-%s*%[%s*[a-z ]%s*%]%s*(.*)',
        },
        Start       = {
            type = 'date',
            pattern = '',
        },
        End         = {
            type = 'date',
            pattern = '',
        },
        Due         = {
            type = 'date',
            pattern = '',
        },
        Until       = {
            type = 'date',
            pattern = '',
        },
        Wait        = {
            type = 'date',
            pattern = '',
        },
        Modified    = {
            type = 'date',
            pattern = '',
        },
        Scheduled   = {
            type = 'date',
            pattern = '',
        },
        Recur       = {
            type = 'string',
            pattern = '',
        },
        Mask        = {
            type = 'string',
            pattern = '',
        },
        Imask       = {
            type = 'integer',
            pattern = '',
        },
        Parent      = {
            type = 'UUID',
            pattern = '',
        },
        Project     = {
            type = 'string',
            pattern = '',
        },
        Priority    = {
            type = 'string',
            pattern = '',
        },
        Depends     = {
            type = 'string',
            pattern = '',
        },
        Tags        = {
            type = 'string',
            pattern = '(#[a-zA-Z_%-]+)',
        },
        Annotation  = {
            type = 'string',
            pattern = '',
        },
        Filename    = {
            type = 'string',
            pattern = '[/]?[a-zA-ZçÇãõóéá]+.*%.md',
        },
        Line_number = {
            type = 'string',
            pattern = ':(%d+):',
        },
        Parameter   = {
            type = 'string',
            pattern = '%[([a-zA-Z_]+)%s*::%s*([a-zA-Z0-9:%s%-]*)%]',
        },
    },
}

-- Parse a task string into a table
function M.find_metatags(task)
    local metatags = {}
    for mtag in task:gmatch(M.pattern.parameter) do
        table.insert(metatags, mtag)
        task = task:gsub(M.pattern.parameter, '')
    end
    return metatags, task
end

function M.get_param_value(task,metatag)
    local pattern = '%[' .. metatag .. '%s*::%s*([a-zA-Z0-9:%- ]*)%]'
    return task:match(pattern)
end

function M.parse(task)
    local status_map = {
        ["[x]"] = "done",
        ["[v]"] = "in progress",
        ["[ ]"] = "not started"
    }

    -- Extract the status and remove it from the task string
    local status = task:match(M.pattern.status)
    if status == nil then
        print('No status found in task: ' .. task)
        return
    end
    status = '[' .. status .. ']'

    status = status_map[status] or "not started yet"

    local parameters = {}

    local uuid = task:match(M.fields.Uuid.pattern)
    local filename = task:match(M.pattern.filename)
    -- task = task.gsub(task, M.pattern.filename, '')
    local line_number = tonumber(task:match(M.pattern.line_number))
    local description = task:match(M.pattern.description)
    local tags = {}
    for tag in task:gmatch(M.pattern.tag) do
        tags[#tags+1] = tag
        description = description:gsub(M.pattern.tag, '')
    end
    local k = 0
    for param, value in task:gmatch(M.pattern.parameter) do
        parameters[param] = value
        description = description:gsub(M.pattern.parameter .. '%s*', '')
        k = k + 1
    end

    if filename == nil or line_number == nil or description == nil then
        print('Could not parse task: ' .. task)
        return
    end
    local task_t = {
        uuid = uuid,
        filename = filename,
        line_number = line_number,
        status = status,
        description = description:match('^%s*(.*)%s*$'),
        tags = tags,
    }
    for k, v in pairs(parameters) do
        task_t[k] = v
    end

    return task_t
end



-- Main function to handle input from stdin and output to stdout
function M.run()
    for line in io.lines() do
        -- Extract filename and line number
        local parsed_task = M.parse_task(line)
        local json_output = require"cjson".encode(parsed_task, { indent = true, level = 4 })  -- Pretty print with 4 spaces
    end
end

-- Run the main function
-- main()

return M
