--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Net = require(ReplicatedStorage.Shared.Net)
local Events = require(ReplicatedStorage:WaitForChild("systems"):WaitForChild("Lantern"):WaitForChild("LanternEvents"))
local Shared = require(ReplicatedStorage.systems.Lantern.LanternShared)

type LanternRecord = {
    lanternId: string,
    ownerUserId: number,
    pondId: string,
    isLit: boolean,
    oilReserve: number,
    burnRate: number,
    expiresAt: number?,
    style: string?,
}

local LanternService = {}

local lanterns: { [string]: LanternRecord } = {}
local dirty: { [string]: boolean } = {}
local pondScatterPending: { [string]: { reason: string, at: number } } = {}

local function now()
    return os.clock()
end

local function computeExpiry(oilReserve: number, burnRate: number): number
    if burnRate <= 0 then return now() + 1e9 end
    return now() + (oilReserve / burnRate) * 60
end

function LanternService.Init(services)
    LanternService._services = services
    LanternService._timer = services.LanternTimerQueue
    LanternService._replication = services.LanternReplication
end

local function getProfile(player: Player)
    local SaveService = LanternService._services.SaveService
    return SaveService and SaveService.GetProfile(player) or nil
end

local function ensureLanternState(profile)
    profile.lantern = profile.lantern or {
        ponds = { mainId = "pond_1", connected = {}, lanternSlots = 1 },
        oil = { canister = 0, stored = 0 },
        lanterns = {},
        runLantern = { on = false, visCharge = 1.0, fxMode = "auto" },
        flame = { amount = 0, voyageTier = 0 },
        settings = { lowPerf = true, fxStepHz = Shared.PERF.fxStepHzDefault },
    }
end

-- Server authority: place a base lantern if within slot cap
function LanternService.PlaceBaseLantern(player: Player, pondId: string, style: string)
    local profile = getProfile(player)
    if not profile then return { ok = false, err = "NO_PROFILE" } end
    ensureLanternState(profile)

    local lid = "lantern_" .. tostring(math.floor(now() * 1000))
    local burnRate = Shared.ECON.baseBurnRate or 1
    local rec: LanternRecord = {
        lanternId = lid,
        ownerUserId = player.UserId,
        pondId = pondId or profile.lantern.ponds.mainId,
        isLit = false,
        oilReserve = 0,
        burnRate = burnRate,
        expiresAt = nil,
        style = style or "default",
    }
    lanterns[lid] = rec
    dirty[lid] = true
    return { ok = true, lanternId = lid }
end

function LanternService.RefillBaseLantern(player: Player, lanternId: string, amount: number)
    local profile = getProfile(player)
    if not profile then return { ok = false, err = "NO_PROFILE" } end
    ensureLanternState(profile)
    amount = math.max(0, math.floor(amount or 0))
    local lrec = lanterns[lanternId]
    if not lrec then return { ok = false, err = "LANTERN_NOT_FOUND" } end
    if lrec.ownerUserId ~= player.UserId then return { ok = false, err = "NOT_OWNER" } end

    -- Check inventory for oil canisters first
    local InventoryIntegration = LanternService._services and LanternService._services.InventoryIntegrationService
    if InventoryIntegration then
        local oilCanisters = InventoryIntegration:ValidateOilCanister(player)
        if oilCanisters > 0 then
            -- Each canister provides 50 oil units
            local canistersNeeded = math.ceil(amount / 50)
            if oilCanisters >= canistersNeeded then
                -- Consume canisters instead of stored oil
                local consumed = InventoryIntegration:ConsumeOilCanister(player, canistersNeeded)
                if consumed then
                    lrec.oilReserve += amount
                    lrec.isLit = true
                    lrec.expiresAt = computeExpiry(lrec.oilReserve, lrec.burnRate)
                    if LanternService._timer then
                        LanternService._timer.AddOrUpdate(lanternId, lrec.expiresAt :: number)
                    end
                    dirty[lanternId] = true
                    return { ok = true, source = "inventory" }
                end
            end
        end
    end

    -- Fallback to stored oil
    if profile.lantern.oil.stored < amount then
        return { ok = false, err = "INSUFFICIENT_OIL" }
    end
    profile.lantern.oil.stored -= amount
    lrec.oilReserve += amount
    lrec.isLit = true
    lrec.expiresAt = computeExpiry(lrec.oilReserve, lrec.burnRate)
    if LanternService._timer then
        LanternService._timer.AddOrUpdate(lanternId, lrec.expiresAt :: number)
    end
    dirty[lanternId] = true
    return { ok = true, source = "storage" }
end

function LanternService.DepositOil(player: Player, amount: number)
    local profile = getProfile(player)
    if not profile then return { ok = false, err = "NO_PROFILE" } end
    ensureLanternState(profile)
    amount = math.max(0, math.floor(amount or 0))
    if profile.lantern.oil.canister < amount then
        return { ok = false, err = "INSUFFICIENT_CANISTER" }
    end
    profile.lantern.oil.canister -= amount
    profile.lantern.oil.stored += amount
    return { ok = true, stored = profile.lantern.oil.stored }
end

function LanternService.ToggleRunLantern(player: Player, on: boolean)
    local profile = getProfile(player)
    if not profile then return { ok = false, err = "NO_PROFILE" } end
    ensureLanternState(profile)
    profile.lantern.runLantern.on = on and true or false
    -- Only used for sanity/telemetry server-side; no gameplay authority.
    return { ok = true, on = profile.lantern.runLantern.on }
end

function LanternService._expireLantern(lanternId: string)
    local lrec = lanterns[lanternId]
    if not lrec then return end
    lrec.isLit = false
    lrec.oilReserve = 0
    lrec.expiresAt = nil
    dirty[lanternId] = true
    -- Aggregate scatter by pond
    pondScatterPending[lrec.pondId] = { reason = "Depleted", at = now() }
end

function LanternService._collectDirty()
    local out = {}
    for lid, _ in pairs(dirty) do
        local l = lanterns[lid]
        if l then
            out[lid] = { isLit = l.isLit, oilReserve = l.oilReserve }
        end
        dirty[lid] = nil
    end
    return out
end

function LanternService.FlushReplication()
    -- Called by replication tick to send batched deltas
    local batch = LanternService._collectDirty()
    if next(batch) ~= nil then
        for _, plr in ipairs(Players:GetPlayers()) do
            Net:GetEvent(Events.Events.RE_OnLanternStatesBatch):FireClient(plr, batch)
        end
    end
    -- Coalesce scatters by pond.
    if next(pondScatterPending) ~= nil then
        for pondId, info in pairs(pondScatterPending) do
            for _, plr in ipairs(Players:GetPlayers()) do
                Net:GetEvent(Events.Events.RE_OnMinionScatter):FireClient(plr, pondId, info.reason)
            end
            pondScatterPending[pondId] = nil
        end
    end
end

return LanternService

