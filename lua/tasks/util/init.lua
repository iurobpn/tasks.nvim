M = {}

--- run command and return output
--- @param cmd string
--- @return string output
function M.run(cmd)
    local fd = io.popen(cmd)
    if not fd then
        print("Error: to run command: " .. cmd)
        return ''
    end
    local out = fd:read("*a")
    fd:close()
    return out
end

--- read a file return its content
--- @param filename string
--- @return string output
function M.read(filename)
    local content = ''
    local fd = io.open(filename, "r")
    if not fd then
        print("Error: Unable to open file " .. filename)
        return ''
    else
        content = fd:read("*a")
    end
    fd:close()
    return content
end


return M
