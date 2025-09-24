--!strict
-- OilReservoirSaveStore: helpers for oil reservoir blob read/write (OilReservoirs_v1)

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

export type OilRecord = { id: string, pk: string, p: {number}, size: string, capacity: number, t: number, u: number? }

local STORE_NAME = "OilReservoirs_v1"
local ds = DataStoreService:GetDataStore(STORE_NAME)

if RunService:IsStudio() then
    print("[OilReservoirSaveStore] Studio mode - DataStore works if 'Allow Studio Access to API Services' is enabled")
end

local M = {}

function M.loadReservoirsForPlot(plotKey: string): { OilRecord }
    local ok, blob = pcall(function() return ds:GetAsync(plotKey) end)
    local items: { OilRecord } = {}
    if not ok then
        if RunService:IsStudio() then
            print(string.format("[OilReservoirSaveStore] Could not load reservoirs for plot %s - Enable Studio API Services", plotKey))
        else
            warn(string.format("[OilReservoirSaveStore] Failed to load reservoirs for plot %s: %s", plotKey, tostring(blob)))
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

function M.upsertReservoir(rec: OilRecord)
    if type(rec) ~= "table" or type(rec.id) ~= "string" then return end
    local plotKey = string.match(rec.id, "^res|([^|]+)|") or "P1"
    local ok, err = pcall(function()
        ds:UpdateAsync(plotKey, function(old)
            local blob = old
            if type(blob) ~= "table" then blob = { version = 1, items = {} } end
            if type(blob.items) ~= "table" then blob.items = {} end
            local byId: { [string]: OilRecord } = {}
            for _, it in ipairs(blob.items) do
                if type(it) == "table" and type(it.id) == "string" then
                    byId[it.id] = it :: any
                end
            end
            byId[rec.id] = rec
            local out: { OilRecord } = {}
            for _, it in pairs(byId) do table.insert(out, it) end
            blob.items = out
            return blob
        end)
    end)
    if not ok then
        if RunService:IsStudio() then
            print(string.format("[OilReservoirSaveStore] Could not save reservoir %s - Enable Studio API Services", rec.id))
        else
            warn(string.format("[OilReservoirSaveStore] Failed to save reservoir %s: %s", rec.id, tostring(err)))
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
            print(string.format("[OilReservoirSaveStore] Could not clear plot %s - Enable Studio API Services", plotKey))
        else
            warn(string.format("[OilReservoirSaveStore] Failed to clear plot %s: %s", plotKey, tostring(err)))
        end
    end
end

function M.removeReservoir(resId: string): boolean
    if type(resId) ~= "string" then return false end
    local plotKey = string.match(resId, "^res|([^|]+)|") or "P1"
    local ok, err = pcall(function()
        ds:UpdateAsync(plotKey, function(old)
            local blob = old
            if type(blob) ~= "table" then blob = { version = 1, items = {} } end
            if type(blob.items) ~= "table" then blob.items = {} end
            local out: { OilRecord } = {}
            for _, it in ipairs(blob.items) do
                if type(it) == "table" and type(it.id) == "string" and it.id ~= resId then
                    table.insert(out, it :: any)
                end
            end
            blob.items = out
            return blob
        end)
    end)
    if not ok then
        if RunService:IsStudio() then
            print(string.format("[OilReservoirSaveStore] Could not remove %s - Enable Studio API Services", resId))
        else
            warn(string.format("[OilReservoirSaveStore] Failed to remove %s: %s", resId, tostring(err)))
        end
        return false
    end
    return true
end

return M

