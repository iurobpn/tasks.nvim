-- local tw = require'tasks.TaskWarrior'
-- local Task = require'tasks.Task'
local Filter = require'tasks.filter'

local function test_filter()
    local filter = Filter()
    filter:add("status:pending")
    filter:add("relatorio mensal")
    filter:add("+work +now")
    assert(filter:build() == "status:pending and relatorio mensal +work +now")
    local raw_tasks = filter:get_tasks()
    local tasks = require'cjson'.decode(raw_tasks)
    print("Number of tasks: " .. #tasks)
    for _, task in ipairs(tasks) do
        print("Task " .. task.uuid .. ": " .. task.description)
        assert(task.status == "pending")
        assert(task.tags:find("work") ~= nil)
        assert(task.tags:find("now") ~= nil)
    end
end

test_filter()
