local M = {}

---------------- FORMAT methods -----------------------------
---convert task to a short string
---@param task table 
---@return string
function M.toshortstring(task)
    local mtags = ''
    local utils = require'utils'
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
---@param fields table
---@return string
function M.tostring(task, fields)
    if fields == nil then
        fields = {
            'description',
            'status',
            'due',
            'tags',
            'filename',
            'linenr',
        }
    else
        if not tbl.contains(fields,'filename') then
            table.insert(fields, 'filename')
        end
        if not tbl.contains(fields,'linenr') then
            table.insert(fields, 'linenr')
        end
    end

    local status
    print('task status; ' .. task.status)
    if task.status == 'pending' then
        status = ' '
    elseif task.status == 'working' then
        status = '.'
    elseif task.status == 'completed' then
        status = 'x'
    end

    local due = ''
    if task.due ~= nil then
        due = string.format('[%s:: %s]', 'due', task.due)
    end

    local tags = ''
    if task.tags ~= nil then
        tags = '#' .. table.concat(task.tags,' #')
    end

    local file = ''
    if task.filename ~= nil and task.linenr ~= nil then
        file = '| ' .. task.filename .. ':' .. task.linenr
    end

    local tbl = require'utils.tbl'
    local mtags = ''
    if task then
        for k,v in pairs(task) do
            if tbl.contains(fields,k) then
                mtags = mtags .. string.format(' [%s:: %s]', k, v)
            end
        end
    end

    local uuid = task.uuid
    if uuid == nil then
        uuid = ''
    else
        uuid = string.format('@{%s}', uuid)
    end
    local line = string.format('- [%s] %s %s %s %s %s %s', status, task.description, tags, due, mtags, file, uuid)

    return line
end

--- convert a metatag to a string
---@param mtag string
---@param val any
---@return string
-- function M.mtag_to_string(mtag,val)
--     return string.format('[%s:: %s]', mtag, val)
-- end

-- these should on a formatter class
function M.params_to_string(parameters)
    local str = ''
    for k,v in pairs(parameters) do
        str = str .. '[' .. k .. ':: ' .. v .. '] '
    end
    return str
end
function M.tags_to_string(tags)
    local str = ''
    for _,tag in ipairs(tags) do
        str = str ..  tag .. ' '
    end
    return str
end
-- this should be in a formatter class - end

---------------- FORMAT methods -----------------------------
return M

