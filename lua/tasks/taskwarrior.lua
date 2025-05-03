-- A taskwarrior backend module

local TaskWarrior = {

}

--- @brief Import a taskwarrior json file
--- @param filename string
--- @return table uuids
function TaskWarrior.import_file(filename)
    local str_uuids =  require'util'.run("task import " .. filename)
    return TaskWarrior.get_uuids(str_uuids)
end

--- @brief Import a taskwarrior json tasks string
--- @param task string
--- @return table uuids
function TaskWarrior.import(task)
    local uuids =  require'util'.run("echo '" .. task "' | task import ")
    return TaskWarrior.get_uuids(uuids) -- uuids are strings
end

--- from the output of an import command, recover the uuids to update the tasks
--- @param import_out string
--- @return table uuids
function TaskWarrior.get_uuids(import_out)
    local pattern = "^%s+%w+%s+([0-9a-f%-]+) .*"
    local uuids = {}
    for line in import_out:gmatch("[^\r\n]+") do
        local id = line:match(pattern)
        if id then
            table.insert(uuids, id)
        end
    end
    return uuids
end

--- @brief Import a taskwarrior json string
--- @param task table
--- @return string uuid
function TaskWarrior.save_task(task)
    local str_task = require'cjson'.encode(task.data)
    local uuids = TaskWarrior.import(str_task)

    return uuids[1] or ''
end


-- @abc.abstractmethod
function TaskWarrior.delete_task(task)
end


-- @abc.abstractmethod
function TaskWarrior.start_task(task)
end


-- @abc.abstractmethod
function TaskWarrior.stop_task(task)
end


-- @abc.abstractmethod
function TaskWarrior.complete_task(task)
end


-- @abc.abstractmethod
function TaskWarrior.refresh_task(task, after_save)
    -- Refreshes the given task. Returns new data dict with serialized attributes.
    --after_save=False)
end

-- @abc.abstractmethod
function TaskWarrior.annotate_task(task, annotation)
end


-- @abc.abstractmethod
function TaskWarrior.denotate_task(task, annotation)
end


-- @abc.abstractmethod
function TaskWarrior.sync(tasks)
    -- Syncs the backend database with the taskd server
end


function TaskWarrior.convert_datetime_string(value)
    --[[
    Converts TaskWarrior. syntax datetime string to a localized datetime
        object. This method is not mandatory.
    --]]
end

-- local fname = 'tasks.json'
local fname = 'out.txt'
-- local fd = io.popen("task import " .. fname)
local util = require'util'
local out = util.read(fname)
print(out)
out = TaskWarrior:get_uuids(out)
print('out: ')
print(require'inspect'.inspect(out))

_G.TaskWarrior = TaskWarrior
return TaskWarrior
