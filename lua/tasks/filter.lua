TaskWarrior = require'tasks.taskwarrior'
local Filter = {
    default = "status:pending",
    params = { },
}

-- @brief Filter add param method
-- @param param string
-- @details
-- - add a param to the list of params
function Filter:add(param)
    print("Filter:add " .. param)
    if param == nil then
        return
    end
    print("Filter:add " .. param .. ' added')
    table.insert(self.params, param)
end

-- @brief Filter clear all the parameters for this filter
function Filter:clear()
    self.params = {}
end
function Filter:get_tasks()
    local filter = self:build()
    print("Filter:get_tasks " .. filter)
    local out = require'tasks.util'.run("task " .. filter .. " export")
    return out
end

-- @brief build the filter expression
function Filter:build()
    local filter = self.default
    if #self.params > 0 then
        filter = filter .. " and " .. table.concat(self.params, " and ")
    end
    -- local context, cparams = self.get_context()
    -- if context ~= "none" then
    --     filter = filter .. " and " .. "(" .. cparams .. ")"
    -- end
    local context = TaskWarrior._context
    if context ~= "none" and context ~= nil and #context == 0 then
        filter = filter .. " +" .. context -- context is limited to a tag
    end
    return filter
end



--- @brief get the current context definition
--- @details
--- - get the current context from taskwarrior
--- - if the context is not set, return "none"
--- - if the context is set, return the context name and its definition
---
--- @returns string context name, string context definition
function Filter.get_context()
    local out = require'tasks.util'.run("task context | grep yes | grep read")
    if out == "" then
        return "none", ''
    end
    print("task context: " .. out)
    
    -- local n, m, context, filter = string.find(out, "^([a-zA-Z]+[a-zA-Z0-9-_]*)%s+read%s+([^ ]*)%s+yes *$")
    local context, filter = out:match( [[^([a-zA-Z]+[a-zA-Z0-9-_]*)%s+read%s+(+?[a-zA-Z]+[a-zA-Z0-9-_]*)%s+yes *$]])

    if context ~= nil then
        print("Context: " .. context)
    else
        print("Context: nil")
        context= "none"
    end
    if filter ~= nil then
        print("filtered: " .. filter)
    else
        print("filtered: nil")
        filter = ''
    end

    return context, filter
end


require'class'
Filter = _G.class(Filter)

return Filter
