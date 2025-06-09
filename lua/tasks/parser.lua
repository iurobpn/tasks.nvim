#!/usr/local/bin/lua
local M = {
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
            ' ([%a_]+):([%w:%-]+) ',
            {
                get = '%[([%a_]+):: +([^%]]+)%]',
                sub = '%[[%a_]+:: +[^%]]+%]'
            },
        },
        tag = {
            '[#+](%w[%w%d/_%-]*)',
        },
        description = {
            '%- %[[a-z ]%] +(.*) *',
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
        if type(pattern) == 'table' then
            -- If the pattern is a table, use the get pattern
            pattern = pattern.get
        end
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

    task = task:gsub('%(', '%('):gsub('%)', '%)')
    local task_t = {}
    task_t.status = status_map[status] or "pending"

    for item, patterns in pairs(M.patterns) do
        if item ~= 'param' and item ~= 'tag' and item ~= "status" then
            for _,pattern in ipairs(patterns) do
                local it = task:match(pattern)
                if it then
                    task_t[item] = it
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
        local sub_pattern, get_pattern
        if type(pattern) == 'table' then
            sub_pattern = pattern.sub
            get_pattern = pattern.get
        else
            sub_pattern = pattern
            get_pattern = pattern
        end

        for param, value in task:gmatch(get_pattern) do
            task_t[param] = value
            local desc = task_t.description:gsub('%s*' .. sub_pattern .. '%s*', '')
            if desc ~= nil and desc ~= '' then
                task_t.description = desc
            else
                print('No description found for task: ' .. require'inspect'.inspect(task))
                break
            end
        end
    end
    -- for _, pattern in ipairs(M.patterns.param) do
    --     print('pattern: ' .. vim.inspect(pattern))
    --     local sub_pattern, get_pattern
    --     if type(pattern) == 'table' then
    --         sub_pattern = pattern.sub
    --         get_pattern = pattern.get
    --     else
    --         sub_pattern = pattern
    --         get_pattern = pattern
    --     end
    --     for param, value in task:gmatch(get_pattern) do
    --         task_t[param] = value
    --         local desc = task_t.description:gsub('%s*' .. sub_pattern .. '%s*', '')
    --         if desc ~= nil and desc ~= '' then
    --             task_t.description = desc
    --         else
    --             vim.notify('No description found for task: ' .. vim.inspect(task), vim.log.levels.WARN)
    --             break
    --         end
    --     end
    -- end

    if task_t.description == nil then
        print('Task has no description ' .. task)
    else
        task_t.description = task_t.description:gsub('%s+$', '')
        task_t.description = task_t.description:gsub('^%s+', '')
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
