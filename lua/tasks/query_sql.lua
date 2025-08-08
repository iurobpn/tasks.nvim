require('katu.utils.class')
local M = {}

local Query = {
    filename = 'tasks.db',
    path = '/home/gagarin/git/pkm',
    sql = nil,
}

Query = class(Query, {constructor = function(filename)
    local obj = {}
    if filename ~= nil then
        obj.filename = filename
    end
    local sql = require('dev.lua.sqlite2')
    obj.sql = sql.Sql(obj.path .. obj.filename)
    return obj
end})

function Query:select_by_id(id)
    local fmt = string.format
    id = id or 1
    local query_task = fmt('SELECT * FROM tasks WHERE id = %d;', id)
    local query_tags = fmt('SELECT tag FROM tags WHERE task_id = %d;', id)
    local query_params = fmt('SELECT name, value FROM parameters WHERE task_id = %d;', id)

    self.sql:connect()

    local task = self.sql:query_n(query_task)
    local params = self.sql:query_n(query_params)
    local tags = self.sql:query_n(query_tags)
    self.sql:close()
    task = task[1]
    task.parameters = {}
    for _, p in ipairs(params) do
        task.parameters[p.name] = p.value
    end
    task.tags = {}
    for _, tag in ipairs(tags) do
        table.insert(task.tags, tag.tag)
    end

    return task
end

function Query:select_by_tag_and_due(tag, order)
    tag = tag or 0
    -- local query_tag = "select distinct t.id from tasks t left join tags tg ON t.id = tg.task_id where tg.tag = '#main'"
    -- local query_task = fmt('SELECT * FROM tasks WHERE id = %s;', tag)
    -- local query_tags = fmt('SELECT tag FROM tags WHERE task_id = %s;', tag)
 --    local query_params = fmt('SELECT name, value FROM parameters WHERE task_id = %d;', tag)
    local query = string.format([[
        SELECT distinct t.*,  p.name AS name, p.value AS value, tg.tag
    FROM tasks t
    LEFT JOIN parameters p ON t.id = p.task_id
    LEFT JOIN tags tg ON t.id = tg.task_id
    WHERE tg.tag = '%s' and t.status != 'done' and p.name = 'due'
    ORDER BY p.value %s;
]], tag, (order or ''))

    return self:select(query)
end

function Query:select_by_tag(tag)
    tag = tag or 0
    -- local query_tag = "select distinct t.id from tasks t left join tags tg ON t.id = tg.task_id where tg.tag = '#main'"
    -- local query_task = fmt('SELECT * FROM tasks WHERE id = %s;', tag)
    -- local query_tags = fmt('SELECT tag FROM tags WHERE task_id = %s;', tag)
 --    local query_params = fmt('SELECT name, value FROM parameters WHERE task_id = %d;', tag)
    local query = [[
        SELECT distinct t.*,  p.name AS name, p.value AS value, tg.tag
    FROM tasks t
    LEFT JOIN parameters p ON t.id = p.task_id
    LEFT JOIN tags tg ON t.id = tg.task_id
    WHERE t.status != 'done']]

    if tag ~= nil then
        query = query .. string.format([[ and tg.tag = '%s']], tag)
    end
    return self:select(query .. ';')
end

function Query:select(query)
    self.sql:connect()

    local tasks = {}
    local raw_tasks = self.sql:query_n(query)
    self.sql:close()

    local tasks_per_id = {}
    for _,rtask in ipairs(raw_tasks) do
        local task_id = rtask.id

        -- If this task_id is not already in the tasks table, initialize it
        if not tasks[task_id] then
            if rtask.filename == nil or rtask.id == nil or rtask.line_number == nil or rtask.status == nil then
                require"utils".pprint(rtask)
                error('task id: ' .. task_id .. ' is not valid')
            end

            table.insert(tasks, {
                id = task_id,
                filename = rtask.filename,
                line_number = rtask.line_number,
                status = rtask.status,
                description = rtask.description,
                parameters = {},
                tags = {}
            })
            tasks_per_id[task_id] = tasks[#tasks]
        end

        -- Add the parameter if it exists and is not already added
        if rtask.name ~= nil and rtask.value and tasks_per_id[task_id].parameters[rtask.name] == nil then
            tasks_per_id[task_id].parameters[rtask.name] = rtask.value
        end

        -- Add the tag if it exists and is not already added
        if rtask.tag ~= nil and not require"utils".contains(tasks_per_id[task_id].tags,rtask.tag) then
            table.insert(tasks_per_id[task_id].tags, rtask.tag)
        end
    end

    return tasks
end

function Query.open_context_window(filename, line_nr)
    
    local context_width = math.floor(vim.o.columns * 0.4)
    local context_height = math.floor(vim.o.lines * 0.5)
    local context_row = math.floor((vim.o.lines - context_height) / 4)
    local context_col = math.floor(vim.o.columns * 0.55)

    -- print('filename: ' .. filename)
    -- print('line_nr: ' .. line_nr)
    local content = nvim.utils.get_context(filename, line_nr)

    local win = nvim.ui.views.fit()
    win:config(
        {
            -- relative = 'editor',
            -- size = {
            --     absolute = {
            --         width = context_width,
            --         height = context_height,
            --     },
            -- },
            position = {
                absolute = {
                    row = context_row,
                    col = context_col,
                },
            },
            buffer = nvim.ui.views.get_scratch_opt(),
            border = 'single',
            content = content,
            options = {
                buffer = {
                    modifiable = false,
                },
                window = {
                    wrap = false,
                    winbar = 'file context on line ' .. line_nr,
                },
            },
        }
    )

    win:open()
    -- vim.cmd('set ft=markdown')
    --get last line nr
    line_nr = math.floor(#content/2)
    vim.api.nvim_win_set_cursor(win.vid, {line_nr, 0})
end
M.Query = Query

return M
