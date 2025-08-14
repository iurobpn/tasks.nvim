TaskWarrior = require'tasks.TaskWarrior'

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
    local data = require'tasks.util'.json_decode(str)
    copy(data, self.data)
    self.dirty = 0
end

function Task:save()
    if self.dirty == 0 then
        return
    end
    save_task(task)
end

function Task:start()
    TaskWarrior.start_task(self)
end
function Task:stop()
    TaskWarrior.stop_task(self)
end
function Task:done()
    TaskWarrior.done_task(self)
end
function Task:add_annotation(annotation)
    if not annotation then
        return
    end
    TaskWarrior.add_annotation(self, annotation)
end
function Task:remove_annotation(annotation)
    if not annotation then
        return
    end
    TaskWarrior.remove_annotation(self, annotation)
end

function Task:delete()
    TaskWarrior.delete_task(self)
end



return Task
