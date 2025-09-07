--!strict

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

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
    -- Simple square plot centered at origin
    local half = 32
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

return PlotService
