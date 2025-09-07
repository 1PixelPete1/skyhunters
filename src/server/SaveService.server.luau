--!strict
-- Lantern Persistence M0.3 (server)
-- - Batches saves per plot to DataStore "Lanterns_v1"
-- - Idempotent restore on player plot assignment

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local CollectionService = game:GetService("CollectionService")

local ApplyCore = require(ReplicatedStorage.Shared.ApplyCore)
local PlacementPolicy = require(ReplicatedStorage.Shared.PlacementPolicy)

local PlotService = require(ServerScriptService.Systems.PlotService)

local STORE_NAME = "Lanterns_v1"
local ds = DataStoreService:GetDataStore(STORE_NAME)

local FLUSH_COUNT = 6
local FLUSH_SECS = 45

local ALLOWED_PRESETS = { lantern_basic = true }

local PlacedRoot = workspace:FindFirstChild("Placed") or Instance.new("Folder")
PlacedRoot.Name = "Placed"
PlacedRoot.Parent = workspace
local LanternFolder = PlacedRoot:FindFirstChild("Lanterns") or Instance.new("Folder")
LanternFolder.Name = "Lanterns"
LanternFolder.Parent = PlacedRoot

-- Schema types
export type LanternRecord = {
    id: string,
    pk: string,
    p: { number }, -- compact position [px,py,pz]
    r: { number }, -- compact rotation [rx,ry,rz]
    t: number,
    u: number?,
    seed: number?,
    seg: number?,
}
export type LanternBlobV1 = { version: number, items: { LanternRecord } }

-- Backward-compat alias for local type usage below
type Record = LanternRecord
type PlotCache = {
    items: { [string]: Record },
    spawned: { [string]: boolean },
    newCount: number,
    lastFlushAt: number,
    flushing: boolean,
    flushScheduled: boolean,
}

local byPlot: { [string]: PlotCache } = {}

local function now()
    return os.clock()
end

local function ensureCache(plotId: string): PlotCache
    local c = byPlot[plotId]
    if not c then
        c = { items = {}, spawned = {}, newCount = 0, lastFlushAt = 0, flushing = false, flushScheduled = false }
        byPlot[plotId] = c
    end
    return c
end

local function quantize(x: number, decimals: number): number
    local m = 10 ^ (math.max(0, math.floor(decimals)))
    return math.floor(x * m + 0.5) / m
end

local function cfToCompact(cf: CFrame): ({ number }, { number })
    local p = cf.Position
    local rx, ry, rz = cf:ToOrientation()
    return { quantize(p.X, 2), quantize(p.Y, 2), quantize(p.Z, 2) }, { quantize(rx, 3), quantize(ry, 3), quantize(rz, 3) }
end

local function compactToCFrame(p: { number }, r: { number }): CFrame
    local px, py, pz = table.unpack(p, 1, 3)
    local rx, ry, rz = table.unpack(r, 1, 3)
    local pos = Vector3.new(px or 0, py or 0, pz or 0)
    return CFrame.new(pos) * CFrame.Angles(rx, ry, rz)
end

local function makeId(plotId: string, presetKey: string, cf: CFrame): string
    local p, r = cfToCompact(cf)
    local px, py, pz = table.unpack(p, 1, 3)
    local rx, ry, rz = table.unpack(r, 1, 3)
    return string.format("lan|%s|%s|%.2f|%.2f|%.2f|%.3f", plotId, presetKey, px or 0, py or 0, pz or 0, ry or 0)
end

-- Forward declaration so scheduleFlush can reference it
local flushPlot: (plotId: string) -> ()

local function scheduleFlush(plotId: string)
    local cache = ensureCache(plotId)
    if cache.flushScheduled then return end
    cache.flushScheduled = true
    task.delay(FLUSH_SECS, function()
        cache.flushScheduled = false
        local elapsed = now() - (cache.lastFlushAt or 0)
        if cache.newCount > 0 and elapsed >= 0 then
            -- Time-based flush
            flushPlot(plotId)
        end
    end)
end

local function logSave(plotId: string, itemsCount: number, approxBytes: number)
    print(('[Save] plot=%s items=%d bytes=%d ok'):format(plotId, itemsCount, approxBytes))
end

local function logLoad(plotId: string, restored: number, skipped: number)
    print(('[Load] plot=%s restored=%d skipped=%d'):format(plotId, restored, skipped))
end

local function approxSizeBytes(tbl: any): number
    local ok, str = pcall(function() return HttpService:JSONEncode(tbl) end)
    if ok and type(str) == "string" then
        return #str
    end
    return 0
end

flushPlot = function(plotId: string)
    local cache = ensureCache(plotId)
    if cache.flushing or cache.newCount <= 0 then return end
    cache.flushing = true
    local attempts = 0
    local maxAttempts = 5
    local backoff = 1.0
    while attempts < maxAttempts do
        attempts += 1
        local ok, err = pcall(function()
            ds:UpdateAsync(plotId, function(old)
                local blob = old
                if type(blob) ~= "table" then blob = { version = 1, items = {} } end
                if type(blob.items) ~= "table" then blob.items = {} end

                -- Build id -> record map from remote
                local remoteById: { [string]: LanternRecord } = {}
                for _, rec in ipairs(blob.items) do
                    if type(rec) == "table" and type(rec.id) == "string" then
                        remoteById[rec.id] = rec :: any
                    end
                end

                -- Merge new items from cache; duplicates ignored
                for id, rec in pairs(cache.items) do
                    if not remoteById[id] then
                        remoteById[id] = rec
                    end
                end

                -- Flatten back to array
                local out: { LanternRecord } = {}
                for _, rec in pairs(remoteById) do table.insert(out, rec) end
                blob.items = out
                return blob
            end)
        end)
        if ok then
            cache.lastFlushAt = now()
            cache.newCount = 0
            cache.flushing = false
            local approx = approxSizeBytes({ version = 1, items = (function()
                local t = {}
                for _, rec in pairs(cache.items) do table.insert(t, rec) end
                return t
            end)() })
            logSave(plotId, (function() local n=0 for _ in pairs(cache.items) do n+=1 end return n end)(), approx)
            return
        end
        task.wait(backoff)
        backoff *= 2
    end
    cache.flushing = false
    warn(("[Save] flush failed plot=%s attempts=%d"):format(plotId, attempts))
end

local function ensureTagLantern(inst: Instance)
    if inst then CollectionService:AddTag(inst, "Lantern") end
end

local function reconstructAndSpawn(rec: Record)
    local cf = compactToCFrame(rec.p, rec.r)
    local model = ApplyCore.place(rec.pk, cf)
    if model then
        model.Parent = LanternFolder
        CollectionService:AddTag(model, "Lantern")
    end
    return model ~= nil
end

local function resolveIslandContext(): (string, CFrame)
    local islandModel = workspace:FindFirstChild("Islands")
        and workspace.Islands:FindFirstChild("Island_01")
    if islandModel and islandModel.PrimaryPart then
        local key = islandModel:GetAttribute("PresetKey") or "plane_64m"
        return key, islandModel.PrimaryPart.CFrame
    end
    return "plane_64m", CFrame.new()
end

local function isValidRecordForCurrentRules(rec: Record): boolean
    if type(rec) ~= "table" or type(rec.pk) ~= "string" or type(rec.id) ~= "string" then return false end
    if not ALLOWED_PRESETS[rec.pk] then return false end
    local px, py, pz = table.unpack(rec.p, 1, 3)
    local pos = Vector3.new(px or 0, py or 0, pz or 0)
    local islandKey, islandCF = resolveIslandContext()
    local ok, reason = PlacementPolicy.validateLantern({
        position = pos,
        islandPresetKey = islandKey,
        islandCFrame = islandCF,
    })
    return ok == true
end

local function loadPlot(plotId: string)
    local cache = ensureCache(plotId)
    local ok, blob = pcall(function() return ds:GetAsync(plotId) end)
    local restored, skipped = 0, 0
    if ok and type(blob) == "table" and type(blob.items) == "table" then
        for _, rec in ipairs(blob.items) do
            local r = rec :: any
            if type(r) == "table" and type(r.id) == "string" then
                if cache.spawned[r.id] then
                    skipped += 1
                elseif isValidRecordForCurrentRules(r) then
                    cache.items[r.id] = r
                    local spawned = reconstructAndSpawn(r)
                    if spawned then
                        cache.spawned[r.id] = true
                        restored += 1
                    else
                        skipped += 1
                    end
                else
                    skipped += 1
                end
            end
        end
    end
    logLoad(plotId, restored, skipped)
end

local function onLanternPlaced(plotId: string, presetKey: string, cf: CFrame, player: Player?)
    if type(plotId) ~= "string" or not ALLOWED_PRESETS[presetKey] or typeof(cf) ~= "CFrame" then return end
    local cache = ensureCache(plotId)
    local id = makeId(plotId, presetKey, cf)
    if cache.items[id] then
        -- Duplicate; ignore
        return
    end
    local p, r = cfToCompact(cf)
    local rec: Record = { id = id, pk = presetKey, p = p, r = r, t = os.time(), u = player and player.UserId or nil }
    cache.items[id] = rec
    cache.newCount += 1
    if cache.newCount >= FLUSH_COUNT then
        flushPlot(plotId)
    else
        scheduleFlush(plotId)
    end
end

-- Bindable for placement hook
local be = Instance.new("BindableEvent")
be.Name = "BE_OnLanternPlaced"
be.Parent = script.Parent
be.Event:Connect(onLanternPlaced)

-- Load on plot assignment (player join)
Players.PlayerAdded:Connect(function(player)
    local assignment = PlotService.ClaimPlot(player)
    if assignment and assignment.plotId then
        loadPlot(assignment.plotId)
    end
end)

-- Public helpers for services
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
    -- Derive plot key from id prefix: lan|plot|...
    local pk = string.match(rec.id, "^lan|([^|]+)|") or "P1"
    local cache = ensureCache(pk)
    cache.items[rec.id] = rec
    cache.newCount += 1
    if cache.newCount >= FLUSH_COUNT then
        flushPlot(pk)
    else
        scheduleFlush(pk)
    end
end

return M
