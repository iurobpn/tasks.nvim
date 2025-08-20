local M = {
    filename = '',
    file = 'tasks.json',
    folder = '.tasks',
    path = os.getenv('HOME') .. '/pkm',
    backend = 'jq',
}
M.filename = M.path .. '/' .. M.folder .. '/' .. M.file

-- Example usage
-- local output = get_command_output("fish -c 'echo Hello from Fish!'")
-- read and parse tasks from the notes to a lua table
-- @param folder str --folder with the notes
-- @return: a table of tasks
function M:read_notes(folder)
    if folder ~= nil and folder ~='' then
        folder = self.path
    end
    if self.path == nil or self.path == '' then
        print('path is nil')
        return
    end
    -- local source = debug.getinfo(1, "S").source
    -- local source_dir = source:sub(2) .. '/../../scripts'
    local raw_tasks = require"tasks.find".find_tasks(folder)
    local id_counter =  1

    if raw_tasks == nil then
        print('find_tasks returned nil')
        return
    end

    raw_tasks  = require"katu.utils".split(raw_tasks, '\n')
    if raw_tasks == nil then
        print('splitted tasks are nil')
        return
    end

    local tasks = {}
    local parser = require"tasks.parser"
    for _, line in ipairs(raw_tasks) do
        local task = parser.parse(line)
        if task == nil then
            print('parser failed to parse the task')
        else
            task.id = id_counter
            id_counter = id_counter + 1
            table.insert(tasks, task)
        end
    end

    return tasks
end

function M:get_fullpath()
    return self.path .. '/' .. self.folder .. '/' .. self.file
end

function M:ensure_path()
    local path = self.path .. '/' .. self.folder
    if not require"katu.utils.fs".file_exists(path) then
        os.execute("mkdir -p " .. path)
    end
end

-- write to filçe db
function M:write(tasks)
    self:ensure_path()
    require('tasks.' .. self.backend).write(tasks, _G.tasks:get_filename())
end

local mod = {
    Indexer = M
}
-- get a indexer
-- @param folder str --folder with the notes
-- @param filename str --filename of the notes
function mod.index(folder,filename)
    local indexer = mod.Indexer(folder, filename)

    if indexer == nil then
        print('indexer object is nil')
        return
    end
    local tasks = indexer:read_notes()
    indexer:write(tasks)
end
function mod.index_process(folder, filename)
    if folder == nil then
        folder = mod.Indexer.folder
    end
    if filename == nil then
        filename = mod.Indexer.filename
    end
    local res, err = pcall(os.execute,[[
        lua -e '
            local indexer = require("tasks").get_indexer("]] .. folder .. ',' .. filename .. [[")
            local tasks = indexer:read_notes()
            indexer:write(tasks)
        '
        ]])
    if not res then
        print('Error executing command: ' .. err)
    else
        print('Indexing output: ' .. tostring(res))
    end
end
function mod.index_thread()
    Thread = require'thread'
    local thread = Thread(
        function()
            local Tasks = require'tasks'
            if Tasks == nil then
                print('Tasks object is nil')
                return
            end
            I=require"inspect"
            print("Tasks: " .. I(Tasks))
            local Indexer = Tasks.Indexer
            print("Indexer: " .. I(Indexer))
            local indexer = Indexer()
            print("indexer: " .. I(indexer))
            if indexer == nil then
                print('indexer object is nil')
                return
            end
            local tasks = indexer:read_notes()
            indexer:write(tasks)
        end
    )
    thread:start()
    thread.running = false
end

require"katu.utils.class"
M = _G.class(M, {constructor = function(folder, filename)
    local obj = {}
    if folder ~= nil then
        obj.folder = folder
    end
    if filename ~= nil then
        obj.filename = filename
    end
    return obj
end}
)

return mod

