-- LanternService.lua
-- Core lantern management and resource generation

local LanternService = {}
local RunService = game:GetService("RunService")

-- Constants
local TICK_RATE = 1 -- seconds
local BASE_GENERATION_RATE = 0.1 -- resource per tick
local DEPRECIATION_START = 100 -- units before depreciation
local DEPRECIATION_RATE = 0.95 -- multiplicative per unit above threshold

-- Active lanterns by plot
local plotLanterns = {} -- {plotId = {lanternId = {model, stats, reservoir}}}
local lastTick = tick()

function LanternService:RegisterLantern(plotId, lanternId, model, stats)
    if not plotLanterns[plotId] then
        plotLanterns[plotId] = {}
    end
    
    plotLanterns[plotId][lanternId] = {
        model = model,
        stats = stats or {
            generationRate = BASE_GENERATION_RATE,
            range = 50,
            brightness = 1,
            rarity = 1
        },
        reservoir = 0
    }
    
    -- Fire update for light merger
    self:FireLanternTopologyChanged(plotId)
end

function LanternService:RemoveLantern(plotId, lanternId)
    if plotLanterns[plotId] and plotLanterns[plotId][lanternId] then
        plotLanterns[plotId][lanternId] = nil
        self:FireLanternTopologyChanged(plotId)
    end
end

function LanternService:GetPlotReservoir(plotId)
    local total = 0
    if plotLanterns[plotId] then
        for _, lantern in pairs(plotLanterns[plotId]) do
            total = total + (lantern.reservoir or 0)
        end
    end
    return total
end

function LanternService:SellReservoir(player, plotId)
    local amount = self:GetPlotReservoir(plotId)
    if amount <= 0 then return 0 end
    
    -- Calculate with depreciation
    local effectiveAmount = amount
    if amount > DEPRECIATION_START then
        local excess = amount - DEPRECIATION_START
        effectiveAmount = DEPRECIATION_START + (excess * DEPRECIATION_RATE)
    end
    
    -- Clear reservoirs
    if plotLanterns[plotId] then
        for _, lantern in pairs(plotLanterns[plotId]) do
            lantern.reservoir = 0
        end
    end
    
    -- Convert to gold (placeholder rate)
    local gold = math.floor(effectiveAmount * 10)
    -- TODO: Add gold to player through economy service
    
    return gold, amount -- return both for UI feedback
end

-- Generation tick
function LanternService:Tick()
    local now = tick()
    local dt = now - lastTick
    
    if dt < TICK_RATE then return end
    lastTick = now
    
    for plotId, lanterns in pairs(plotLanterns) do
        for lanternId, data in pairs(lanterns) do
            -- Generate resource
            data.reservoir = data.reservoir + data.stats.generationRate
            
            -- Cap at some maximum if needed
            data.reservoir = math.min(data.reservoir, 1000)
        end
    end
end

function LanternService:GetLanternLightData(plotId)
    -- For light merger client
    local lights = {}
    if plotLanterns[plotId] then
        for lanternId, data in pairs(plotLanterns[plotId]) do
            if data.model and data.model.PrimaryPart then
                table.insert(lights, {
                    id = lanternId,
                    position = data.model.PrimaryPart.Position,
                    range = data.stats.range,
                    brightness = data.stats.brightness,
                    rarity = data.stats.rarity or 1
                })
            end
        end
    end
    return lights
end

function LanternService:FireLanternTopologyChanged(plotId)
    -- Network to plot owner's client for merger update
    -- Implementation depends on your networking setup
end

-- Initialize tick loop
RunService.Heartbeat:Connect(function()
    LanternService:Tick()
end)

return LanternService