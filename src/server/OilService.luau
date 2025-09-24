--!strict
-- OilService: visual terrain-wide oil layer with variable capacity system

local Workspace = game:GetService("Workspace")
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Shared")
local Config = RS:WaitForChild("Config")
local SafeRequire = require(Shared:WaitForChild("SafeRequire"))
local function load(inst: Instance?)
    local r = SafeRequire.load(inst)
    if r.ok then return r.mod end
    warn("[OilService] require failed for", r.path or "[nil]", r.reason or "unknown")
    return nil
end

local PondFieldService = load(script.Parent:WaitForChild("PondFieldService"))
local WorldConfig = require(Config:WaitForChild("WorldConfig"))

local OilService = {}

local container = Workspace:FindFirstChild("Oil") or Instance.new("Folder")
container.Name = "Oil"
container.Parent = Workspace

-- Enhanced storage for oil system
local oilLayers: { [string]: Part } = {} -- NEW: terrain-wide oil layers
local thermometers: { [string]: Part } = {} -- Thermometer gauges
local centers: { [string]: Vector3 } = {}
local levelByPlot: { [string]: number } = {} -- Current oil amount (0-capacity)
local capacityByPlot: { [string]: number } = {} -- Maximum capacity per plot
local baseCapacityByPlot: { [string]: number } = {} -- Base capacity from ponds
local plotBounds: { [string]: { center: Vector3, size: Vector3 } } = {} -- Plot boundaries

-- NEW: Create terrain-wide oil layer underneath the island
local function ensureOilLayer(pk: string, plotCenter: Vector3): Part
    local layer = oilLayers[pk]
    if layer and layer.Parent then return layer end
    
    -- Get island size from WorldConfig
    local islandSize = WorldConfig.ISLANDS.SizeStuds or 192
    local plotSize = plotBounds[pk] and plotBounds[pk].size or Vector3.new(islandSize, 10, islandSize)
    
    layer = Instance.new("Part")
    layer.Name = "OilLayer_" .. pk
    layer.Anchored = true
    layer.CanCollide = false
    layer.Material = Enum.Material.SmoothPlastic
    layer.Color = Color3.fromRGB(10, 10, 10)
    layer.Transparency = 0.3
    layer.Parent = container
    oilLayers[pk] = layer
    
    -- Start with minimal height (will be updated by updateVisualization)
    layer.Size = Vector3.new(plotSize.X, 0.1, plotSize.Z)
    layer.CFrame = CFrame.new(plotCenter + Vector3.new(0, -5, 0))
    
    return layer
end

-- NEW: Create thermometer gauge near pond
local function ensureThermometer(pk: string, center: Vector3, radius: number): Part
    local thermo = thermometers[pk]
    if thermo and thermo.Parent then return thermo end
    
    -- Create cylindrical housing
    thermo = Instance.new("Part")
    thermo.Name = "OilGauge_" .. pk
    thermo.Anchored = true
    thermo.CanCollide = false
    thermo.Material = Enum.Material.Metal
    thermo.Color = Color3.fromRGB(120, 120, 120)
    thermo.Shape = Enum.PartType.Cylinder
    thermo.Size = Vector3.new(0.9, 4.0, 0.9) -- diameter, height, diameter
    local thermometerPos = center + Vector3.new(radius + 1.5, 2, 0)
    -- Orient cylinder vertically (Cylinder’s length axis is along Y for PartType.Cylinder)
    thermo.CFrame = CFrame.new(thermometerPos)
    thermo.Parent = container
    thermometers[pk] = thermo
    
    -- Create cylindrical oil level indicator inside the gauge
    local indicator = Instance.new("Part")
    indicator.Name = "OilLevel"
    indicator.Anchored = true
    indicator.CanCollide = false
    indicator.Material = Enum.Material.Neon
    indicator.Color = Color3.fromRGB(20, 20, 20) -- Dark when empty
    indicator.Shape = Enum.PartType.Cylinder
    indicator.Size = Vector3.new(0.6, 0.2, 0.6) -- start thin column
    indicator.CFrame = CFrame.new(thermometerPos + Vector3.new(0, -1.8, 0))
    indicator.Parent = thermo
    
    -- Create capacity label
    local label = Instance.new("SurfaceGui")
    label.Name = "CapacityLabel"
    label.Face = Enum.NormalId.Front
    label.Parent = thermo
    
    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, 0, 1, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.Text = "0/100"
    textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    textLabel.TextScaled = true
    textLabel.Font = Enum.Font.SourceSansBold
    textLabel.Parent = label
    
    return thermo
end

function OilService.initForPlot(pk: string, center: Vector3, radius: number)
    -- Store plot center and bounds for oil layer calculation
    centers[pk] = center
    local islandSize = WorldConfig.ISLANDS.SizeStuds or 192
    plotBounds[pk] = {
        center = center,
        size = Vector3.new(islandSize, 10, islandSize)
    }
    
    ensureOilLayer(pk, center) -- NEW: create terrain-wide oil layer
    ensureThermometer(pk, center, radius) -- Create thermometer
    levelByPlot[pk] = levelByPlot[pk] or 0
    
    -- Set base capacity from pond (based on pond area)
    local baseCapacity = math.floor(radius * radius * 0.5) -- Capacity based on pond size
    baseCapacityByPlot[pk] = baseCapacity
    capacityByPlot[pk] = capacityByPlot[pk] or baseCapacity
    
    print(string.format("[OilService] Initialized plot %s with base capacity %d from pond (radius=%.1f)", pk, baseCapacity, radius))
    
    -- Force update with current level to apply new height calculation
    OilService.updateVisualization(pk)
end

-- NEW: Set oil amount (not percentage, but actual units)
function OilService.setOilAmount(pk: string, amount: number)
    local capacity = capacityByPlot[pk] or 100
    local actualAmount = math.clamp(amount, 0, capacity)
    levelByPlot[pk] = actualAmount
    OilService.updateVisualization(pk)
end

-- DEPRECATED: Keep for backward compatibility but convert to amount-based
function OilService.setOilLevel(pk: string, level: number)
    local capacity = capacityByPlot[pk] or 100
    local amount = (level / 100) * capacity
    OilService.setOilAmount(pk, amount)
end

-- NEW: Update both oil layer and thermometer visualization
function OilService.updateVisualization(pk: string)
    local layer = oilLayers[pk]
    local thermo = thermometers[pk]
    if not layer then return end
    
    local center = centers[pk] or Vector3.new(0,0,0)
    local currentAmount = levelByPlot[pk] or 0
    local capacity = capacityByPlot[pk] or 100
    local fillPercent = capacity > 0 and (currentAmount / capacity) or 0
    
    -- Update terrain-wide oil layer - height represents volume
    local plotBound = plotBounds[pk]
    if plotBound then
        local baseY = center.Y - 6.0  -- Base of oil layer, well below terrain
        local maxOilHeight = 3.0      -- Maximum oil height when at full capacity
        local oilHeight = math.max(0.1, fillPercent * maxOilHeight)
        
        layer.Size = Vector3.new(plotBound.size.X, oilHeight, plotBound.size.Z)
        layer.CFrame = CFrame.new(plotBound.center.X, baseY + oilHeight * 0.5, plotBound.center.Z)
        
        -- Update oil color based on fill level
        if fillPercent < 0.1 then
            layer.Color = Color3.fromRGB(5, 5, 5)     -- Very dark when almost empty
            layer.Transparency = 0.8
        elseif fillPercent < 0.5 then
            layer.Color = Color3.fromRGB(15, 10, 5)   -- Dark brown when low
            layer.Transparency = 0.5
        else
            layer.Color = Color3.fromRGB(25, 15, 5)   -- Darker oil color when fuller
            layer.Transparency = 0.3
        end
    end
    
    -- Update thermometer if it exists
    if thermo then
        local indicator = thermo:FindFirstChild("OilLevel")
        if indicator then
            -- Update indicator size and color based on fill level
            local maxIndicatorHeight = 3.5 -- Max height inside gauge
            local indicatorHeight = math.max(0.2, fillPercent * maxIndicatorHeight)
            indicator.Size = Vector3.new(0.6, indicatorHeight, 0.6)
            
            -- Position at bottom and grow upward
            local thermometerPos = thermo.Position
            indicator.CFrame = CFrame.new(thermometerPos + Vector3.new(0, -1.8 + indicatorHeight * 0.5, 0))
            
            -- Color based on fill level
            if fillPercent < 0.3 then
                indicator.Color = Color3.fromRGB(80, 20, 20) -- Dark red when low
            elseif fillPercent < 0.7 then
                indicator.Color = Color3.fromRGB(100, 60, 20) -- Orange when medium
            else
                indicator.Color = Color3.fromRGB(20, 80, 20) -- Green when high
            end
        end
        
        -- Update capacity label
        local label = thermo:FindFirstChild("CapacityLabel")
        if label then
            local textLabel = label:FindFirstChild("TextLabel")
            if textLabel then
                textLabel.Text = string.format("%.0f/%.0f", currentAmount, capacity)
            end
        end
    end
end

-- NEW: Get current oil amount
function OilService.getOilAmount(pk: string): number
    return levelByPlot[pk] or 0
end

-- NEW: Get current capacity
function OilService.getOilCapacity(pk: string): number
    return capacityByPlot[pk] or 100
end

-- NEW: Get oil level as percentage (0-100)
function OilService.getOilLevel(pk: string): number
    local amount = levelByPlot[pk] or 0
    local capacity = capacityByPlot[pk] or 100
    return capacity > 0 and (amount / capacity) * 100 or 0
end

-- NEW: Add capacity from oil reservoirs
function OilService.addCapacityForPlot(pk: string, additionalCapacity: number)
    local baseCapacity = baseCapacityByPlot[pk] or 100
    capacityByPlot[pk] = baseCapacity + additionalCapacity
    print(string.format("[OilService] Added %d capacity to plot %s, total: %d", additionalCapacity, pk, capacityByPlot[pk]))
    OilService.updateVisualization(pk)
end

-- NEW: Remove capacity when oil reservoirs are removed
function OilService.removeCapacityForPlot(pk: string, removedCapacity: number)
    local baseCapacity = baseCapacityByPlot[pk] or 100
    capacityByPlot[pk] = math.max(baseCapacity, (capacityByPlot[pk] or 100) - removedCapacity)
    -- Clamp current oil amount to new capacity
    local currentAmount = levelByPlot[pk] or 0
    if currentAmount > capacityByPlot[pk] then
        levelByPlot[pk] = capacityByPlot[pk]
    end
    print(string.format("[OilService] Removed %d capacity from plot %s, total: %d", removedCapacity, pk, capacityByPlot[pk]))
    OilService.updateVisualization(pk)
end

-- NEW: Set total capacity directly (used during restoration)
function OilService.setCapacityForPlot(pk: string, totalCapacity: number)
    local baseCapacity = baseCapacityByPlot[pk] or 100
    capacityByPlot[pk] = math.max(baseCapacity, totalCapacity)
    -- Clamp current oil amount to new capacity
    local currentAmount = levelByPlot[pk] or 0
    if currentAmount > capacityByPlot[pk] then
        levelByPlot[pk] = capacityByPlot[pk]
    end
    OilService.updateVisualization(pk)
end

-- NEW: Update base capacity when ponds are added (called by PondNetworkService)
function OilService.addPondCapacity(pk: string, pondRadius: number)
    local additionalBaseCapacity = math.floor(pondRadius * pondRadius * 0.5)
    local currentBaseCapacity = baseCapacityByPlot[pk] or 0
    baseCapacityByPlot[pk] = currentBaseCapacity + additionalBaseCapacity
    
    -- Recalculate total capacity (base + reservoirs)
    local reservoirCapacity = (capacityByPlot[pk] or 0) - currentBaseCapacity
    capacityByPlot[pk] = baseCapacityByPlot[pk] + math.max(0, reservoirCapacity)
    
    print(string.format("[OilService] Added pond capacity %d to plot %s, new base: %d, total: %d", 
        additionalBaseCapacity, pk, baseCapacityByPlot[pk], capacityByPlot[pk]))
    OilService.updateVisualization(pk)
end

function OilService.isWithinSupply(pk: string, pos: Vector3): boolean
    return PondFieldService.isWithinSupply(pk, pos)
end

return OilService

