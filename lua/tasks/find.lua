local M = {}
function M.find_tasks(folder, ...)
    if folder == nil then
        folder = vim.fn.getcwd()
    end
    local opts = {...}
    opts = opts[1] or {}

    -- not started
    -- pattern='\\- \\[ \\]'
    local pattern = ''
    if opts.completed ~= nil then
        pattern='\\- \\[ *x *\\]'
    else
        pattern='\\- \\[ \\]'
    end
    local cmd = 'rg "' .. pattern .. '" --type=md -n ' .. folder
    if opts.args ~= nil then
        cmd = cmd .. ' | grep ' .. opts.args
    end

    return require'utils'.get_command_output(cmd)
end
return M
