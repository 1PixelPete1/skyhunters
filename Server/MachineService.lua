-- MachineService.lua
-- Handles machine placement and stat multiplication

local MachineService = {}

-- Machine effect calculations with diminishing returns
local DIMINISHING_FACTOR = 0.85 -- Each additional stack is 85% as effective

-- Active machines by plot
local plotMachines = {} -- {plotId = {machineId = {type, rarity, position}}}

function MachineService:PlaceMachine(plotId, machineType, rarity, position)
    if not plotMachines[plotId] then
        plotMachines[plotId] = {}
    end
    
    local machineId = "machine_" .. tick()
    plotMachines[plotId][machineId] = {
        type = machineType,
        rarity = rarity,
        position = position,
        radius = self:GetMachineRadius(machineType, rarity)
    }
    
    return machineId
end

function MachineService:GetMachineRadius(machineType, rarity)
    if machineType == "Condenser" then
        return 30 + (rarity * 10) -- 40, 50, 60 studs by rarity
    elseif machineType == "Collector" then
        return math.huge -- Global effect
    elseif machineType == "Amplifier" then
        return 50 + (rarity * 15) -- 65, 80, 95 studs
    end
    return 50
end

function MachineService:CalculateLanternMultipliers(plotId, lanternPosition)
    local multipliers = {
        generation = 1,
        range = 1,
        brightness = 1
    }
    
    if not plotMachines[plotId] then
        return multipliers
    end
    
    -- Track stacks for diminishing returns
    local stacks = {
        Condenser = 0,
        Collector = 0,
        Amplifier = 0
    }
    
    -- Check each machine's effect
    for _, machine in pairs(plotMachines[plotId]) do
        local distance = (machine.position - lanternPosition).Magnitude
        
        if machine.type == "Condenser" and distance <= machine.radius then
            stacks.Condenser = stacks.Condenser + 1
            local effectiveness = math.pow(DIMINISHING_FACTOR, stacks.Condenser - 1)
            local bonus = 0.2 + (machine.rarity * 0.15) -- 0.35, 0.5, 0.65
            multipliers.range = multipliers.range * (1 + bonus * effectiveness)
            
        elseif machine.type == "Collector" then
            stacks.Collector = stacks.Collector + 1
            local effectiveness = math.pow(DIMINISHING_FACTOR, stacks.Collector - 1)
            local bonus = 0.1 + (machine.rarity * 0.1) -- 0.2, 0.3, 0.4
            multipliers.generation = multipliers.generation * (1 + bonus * effectiveness)
            
        elseif machine.type == "Amplifier" and distance <= machine.radius then
            stacks.Amplifier = stacks.Amplifier + 1
            local effectiveness = math.pow(DIMINISHING_FACTOR, stacks.Amplifier - 1)
            local bonus = 0.05 + (machine.rarity * 0.05) -- 0.1, 0.15, 0.2
            multipliers.generation = multipliers.generation * (1 + bonus * effectiveness)
            multipliers.brightness = multipliers.brightness * (1 + bonus * 0.5 * effectiveness)
        end
    end
    
    return multipliers
end

function MachineService:GetPlotMachineCount(plotId, machineType)
    if not plotMachines[plotId] then return 0 end
    
    local count = 0
    for _, machine in pairs(plotMachines[plotId]) do
        if not machineType or machine.type == machineType then
            count = count + 1
        end
    end
    return count
end

return MachineService