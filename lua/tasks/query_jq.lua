local M = {
    list = require('tasks.query_list'),
    hist = {}
}

local Query = {}

-- static variables
Query.path = '/home/gagarin/git/my/home/pkm'
Query.jsonfiles = {
    tasks = {
        filename = 'tasks.json',
        mod_dir = '.tasks',
        prefix = 'jq',
    },
    -- markdowndb static variables
    mddb = {
        filename = 'files.json',
        mod_dir = '.markdowndb',
        prefix = 'jqf',
    },
}

Query.current = Query.tasks
--constructor
Query.new = function(self, filename)
    if filename ~= nil then
        self.filename = filename
    end
    return self
end


Query.file = function(self,jsonfile)
    if jsonfile == nil and Query.jsonfiles.current == nil then
        jsonfile = Query.jsonfiles.tasks
    elseif jsonfile == nil then
        jsonfile = Query.jsonfiles.current
    else
        if type(jsonfile) == 'string' then
            jsonfile = Query.jsonfiles[jsonfile]
        end
    end

    return self.path .. '/' .. jsonfile.mod_dir .. '/' .. jsonfile.filename
end

Query.get_path = function(jsonfile)
    return Query.path .. '/' .. Query.jsonfiles[jsonfile].mod_dir
end

function Query:select_by_id(id)
    -- local query = fmt('jq "[ .[] | select(.id == %d)" %s ]', id, self:file())
    if type(id) == 'string' then
        id = tonumber(id)
    end
    if id == nil or id <= 0 then
        return nil
    end
    local query = '.id == ' .. id

    return query
end

function Query.select_by_tags(tags,op)
    op = op or 'and'
    local query
    -- if tag == nil then
    --     query = string.format([['[ .[] | select(.status != "done" and .due != null) ]']])
    -- else
    --     query = string.format([['[ .[] | select(.status != "done" and .due != null and .tags[] == "%s") ]']], tag)
    -- end
    query = '( ( .tags[] == "' .. tags[1] .. '" )'
    for i = 2, #tags do
        query = query .. ' ' .. op .. '( .tags[] == "' .. tags[i] .. '" )'
    end
    query = query .. ' )'

    return query
end

function Query.select_by_due(due)
    -- local query = string.format([['[ .[] | select(.status != "done" and .tags[] == "%s") ]' ]], tag)
    if due == nil then
        return nil
    end
    if due then
        return '.due != null'
    else
        return '.due == null'
    end
end

function Query.select_by_status(status)
    local query = nil
    if status == 'undone' or status == 'not done' then
        query = '.status != "done"'
    elseif status == 'done' then
        query = '.status == "done"'
    end

    return query
end

function Query:select(option)
    option = option or {}
    local cmd
    local andstr = ''
    if type(option) == 'string' then
        cmd = option
    else
        local query = '[ .[] | select('

        if option.id ~= nil then
            query = query .. andstr .. self.select_by_id(option.id)
            andstr = ' and '
        end
        if option.status ~= nil then
            query = query .. andstr .. self.select_by_status(option.status)
            andstr = ' and '
        end
        if option.due ~= nil then
            query = query .. andstr .. self.select_by_due(option.due)
            andstr = ' and '
        end
        if option.tags ~= nil and #option.tags > 0 and option.tags[1] ~= nil then
            query = query .. andstr .. self.select_by_tags(option.tags)
        end
        query = query .. ')] | sort_by(.due) | unique | sort_by(.due)'
        -- {{jq: '[ .[] | select(.status!="done" and .due!=null ) ] | sort_by(.due)' }}

        -- '.status != "done" and .due != null) ]']])

        cmd = string.format("jq '%s'", query)
    end
    local str_tasks = self:run(cmd)
    local tasks
    if str_tasks == '' or str_tasks == '[]' then
        tasks = {}
    else
        tasks = require'tasks.util'.json_decode('{ "tasks": ' .. str_tasks .. ' }')
        tasks = tasks.tasks
    end
    return tasks
end

function Query:run(cmd)
    -- table.insert(Query.hist, cmd)
    local file = self:file()
    cmd = cmd .. ' ' .. file
    local strtasks = ''
    strtasks = require"tasks.util".run(cmd)
    return strtasks
end

M.Query = Query

function Query.history()
    require'fzf-lua'.fzf_exec(Query.hist, {
        prompt = 'Select a query>',
        actions = {
            ["default"] = function(selected)
                local query = selected[1]
                vim.notify(string.format('Query: %s', query))
                require"tasks.views".search(query)
            end
        }
    })
end

function Query.init()
    local Msaved = vim.g.proj.get('query_history')
    if Msaved then
        Query.hist = Msaved
    else
        Query.hist = {}
    end
    vim.g.proj.register('query_history', Query.hist)
end

Query = class(Query)

-- create a keymap to open the query history
vim.api.nvim_set_keymap('n', '<localleader>q', ':lua require("tasks.query_jq").Query.history()<CR>', { noremap = true, silent = true })

Query.init()

return M
