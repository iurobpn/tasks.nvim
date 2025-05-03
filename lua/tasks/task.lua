local fname = 'tasks.json'

local data = {
    uuid = nil,
    id = nil,
    description = nil,
    status = nil,
    project = nil,
    tags = {},
}

local Task = {
    data = data,
    dirty = 0,
}

Task.__index = data
Task.__newindex = function(t, k, v)
    t.dirty = 1
    t.data[k] = v
end

function Task:new(o)
    o = o or {}
    setmetatable(o, self)
    return o
end

local function copy(src,dest)
    for k,v in pairs(src) do
        dest[k] = v
    end
end

-- from string
function Task:load(str)
    local data = require'cjson'.decode(str)
    copy(data, self.data)
    self.dirty = 0
end

function Task:save()
    if self.dirty == 0 then
        return
    end
    require'TaskWarrior'.save_task(task)
end

--- commands - make use of taskwarrior backend
---
-- update task with taskwarrior data
function Task:update()
end

function Task:start()
end
function Task:stop()
end
function Task:done()
end
function Task:add_annotation()
end
function Task:remove_annotation()
end


return Task
