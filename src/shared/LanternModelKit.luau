--!strict
-- LanternModelKit: builds lantern models deterministically from params
-- Now supports multiple lantern types

export type BuildParams = {
    seed: number?,
    segments: number?,
    stemHeight: number?,
    stemThickness: number?,
    headSize: number?,
    lanternType: string?, -- NEW: specifies which lantern type to build
}

export type BuildResult = { model: Model, meta: BuildParams & { segments: number, lanternType: string } }

local LanternModelKit = {}

-- Registry of lantern builders
local LanternBuilders = {}

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

-- Original default lantern builder
local function buildDefault(cf: CFrame, params: BuildParams): BuildResult
    local segs = clamp((params and params.segments) or 2, 1, 6)
    local stemH = clamp((params and params.stemHeight) or 2.0, 0.5, 8.0)
    local stemT = clamp((params and params.stemThickness) or 0.2, 0.1, 1.0)
    local headS = clamp((params and params.headSize) or 0.8, 0.4, 2.0)
    local seed = (params and params.seed) or 0

    local model = Instance.new("Model")
    model.Name = "Lantern_Default"

    -- Base plate
    local baseH = 0.2
    local base = part("Base", Vector3.new(stemT * 2, baseH, stemT * 2), cf * CFrame.new(0, baseH * 0.5, 0), Color3.fromRGB(60, 60, 60), Enum.Material.Metal)
    base.Parent = model

    -- Stem: N stacked segments
    local segH = stemH / segs
    local y = baseH
    for i = 1, segs do
        local seg = part("Stem_" .. i, Vector3.new(stemT, segH, stemT), cf * CFrame.new(0, y + segH * 0.5, 0), Color3.fromRGB(100, 100, 100), Enum.Material.Metal)
        seg.Parent = model
        y += segH
    end

    -- Head
    local head = part("Head", Vector3.new(headS, headS, headS), cf * CFrame.new(0, y + headS * 0.5, 0), Color3.fromRGB(255, 220, 120), Enum.Material.Glass)
    head.Transparency = 0.2
    head.Parent = model

    -- Primary part for easy placement
    model.PrimaryPart = base

    -- Attributes
    model:SetAttribute("Kind", "Default")
    model:SetAttribute("Segments", segs)
    model:SetAttribute("Seed", seed)

    return { model = model, meta = { seed = seed, segments = segs, stemHeight = stemH, stemThickness = stemT, headSize = headS, lanternType = "Default" } }
end

-- NEW: Default2 lantern builder (spheres stacked on each other)
local function buildDefault2(cf: CFrame, params: BuildParams): BuildResult
    local segs = clamp((params and params.segments) or 3, 2, 5) -- Default2 uses more segments
    local stemH = clamp((params and params.stemHeight) or 2.5, 0.8, 6.0)
    local stemT = clamp((params and params.stemThickness) or 0.15, 0.1, 0.8)
    local headS = clamp((params and params.headSize) or 1.0, 0.5, 2.5)
    local seed = (params and params.seed) or 0

    local model = Instance.new("Model")
    model.Name = "Lantern_Default2"

    -- Base sphere (slightly flattened)
    local baseH = 0.3
    local baseRadius = stemT * 1.5
    local base = part("Base", Vector3.new(baseRadius * 2, baseH, baseRadius * 2), cf * CFrame.new(0, baseH * 0.5, 0), Color3.fromRGB(80, 70, 60), Enum.Material.Metal)
    base.Shape = Enum.PartType.Ball
    base.Parent = model

    -- Stem: stacked spheres of decreasing size
    local segH = stemH / segs
    local y = baseH
    for i = 1, segs do
        local segRadius = stemT * (1.2 - (i - 1) * 0.15) -- Gradually decrease size
        local segSize = segRadius * 2
        local seg = part("Stem_" .. i, Vector3.new(segSize, segSize, segSize), cf * CFrame.new(0, y + segH * 0.5, 0), Color3.fromRGB(120, 100, 80), Enum.Material.Metal)
        seg.Shape = Enum.PartType.Ball
        seg.Parent = model
        y += segH
    end

    -- Head: larger glowing sphere
    local head = part("Head", Vector3.new(headS, headS, headS), cf * CFrame.new(0, y + headS * 0.5, 0), Color3.fromRGB(255, 200, 100), Enum.Material.ForceField)
    head.Shape = Enum.PartType.Ball
    head.Transparency = 0.3
    head.Parent = model

    -- Add inner glow effect
    local innerGlow = part("InnerGlow", Vector3.new(headS * 0.7, headS * 0.7, headS * 0.7), cf * CFrame.new(0, y + headS * 0.5, 0), Color3.fromRGB(255, 255, 200), Enum.Material.Neon)
    innerGlow.Shape = Enum.PartType.Ball
    innerGlow.Transparency = 0.7
    innerGlow.Parent = model

    -- Primary part for easy placement
    model.PrimaryPart = base

    -- Attributes
    model:SetAttribute("Kind", "Default2")
    model:SetAttribute("Segments", segs)
    model:SetAttribute("Seed", seed)

    return { model = model, meta = { seed = seed, segments = segs, stemHeight = stemH, stemThickness = stemT, headSize = headS, lanternType = "Default2" } }
end

-- Register lantern builders
LanternBuilders["Default"] = buildDefault
LanternBuilders["Default2"] = buildDefault2

-- Get available lantern types
function LanternModelKit.getAvailableTypes(): {string}
    local types = {}
    for typeName, _ in pairs(LanternBuilders) do
        table.insert(types, typeName)
    end
    return types
end

-- Check if a lantern type exists
function LanternModelKit.isValidType(lanternType: string): boolean
    return LanternBuilders[lanternType] ~= nil
end

-- Main build function with type support
function LanternModelKit.Build(cf: CFrame, params: BuildParams?): BuildResult
    local actualParams = params or {}
    local lanternType = actualParams.lanternType or "Default"
    
    -- Fallback to Default if type doesn't exist
    if not LanternBuilders[lanternType] then
        warn("[LanternModelKit] Unknown lantern type: " .. tostring(lanternType) .. ", falling back to Default")
        lanternType = "Default"
    end
    
    local builder = LanternBuilders[lanternType]
    return builder(cf, actualParams)
end

-- Backward compatibility
function LanternModelKit.BuildDefault(cf: CFrame, params: BuildParams?): BuildResult
    local actualParams = params or {}
    actualParams.lanternType = "Default"
    return LanternModelKit.Build(cf, actualParams)
end

function LanternModelKit.BuildDefault2(cf: CFrame, params: BuildParams?): BuildResult
    local actualParams = params or {}
    actualParams.lanternType = "Default2"
    return LanternModelKit.Build(cf, actualParams)
end

return LanternModelKit