--!strict
local ReplicatedStorage
if rawget(_G, "game") and game.GetService then
    ReplicatedStorage = game:GetService("ReplicatedStorage")
else
    ReplicatedStorage = {FindFirstChild=function() return nil end}
end

local ModelResolver = {}

local modelsFolder
if ReplicatedStorage and ReplicatedStorage.WaitForChild then
    modelsFolder = ReplicatedStorage:WaitForChild("models", 2)
end

function ModelResolver.ResolveOne(ref)
    if type(ref) == "string" then
        if modelsFolder then
            local m = modelsFolder:FindFirstChild(ref)
            if m then return m:Clone() end
        end
        warn("ModelResolver: missing model named '"..ref.."' in ReplicatedStorage.models")
        return nil
    elseif type(ref) == "number" then
        local ok, got = pcall(game.GetObjects, game, "rbxassetid://"..tostring(ref))
        if ok and got and got[1] then
            local inst = got[1]
            if inst:IsA("Model") or inst:IsA("Folder") or inst:IsA("BasePart") then
                return inst
            end
        end
        warn("ModelResolver: failed to load asset id "..tostring(ref))
        return nil
    else
        warn("ModelResolver: unsupported ref type "..type(ref))
        return nil
    end
end

-- Pick an entry from { "nameA", "nameB", ... } (or asset ids)
function ModelResolver.ResolveFromList(list)
    if not list or #list == 0 then return nil end
    -- For now just pick first; later randomize if needed
    return ModelResolver.ResolveOne(list[1])
end

return ModelResolver
