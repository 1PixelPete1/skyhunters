--!strict
-- CanvasManager: up-facing canvases for 2D strokes

local CanvasManager = {}
local RS = game:GetService("ReplicatedStorage")
local WorldConfig = require(RS.Config.WorldConfig)
local BoundaryConfig = require(RS.Shared.Boundary.BoundaryConfig)

export type Canvas = {
    id: string,
    part: Part,
    gui: SurfaceGui,
    container: Instance, -- Frame container for segments (under gui)
    pps: number,
    minX: number, minZ: number, maxX: number, maxZ: number,
}

local ROOT = workspace:FindFirstChild("BoundaryCanvases") or Instance.new("Folder")
ROOT.Name = "BoundaryCanvases"; ROOT.Parent = workspace

local pool: { Canvas } = {}
local byId: { [string]: Canvas } = {}

local function makeCanvas(): Canvas
    local part = Instance.new("Part")
    part.Name = "BoundaryCanvas"
    part.Anchored = true
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.CastShadow = false
    part.Transparency = 1
    part.Parent = ROOT

    local gui = Instance.new("SurfaceGui")
    gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    gui.CanvasSize = Vector2.new(128, 128)
    gui.PixelsPerStud = BoundaryConfig.pps_global
    gui.Face = Enum.NormalId.Top
    gui.AlwaysOnTop = true
    gui.Parent = part

    local container = Instance.new("Folder")
    container.Name = "Segments"
    container.Parent = gui

    return {
        id = "",
        part = part,
        gui = gui,
        container = container,
        pps = BoundaryConfig.pps_global,
        minX = 0, minZ = 0, maxX = 0, maxZ = 0,
    }
end

local function sampleMaxY(minX: number, minZ: number, maxX: number, maxZ: number): number
    local maxY = -math.huge
    local minY = math.huge
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Blacklist
    params.FilterDescendantsInstances = { ROOT }
    local function scan(grid: number)
        for i = 0, grid do
            for j = 0, grid do
                local x = minX + (maxX - minX) * (i / grid)
                local z = minZ + (maxZ - minZ) * (j / grid)
                local origin = Vector3.new(x, (workspace.FallenPartsDestroyHeight or -500) + 1000, z)
                local hit = workspace:Raycast(origin, Vector3.new(0, -2000, 0), params)
                if hit then
                    local y = hit.Position.Y
                    if y > maxY then maxY = y end
                    if y < minY then minY = y end
                end
            end
        end
    end
    scan(2) -- 3x3
    if (maxY - minY) > 3.0 then
        maxY = -math.huge; minY = math.huge
        scan(4) -- 5x5 densify on slopes
    end
    if maxY == -math.huge then maxY = 0 end
    return maxY
end

local function rimPeakY(): number
    local rims = workspace:FindFirstChild("PondRims")
    local peak = -math.huge
    if rims then
        for _, d in ipairs(rims:GetDescendants()) do
            if d:IsA("BasePart") and d.Name == "RimStone" then
                local top = d.Position.Y + d.Size.Y * 0.5
                if top > peak then peak = top end
            end
        end
    end
    if peak == -math.huge then
        return (WorldConfig.ISLANDS and WorldConfig.ISLANDS.DefaultHeightY) or 0
    end
    return peak
end

function CanvasManager.acquire(id: string, minX: number, minZ: number, maxX: number, maxZ: number, pps: number, yOffset: number): Canvas
    local cv = byId[id]
    if not cv then
        cv = (#pool > 0) and table.remove(pool) or makeCanvas()
        byId[id] = cv
        cv.id = id
    end
    cv.pps = pps
    cv.minX = minX; cv.minZ = minZ; cv.maxX = maxX; cv.maxZ = maxZ
    local sizeX = math.max(0.5, maxX - minX)
    local sizeZ = math.max(0.5, maxZ - minZ)
    cv.part.Size = Vector3.new(sizeX, 0.2, sizeZ)
    local cx = (minX + maxX) * 0.5
    local cz = (minZ + maxZ) * 0.5
    -- Sample local terrain height per canvas to prevent floating visuals
    -- Uniform height slightly above peak rim stones
    local y = rimPeakY() + yOffset
    cv.part.CFrame = CFrame.new(cx, y, cz)
    cv.gui.PixelsPerStud = pps
    cv.gui.CanvasSize = Vector2.new(math.max(4, math.floor(sizeX * pps + 0.5)), math.max(4, math.floor(sizeZ * pps + 0.5)))
    cv.part.Parent = ROOT
    return cv
end

function CanvasManager.release(id: string)
    local cv = byId[id]
    if not cv then return end
    cv.part.Parent = nil
    table.insert(pool, cv)
    byId[id] = nil
end

function CanvasManager.clearAll()
    for id, cv in pairs(byId) do
        cv.part.Parent = nil
        table.insert(pool, cv)
        byId[id] = nil
    end
end

-- Map world XZ to canvas pixel (px,py). Z maps to Y flipped so north is up.
function CanvasManager.worldToCanvas(cv: Canvas, x: number, z: number): Vector2
    local px = (x - cv.minX) * cv.pps
    local py = (cv.maxZ - z) * cv.pps
    return Vector2.new(px, py)
end

return CanvasManager
