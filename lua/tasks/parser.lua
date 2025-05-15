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
        uuid='@{([a-zA-Z0-9%-]+)}',
    },

    fields = {
        status      = {
            type = 'string',
            pattern = '%- %s*%[%s*([xv ])%s*%]',
        },
        uuid        = {
            type = 'hex',
            pattern = '@{([a-zA-Z0-9%-]+)}',
        },
        entry       = {
            type = 'date',
            pattern = '',
        },
        description = {
            type = 'string',
            pattern = '%-%s*%[%s*[a-z ]%s*%]%s*(.*)',
        },
        start       = {
            type = 'date',
            pattern = '',
        },
        due         = {
            type = 'date',
            pattern = '',
        },
        wait        = {
            type = 'date',
            pattern = '',
        },
        modified    = {
            type = 'date',
            pattern = '',
        },
        scheduled   = {
            type = 'date',
            pattern = '',
        },
        recur       = {
            type = 'string',
            pattern = '',
        },
        mask        = {
            type = 'string',
            pattern = '',
        },
        imask       = {
            type = 'integer',
            pattern = '',
        },
        parent      = {
            type = 'UUID',
            pattern = '',
        },
        project     = {
            type = 'string',
            pattern = '',
        },
        priority    = {
            type = 'string',
            pattern = '',
        },
        depends     = {
            type = 'string',
            pattern = '',
        },
        tags        = {
            type = 'string',
            pattern = '(#[a-zA-Z_%-]+)',
        },
        annotation  = {
            type = 'string',
            pattern = '',
        },
        filename    = {
            type = 'string',
            pattern = '[/]?[a-zA-ZçÇãõóéá]+.*%.md',
        },
        line_number = {
            type = 'string',
            pattern = ':(%d+):',
        },
        parameter   = {
            type = 'string',
            pattern = '%[([a-zA-Z_]+)%s*::%s*([a-zA-Z0-9:%s%-]*)%]',
        },
    },
}
M["end"] = {
    type = 'date',
    pattern = '',
}
M["until"] = {
    type = 'date',
    pattern = '',
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
        ["[x]"] = "completed",
        ["[v]"] = "working",
        ["[ ]"] = "pending"
    }

    -- Extract the status and remove it from the task string
    local status = task:match(M.pattern.status)
    if status == nil then
        print('No status found in task: ' .. task)
        return
    end
    status = '[' .. status .. ']'

    status = status_map[status] or "not started yet"
    print('status: ' .. status)

    local parameters = {}

    local uuid = task:match(M.fields.uuid.pattern)
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

    if description == nil then
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

    print('task_t ' .. vim.inspect(task_t))

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
