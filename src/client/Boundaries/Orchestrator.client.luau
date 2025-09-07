--!strict
-- Orchestrator: Snapshot -> Geometry2D -> CanvasManager -> StrokeRenderer2D

local RS = game:GetService("ReplicatedStorage")
print("[Boundary] Orchestrator init")

local NetClient = require(script.Parent.Parent:WaitForChild("PondNetworkClient"))
local PondFieldMath = require(RS.Shared.PondFieldMath)
local Geometry2D = require(script.Parent:WaitForChild("Geometry2D"))
local CanvasManager = require(script.Parent:WaitForChild("CanvasManager"))
local StrokeRenderer2D = require(script.Parent:WaitForChild("StrokeRenderer2D"))

local CONFIG = {
    POND_SCALE = 0.5,
    PAD = 1.25,
    PPS = 24, -- pixels per stud (global)
    STROKE_PX = 3, -- odd px for readability
    pondMinSeg = 24,
    pondMaxSeg = 96,
    pondChordPx = 10,
    lakeStepPxNear = 10,
    epsilon = 0.05,
    yOffset = 0.15,
    maxSegmentsPerCanvas = 300,
    maxTotalSegments = 2500,
    maxRedrawsPerFrame = 4,
    -- Gap controls (Angle-Wedge method)
    pixelFudgeAngleDeg = 4.0,
    gapMarginStuds = 2.0,
    CanvasPxCap = 3072,
    EnableTiling = false,
    EnableGaps = false,
}

local active: { [string]: boolean } = {}
local totalSegments = 0
local queue: { { kind: string, id: string } } = {}
local queued: { [string]: boolean } = {}
local processing = false
local DEBUG = false

local function worldToCanvasPoints(cv, pts: { Vector2 }): { Vector2 }
    local out = table.create(#pts)
    for i = 1, #pts do
        local p = pts[i]
        out[i] = CanvasManager.worldToCanvas(cv, p.X, p.Y)
    end
    return out
end

local function clipPolylineOutsideDisc(points: { Vector2 }, center: Vector2, R: number): { Vector2 }
    if #points == 0 then return points end
    local function inside(p: Vector2): boolean
        return (p - center).Magnitude < R
    end
    local function lerp(a: Vector2, b: Vector2, t: number): Vector2
        return a + (b - a) * t
    end
    local function findCross(a: Vector2, b: Vector2): Vector2
        -- Bisect to find point on segment where distance == R
        local lo, hi = 0.0, 1.0
        local pa, pb = a, b
        for _ = 1, 8 do
            local mid = (lo + hi) * 0.5
            local p = lerp(pa, pb, mid)
            if (p - center).Magnitude < R then
                lo = mid
            else
                hi = mid
            end
        end
        return lerp(pa, pb, hi)
    end
    local out: { Vector2 } = {}
    local prev = points[1]
    local prevInside = inside(prev)
    if not prevInside then table.insert(out, prev) end
    for i = 2, #points do
        local cur = points[i]
        local curInside = inside(cur)
        if prevInside and not curInside then
            -- Exiting disc: add intersection then current
            local cross = findCross(prev, cur)
            table.insert(out, cross)
            table.insert(out, cur)
        elseif (not prevInside) and (not curInside) then
            -- Staying outside: add current
            table.insert(out, cur)
        elseif (not prevInside) and curInside then
            -- Entering disc: add intersection only
            local cross = findCross(prev, cur)
            table.insert(out, cross)
        else
            -- Staying inside: add nothing
        end
        prev = cur
        prevInside = curInside
    end
    return out
end

local function countMap(t)
    local n=0; for _ in pairs(t or {}) do n+=1 end; return n end

local function renderPond(id: string, pos: Vector2, radius: number)
    local R = radius * (1 + CONFIG.POND_SCALE) + CONFIG.PAD
    local pts = Geometry2D.circleSample(pos, R, CONFIG.PPS, CONFIG.pondMinSeg, CONFIG.pondMaxSeg, CONFIG.pondChordPx)
    local runs: { { Vector2 } } = { pts }
    -- AABB from all runs
    local minX, minZ, maxX, maxZ
    local padStud = (CONFIG.STROKE_PX * 0.5) / CONFIG.PPS
    for ri, run in ipairs(runs) do
        local a,b,c,d = Geometry2D.aabbOfPoints(run, padStud)
        if ri == 1 then minX, minZ, maxX, maxZ = a,b,c,d else
            minX = math.min(minX, a); minZ = math.min(minZ, b)
            maxX = math.max(maxX, c); maxZ = math.max(maxZ, d)
        end
    end
    if not minX then
        -- No runs (fully masked). Still allocate a tiny canvas to avoid churn.
        minX, minZ, maxX, maxZ = pos.X - R - padStud, pos.Y - R - padStud, pos.X + R + padStud, pos.Y + R + padStud
    end
    local sizeX = maxX - minX
    local sizeZ = maxZ - minZ
    local tileMax = math.floor(CONFIG.CanvasPxCap / CONFIG.PPS)
    if sizeX > tileMax then
        local midX = (minX + maxX) * 0.5
        local cvL = CanvasManager.acquire("pond:" .. id .. ":L", minX, minZ, midX + (1/CONFIG.PPS), maxZ, CONFIG.PPS, CONFIG.yOffset)
        local cvR = CanvasManager.acquire("pond:" .. id .. ":R", midX - (1/CONFIG.PPS), minZ, maxX, maxZ, CONFIG.PPS, CONFIG.yOffset)
        for _, run in ipairs(runs) do
            local pxL = {}
            for i=1,#run do local p=run[i]; if p.X <= midX+(1/CONFIG.PPS) then table.insert(pxL, p) end end
            StrokeRenderer2D.drawPolyline(cvL, worldToCanvasPoints(cvL, pxL), CONFIG.STROKE_PX, Color3.fromRGB(30, 220, 60), CONFIG.maxSegmentsPerCanvas)
            local pxR = {}
            for i=1,#run do local p=run[i]; if p.X >= midX-(1/CONFIG.PPS) then table.insert(pxR, p) end end
            StrokeRenderer2D.drawPolyline(cvR, worldToCanvasPoints(cvR, pxR), CONFIG.STROKE_PX, Color3.fromRGB(30, 220, 60), CONFIG.maxSegmentsPerCanvas)
        end
        active[cvL.id] = true; active[cvR.id] = true
    elseif sizeZ > tileMax then
        local midZ = (minZ + maxZ) * 0.5
        local cvT = CanvasManager.acquire("pond:" .. id .. ":T", minX, minZ, maxX, midZ + (1/CONFIG.PPS), CONFIG.PPS, CONFIG.yOffset)
        local cvB = CanvasManager.acquire("pond:" .. id .. ":B", minX, midZ - (1/CONFIG.PPS), maxX, maxZ, CONFIG.PPS, CONFIG.yOffset)
        for _, run in ipairs(runs) do
            local pxT = {}
            for i=1,#run do local p=run[i]; if p.Y <= midZ+(1/CONFIG.PPS) then table.insert(pxT, p) end end
            StrokeRenderer2D.drawPolyline(cvT, worldToCanvasPoints(cvT, pxT), CONFIG.STROKE_PX, Color3.fromRGB(30, 220, 60), CONFIG.maxSegmentsPerCanvas)
            local pxB = {}
            for i=1,#run do local p=run[i]; if p.Y >= midZ-(1/CONFIG.PPS) then table.insert(pxB, p) end end
            StrokeRenderer2D.drawPolyline(cvB, worldToCanvasPoints(cvB, pxB), CONFIG.STROKE_PX, Color3.fromRGB(30, 220, 60), CONFIG.maxSegmentsPerCanvas)
        end
        active[cvT.id] = true; active[cvB.id] = true
    else
    local cv = CanvasManager.acquire("pond:" .. id, minX, minZ, maxX, maxZ, CONFIG.PPS, CONFIG.yOffset)
    for _, run in ipairs(runs) do
        local pxPts = worldToCanvasPoints(cv, run)
        local used = StrokeRenderer2D.drawPolyline(cv, pxPts, CONFIG.STROKE_PX, Color3.fromRGB(30, 220, 60), CONFIG.maxSegmentsPerCanvas)
        if DEBUG then
            print(string.format("[Boundary] pond id=%s runPts=%d segs=%d aabb=(%.1f,%.1f)-(%.1f,%.1f)", id, #pxPts, used, minX, minZ, maxX, maxZ))
        end
    end
    active[cv.id] = true
end
end

local function renderLake(id: string, lake)
    -- Prefer server-built bounds (Canal parts) to match dynamic shape exactly
    local canals = workspace:FindFirstChild("Canals")
    local canalModel = canals and canals:FindFirstChild("Canal_" .. id)
    local left, right = {}, {}
    if canalModel then
        local bounds = canalModel:FindFirstChild("Bounds")
        if bounds then
            local leftParts, rightParts = {}, {}
            for _, ch in ipairs(bounds:GetChildren()) do
                if ch:IsA("BasePart") then
                    if string.find(ch.Name, "BoundL_") == 1 then table.insert(leftParts, ch)
                    elseif string.find(ch.Name, "BoundR_") == 1 then table.insert(rightParts, ch) end
                end
            end
            table.sort(leftParts, function(a,b) return (a:GetAttribute("Index") or 0) < (b:GetAttribute("Index") or 0) end)
            table.sort(rightParts, function(a,b) return (a:GetAttribute("Index") or 0) < (b:GetAttribute("Index") or 0) end)
            local function endpoints(part: BasePart): (Vector2, Vector2)
                local half = part.Size.Z * 0.5
                local a3 = part.CFrame:PointToWorldSpace(Vector3.new(0, 0, -half))
                local b3 = part.CFrame:PointToWorldSpace(Vector3.new(0, 0, half))
                return Vector2.new(a3.X, a3.Z), Vector2.new(b3.X, b3.Z)
            end
            -- Build polylines that follow the path: [a1, b1, b2, b3, ...]
            local function buildPolyline(parts)
                local pts: { Vector2 } = {}
                if #parts == 0 then return pts end
                local a,b = endpoints(parts[1])
                table.insert(pts, a)
                table.insert(pts, b)
                local last = b
                for i=2,#parts do
                    local ai, bi = endpoints(parts[i])
                    -- choose orientation that continues from last
                    if (ai - last).Magnitude <= (bi - last).Magnitude then
                        table.insert(pts, bi)
                        last = bi
                    else
                        table.insert(pts, ai)
                        last = ai
                    end
                end
                return pts
            end
            left = buildPolyline(leftParts)
            right = buildPolyline(rightParts)
        end
    end
    if #left < 2 or #right < 2 then
        -- Fallback to math if canal parts missing
        local center = lake.path or {}
        if #center < 2 then return end
        local step = CONFIG.lakeStepPxNear / CONFIG.PPS
        local res = Geometry2D.resampleByArcLength(center, step)
        res = Geometry2D.simplifyNearDuplicates(res, CONFIG.epsilon)
        local offset = (lake.width * 0.5) + CONFIG.PAD
        left = Geometry2D.offsetPolylineBevel(res, offset, 1)
        right = Geometry2D.offsetPolylineBevel(res, offset, -1)
    end
    -- AABB from rims + stroke pad
    local minX, minZ, maxX, maxZ = Geometry2D.aabbOfPoints(left, (CONFIG.STROKE_PX * 0.5) / CONFIG.PPS)
    local minX2, minZ2, maxX2, maxZ2 = Geometry2D.aabbOfPoints(right, (CONFIG.STROKE_PX * 0.5) / CONFIG.PPS)
    minX = math.min(minX, minX2); minZ = math.min(minZ, minZ2)
    maxX = math.max(maxX, maxX2); maxZ = math.max(maxZ, maxZ2)
    if not CONFIG.EnableTiling then
        local cv = CanvasManager.acquire("lake:" .. id, minX, minZ, maxX, maxZ, CONFIG.PPS, CONFIG.yOffset)
        StrokeRenderer2D.clear(cv)
        local leftPts = worldToCanvasPoints(cv, left)
        local rightPts = worldToCanvasPoints(cv, right)
        local used1 = StrokeRenderer2D.drawPolyline(cv, leftPts, CONFIG.STROKE_PX, Color3.fromRGB(30, 220, 60), CONFIG.maxSegmentsPerCanvas)
        local budgetLeft = math.max(0, CONFIG.maxSegmentsPerCanvas - used1)
        local used2 = StrokeRenderer2D.drawPolyline(cv, rightPts, CONFIG.STROKE_PX, Color3.fromRGB(30, 220, 60), budgetLeft)
        if DEBUG then
            print(string.format("[Boundary] lake id=%s Lpts=%d Rpts=%d seg1=%d seg2=%d aabb=(%.1f,%.1f)-(%.1f,%.1f)", id, #leftPts, #rightPts, used1, used2, minX, minZ, maxX, maxZ))
        end
        active[cv.id] = true
    else
        -- Tiling path can be re-enabled later when clipping per tile is added robustly
        local cv = CanvasManager.acquire("lake:" .. id, minX, minZ, maxX, maxZ, CONFIG.PPS, CONFIG.yOffset)
        StrokeRenderer2D.clear(cv)
        local leftPts = worldToCanvasPoints(cv, left)
        local rightPts = worldToCanvasPoints(cv, right)
        local used1 = StrokeRenderer2D.drawPolyline(cv, leftPts, CONFIG.STROKE_PX, Color3.fromRGB(30, 220, 60), CONFIG.maxSegmentsPerCanvas)
        local budgetLeft = math.max(0, CONFIG.maxSegmentsPerCanvas - used1)
        StrokeRenderer2D.drawPolyline(cv, rightPts, CONFIG.STROKE_PX, Color3.fromRGB(30, 220, 60), budgetLeft)
        active[cv.id] = true
    end
end

local function enqueue(kind: string, id: string)
    local key = kind .. ":" .. id
    if queued[key] then return end
    table.insert(queue, { kind = kind, id = id })
    queued[key] = true
end

local function processQueue()
    if processing then return end
    processing = true
    local budget = CONFIG.maxRedrawsPerFrame
    while budget > 0 and #queue > 0 do
        local job = table.remove(queue, 1)
        queued[job.kind .. ":" .. job.id] = nil
        local snap = NetClient.snapshot
        if snap then
            if job.kind == "pond" then
                local p = snap.ponds[job.id]
                if p then renderPond(job.id, p.pos, p.radius) end
            else
                local l = snap.lakes[job.id]
                if l then renderLake(job.id, l) end
            end
        end
        budget -= 1
    end
    processing = false
end

NetClient.Changed.Event:Connect(function()
    -- On any change, enqueue all for now; coalescing by id avoids duplicates
    local snap = NetClient.snapshot
    if not snap then return end
    local pc = countMap(snap.ponds)
    local lc = countMap(snap.lakes)
    print(string.format("[Boundary] snapshot changed ponds=%d lakes=%d", pc, lc))
    for id, _ in pairs(snap.ponds) do enqueue("pond", id) end
    for id, _ in pairs(snap.lakes) do enqueue("lake", id) end
end)

game:GetService("RunService").Heartbeat:Connect(processQueue)

-- initial enqueue
task.defer(function()
    local snap = NetClient.snapshot
    if not snap then print("[Boundary] no snapshot on init"); return end
    print(string.format("[Boundary] initial enqueue ponds=%d lakes=%d", (snap.ponds and #table.create(0) or 0), (snap.lakes and #table.create(0) or 0)))
    for id, _ in pairs(snap.ponds) do enqueue("pond", id) end
    for id, _ in pairs(snap.lakes) do enqueue("lake", id) end
end)

-- Debug toggle via remote
do
    local Net = RS:FindFirstChild("Net")
    local Remotes = Net and Net:FindFirstChild("Remotes")
    local RE = Remotes and Remotes:FindFirstChild("RE_DevBoundaryDebug")
    if RE and RE:IsA("RemoteEvent") then
        RE.OnClientEvent:Connect(function(on)
            DEBUG = on and true or false
            print("[Boundary] debug=", DEBUG)
        end)
    end
end
