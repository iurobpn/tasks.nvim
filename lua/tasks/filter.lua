local Filter = {
    default = "status:pending",
    params = { },
}

-- @brief Filter add param method
-- @param param string
-- @details
-- - add a param to the list of params
function Filter:add(param)
    if not param then
        return
    end
    table.insert(self.params, param)
end

-- @brief Filter clear all the parameters for this filter
function Filter:clear()
    self.params = {}
end
function Filter:get_tasks()
    local filter = self:build()
    local out = require'tasks.util'.run("task " .. filter .. " export")
    return out
end
-- @brief build the filter expression
function Filter:build()
    local filter = self.default
    if #self.params > 0 then
        filter = filter .. " and " .. table.concat(self.params, " and ")
    end
    local context, params = self:get_context()
    if context ~= "none" then
        filter = filter .. " and " .. "(" .. params .. ")"
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
function Filter:get_context()
    local out = require'tasks.util'.run("task context | grep yes | grep read")
    if out == "" then
        return "none", ''
    end

    local _, _, context, filter = out:find("^([^ ]*)%s+read%s+([^ ]*)%s+yes *$")
    return context, filter
end


require'class'
Filter = _G.class(Filter)

return Filter
