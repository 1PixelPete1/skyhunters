local Uid = {}

local counters = {}

local digits = {}
for i = 0, 9 do
    digits[i] = tostring(i)
end
for i = 10, 35 do
    digits[i] = string.char(87 + i) -- 97-10=87? Wait: char for 'a' should be 97; i=10 -> 97: yes char = 87 + i
end

local function encodeBase36(n)
    if n == 0 then
        return "0"
    end
    local t = {}
    while n > 0 do
        local r = n % 36
        table.insert(t, 1, digits[r])
        n = math.floor(n / 36)
    end
    return table.concat(t)
end

function Uid.next(prefix)
    counters[prefix] = (counters[prefix] or 0) + 1
    local id = encodeBase36(counters[prefix])
    return prefix .. "-" .. id
end

return Uid

