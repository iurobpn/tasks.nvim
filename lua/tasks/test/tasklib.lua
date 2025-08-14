local Filter = require'tasks.filter'

local function test_filter()
    local filter = Filter()
    filter:add("status:pending")
    -- filter:add("relatorio mensal")
    filter:add("+work +now")
    -- assert(filter:build() == "status:pending and relatorio mensal +work +now")
    local raw_tasks = filter:get_tasks()
    local tasks = require'tasks.util'.json_decode(raw_tasks)
    str_tasks = {}
    -- print("Number of tasks: " .. #tasks)
    for _, task in ipairs(tasks) do
        table.insert(str_tasks, "- [ ] " .. task.description .. " @{" .. task.uuid .. "}")
        -- assert(task.status == "pending")
        -- assert(task.tags:find("work") ~= nil)
        -- assert(task.tags:find("now") ~= nil)
    end
    require'fzf-lua'.fzf_exec(str_tasks, {
        fzf_opts = {
            ["--height"] = "50%",
            ["--layout"] = "reverse",
            ["--info"] = "inline",
            ["--multi"] = true,
            ["--preview"] = "echo {} | sed 's/@{\\(.*\\)}/\\1/' | task",
        },
        actions = {
            ["default"] = function(selected)
                for _, task in ipairs(selected) do
                    local uuid = task:match("@{(.*)}")
                    if uuid then
                        vim.api.nvim_put({task}, "l", true, true)
                    end
                end
            end,
        },
    })
end

test_filter()
