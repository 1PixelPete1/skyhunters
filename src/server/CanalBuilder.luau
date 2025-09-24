--!strict
-- CanalBuilder: temporary canal visualization using Parts (seed-based, persistent per lake id)

local RS = game:GetService("ReplicatedStorage")
local WorldConfig = require(RS.Config.WorldConfig)

local CanalBuilder = {}

local ROOT = workspace:FindFirstChild("Canals") or Instance.new("Folder")
ROOT.Name = "Canals"; ROOT.Parent = workspace

local function ensureModel(id: string): Model
    local m = ROOT:FindFirstChild("Canal_" .. id)
    if m and m:IsA("Model") then return m end
    m = Instance.new("Model")
    m.Name = "Canal_" .. id
    m.Parent = ROOT
    return m
end

local function buildSegment(parent: Instance, a: Vector2, b: Vector2, y: number, width: number, color: Color3): Part?
    local dir = b - a
    local len = dir.Magnitude
    if len <= 0.05 then return end
    dir = dir.Unit
    local mid = (a + b) * 0.5
    local part = Instance.new("Part")
    part.Anchored = true
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.Material = Enum.Material.Neon
    part.Color = color
    part.Transparency = 0.4
    -- Properly orient along the canal direction: Z-axis along path, X-axis as width
    part.Size = Vector3.new(math.max(0.2, width), 0.2, math.max(0.2, len))
    local origin = Vector3.new(mid.X, y, mid.Y)
    local dir3 = Vector3.new(dir.X, 0, dir.Y)
    -- Create CFrame that aligns Z-axis with canal direction
    local cf = CFrame.lookAt(origin, origin + dir3, Vector3.yAxis)
    part.CFrame = cf
    part.Parent = parent
    return part
end

-- Build canal "body" and parallel bounds from a centerline path
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
    if peak == -math.huge then peak = (WorldConfig.ISLANDS and WorldConfig.ISLANDS.DefaultHeightY or 0) end
    return peak
end

local function sampleMaxYPath(path: { Vector2 }): number
    local maxY = -math.huge
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Whitelist
    params.FilterDescendantsInstances = { workspace.Terrain }
    for i = 1, #path do
        local p = path[i]
        local origin = Vector3.new(p.X, (workspace.FallenPartsDestroyHeight or -500) + 1000, p.Y)
        local hit = workspace:Raycast(origin, Vector3.new(0, -2000, 0), params)
        if hit and hit.Instance == workspace.Terrain then
            if hit.Position.Y > maxY then maxY = hit.Position.Y end
        end
    end
    if maxY == -math.huge then
        return rimPeakY()
    end
    return math.max(maxY, rimPeakY())
end

local function clipPathOutsideCircleStart(path: { Vector2 }, center: Vector2, R: number): { Vector2 }
    local function inside(p: Vector2) 
        -- Use a smaller rim offset to stop closer to rim stones, not too far away
        local rimOffset = 0.5  -- Stop 0.5 studs before pond edge (at rim stones)
        return (p - center).Magnitude < (R - rimOffset) 
    end
    if #path < 2 then return path end
    local idx = 1
    while idx <= #path and inside(path[idx]) do idx += 1 end
    if idx == 1 then return path end -- already starts outside
    if idx > #path then return { } end -- entire path inside
    local a = path[idx - 1]
    local b = path[idx]
    -- bisection to find crossing
    local lo, hi = 0.0, 1.0
    for _ = 1, 16 do
        local mid = (lo + hi) * 0.5
        local p = a + (b - a) * mid
        if inside(p) then lo = mid else hi = mid end
    end
    local cross = a + (b - a) * hi
    local out = {}
    table.insert(out, cross)
    for i = idx, #path do table.insert(out, path[i]) end
    return out
end

local function clipPathOutsideCircleEnd(path: { Vector2 }, center: Vector2, R: number): { Vector2 }
    local function inside(p: Vector2) 
        -- Use a smaller rim offset to stop closer to rim stones, not too far away
        local rimOffset = 0.5  -- Stop 0.5 studs before pond edge (at rim stones)
        return (p - center).Magnitude < (R - rimOffset) 
    end
    if #path < 2 then return path end
    local idx = #path
    while idx >= 1 and inside(path[idx]) do idx -= 1 end
    if idx == #path then return path end -- already ends outside
    if idx < 1 then return { } end -- entire path inside
    local a = path[idx]
    local b = path[idx + 1]
    local lo, hi = 0.0, 1.0
    for _ = 1, 16 do
        local mid = (lo + hi) * 0.5
        local p = a + (b - a) * mid
        if inside(p) then hi = mid else lo = mid end
    end
    local cross = a + (b - a) * lo
    local out = {}
    for i = 1, idx do table.insert(out, path[i]) end
    table.insert(out, cross)
    return out
end

function CanalBuilder.ClipPathToRings(path: { Vector2 }, pondA: {pos: Vector2, radius: number}?, pondB: {pos: Vector2, radius: number}?)
    local out = path
    if pondA and pondA.pos and pondA.radius then
        out = clipPathOutsideCircleStart(out, pondA.pos, pondA.radius)
    end
    if pondB and pondB.pos and pondB.radius then
        out = clipPathOutsideCircleEnd(out, pondB.pos, pondB.radius)
    end
    return out
end

function CanalBuilder.BuildFromCenterline(lakeId: string, path: { Vector2 }, width: number, pondA: {pos: Vector2, radius: number}?, pondB: {pos: Vector2, radius: number}?)
    print(string.format("[CanalBuilder] build lake=%s width=%.1f pts=%d", lakeId, width or -1, #path))
    local m = ensureModel(lakeId)
    m:ClearAllChildren()
    local y = sampleMaxYPath(path) + 0.12
    local body = Instance.new("Folder"); body.Name = "Body"; body.Parent = m
    local bounds = Instance.new("Folder"); bounds.Name = "Bounds"; bounds.Parent = m
    local visW = math.max(2, (width > 0 and width or 10)) -- width provided is already visual
    local halfW = visW * 0.5
    local offL = Color3.fromRGB(30, 220, 60)
    local offR = Color3.fromRGB(30, 220, 60)
    
    -- Clip entire path to be outside both pond ACTUAL radii (not boundary radii)
    -- This prevents stones from appearing in the carved pond areas
    if pondA and pondA.pos and pondA.radius then 
        path = clipPathOutsideCircleStart(path, pondA.pos, pondA.radius) 
    end
    if pondB and pondB.pos and pondB.radius then 
        path = clipPathOutsideCircleEnd(path, pondB.pos, pondB.radius) 
    end
    
    if #path < 2 then
        warn("[CanalBuilder] path fully inside ponds after clipping; skipping build")
        return
    end

    local overlap = 0.2
    for i = 1, #path - 1 do
        local a = path[i]
        local b = path[i+1]
        if (a - b).Magnitude < 0.01 then
            -- skip degenerate segment
            continue
        end
        print(string.format("[CanalBuilder] seg %d a=(%.1f,%.1f) b=(%.1f,%.1f)", i, a.X, a.Y, b.X, b.Y))
        -- Body segment
        local wcol = Color3.fromRGB(0, 200, 255)
        buildSegment(body, a, b, y, visW, wcol)
        -- Parallel bounds
        local dir = (b - a)
        if dir.Magnitude > 0 then
            dir = dir.Unit
            local n = Vector2.new(-dir.Y, dir.X)
            -- overlap inner segments to avoid gaps; avoid overshoot on endpoints
            local aL = a + n * halfW
            local bL = b + n * halfW
            local aR = a - n * halfW
            local bR = b - n * halfW
            local addOverlap = (i > 1 and i < #path - 0) and overlap or 0
            -- extend along dir by half overlap on each side
            local aL2 = aL - dir * (addOverlap * 0.5)
            local bL2 = bL + dir * (addOverlap * 0.5)
            local aR2 = aR - dir * (addOverlap * 0.5)
            local bR2 = bR + dir * (addOverlap * 0.5)
            local lPart = buildSegment(bounds, aL2, bL2, y + 0.01, 0.2, offL)
            if lPart then lPart.Name = string.format("BoundL_%02d", i); lPart:SetAttribute("Index", i) end
            local rPart = buildSegment(bounds, aR2, bR2, y + 0.01, 0.2, offR)
            if rPart then rPart.Name = string.format("BoundR_%02d", i); rPart:SetAttribute("Index", i) end
        end
    end
end

return CanalBuilder
