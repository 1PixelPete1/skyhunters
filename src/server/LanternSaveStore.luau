--!strict
-- LanternSaveStore: minimal helpers for lantern blob read/write (Lanterns_v1)

local DataStoreService = game:GetService("DataStoreService")

export type LanternRecord = { id: string, pk: string, p: {number}, r: {number}, t: number, u: number?, seed: number?, seg: number? }

local STORE_NAME = "Lanterns_v1"
local ds = DataStoreService:GetDataStore(STORE_NAME)

local M = {}

function M.loadLanternsForPlot(plotKey: string): { LanternRecord }
    local ok, blob = pcall(function() return ds:GetAsync(plotKey) end)
    local items: { LanternRecord } = {}
    if ok and type(blob) == "table" and type(blob.items) == "table" then
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
    pcall(function()
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
end

function M.clearPlot(plotKey: string)
    if type(plotKey) ~= "string" then return end
    pcall(function()
        ds:UpdateAsync(plotKey, function(_old)
            return { version = 1, items = {} }
        end)
    end)
end

return M
