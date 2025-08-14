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

--- convert table to string
--- @param tbl table
--- @return string
function json_encode(tbl)
    return require"dkjson".encode(tbl)
end

--- convert string json to lua table
--- @param s string
--- @return table
function json_decode(s)
    return require"dkjson".decode(s)
end

return M
