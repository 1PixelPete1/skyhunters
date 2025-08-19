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

local modelsFolder
if ReplicatedStorage and ReplicatedStorage.WaitForChild then
    modelsFolder = ReplicatedStorage:WaitForChild("models", 2)
end

function ModelResolver.ResolveOne(ref)
    if type(ref) == "string" then
        if modelsFolder then
            local m = modelsFolder:FindFirstChild(ref)
            if m then
                return m:Clone()
            end
        end
        warn("ModelResolver: missing model named '" .. ref .. "' in ReplicatedStorage.models")
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
