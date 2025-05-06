-- jq/cjson backend to tasks
local M = {
    list = require('tasks.query_list'),
    hist = {},
}

function M.check_deps()
    local res, _ = pcall(require,'cjson')
    if not res then
        print("cjson is not present, please install it")
        return false
    end
    res, _ = pcall(io.popen,'command -v jq 2>&1 > /dev/null')
    if not res then
        print("jq is not present, please install it")
        return false
    end
    return res
end

function M.write(tasks,filename)
    -- print('Jq: Writing tasks to ' .. filename)
    if filename == nil then
        print('Filename is nil')
        return
    end
    if tasks == nil then
        print('Tasks are nil')
        return
    end
    if tasks == {} then
        print('Tasks are empty')
        return
    end
    local json_tasks = vim.fn.json_encode(tasks)

    local fd = io.open( filename, 'w')
    if fd == nil then
        print('Failed to open ' .. filename)
        return
    end
    -- print('Writing tasks to ' .. filename)
    fd:write(json_tasks)
    fd:close()

    -- print('Task indexing completed')
end

function M.log_tasks(tasks,folder)
    if tasks == nil then
        print('Tasks are nil')
        return
    end
    if tasks == {} then
        print('stasks are empty')
        return
    end
    folder = require'utils.fs'.get_path(folder)
    local fname = folder .. '/tasks.log'
    print('log_tasks: Writing tasks to ' .. fname)
    local fd = io.open(fname, 'w')
    if not fd then
        print('Failed to open ' .. fname)
        return
    end
    print('log_tasks: file ' .. fname .. ' open')
    str_tasks = require'inspect'(tasks)
    io.write(tasks)
    fd:close()
    print('log_tasks: Tasks written to ' .. fname)
end

local Query = {}

-- static variables
Query.path = '/home/gagarin/git/pkm'
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

-- query currently works on:
Query.current = Query.tasks
--constructor
function Query:new(filename)
    if filename ~= nil then
        self.filename = filename
    end
    return self
end

-- confusing, all of this to select a file and path?
function Query:file (jsonfile)
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

function Query.get_path(jsonfile)
    return Query.path .. '/' .. Query.jsonfiles[jsonfile].mod_dir
end



-- query functions
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
    local query = ''
    for _,tag in ipairs(tags) do
        query = query .. ' ' .. op .. '( .tags[] == "' .. tag .. '" )'
    end
    query = '( ' .. query .. ' )'

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

function Query:cmd_builder(options)
    options = options or {}
    local cmd = nil
    if type(options) == 'string' then
        cmd = options
    else
        local query = '[ .[] | select('

        local andstr = ''
        if options.id ~= nil then
            query = query .. self.select_by_id(options.id)
            andstr = ' and '
        end
        if options.status ~= nil then
            query = query .. andstr .. self.select_by_status(options.status)
            andstr = ' and '
        end
        if options.due ~= nil then
            query = query .. andstr .. self.select_by_due(options.due)
            andstr = ' and '
        end
        if options.tags ~= nil and #options.tags > 0 and options.tags[1] ~= nil then
            query = query .. andstr .. self.select_by_tags(options.tags)
        end
        query = query .. ')] | sort_by(.due) | unique | sort_by(.due)'

        cmd = string.format("jq '%s'", query)
    end
    return cmd
end

--generic selct function (select is inspired by the former sql backend )
function Query:select(option)
    option = option or {}

    local cmd = Query:cmd_builder(option)

    local str_tasks = self:run(cmd)

    local tasks
    if str_tasks == '' then
        tasks = {}
    else
        tasks = vim.fn.json_decode(str_tasks)
    end

    return tasks
end

function Query:run(cmd)
    table.insert(Query.hist, cmd)
    local file = self:file()
    local str_tasks = require"utils".get_command_output(cmd .. ' ' .. file)
    return str_tasks
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

require"class"
Query = class(Query,{constructor = Query.new})

-- create a keymap to open the query history
if not (vim == nil) and not (vim.api.nvim_set_keymap == nil)then
    vim.api.nvim_set_keymap('n', '<localleader>q', ':lua require("tasks.query_jq").Query.history()<CR>', { noremap = true, silent = true })
end

-- Query.init()

return M
