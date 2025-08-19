--!strict
-- returns a pure table (no Roblox types)
local Util = {}

function Util.deepCopy(t, seen)
    if type(t) ~= "table" then return t end
    seen = seen or {}
    if seen[t] then return seen[t] end
    local nt = {}
    seen[t] = nt
    for k, v in pairs(t) do
        nt[Util.deepCopy(k, seen)] = Util.deepCopy(v, seen)
    end
    return nt
end

-- shallow merge of b into a (new table)
function Util.safeMerge(a, b)
    local out = {}
    for k, v in pairs(a or {}) do out[k] = v end
    for k, v in pairs(b or {}) do out[k] = v end
    return out
end

-- merge-with-arrays: copies arrays by value
function Util.mergeConfig(baseCfg, authored)
    local cfg = Util.deepCopy(baseCfg or {})
    for k, v in pairs(authored or {}) do
        if type(v) == "table" then
            cfg[k] = Util.deepCopy(v)
        else
            cfg[k] = v
        end
    end
    return cfg
end

return Util
