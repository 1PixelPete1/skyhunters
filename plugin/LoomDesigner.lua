local LoomDesigner = {}

local function serialize(v)
    if type(v) == "table" then
        local parts = {}
        for k,val in pairs(v) do
            local key
            if type(k) == "string" and k:match("^%a[%w_]*$") then
                key = k .. " = "
            else
                key = "[" .. serialize(k) .. "] = "
            end
            parts[#parts+1] = key .. serialize(val)
        end
        return "{" .. table.concat(parts, ",") .. "}"
    elseif type(v) == "string" then
        return string.format("%q", v)
    else
        return tostring(v)
    end
end

function LoomDesigner.ExportConfig(cfg, path)
    local f = io.open(path, "w")
    if not f then return false end
    local wrapped = {[cfg.id] = cfg}
    f:write("return " .. serialize(wrapped))
    f:close()
    return true
end

return LoomDesigner
