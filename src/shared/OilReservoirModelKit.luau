--!strict
-- OilReservoirModelKit: builds oil reservoir models for increasing oil capacity

export type BuildParams = {
    seed: number?,
    size: string?, -- "small", "medium", "large"
    capacity: number?, -- oil capacity this reservoir adds
}

export type BuildResult = { model: Model, meta: BuildParams & { size: string, capacity: number } }

local OilReservoirModelKit = {}

local function clamp(n: number, a: number, b: number): number
    return math.max(a, math.min(b, n))
end

local function part(name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
    local p = Instance.new("Part")
    p.Name = name
    p.Anchored = true
    p.CanCollide = false
    p.Size = size
    p.CFrame = cframe
    p.Color = color
    p.Material = material
    return p
end

-- Size configurations for different reservoir types
local SizeConfigs = {
    small = {
        baseSize = Vector3.new(2, 1, 2),
        tankSize = Vector3.new(1.5, 2, 1.5),
        capacity = 25,
        pipeHeight = 0.5,
    },
    medium = {
        baseSize = Vector3.new(3, 1.2, 3),
        tankSize = Vector3.new(2.5, 3, 2.5),
        capacity = 50,
        pipeHeight = 0.8,
    },
    large = {
        baseSize = Vector3.new(4, 1.5, 4),
        tankSize = Vector3.new(3.5, 4, 3.5),
        capacity = 100,
        pipeHeight = 1.0,
    },
}

local function buildReservoir(cf: CFrame, params: BuildParams): BuildResult
    local size = params.size or "small"
    local config = SizeConfigs[size] or SizeConfigs.small
    local seed = params.seed or 0
    local capacity = params.capacity or config.capacity

    local model = Instance.new("Model")
    model.Name = "OilReservoir_" .. size

    -- Base platform
    local base = part("Base", config.baseSize, cf * CFrame.new(0, config.baseSize.Y * 0.5, 0), 
        Color3.fromRGB(60, 60, 60), Enum.Material.Metal)
    base.Parent = model

    -- Main tank (cylindrical)
    local tankY = config.baseSize.Y + config.tankSize.Y * 0.5
    local tank = part("Tank", config.tankSize, cf * CFrame.new(0, tankY, 0), 
        Color3.fromRGB(40, 40, 40), Enum.Material.Metal)
    tank.Shape = Enum.PartType.Cylinder
    tank.Parent = model

    -- Oil level indicator (thin vertical strip)
    local indicatorSize = Vector3.new(0.2, config.tankSize.Y * 0.8, 0.2)
    local indicator = part("OilIndicator", indicatorSize, cf * CFrame.new(config.tankSize.X * 0.6, tankY, 0), 
        Color3.fromRGB(100, 100, 100), Enum.Material.SmoothPlastic)
    indicator.Parent = model

    -- Pipes/connectors
    local pipeSize = Vector3.new(0.3, config.pipeHeight, 0.3)
    local pipe1 = part("Pipe1", pipeSize, cf * CFrame.new(-config.tankSize.X * 0.4, config.baseSize.Y + config.pipeHeight * 0.5, config.tankSize.Z * 0.4), 
        Color3.fromRGB(80, 80, 80), Enum.Material.Metal)
    pipe1.Parent = model

    local pipe2 = part("Pipe2", pipeSize, cf * CFrame.new(config.tankSize.X * 0.4, config.baseSize.Y + config.pipeHeight * 0.5, -config.tankSize.Z * 0.4), 
        Color3.fromRGB(80, 80, 80), Enum.Material.Metal)
    pipe2.Parent = model

    -- Primary part for easy placement
    model.PrimaryPart = base

    -- Attributes
    model:SetAttribute("Kind", "OilReservoir")
    model:SetAttribute("Size", size)
    model:SetAttribute("Capacity", capacity)
    model:SetAttribute("Seed", seed)

    return { 
        model = model, 
        meta = { 
            seed = seed, 
            size = size, 
            capacity = capacity 
        } 
    }
end

-- Get available reservoir sizes
function OilReservoirModelKit.getAvailableSizes(): {string}
    local sizes = {}
    for sizeName, _ in pairs(SizeConfigs) do
        table.insert(sizes, sizeName)
    end
    return sizes
end

-- Check if a reservoir size exists
function OilReservoirModelKit.isValidSize(size: string): boolean
    return SizeConfigs[size] ~= nil
end

-- Get capacity for a size
function OilReservoirModelKit.getCapacityForSize(size: string): number
    local config = SizeConfigs[size]
    return config and config.capacity or 0
end

-- Main build function
function OilReservoirModelKit.Build(cf: CFrame, params: BuildParams?): BuildResult
    local actualParams = params or {}
    return buildReservoir(cf, actualParams)
end

return OilReservoirModelKit