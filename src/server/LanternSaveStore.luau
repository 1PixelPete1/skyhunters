--!strict
-- LanternSaveStore: minimal helpers for lantern blob read/write (Lanterns_v1)

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

export type LanternRecord = { id: string, pk: string, p: {number}, r: {number}, t: number, u: number?, seed: number?, seg: number?, lanternType: string? }

local STORE_NAME = "Lanterns_v1"
-- DataStores work in production and in Studio if "Allow Studio Access to API Services" is enabled
-- We'll try to use DataStore and handle errors gracefully
local ds = DataStoreService:GetDataStore(STORE_NAME)

if RunService:IsStudio() then
    print("[LanternSaveStore] Studio mode - DataStore will work if 'Allow Studio Access to API Services' is enabled in Game Settings > Security")
end

local M = {}

function M.loadLanternsForPlot(plotKey: string): { LanternRecord }
    local ok, blob = pcall(function() return ds:GetAsync(plotKey) end)
    local items: { LanternRecord } = {}
    
    if not ok then
        if RunService:IsStudio() then
            print(string.format("[LanternSaveStore] Could not load lanterns for plot %s - Enable 'Allow Studio Access to API Services' in Game Settings > Security", plotKey))
        else
            warn(string.format("[LanternSaveStore] Failed to load lanterns for plot %s: %s", plotKey, tostring(blob)))
        end
        return items
    end
    
    if type(blob) == "table" and type(blob.items) == "table" then
        for _, rec in ipairs(blob.items) do
            if type(rec) == "table" and type(rec.id) == "string" then
                table.insert(items, rec :: any)
            end
        end
    end
    return items
end

function M.upsertLantern(rec: LanternRecord)
    if type(rec) ~= "table" or type(rec.id) ~= "string" then return end
    
    local plotKey = string.match(rec.id, "^lan|([^|]+)|") or "P1"
    local ok, err = pcall(function()
        ds:UpdateAsync(plotKey, function(old)
            local blob = old
            if type(blob) ~= "table" then blob = { version = 1, items = {} } end
            if type(blob.items) ~= "table" then blob.items = {} end
            local byId: { [string]: LanternRecord } = {}
            for _, it in ipairs(blob.items) do
                if type(it) == "table" and type(it.id) == "string" then
                    byId[it.id] = it :: any
                end
            end
            byId[rec.id] = rec
            local out: { LanternRecord } = {}
            for _, it in pairs(byId) do table.insert(out, it) end
            blob.items = out
            return blob
        end)
    end)
    
    if not ok then
        if RunService:IsStudio() then
            print(string.format("[LanternSaveStore] Could not save lantern %s - Enable 'Allow Studio Access to API Services' in Game Settings > Security", rec.id))
        else
            warn(string.format("[LanternSaveStore] Failed to save lantern %s: %s", rec.id, tostring(err)))
        end
    end
end

function M.clearPlot(plotKey: string)
    if type(plotKey) ~= "string" then return end
    
    local ok, err = pcall(function()
        ds:UpdateAsync(plotKey, function(_old)
            return { version = 1, items = {} }
        end)
    end)
    
    if not ok then
        if RunService:IsStudio() then
            print(string.format("[LanternSaveStore] Could not clear plot %s - Enable 'Allow Studio Access to API Services' in Game Settings > Security", plotKey))
        else
            warn(string.format("[LanternSaveStore] Failed to clear plot %s: %s", plotKey, tostring(err)))
        end
    end
end

-- Remove specific lantern from persistent storage
function M.removeLantern(lanternId: string): boolean
    if type(lanternId) ~= "string" then 
        warn("[LanternSaveStore] removeLantern called with invalid lanternId:", lanternId)
        return false 
    end
    
    local plotKey = string.match(lanternId, "^lan|([^|]+)|") or "P1"
    print(string.format("[LanternSaveStore] Attempting to remove lantern %s from plot %s", lanternId, plotKey))
    
    local ok, err = pcall(function()
        ds:UpdateAsync(plotKey, function(old)
            local blob = old
            if type(blob) ~= "table" then blob = { version = 1, items = {} } end
            if type(blob.items) ~= "table" then blob.items = {} end
            
            -- Remove the lantern from the blob
            local byId: { [string]: LanternRecord } = {}
            local found = false
            for _, it in ipairs(blob.items) do
                if type(it) == "table" and type(it.id) == "string" then
                    if it.id == lanternId then
                        found = true
                        print(string.format("[LanternSaveStore] Found lantern %s for removal", lanternId))
                    else
                        byId[it.id] = it :: any
                    end
                end
            end
            
            if not found then
                -- Debug: List all lanterns in this plot
                local lanternIds = {}
                for id, _ in pairs(byId) do
                    table.insert(lanternIds, id)
                end
                print(string.format("[LanternSaveStore] Lantern %s not found in plot %s. Available: %s", lanternId, plotKey, table.concat(lanternIds, ", ")))
            end
            
            -- Rebuild the items array
            local out: { LanternRecord } = {}
            for _, it in pairs(byId) do table.insert(out, it) end
            blob.items = out
            return blob
        end)
    end)
    
    if not ok then
        if RunService:IsStudio() then
            print(string.format("[LanternSaveStore] Could not remove lantern %s - Enable 'Allow Studio Access to API Services' in Game Settings > Security", lanternId))
        else
            warn(string.format("[LanternSaveStore] Failed to remove lantern %s: %s", lanternId, tostring(err)))
        end
        return false
    end
    
    print(string.format("[LanternSaveStore] Successfully removed lantern %s from plot %s", lanternId, plotKey))
    return true
end

return M
