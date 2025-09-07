--!strict
-- LanternModelKit: builds a simple default lantern model deterministically from params

export type BuildParams = {
    seed: number?,
    segments: number?,
    stemHeight: number?,
    stemThickness: number?,
    headSize: number?,
}

export type BuildResult = { model: Model, meta: BuildParams & { segments: number } }

local LanternModelKit = {}

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

function LanternModelKit.Build(cf: CFrame, params: BuildParams?): BuildResult
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

    return { model = model, meta = { seed = seed, segments = segs, stemHeight = stemH, stemThickness = stemT, headSize = headS } }
end

return LanternModelKit

