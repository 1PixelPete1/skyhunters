--!strict
-- OilService: simple visual OilBox per plot (0..100 level)

local Workspace = game:GetService("Workspace")
local PondFieldService = require(script.Parent:WaitForChild("PondFieldService"))

local OilService = {}

local container = Workspace:FindFirstChild("Oil") or Instance.new("Folder")
container.Name = "Oil"
container.Parent = Workspace

local boxes: { [string]: Part } = {}
local centers: { [string]: Vector3 } = {}
local levelByPlot: { [string]: number } = {}

local function ensureBox(pk: string, center: Vector3, radius: number): Part
    local p = boxes[pk]
    if p and p.Parent then return p end
    p = Instance.new("Part")
    p.Name = "OilBox_" .. pk
    p.Anchored = true
    p.CanCollide = false
    p.Material = Enum.Material.SmoothPlastic
    p.Color = Color3.fromRGB(10, 10, 10)
    p.Transparency = 0.3
    p.Parent = container
    boxes[pk] = p
    -- initial size/position
    p.Size = Vector3.new(math.max(1, radius * 2), 0.2, math.max(1, radius * 2))
    p.CFrame = CFrame.new(center + Vector3.new(0, -0.1, 0))
    return p
end

function OilService.initForPlot(pk: string, center: Vector3, radius: number)
    ensureBox(pk, center, radius)
    centers[pk] = center
    levelByPlot[pk] = levelByPlot[pk] or 0
    -- FIXED: Force update with current level to apply new height calculation
    OilService.setOilLevel(pk, levelByPlot[pk])
end

function OilService.setOilLevel(pk: string, level: number)
    local lvl = math.clamp(level, 0, 100)
    levelByPlot[pk] = lvl
    local box = boxes[pk]
    if not box then return end
    -- FIXED: Place oil 2 studs lower to avoid terrain flickering
    local center = centers[pk] or Vector3.new(0,0,0)
    local targetTop = center.Y - 2.6  -- FIXED: was -0.6, now -2.6 (2 studs lower)
    local baseY = center.Y - 5.0     -- FIXED: lowered proportionally
    local maxH = math.max(0.6, targetTop - baseY)
    local h = (lvl / 100) * maxH
    local size = box.Size
    box.Size = Vector3.new(size.X, math.max(0.1, h), size.Z)
    local basePos = Vector3.new(center.X, baseY, center.Z)
    box.CFrame = CFrame.new(basePos + Vector3.new(0, box.Size.Y * 0.5, 0))
end

function OilService.getOilLevel(pk: string): number
    return levelByPlot[pk] or 0
end

function OilService.isWithinSupply(pk: string, pos: Vector3): boolean
    return PondFieldService.isWithinSupply(pk, pos)
end

return OilService
