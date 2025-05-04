s = 'work read  +work      yes'

context, filter = s:match( [[^([a-zA-Z]+[a-zA-Z0-9-_]*)%s+read%s+(+?[a-zA-Z]+[a-zA-Z0-9-_]*)%s+yes *$]])

if n ~= nil then
    print('n = ' .. n)
else
    print('n = nil')
end
if m ~= nil then
    print('m = ' .. m)
else
    print('m = nil')
end
if context ~= nil then
    print("Context: " .. context)
else
    print("Context: nil")
end
if filter ~= nil then
    print("filtered: " .. filter)
else
    print("filtered: nil")
end
