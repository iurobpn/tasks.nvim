local log = require("tasks.util.log")

local tasks = {}

--- tasks configuration with its default values.
---
---@type table
--- Default values:
---@eval return MiniDoc.afterlines_to_code(MiniDoc.current.eval_section)
tasks.options = {
    -- Prints useful logs about what event are triggered, and reasons actions are executed.
    debug = false,
}

---@private
local defaults = vim.deepcopy(tasks.options)

--- Defaults tasks options by merging user provided options with the default plugin values.
---
---@param options table Module config table. See |tasks.options|.
---
---@private
function tasks.defaults(options)
    tasks.options =
        vim.deepcopy(vim.tbl_deep_extend("keep", options or {}, defaults or {}))

    -- let your user know that they provided a wrong value, this is reported when your plugin is executed.
    assert(
        type(tasks.options.debug) == "boolean",
        "`debug` must be a boolean (`true` or `false`)."
    )

    return tasks.options
end

--- Define your tasks setup.
---
---@param options table Module config table. See |tasks.options|.
---
---@usage `require("tasks").setup()` (add `{}` with your |tasks.options| table)
function tasks.setup(options)
    tasks.options = tasks.defaults(options or {})

    log.warn_deprecation(tasks.options)

    return tasks.options
end

return tasks
