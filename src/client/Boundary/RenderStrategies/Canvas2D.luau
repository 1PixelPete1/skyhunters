--!strict
-- Canvas2D strategy: up-facing SurfaceGui with Frame segments (editor-crisp look)

local RS = game:GetService("ReplicatedStorage")
local BoundaryConfig = require(RS.Shared.Boundary.BoundaryConfig)
local CanvasManager = require(script.Parent.Parent.Parent:WaitForChild("Boundaries"):WaitForChild("CanvasManager"))
local StrokeRenderer2D = require(script.Parent.Parent.Parent:WaitForChild("Boundaries"):WaitForChild("StrokeRenderer2D"))

local STROKE_PX = 3

local Strategy = {}

local function aabbOfPoints(points: { Vector2 }, padStud: number): (number, number, number, number)
    local minX, minZ = math.huge, math.huge
    local maxX, maxZ = -math.huge, -math.huge
    for _, p in ipairs(points) do
        if p.X < minX then minX = p.X end
        if p.Y < minZ then minZ = p.Y end
        if p.X > maxX then maxX = p.X end
        if p.Y > maxZ then maxZ = p.Y end
    end
    if minX == math.huge then minX, minZ, maxX, maxZ = 0, 0, 0, 0 end
    return minX - padStud, minZ - padStud, maxX + padStud, maxZ + padStud
end

function Strategy.clearAll()
    CanvasManager.clearAll()
end

function Strategy.renderSoup(payload): number
    local soup = payload.soup
    Strategy.clearAll()
    local used = 0
    for _, pl in ipairs(soup.polylines or {}) do
        local ptsW = pl.pts or {}
        if #ptsW >= 2 then
            local padStud = (STROKE_PX * 0.5) / BoundaryConfig.pps_global
            local minX, minZ, maxX, maxZ = aabbOfPoints(ptsW, padStud)
            local cv = CanvasManager.acquire(pl.id, minX, minZ, maxX, maxZ, BoundaryConfig.pps_global, 0.15)
            StrokeRenderer2D.clear(cv)
            local ptsPx = table.create(#ptsW)
            for i = 1, #ptsW do
                local p = ptsW[i]
                ptsPx[i] = CanvasManager.worldToCanvas(cv, p.X, p.Y)
            end
            used += StrokeRenderer2D.drawPolyline(cv, ptsPx, STROKE_PX, Color3.fromRGB(30, 220, 60), 100000)
        end
    end
    return used
end

return Strategy

