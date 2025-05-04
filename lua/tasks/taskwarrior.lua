-- A taskwarrior backend module

-- TESTING
-- taskrc: TASKRC='/home/user/.taskrc', to make use of another taskrc
-- task rc:/home/user/.taskrc, to make use of another taskrc
-- TASKDATA=/tmp/.task/ task ...

-- @brief taskwarrior backend
-- @details
-- - this module is used to interact with taskwarrior
-- - it uses the task command line interface to run commands
-- - it uses the cjson library to encode/decode json data
-- - it uses the util module to run commands and read files
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
    local uuids =  require'util'.run("echo '" .. task .. "' | task import ")
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

--- @brief Import a taskwarrior json string
--- @param task table
--- @return string
function TaskWarrior.delete_task(task)
    return TaskWarrior.run_cmd('delete', task.data.uuid)
end

--- @brief start a task
--- @param task table
function TaskWarrior.start_task(task)
    return TaskWarrior.run_cmd('start', task.data.uuid)
end

--- @brief Run a command on the task
--- @param cmd string
--- @param uuid string
--- @param ... string
--- @return string output
function TaskWarrior.run_cmd(cmd, uuid, ...)
    local args = ... or ''
    cmd = "task " .. uuid .. " " .. cmd .. " " .. args
    local out = require'util'.run(cmd)
    return out
end


--- @brief stop a task
--- @param task table
function TaskWarrior.stop_task(task)
    return TaskWarrior.run_cmd('stop', task.data.uuid)
end


--- @brief mark a task as done
--- @param task table
function TaskWarrior.complete_task(task)
    return TaskWarrior.run_cmd('done', task.data.uuid)
end


--- @brief add an annotation to a task
--- @param task table
--- @param annotation string
--- @return string
function TaskWarrior.annotate_task(task, annotation)
    return TaskWarrior.run_cmd('annotate', task.data.uuid,annotation)
end


--- @brief remove an annotation from a task
--- @param task table
--- @param annotation string
--- @return string
function TaskWarrior.denotate_task(task, annotation)
    return TaskWarrior.run_cmd('denotate', task.data.uuid, annotation)
end


--- @brief sync the taskwarrior database with the server
--- @param tasks table
--- @return string
function TaskWarrior.sync(tasks)
    -- Syncs the backend database with the taskd server
end


--- @brief convert a datetime string to a localized datetime object
--- @param value string
--- @return table
function TaskWarrior.convert_datetime_string(value)
    --[[
    Converts TaskWarrior. syntax datetime string to a localized datetime
        object. This method is not mandatory.
    --]]
end

return TaskWarrior
