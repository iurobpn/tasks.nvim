-- internal methods
local main = {}

-- Toggle the plugin by calling the `enable`/`disable` methods respectively.
--
---@param scope string: internal identifier for logging purposes.
---@private
function main.toggle(scope)
    local state = require("tasks.state")
    local log = require("tasks.util.log")
    if state.get_enabled(state) then
        log.debug(scope, "tasks is now disabled!")

        return main.disable(scope)
    end

    log.debug(scope, "tasks is now enabled!")

    main.enable(scope)
end

--- Initializes the plugin, sets event listeners and internal state.
---
--- @param scope string: internal identifier for logging purposes.
---@private
function main.enable(scope)
    local state = require("tasks.state")
    local log = require("tasks.util.log")
    if state.get_enabled(state) then
        log.debug(scope, "tasks is already enabled")

        return
    end

    state.set_enabled(state)

    -- saves the state globally to `_G.tasks.state`
    state.save(state)
end

--- Disables the plugin for the given tab, clear highlight groups and autocmds, closes side buffers and resets the internal state.
---
--- @param scope string: internal identifier for logging purposes.
---@private
function main.disable(scope)
    local state = require("tasks.state")
    local log = require("tasks.util.log")
    if not state.get_enabled(state) then
        log.debug(scope, "tasks is already disabled")

        return
    end

    state.set_disabled(state)

    -- saves the state globally to `_G.tasks.state`
    state.save(state)
end

return main
