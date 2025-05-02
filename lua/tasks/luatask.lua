local fname = 'tasks.json'

local TW = {

}


local function run(cmd)
    local fd = io.popen(cmd)
    if not fd then
        print("Error: Unable to open file " .. fname)
        return
    end
    local out = fd:read("*a")
    fd:close()
    return out
end

local function read(filename)
    local fd = io.open(filename, "r")
    if not fd then
        print("Error: Unable to open file " .. filename)
        return
    end
    local content = fd:read("*a")
    fd:close()
    return content
end

function TW:import(filename)
    return run("task import " .. filename)
end

-- from the output of an import command, recover the uuids to update the tasks
function TW:get_uuids(import_out)
    local pattern = "^%s+%w+%s+([0-9a-f%-]+) .*"
    local uuids = {}
    for line in import_out:gmatch("[^\r\n]+") do
        local id = line:match(pattern)
        if id then
            table.insert(uuids, id)
        end
    end
    return uuids
end


local fname = 'out.txt'
-- local fd = io.popen("task import " .. fname)
local out = read(fname)
print(out)
out = TW:get_uuids(out)
print('out: ')
print(require'inspect'.inspect(out))

_G.TaskWarrior = TW
return TW
