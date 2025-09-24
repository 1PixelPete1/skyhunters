--!strict

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WorldConfig = require(ReplicatedStorage.Config.WorldConfig)

local PlotService = {}

type AABB = { min: Vector3, max: Vector3 }

local assignedByUser: { [number]: string } = {}
local userByPlot: { [string]: number } = {}
local seedPerPlot: { [string]: number } = {}
local globalSeed = tonumber(string.sub(HttpService:GenerateGUID(false), 1, 8), 16)

function PlotService.Init(services)
    PlotService._services = services
end

local function defaultBounds(): AABB
    -- Plot bounds should match the actual terrain size from config (fallback to 192)
    local size = (WorldConfig and WorldConfig.ISLANDS and WorldConfig.ISLANDS.SizeStuds) or 192
    local half = size * 0.5
    return { min = Vector3.new(-half, 0, -half), max = Vector3.new(half, 64, half) }
end

function PlotService.ClaimPlot(player: Player)
    if assignedByUser[player.UserId] then
        local plotId = assignedByUser[player.UserId]
        return {
            plotId = plotId,
            origin = CFrame.new(),
            bounds = defaultBounds(),
        }
    end
    local plotId = "P" .. tostring(#seedPerPlot + 1)
    assignedByUser[player.UserId] = plotId
    userByPlot[plotId] = player.UserId
    seedPerPlot[plotId] = PlotService.GetPlotSeed(plotId)
    return {
        plotId = plotId,
        origin = CFrame.new(),
        bounds = defaultBounds(),
    }
end

function PlotService.ReleasePlot(player: Player)
    local plotId = assignedByUser[player.UserId]
    if plotId then
        assignedByUser[player.UserId] = nil
        userByPlot[plotId] = nil
    end
end

function PlotService.GetPlotSeed(plotId: string): number
    local hash = 0
    for i = 1, #plotId do
        hash = (hash * 33 + string.byte(plotId, i)) % 2^31
    end
    return (globalSeed + hash) % 2^31
end

function PlotService.GetPlayerForPlot(plotId: string): Player?
    local userId = userByPlot[plotId]
    if not userId then return nil end
    return Players:GetPlayerByUserId(userId)
end

-- Get plot key from position
function PlotService.GetPlotKeyFromPosition(position: Vector3): string?
    if typeof(position) ~= "Vector3" then
        return nil
    end
    -- Check all plots to see if position is within bounds
    for plotId, _ in pairs(userByPlot) do
        local bounds = defaultBounds()
        -- Defensive extraction to avoid nil comparison errors
        local minX = tonumber(bounds and bounds.min and (bounds.min :: any).X) or -96
        local maxX = tonumber(bounds and bounds.max and (bounds.max :: any).X) or 96
        local minZ = tonumber(bounds and bounds.min and (bounds.min :: any).Z) or -96
        local maxZ = tonumber(bounds and bounds.max and (bounds.max :: any).Z) or 96
        -- Assuming plots are at origin for now, adjust as needed
        if position.X >= minX and position.X <= maxX and
           position.Z >= minZ and position.Z <= maxZ then
            return plotId
        end
    end
    return nil
end

-- Get plot owner from plot key
function PlotService.GetPlotOwner(plotKey: string): Player?
    local userId = userByPlot[plotKey]
    if not userId then return nil end
    return Players:GetPlayerByUserId(userId)
end

-- Get plot data
function PlotService.GetPlotData(plotKey: string): any?
    local userId = userByPlot[plotKey]
    if not userId then return nil end
    
    return {
        plotId = plotKey,
        origin = Vector3.new(0, 100, 0),  -- Adjust based on your world layout
        bounds = defaultBounds(),
        seed = seedPerPlot[plotKey],
        owner = userId
    }
end

-- Convenience accessor for current assignment (without mutating state)
function PlotService.GetAssignment(player: Player)
    local existing = assignedByUser[player.UserId]
    if existing then
        return {
            plotId = existing,
            origin = CFrame.new(),
            bounds = defaultBounds(),
        }
    end
    -- If none, return nil (callers may choose to ClaimPlot)
    return nil
end

return PlotService
