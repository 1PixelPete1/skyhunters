--!strict
-- PondFieldService: simple disc-based supply per plot

local RS = game:GetService("ReplicatedStorage")

local PondFieldService = {}

type Disc = { center: Vector3, radius: number }

local byPlot: { [string]: { discs: { Disc } } } = {}

local function ensurePlot(pk: string)
    local t = byPlot[pk]
    if not t then
        t = { discs = {} }
        byPlot[pk] = t
    end
    return t
end

function PondFieldService.ensureDefault(pk: string, center: Vector3, radius: number)
    local t = ensurePlot(pk)
    t.discs = { { center = center, radius = radius } }
end

function PondFieldService.getDiscs(pk: string): { Disc }
    local t = byPlot[pk]
    if not t then return {} end
    return t.discs
end

function PondFieldService.isWithinSupply(pk: string, pos: Vector3): boolean
    local discs = PondFieldService.getDiscs(pk)
    for _, d in ipairs(discs) do
        local dx = pos.X - d.center.X
        local dz = pos.Z - d.center.Z
        if (dx*dx + dz*dz) <= (d.radius * d.radius) then
            return true
        end
    end
    return false
end

-- RemoteFunction: RF_GetPondDisc (primary disc)
local LegacyRemotes = RS:FindFirstChild("Remotes") or Instance.new("Folder")
LegacyRemotes.Name = "Remotes"; LegacyRemotes.Parent = RS
local Net = RS:FindFirstChild("Net") or Instance.new("Folder"); Net.Name = "Net"; Net.Parent = RS
local NetRemotes = Net:FindFirstChild("Remotes") or Instance.new("Folder"); NetRemotes.Name = "Remotes"; NetRemotes.Parent = Net

local RF = LegacyRemotes:FindFirstChild("RF_GetPondDisc") or Instance.new("RemoteFunction")
RF.Name = "RF_GetPondDisc"; RF.Parent = LegacyRemotes
local RF_Net = NetRemotes:FindFirstChild("RF_GetPondDisc") or Instance.new("RemoteFunction")
RF_Net.Name = "RF_GetPondDisc"; RF_Net.Parent = NetRemotes

local warned = false
local function handleGetPondDisc(player, plotKey: string)
    if not warned then
        warned = true
        warn("[Deprecation] RF_GetPondDisc is deprecated; use RF_GetPondNetworkSnapshot")
    end
    if type(plotKey) ~= "string" then return nil, nil end
    local discs = PondFieldService.getDiscs(plotKey)
    local d = discs[1]
    if d then
        return d.center, d.radius
    end
    return nil, nil
end

RF.OnServerInvoke = handleGetPondDisc
RF_Net.OnServerInvoke = handleGetPondDisc

return PondFieldService
