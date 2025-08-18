--!strict
local RequireUtil = {}

local function descend(root: Instance?, path: {string}): Instance?
    local node = root
    for _, name in ipairs(path) do
        if not node then return nil end
        node = node:FindFirstChild(name)
    end
    return node
end

function RequireUtil.fromReplicatedStorage(path: {string})
    local ok, RS = pcall(game.GetService, game, "ReplicatedStorage")
    if not ok or not RS then return nil end
    local inst = descend(RS, path)
    if inst and inst:IsA("ModuleScript") then
        return require(inst)
    end
    return nil
end

function RequireUtil.fromRelative(anchor: Instance, path: {string})
    local inst = descend(anchor, path)
    if inst and inst:IsA("ModuleScript") then
        return require(inst)
    end
    return nil
end

function RequireUtil.must(mod, name: string)
    if not mod then error(("[LoomDesigner] Could not resolve module: %s"):format(name), 2) end
    return mod
end

return RequireUtil
