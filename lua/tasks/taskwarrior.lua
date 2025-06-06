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

    -- date = '%d%d%d%d%-[0-1]%d%-[0-3]%d%]',
local TaskWarrior = {
    _context = 'none',
    debug = false,
    prefix = '',

    fields = {
        status      = {
            type = 'string',
        },
        uuid        = {
            type = 'UUID',
        },
        entry       = {
            type = 'date',
        },
        description = {
            type = 'string',
        },
        start       = {
            type = 'date',
        },
        due         = {
            type = 'date',
        },
        wait        = {
            type = 'date',
        },
        modified    = {
            type = 'date',
        },
        scheduled   = {
            type = 'date',
        },
        recur       = {
            type = 'string',
        },
        mask        = {
            type = 'string',
        },
        imask       = {
            type = 'integer',
        },
        parent      = {
            type = 'UUID',
        },
        project     = {
            type = 'string',
        },
        priority    = {
            type = 'string',
        },
        depends     = {
            type = 'string',
        },
        tags        = {
            type = 'string',
        },
        annotation  = {
            type = 'string',
        },
        filename    = {
            type = 'string',
        },
        line_number = {
            type = 'string',
        },
    },
}

TW = TaskWarrior
function TaskWarrior.mkdebug()
    if TW.debug then
        TW.prefix = 'export TASKDATA=/tmp/.task/ && '
    else
        TW.prefix = ''
    end
end
if TaskWarrior.debug then
    TW.prefix = 'export TASKDATA=/tmp/.task; '
end

--- @brief Run a command on the task
--- @param cmd string
--- @param uuid string
--- @param ... string
--- @return string output
function TaskWarrior.run_cmd(cmd, uuid, ...)
    local args = ... or ''
    cmd = TW.prefix .. "task " .. uuid .. " " .. cmd .. " " .. args
    print('run_cmd: cmd: ', cmd)
    local out = require'tasks.util'.run(cmd)
    return out
end

--- @brief Get a taskwarrior task
--- @param uuid string
--- @return table task
function TaskWarrior.get_task(uuid)
    if uuid == nil or uuid == '' then
        print('get_task: uuid is nil or empty')
        return nil
    end

    local cmd = TW.prefix .. "task " .. uuid .. " export"
    print('get_task: cmd: ', cmd)
    local json = require'tasks.util'.run(cmd)
    print('json from get_task: ', json)
    local data = require'dkjson'.decode(json)
    if #data > 0 then
        data = data[1]
    end
    return data
end

--- @brief Import a taskwarrior json file
--- @param filename string
--- @return table uuids
function TaskWarrior.import_file(filename)
    local str_uuids =  require'util'.run(TW.prefix .. "task import " .. filename)
    return TaskWarrior.get_uuids(str_uuids)
end

--- @brief Import a taskwarrior json tasks string
--- @param json string
--- @return table uuids
function TaskWarrior.import(json)
    local prefix = ''
    local cmd = prefix .. "echo '" .. json .. "' | task import "
    print('import: cmd: ', cmd)
    local uuids =  require'tasks.util'.run(cmd)
    if uuids == nil or uuids == '' then
        print('import: uuids is nil or empty')
        return nil
    end
    out = TaskWarrior.get_uuids(uuids) -- uuids are strings
    if out == nil or #out == 0 then
        print('import: out is nil or empty')
        return nil
    end
    return out
end

-- @brief set or get the current context
-- @param context string
-- @return string cmd output
function TaskWarrior.context(context)
    if context == nil then
        context = ''
    end
    TaskWarrior._context = context

    return require'tasks.util'.run(TW.prefix .. "task context " .. context)
end

--- @brief set a task into a taskwarrior db
--- @param task table
--- @return string uuid
function TaskWarrior.set_task(task)
    local str_task = ''
    if type(task) == 'table' then
        str_task = require'cjson'.encode(task)
    else
        str_task = task
    end
    local uuids = TaskWarrior.import(str_task)

    return uuids[1] or ''
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
    -- print('get_uuids: str: ', import_out)
    -- print('get_uuids: uuids: ', vim.inspect(uuids))

    return uuids
end

--- @brief Import a taskwarrior json string
--- @param task table
--- @return string uuid
function TaskWarrior.update_task(task)
    local str_task = ''
    if type(task) == 'table' then
        str_task = require'cjson'.encode(task)
    else
        str_task = task
    end
    local uuids = TaskWarrior.import(str_task)

    return uuids[1] or ''
end



--- @brief Import a taskwarrior json string
--- @param task table
--- @return string
function TaskWarrior.delete_task(task)
    cmd = TW.prefix .. "yes | task " .. task.uuid .. " delete"

    vim.ui.input({prompt = 'delete task ' .. task.uuid .. '? (y|N) '},
        function(input)
            if input == nil then
                print('delete_task: user cancelled')
                return nil
            end
            if input == 'y' or input == 'yes' then
                return require'tasks.util'.run(cmd)
            else
                print('delete_task: user cancelled')
                return nil
            end
        end
    )
end

--- @brief start a task
--- @param task table
function TaskWarrior.start_task(task)
    return TaskWarrior.run_cmd('start', task.uuid)
end

--- @brief add a new task
--- @param task table jsonified task
function TaskWarrior.add_task(task)
    json = vim.json.encode(task)
    if json == nil or json == '' then
        print('add_task: json is nil or empty')
        return nil
    end
    return TaskWarrior.import(json)
end



--- @brief stop a task
--- @param task table
function TaskWarrior.stop_task(task)
    return TaskWarrior.run_cmd('stop', task.uuid)
end


--- @brief mark a task as done
--- @param task table
function TaskWarrior.complete_task(task)
    if task == nil or task.uuid == nil then
        print('complete_task: task is nil or doesnt have uuid')
        return nil
    end
    return TaskWarrior.run_cmd('done', task.uuid)
end


--- @brief add an annotation to a task
--- @param task table
--- @param annotation string
--- @return string
function TaskWarrior.annotate_task(task, annotation)
    return TaskWarrior.run_cmd('annotate', task.uuid,annotation)
end


--- @brief remove an annotation from a task
--- @param task table
--- @param annotation string
--- @return string
function TaskWarrior.denotate_task(task, annotation)
    return TaskWarrior.run_cmd('denotate', task.uuid, annotation)
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
_G.TaskWarrior = TaskWarrior
return _G.TaskWarrior
