local main = require("tasks.main")
local config = require("tasks.config")

local tasks = {}

--- Toggle the plugin by calling the `enable`/`disable` methods respectively.
function tasks.toggle()
    if _G.tasks.config == nil then
        _G.tasks.config = config.options
    end

    main.toggle("public_api_toggle")
end

--- Initializes the plugin, sets event listeners and internal state.
function tasks.enable(scope)
    if _G.tasks.config == nil then
        _G.tasks.config = config.options
    end

    main.toggle(scope or "public_api_enable")
end

--- Disables the plugin, clear highlight groups and autocmds, closes side buffers and resets the internal state.
function tasks.disable()
    main.toggle("public_api_disable")
end

-- setup tasks options and merge them with user provided ones.
function tasks.setup(opts)
    _G.tasks.config = config.setup(opts)
end

_G.tasks = tasks

return _G.tasks
