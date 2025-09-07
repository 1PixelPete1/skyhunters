--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Version = nil
pcall(function()
    Version = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Version"))
end)

local SaveService = {}

local profiles: { [number]: any } = {}

function SaveService.Init(services)
    SaveService._services = services

    Players.PlayerAdded:Connect(function(player)
        local profile = SaveService.LoadProfile(player)
        if profile then
            -- Ensure schema is up-to-date and persist once post-migration
            SaveService.SaveProfile(player)
            if services.PlotService then
                local assignment = services.PlotService.ClaimPlot(player)
                local Net = services.Net
                if Net then
                    Net:GetEvent("RE_BaseAssigned"):FireClient(player, assignment)
                    Net:GetEvent("RE_Balances"):FireClient(player, profile.balances)
                end
            end
        end
    end)

    Players.PlayerRemoving:Connect(function(player)
        SaveService.SaveProfile(player)
        if services.PlotService then
            services.PlotService.ReleasePlot(player)
        end
    end)
end

function SaveService.DefaultProfile(userId: number)
    return {
        __schemaVersion = 2,
        userId = userId,
        balances = { aether = 0, crumbs = 0 },
        inventory = {},
        upgrades = {},
        baseState = {
            plotLocalOrigin = nil,
            placements = {},
            collectors = {},
            threadsCache = nil,
            baselineIncome = 0,
        },
        lantern = {
            ponds = { mainId = "pond_1", connected = {}, lanternSlots = 1 },
            oil = { canister = 0, stored = 0 },
            lanterns = {},
            runLantern = { on = false, visCharge = 1.0, fxMode = "auto" },
            flame = { amount = 0, voyageTier = 0 },
            settings = { lowPerf = true, fxStepHz = 10 },
        },
        lastSeen = os.time(),
        baselineAtLogout = 0,
        version = 1,
    }
end

function SaveService.LoadProfile(player: Player)
    local existing = profiles[player.UserId]
    if existing then
        -- migration pass on existing profiles
        SaveService._migrate(existing)
        return existing
    end
    local profile = SaveService.DefaultProfile(player.UserId)
    profiles[player.UserId] = profile
    return profile
end

function SaveService.GetProfile(player: Player)
    return profiles[player.UserId]
end

function SaveService.GetProfileByUserId(userId: number)
    return profiles[userId]
end

function SaveService.SaveProfile(player: Player)
    local profile = profiles[player.UserId]
    if profile then
        profile.lastSeen = os.time()
    end
end

function SaveService._migrate(profile)
    local target = (Version and Version.SCHEMA_VERSION) or 2
    local cur = profile.__schemaVersion or 1
    if cur < target then
        -- prune legacy keys if present (idempotent)
        profile.baseBuilding = nil
        profile.pools = nil
        profile.currents = nil
        profile.tiles = nil
        profile.floorEquipment = nil
        profile.aetherPool = nil
        profile.aetherPools = nil
        -- ensure lantern defaults
        profile.lantern = profile.lantern or {
            ponds = { mainId = "pond_1", connected = {}, lanternSlots = 1 },
            oil = { canister = 0, stored = 0 },
            lanterns = {},
            runLantern = { on = false, visCharge = 1.0, fxMode = "auto" },
            flame = { amount = 0, voyageTier = 0 },
            settings = { lowPerf = true, fxStepHz = 10 },
        }
        profile.__schemaVersion = target
    elseif not profile.__schemaVersion then
        profile.__schemaVersion = target
    end
end

return SaveService
