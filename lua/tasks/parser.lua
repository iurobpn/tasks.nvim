#!/usr/local/bin/lua
local M = {
    -- pattern = {
    --     status = '%- %s*%[%s*([xv ])%s*%]',
    --     filename = '[/]?[a-zA-ZçÇãõóéá]+.*%.md',
    --     line_number = ':(%d+):',
    --     description = '%-%s*%[%s*[a-z ]%s*%]%s*(.*)',
    --     tag = '(#[a-zA-Z_%-]+)',
    --     parameter = '%[([a-zA-Z_]+)%s*::%s*([a-zA-Z0-9:%s%-]*)%]',
    --     metatag = {'%[', '%s*::%s*([a-zA-Z0-9:%- ]*)%]'}, -- a specific metatag
    --     uuid='@{[a-zA-Z0-9%-]+}',
    -- },
    patterns = {
        uuid = {
            '@{(%x+-%x+-%x+-%x+)}',
        },
        status = {
            '%- %s*%[%s*([xv ])%s*%]',
        },
        param = {
            '%[([%a_]+)%s*::%s*([%w:%s%-]*)%]',
            '%[([%a_]+):([%w:%-]*)%]',
        },
        tag = {
            '([#+]%w[%w%d/_%-])',
        },
        description = {
            '%-%s*%[%s*[a-z ]%s*%]%s*(.*)',
        },
        filename = {
            '[/]?[a-zA-ZçÇãõóéá]+.*%.md',
        },
        linenr = {
            ':(%d+):',   
        },
    },
}

function M.parse(task)
    local status_map = {
        ["[x]"] = "completed",
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
    local task_t = {}
    task_t.status = status;

    for item in M.patterns do
        if item ~= 'param' and item ~= 'tag' then
            for pattern in item do
                local it = task:match(pattern)
                if it then
                    task_t[item] = it
                end
            end
        end
    end


    task_t.tags = {}
    for pattern in M.patterns.tag do
        for tag in task:gmatch(pattern) do
            table.insert(task_t.tags, tag)
            task_t.description = description:gsub(pattern, '')
        end
    end
    for pattern in M.patterns.param do
        for param, value in task:gmatch(pattern) do
            task_t[param] = value
            description = description:gsub(pattern .. '%s*', '')
            k = k + 1
        end
    end

    if task_t.filename == nil or task_t.line_number == nil or task_t.description == nil then
        print('Could not parse task: ' .. task)
        return
    end
    task_t.description = task_t.description:match('^%s*(.*)%s*$')

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
