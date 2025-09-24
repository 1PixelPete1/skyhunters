--!strict
-- DungeonPersistence.luau
-- Minimal save/load for dungeon state (per plot)

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local STORE_NAME = "Dungeons_v1"
local ds = DataStoreService:GetDataStore(STORE_NAME)

type DungeonState = {
    layout: any,
    modelName: string?,
    position: Vector3?,
    seed: number?,
    cleared: boolean?,
    lootClaimed: boolean?,
}

local M = {}

-- Save state per plot key
function M.SaveDungeon(plotKey: string, state: DungeonState)
    if type(plotKey) ~= "string" or type(state) ~= "table" then return end
    local ok, err = pcall(function()
        ds:UpdateAsync(plotKey, function(_old)
            -- Store a compact blob; layout is already a table of primitives
            local blob = {
                v = 1,
                layout = state.layout,
                modelName = state.modelName,
                position = state.position,
                seed = state.seed,
                cleared = state.cleared,
                lootClaimed = state.lootClaimed,
            }
            return blob
        end)
    end)
    if not ok then
        if RunService:IsStudio() then
            print(string.format("[DungeonPersistence] Save failed for plot %s (Enable Studio API access)", plotKey))
        else
            warn(string.format("[DungeonPersistence] Save failed for plot %s: %s", plotKey, tostring(err)))
        end
    end
end

function M.LoadDungeon(plotKey: string): DungeonState?
    if type(plotKey) ~= "string" then return nil end
    local ok, blob = pcall(function()
        return ds:GetAsync(plotKey)
    end)
    if not ok then
        if RunService:IsStudio() then
            print(string.format("[DungeonPersistence] Load failed for plot %s (Enable Studio API access)", plotKey))
        else
            warn(string.format("[DungeonPersistence] Load failed for plot %s: %s", plotKey, tostring(blob)))
        end
        return nil
    end
    if type(blob) == "table" and blob.layout then
        return blob :: any
    end
    return nil
end

-- Utility: load all plot dungeons (best-effort; DataStore does not support list keys)
-- In practice you would track known plot keys elsewhere; here we no-op.
function M.LoadAll(): { [string]: DungeonState }
    -- Without a key registry, return empty.
    return {}
end

return M

