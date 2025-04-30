require('class')

local utils = require'utils'
local Sql = require('dev.lua.sqlite').Sql
local json = require('cjson')

local parser = require('tasks.parser')

local M = { 
    filename = 'tasks.db',
    filepath = '.tasks',
    path = '/home/gagarin/git/pkm',
    sql = nil,
}

function M:create_table()
    -- Connect to (or create) the SQLite database
    -- Create a table to store the JSON data
    local create_table_task = [[
CREATE TABLE IF NOT EXISTS tasks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    filename TEXT,
    line_number INTEGER,
    status TEXT,
    description TEXT
);]]

    local create_table_tags = [[
CREATE TABLE IF NOT EXISTS tags (
    task_id INTEGER,
    tag TEXT,
    FOREIGN KEY(task_id) REFERENCES tasks(id)
);]]

    local create_table_parameters = [[
CREATE TABLE IF NOT EXISTS parameters (
    task_id INTEGER,
    name TEXT,
    value TEXT,
    FOREIGN KEY(task_id) REFERENCES tasks(id)
);
]]
    self.sql:run(create_table_task)
    self.sql:run(create_table_tags)
    self.sql:run(create_table_parameters)
end


-- Function to insert data into the SQLite database
function M:insert(task)
    local insert_task_sql = string.format([[
        INSERT INTO tasks (filename, line_number, status, description)
        VALUES ('%s', %d, '%s', '%s');
    ]], task.filename, task.line_number, task.status, task.description)

    if not self.sql.connected then
        print('Not connected to the database')
        return
    end
    self.sql:run(insert_task_sql)

    -- Get the last inserted task_id
    local task_id = self.sql:query("SELECT last_insert_rowid()")

    -- Insert tags
    for _, tag in ipairs(task.tags) do
        local insert_tag_sql = string.format("INSERT INTO tags (task_id, tag) VALUES (%d, '%s');", task_id, tag)
        self.sql:run(insert_tag_sql)
    end

    -- Insert parameters
    for param_name, param_value in pairs(task) do
        if param_name ~= "filename" and param_name ~= "line_number" and param_name ~= "status" and param_name ~= "description" and param_name ~= "tags" and (type(param_name) ~= 'function') then
            local insert_param_sql = string.format("INSERT INTO parameters (task_id, name, value) VALUES (%d, '%s', '%s');", task_id, param_name, param_value)
            self.sql:run(insert_param_sql)
        end
    end
end

-- Example usage
-- local output = get_command_output("fish -c 'echo Hello from Fish!'")
-- read and parse tasks from the notes to a lua table
-- @param folder: folder with the notes
-- @return: a table of tasks
function M:read_notes(folder)
    if folder ~= nil and folder ~='' then
        self.path = folder
    end

    local raw_tasks = utils.get_command_output("fish -c 'set -l DIR (git rev-parse --toplevel); $DIR/scripts/find_tasks.fish --dir=" .. self.path .. "'")
    local id_counter =  1

    if raw_tasks == nil then
        print('find_tasks returned nil')
        return
    end

    raw_tasks  = utils.split(raw_tasks, '\n')
    if raw_tasks == nil then
        print('splitted tasks are nil')
        return
    end

    local tasks = {}
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

function M:to_json(tasks)
    local json_tasks = json.encode(tasks)

    local json_file = self.path .. '/' .. self.filepath .. '/tasks.json'
    local fd = io.open( json_file, 'w')
    if fd == nil then
        print('Failed to open ' .. json_file)
        return
    end
    fd:write(json_tasks)
    fd:close()
    print('Tasks indexing completed')
end

function M:to_sql(raw_tasks)
    self.sql:set_path(self.path)
    self.sql:connect()
    self:create_table()

    for _, line in ipairs(raw_tasks) do
        local task = parser.parse(line)
        if task == nil then
            print('parser failed to parse the task')
        else
            self:insert(task)
        end
    end

    self.sql:close()
end

local mod = {
    Indexer = M
}

Thread = require'thread'
function mod.index()
    print('Indexing tasks ...')
    local thread = Thread(
        function()
            local indexer = require'tasks.indexer'.Indexer()
            local tasks = indexer:read_notes()
            indexer:to_json(tasks)
        end
    )
    thread:start()
    thread.running = false
end

M = class(M, {constructor = function(self, filename)
    if filename ~= nil then
        self.filename = filename
    end
    self.sql = Sql(self.filename)
    return self
end})

return mod


