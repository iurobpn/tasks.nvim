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
---@return string
function M.tostring(task)
    local nonmtags = {
        'description',
        'status',
        'due',
        'tags',
        'filename',
        'line_number',
    }
    local status
    if task.status == 'not started' then
        status = ' '
    elseif task.status == 'in progress' then
        status = '.'
    elseif task.status == 'done' then
        status = 'x'
    end

    local due = ''
    if task.due ~= nil then
        due = string.format('[%s:: %s]', 'due', task.due)
    end
    local tags = table.concat(task.tags,' ')
    local file = '| ' .. task.filename .. ':' .. task.line_number

    local utils = require'utils'
    local mtags = ''
    if task then
        for k,v in pairs(task) do
            if not utils.contains(nonmtags,k) then
                mtags = mtags .. string.format(' [%s:: %s]', k, v)
            end
        end
    end
    local line = string.format('- [%s] %s %s %s %s %s', status, task.description, tags, due, mtags, file, uuid)
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

