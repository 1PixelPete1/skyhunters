--!strict
local RequireUtil = require(script.Parent.RequireUtil)
local ReplicatedStorage
if rawget(_G, "game") and game.GetService then
    ReplicatedStorage = game:GetService("ReplicatedStorage")
else
    ReplicatedStorage = {FindFirstChild=function() return nil end}
end

local ModelResolver = {}

-- simple cache so repeated asset-id lookups don't hit network every rebuild
local _assetCache = {}

-- Resolve the models folder on each call; tolerate "Models"/"models"
local function getModelsFolder()
    if not ReplicatedStorage then return nil end
    local f = ReplicatedStorage:FindFirstChild("models")
        or ReplicatedStorage:FindFirstChild("Models")
    if not f and ReplicatedStorage.WaitForChild then
        -- tiny wait covers early-startup races without blocking UI
        f = ReplicatedStorage:WaitForChild("models", 0.1)
            or ReplicatedStorage:WaitForChild("Models", 0.1)
    end
    return f
end

function ModelResolver.ResolveOne(ref)
    if type(ref) == "string" then
        local folder = getModelsFolder()
        local wanted = tostring(ref):gsub("^%s*(.-)%s*$", "%1")
        if folder then
            -- exact first
            local m = folder:FindFirstChild(wanted)
            if not m then
                -- case-insensitive fallback
                local lw = wanted:lower()
                for _, ch in ipairs(folder:GetChildren()) do
                    if ch.Name:lower() == lw then m = ch; break end
                end
            end
            if m then
                if m:IsA("Model") then
                    return m:Clone()
                else
                    -- wrap non-Model as a Model so downstream always receives a Model
                    local wrap = Instance.new("Model")
                    wrap.Name = m.Name
                    local c = m:Clone()
                    c.Parent = wrap
                    local pp = c:IsA("BasePart") and c or wrap:FindFirstChildWhichIsA("BasePart", true)
                    if pp then (wrap :: any).PrimaryPart = pp end
                    return wrap
                end
            end
        end
        -- richer warning that shows what the resolver actually sees
        local where = folder and folder:GetFullName() or "ReplicatedStorage.models/Models (not found)"
        local have = {}
        if folder then
            for _, ch in ipairs(folder:GetChildren()) do
                table.insert(have, ch.Name .. "(" .. ch.ClassName .. ")")
            end
        end
        warn(("ModelResolver: missing model '%s' in %s; have: [%s]")
            :format(wanted, where, table.concat(have, ", ")))
        return nil
    elseif type(ref) == "number" then
        local cached = _assetCache[ref]
        if cached then
            return cached:Clone()
        end
        local ok, got = pcall(game.GetObjects, game, "rbxassetid://" .. tostring(ref))
        if ok and got and got[1] then
            local inst = got[1]
            if inst:IsA("Model") or inst:IsA("Folder") or inst:IsA("BasePart") then
                _assetCache[ref] = inst
                return inst:Clone()
            end
        end
        warn("ModelResolver: failed to load asset id " .. tostring(ref))
        return nil
    else
        warn("ModelResolver: unsupported ref type " .. type(ref))
        return nil
    end
end

-- Pick an entry from { "nameA", "nameB", ... } (or asset ids)
function ModelResolver.ResolveFromList(list, opts)
    if not list or #list == 0 then return nil end
    local pick
    if opts and type(opts.select) == "function" then
        pick = opts.select(list)
    else
        pick = list[1]
    end
    return ModelResolver.ResolveOne(pick)
end

return ModelResolver
