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
            '@{(%x+%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x+)}',
            -- '@{(%x[%x%-]+%x)}',
            -- '@{(.*)}',
        },
        status = {
            '%- %s*%[%s*([xv ])%s*%]',
        },
        param = {
            '%[([%a_]+)%s*::%s*([%w:%s%-]*)%]',
            '%[([%a_]+):([%w:%-]*)%]',
        },
        tag = {
            '([#+]%w[%w%d/_%-]*)',
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

--- @brief get a value from a parameter:value pair in a line task 
--- @param line string
--- @param param string
--- @return string
function M.get_param_value(line, param)
    -- Check if the line contains the parameter
    for _, pattern in ipairs(M.patterns.param) do
        for key, value in line:gmatch(pattern) do
            -- Extract the value of the parameter
            if key == param then
                return value
            end
        end
    end
    return ''
end

--- @brief get uuid from a line task
--- @param line string
--- @return string
function M.get_uuid(line)
    -- Check if the line contains the uuid
    for _, pattern in ipairs(M.patterns.uuid) do
        for uuid in line:gmatch(pattern) do
            return uuid
        end
    end
    return ''
end

function M.parse(task)
    local status_map = {
        ["x"] = "completed",
        [" "] = "pending"
    }

    -- Extract the status and remove it from the task string
    local status = task:match(M.patterns.status[1])
    if status == nil then
        print('No status found in task: ' .. task)
        return
    end

    local task_t = {}
    task_t.status = status_map[status] or "pending"

    for item, patterns in pairs(M.patterns) do
        if item ~= 'param' and item ~= 'tag' and item ~= "status" then
            for _,pattern in ipairs(patterns) do
                local it = task:match(pattern)
                if it then
                    task_t[item] = it
                    task = task:gsub(pattern, '')
                else
                    -- print('Task: ' .. task .. ' does not match pattern: ' .. pattern)
                end
            end
        end
    end


    task_t.tags = {}
    for _,pattern in ipairs(M.patterns.tag) do
        for tag in task:gmatch(pattern) do
            table.insert(task_t.tags, tag)
            task_t.description = task_t.description:gsub(pattern, '')
        end
    end
    for _, pattern in ipairs(M.patterns.param) do
        for param, value in task:gmatch(pattern) do
            task_t[param] = value
            task_t.description = task_t.description:gsub(pattern .. '%s*', '')
        end
    end

    if task_t.description == nil then
        print('Task has no description ' .. task)
    else
        task_t.description = task_t.description:match('^%s*(.*)%s*$')
    end

    -- print('task_t ' .. vim.inspect(--[[ta --]]sk_t))

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
