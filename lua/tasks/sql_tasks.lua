local M = {
    filename = '.tasks.db',
    sql = nil
}

-- backend in sql
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

function M:write(raw_tasks)
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

_G.class(M, {constructor = function(filename)
    local obj = {}
    if filename ~= nil then
        obj.filename = filename
    end
    obj.sql = require('dev.lua.sqlite').Sql(obj.filename)
end})
