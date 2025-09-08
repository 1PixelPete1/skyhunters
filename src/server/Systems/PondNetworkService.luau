--!strict
-- PondNetworkService: maintains a snapshot of ponds and lakes and broadcasts deltas

local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")
local Terrain = workspace.Terrain
local WorldConfig = require(RS.Config.WorldConfig)
local RimBuilder = require(game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("RimBuilder"))
local HttpService = game:GetService("HttpService")

local Types = require(RS.Shared.PondNetworkTypes)
local CanalBuilder = require(game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("CanalBuilder"))
local BoundaryConfig = require(RS.Shared.Boundary.BoundaryConfig)
local BoundaryGraph = require(SSS:WaitForChild("Server"):WaitForChild("Boundary"):WaitForChild("BoundaryGraph"))

-- Ensure remotes under ReplicatedStorage/Net/Remotes
local Net = RS:FindFirstChild("Net") or Instance.new("Folder")
Net.Name = "Net"; Net.Parent = RS
local Remotes = Net:FindFirstChild("Remotes") or Instance.new("Folder")
Remotes.Name = "Remotes"; Remotes.Parent = Net

local RF_Get = Remotes:FindFirstChild("RF_GetPondNetworkSnapshot") or Instance.new("RemoteFunction")
RF_Get.Name = "RF_GetPondNetworkSnapshot"; RF_Get.Parent = Remotes
local RE_Delta = Remotes:FindFirstChild("RE_PondNetworkDelta") or Instance.new("RemoteEvent")
RE_Delta.Name = "RE_PondNetworkDelta"; RE_Delta.Parent = Remotes

-- Dev remotes (Studio only)
local RF_Add = Remotes:FindFirstChild("RF_AddPond") or Instance.new("RemoteFunction")
RF_Add.Name = "RF_AddPond"; RF_Add.Parent = Remotes
local RF_Link = Remotes:FindFirstChild("RF_LinkPonds") or Instance.new("RemoteFunction")
RF_Link.Name = "RF_LinkPonds"; RF_Link.Parent = Remotes

local S: any = {}
S.snapshot = { version = 0, ponds = {}, lakes = {} } :: Types.Snapshot

local Policy = {
    MinPondRadius = 6,
    MaxPondRadius = 20,
    MaxLakeSpan = 600,
    DefaultLakeWidth = BoundaryConfig.canal_width_default,
    PathSampleStep = 8, -- studs
    AutoLink = true,
    AutoLinkMaxGap = 80, -- studs: max clear gap between pond edges to auto-link (increased)
}

local function newId(prefix: string): string
    return prefix .. "_" .. HttpService:GenerateGUID(false)
end

local function hashToUnit(s: string): number
    local h = 2166136261
    for i = 1, #s do
        h = bit32.bxor(h, string.byte(s, i))
        h = (h * 16777619) % 2^32
    end
    return (h % 1000) / 1000 -- [0,1)
end

local function sampleBezier(a: Vector2, b: Vector2, step: number): { Vector2 }
    local mid = (a + b) * 0.5
    local dir = b - a
    if dir.Magnitude > 0 then
        local n = Vector2.new(-dir.Y, dir.X).Unit
        -- Seed-based wobble for persistent canal shape
        local seed = hashToUnit((tostring(a.X) .. ":" .. tostring(a.Y) .. "|" .. tostring(b.X) .. ":" .. tostring(b.Y)))
        local amp = math.min(30, dir.Magnitude * 0.25)
        local sgn = (seed > 0.5) and 1 or -1
        mid += n * (amp * (0.6 + 0.8 * (seed)) * sgn)
    end
    local dist = dir.Magnitude
    local count = math.clamp(math.floor(dist / math.max(6, step)), 2, 64)
    local pts = table.create(count + 1)
    for i = 0, count do
        local t = i / count
        pts[i+1] = (1-t)*(1-t)*a + 2*(1-t)*t*mid + t*t*b
    end
    return pts
end

S._linkedPairs = {}
local function pairKey(a: string, b: string): string
    if a < b then return a.."|"..b else return b.."|"..a end
end

-- Deterministic theta at pond end: scan decreasing-distance segments near the endpoint
local function computeThetaForEnd(center: Vector2, R: number, path: { Vector2 }, fromStart: boolean): number
    local n = #path
    if n < 2 then return 0 end
    local k = math.min(4, n - 1)
    local function segHits(a: Vector2, b: Vector2): { Vector2 }
        local d = b - a
        local f = a - center
        local A = d:Dot(d)
        local B = 2 * f:Dot(d)
        local C = f:Dot(f) - R*R
        local disc = B*B - 4*A*C
        local out = {}
        if disc < 0 then return out end
        local s = math.sqrt(disc)
        local t1 = (-B - s)/(2*A)
        local t2 = (-B + s)/(2*A)
        if t1 >= 0 and t1 <= 1 then table.insert(out, a + d*t1) end
        if t2 >= 0 and t2 <= 1 and math.abs(t2 - t1) > 1e-6 then table.insert(out, a + d*t2) end
        return out
    end
    local chosen: Vector2? = nil
    if fromStart then
        local prevD = math.huge
        for i = 1, k do
            local a = path[i]; local b = path[i+1]
            if not b then break end
            local d = (a - center).Magnitude
            if d > prevD then break end
            prevD = d
            local hits = segHits(a, b)
            if #hits > 0 then chosen = hits[1]; break end
        end
        if not chosen then
            local a = path[1]; local b = path[2]
            local dir = (a - center)
            if dir.Magnitude <= 0 then dir = (b - a) end
            if dir.Magnitude <= 0 then return 0 end
            dir = dir.Unit
            chosen = center + dir * R
        end
    else
        local prevD = math.huge
        for off = 0, k-1 do
            local i = (n-1) - off
            if i < 1 then break end
            local a = path[i]; local b = path[i+1]
            if not b then break end
            local d = (b - center).Magnitude
            if d > prevD then break end
            prevD = d
            local hits = segHits(a, b)
            if #hits > 0 then chosen = hits[#hits]; break end
        end
        if not chosen then
            local a = path[n-1]; local b = path[n]
            local dir = (b - center)
            if dir.Magnitude <= 0 then dir = (b - a) end
            if dir.Magnitude <= 0 then return 0 end
            dir = dir.Unit
            chosen = center + dir * R
        end
    end
    local v = chosen - center
    return math.atan2(v.Y, v.X)
end

local function autoLink(newId: string)
    if not Policy.AutoLink then return end
    local A = S.snapshot.ponds[newId]; if not A then return end
    local function ringR(p): number
        local POND_SCALE = BoundaryConfig.pond_scale
        local PAD = BoundaryConfig.pad
        return (p.radius or 0) * (1 + POND_SCALE) + PAD
    end
    local function segCircleIntersect(a: Vector2, b: Vector2, c: Vector2, r: number): boolean
        -- distance from circle center c to segment ab <= r
        local ab = b - a
        local denom = ab:Dot(ab)
        local t = 0
        if denom > 0 then t = math.clamp((c - a):Dot(ab)/denom, 0, 1) end
        local proj = a + ab * t
        return (proj - c).Magnitude <= r
    end
    local candidates: { {id:string, dist:number} } = {}
    for id, B in pairs(S.snapshot.ponds) do
        if id ~= newId then
            local centerDist = (A.pos - B.pos).Magnitude
            local edgeGap = centerDist - (A.radius + B.radius)
            if edgeGap <= Policy.AutoLinkMaxGap and centerDist <= Policy.MaxLakeSpan then
                table.insert(candidates, { id = id, dist = centerDist })
            end
        end
    end
    table.sort(candidates, function(a,b) return a.dist < b.dist end)
    do
        local order = {}
        for _, c in ipairs(candidates) do table.insert(order, c.id) end
        print(string.format("[Boundary/Link] candidates new=%s ordered=%s", newId, table.concat(order, ",")))
    end
    local half = (BoundaryConfig.canalHalfWidth or 2.0)
    local clearance = math.max((BoundaryConfig.dotSpacing or 3.5) * 0.6, 0.4)
    local linked = false
    for _, cand in ipairs(candidates) do
        local id = cand.id
        local B = S.snapshot.ponds[id]
        local blocked = false
        for cid, C in pairs(S.snapshot.ponds) do
            if cid ~= newId and cid ~= id then
                local R = ringR(C) + half + clearance
                if segCircleIntersect(A.pos, B.pos, C.pos, R) then
                    blocked = true
                    print(string.format("[Boundary/Link] occluded new=%s skipped_by=%s candidate=%s", newId, cid, id))
                    break
                end
            end
        end
        if not blocked then
            local key = pairKey(newId, id)
            if not S._linkedPairs[key] then
                local lake = S.connectPonds(newId, id, Policy.DefaultLakeWidth)
                if lake then
                    S._linkedPairs[key] = true
                    print(string.format("[Boundary/Link] choose new=%s to=%s dist=%.1f reason=visible", newId, id, cand.dist))
                    linked = true
                end
            end
            break
        end
    end
    if not linked then
        print(string.format("[Boundary/Link] none new=%s reason=no_visible_candidate", newId))
    end
end

function S.addPond(posXZ: Vector2, radius: number)
    radius = math.clamp(radius, Policy.MinPondRadius, Policy.MaxPondRadius)
    -- Overlap guard: prevent placing overlapping ponds (by ring radii)
    local POND_SCALE = BoundaryConfig.pond_scale
    local PAD = BoundaryConfig.pad
    local function ringR(r:number): number return r * (1 + POND_SCALE) + PAD end
    local newRing = ringR(radius)
    local overlapMargin = 0.5
    for pid, p in pairs(S.snapshot.ponds) do
        local dist = (posXZ - p.pos).Magnitude
        local minDist = newRing + ringR(p.radius) + overlapMargin
        if dist < minDist then
            print(string.format("[Boundary/Place] pond_overlap new=%s with=%s dist=%.2f min=%.2f", "pending", pid, dist, minDist))
            return nil
        end
    end
    -- FIXED: Separate sculpt center from boundary centerY
    local yTop = WorldConfig.ISLANDS.DefaultHeightY
    local depth = (WorldConfig.ISLANDS.Pond and WorldConfig.ISLANDS.Pond.Depth) or 2
    local sculptCenter = Vector3.new(posXZ.X, yTop - (depth * 0.5), posXZ.Y)  -- For terrain carving
    local surfaceY = yTop  -- For boundary system (surface level)
    local id = newId("pond")
    local pond = { id = id, pos = posXZ, radius = radius, centerY = surfaceY }  -- Store surface Y
    S.snapshot.ponds[id] = pond
    S.bump({ ponds = { created = { pond } } })
    -- Sculpt terrain: clear to Air only (no Water fill), build rim
    local height = depth
    local clearR = radius + 1.5
    local okCarve1, err1 = pcall(function()
        Terrain:FillCylinder(CFrame.new(sculptCenter, sculptCenter + Vector3.yAxis), height, clearR, Enum.Material.Air)
    end)
    if not okCarve1 then
        warn("[PondNetwork] carve pond failed:", err1)
    else
        print(string.format("[PondNetwork] carved pond surfaceY=%.1f sculptY=%.1f h=%.1f r=%.1f", surfaceY, sculptCenter.Y, height, clearR))
    end
    pcall(function()
        local rims = workspace:FindFirstChild("PondRims") or Instance.new("Folder")
        rims.Name = "PondRims"; rims.Parent = workspace
        local pf = rims:FindFirstChild(id) or Instance.new("Folder")
        pf.Name = id; pf.Parent = rims
        RimBuilder.build(pf, posXZ, radius)
    end)
    print(string.format("[PondNetwork] addPond id=%s pos=(%.1f,%.1f) r=%.1f surfaceY=%.1f", id, posXZ.X, posXZ.Y, radius, surfaceY))
    -- Forward to BoundaryGraph (authoritative data)
    pcall(function()
        BoundaryGraph.addNode({ id = id, posXZ = posXZ, radius = radius })
    end)
    autoLink(id)
    return pond
end

function S.connectPonds(aId: string, bId: string, width: number?)
    local A = S.snapshot.ponds[aId]; if not A then return nil end
    local B = S.snapshot.ponds[bId]; if not B then return nil end
    if (A.pos - B.pos).Magnitude > Policy.MaxLakeSpan then return nil end

    local path = sampleBezier(A.pos, B.pos, Policy.PathSampleStep)
    local id = newId("lake")
    local POND_SCALE = BoundaryConfig.pond_scale
    local PAD = BoundaryConfig.pad
    local function ringR(p): number
        return (p.radius or 0) * (1 + POND_SCALE) + PAD
    end
    -- Clip path to start/end at ring circumferences for authoritative snapshot
    local aInfo = { pos = A.pos, radius = ringR(A) }
    local bInfo = { pos = B.pos, radius = ringR(B) }
    local clipped = CanalBuilder.ClipPathToRings(path, aInfo, bInfo)
    local baseW = width or Policy.DefaultLakeWidth
    local visW = math.max(2, baseW * 0.4) -- visual and acceptance width use the same now
    local lake = { id = id, a = aId, b = bId, path = clipped, width = visW }
    -- Compute and store junctions (deterministic)
    local dotSpacing = BoundaryConfig.dotSpacing or 3.5
    local rimPad = math.max(0.25, dotSpacing * 0.25)
    local canalHalf = BoundaryConfig.canalHalfWidth or (BoundaryConfig.canal_width_default*0.5)
    local lift = (BoundaryConfig.dotLiftY or 0.05)
    local epsRad = math.min(dotSpacing / math.max(1e-5, 3*ringR(A)), 0.035)
    local function arcHalfWidthFor(R:number): number
        return math.asin(math.clamp((canalHalf + rimPad)/math.max(1e-5, R), 0, 1)) + epsRad
    end
    local thetaA = computeThetaForEnd(A.pos, ringR(A), clipped, true)
    local thetaB = computeThetaForEnd(B.pos, ringR(B), clipped, false)
    lake.junctions = {
        { pondId = aId, lakeId = id, theta = thetaA, arcHalfWidth = arcHalfWidthFor(ringR(A)), capLength = 0.75, y = (A.centerY or WorldConfig.ISLANDS.DefaultHeightY) + lift },
        { pondId = bId, lakeId = id, theta = thetaB, arcHalfWidth = arcHalfWidthFor(ringR(B)), capLength = 0.75, y = (B.centerY or WorldConfig.ISLANDS.DefaultHeightY) + lift },
    }
    S.snapshot.lakes[id] = lake
    S.bump({ lakes = { created = { lake } } })
    -- Sculpt a canal along the path: chain of Air-only cylinders (no Water fill)
    local yTop = WorldConfig.ISLANDS.DefaultHeightY
    local depth = (WorldConfig.ISLANDS.Pond and WorldConfig.ISLANDS.Pond.Depth) or 2
    local height = depth
    local clearR = lake.width + 1.5
    local okCarve2, err2 = pcall(function()
        for i = 1, #path do
            local p = path[i]
            local sculptCenter = Vector3.new(p.X, yTop - (depth * 0.5), p.Y)  -- Use depth center for carving
            Terrain:FillCylinder(CFrame.new(sculptCenter, sculptCenter + Vector3.yAxis), height, clearR, Enum.Material.Air)
        end
    end)
    if not okCarve2 then
        warn("[PondNetwork] carve canal failed:", err2)
    else
        print(string.format("[PondNetwork] carved canal steps=%d r=%.1f", #path, clearR))
    
    -- FIXED: Add stone rim segments along canal path for visual connection
    pcall(function()
        local segmentSpacing = 8  -- studs between stone segments
        local segmentCount = math.max(2, math.floor(#path / math.max(1, segmentSpacing / Policy.PathSampleStep)))
        
        local canals = workspace:FindFirstChild("CanalSegments") or Instance.new("Folder")
        canals.Name = "CanalSegments"; canals.Parent = workspace
        local canalFolder = canals:FindFirstChild(id) or Instance.new("Folder")
        canalFolder.Name = id; canalFolder.Parent = canals
        
        -- Clear existing segments
        for _, child in ipairs(canalFolder:GetChildren()) do
            if child.Name == "CanalStone" then child:Destroy() end
        end
        
        -- Place stone segments along the path
        for i = 1, segmentCount do
            local pathIndex = math.floor((i / segmentCount) * (#path - 1)) + 1
            pathIndex = math.clamp(pathIndex, 1, #path)
            local pathPoint = path[pathIndex]
            
            -- Create small stone segment
            local stone = Instance.new("Part")
            stone.Name = "CanalStone"
            stone.Anchored = true
            stone.CanCollide = true
            stone.Material = Enum.Material.Rock
            stone.Color = Color3.fromRGB(118, 116, 112)
            stone.Size = Vector3.new(2, 0.8, 1.5)
            stone.TopSurface = Enum.SurfaceType.Smooth
            stone.BottomSurface = Enum.SurfaceType.Smooth
            
            -- Position on terrain surface like RimBuilder does
            local params = RaycastParams.new()
            params.FilterType = Enum.RaycastFilterType.Whitelist
            params.FilterDescendantsInstances = { workspace.Terrain }
            
            local origin = Vector3.new(pathPoint.X, 1000, pathPoint.Y)
            local hit = workspace:Raycast(origin, Vector3.new(0, -2000, 0), params)
            local surfY = (hit and hit.Position.Y) or (yTop - depth * 0.5)
            
            local stoneY = surfY + (stone.Size.Y * 0.5)
            stone.Position = Vector3.new(pathPoint.X, stoneY, pathPoint.Y)
            stone.Parent = canalFolder
        end
        
        print(string.format("[PondNetwork] canal stones id=%s segments=%d", id, segmentCount))
    end)
    end
    print(string.format("[PondNetwork] connectPonds id=%s a=%s b=%s width=%.1f steps=%d", id, aId, bId, lake.width, #path))
    -- Forward to BoundaryGraph (authoritative data)
    pcall(function()
        BoundaryGraph.addEdge({ id = id, a = aId, b = bId, path = clipped, width = visW })
    end)
    -- Build temporary canal Parts (body + parallel bounds) for visualization
    -- Disable river-like canal parts; stone rails are rendered on client from dot soup
    return lake
end

function S.bump(delta: any)
    S.snapshot.version += 1
    RE_Delta:FireAllClients({ version = S.snapshot.version, delta = delta })
end

function S.getSnapshot(): Types.Snapshot
    return S.snapshot
end

function S.setSnapshot(newSnap: Types.Snapshot)
    S.snapshot = newSnap
    S.bump({ full = true })
end

RF_Get.OnServerInvoke = function(_player)
    return S.snapshot
end

RF_Add.OnServerInvoke = function(player, posXZ: Vector2, radius: number)
    if not RunService:IsStudio() then return nil end
    if typeof(posXZ) ~= "Vector2" then return nil end
    local p = S.addPond(posXZ, tonumber(radius) or 10)
    return p
end

RF_Link.OnServerInvoke = function(player, aId: string, bId: string, width: number?)
    if not RunService:IsStudio() then return nil end
    if type(aId) ~= "string" or type(bId) ~= "string" then return nil end
    local l = S.connectPonds(aId, bId, tonumber(width))
    return l
end

return S
