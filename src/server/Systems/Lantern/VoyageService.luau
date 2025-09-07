--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Events = require(ReplicatedStorage.systems.Lantern.LanternEvents)

local VoyageService = {}

function VoyageService.Init(services)
    VoyageService._services = services
end

function VoyageService.AddFlame(player: Player, amount: number)
    local profile = VoyageService._services.SaveService.GetProfile(player)
    if not profile then return end
    profile.lantern = profile.lantern or { flame = { amount = 0, voyageTier = 0 } }
    local flame = profile.lantern.flame
    flame.amount = math.max(0, (flame.amount or 0) + (amount or 0))
    Net:GetEvent(Events.Events.RE_OnFlameChanged):FireClient(player, flame.amount, flame.voyageTier or 0)
end

function VoyageService.AdvanceVoyageTier(player: Player)
    local profile = VoyageService._services.SaveService.GetProfile(player)
    if not profile then return false end
    profile.lantern = profile.lantern or { flame = { amount = 0, voyageTier = 0 } }
    local flame = profile.lantern.flame
    flame.voyageTier = (flame.voyageTier or 0) + 1
    Net:GetEvent(Events.Events.RE_OnFlameChanged):FireClient(player, flame.amount or 0, flame.voyageTier)
    return true
end

return VoyageService

