--!strict
-- PondNetworkService: maintains a snapshot of ponds and lakes and broadcasts deltas

local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Terrain = workspace.Terrain
local WorldConfig = require(RS.Config.WorldConfig)
local RimBuilder = require(game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("RimBuilder"))
local HttpService = game:GetService("HttpService")

local Types = require(RS.Shared.PondNetworkTypes)
local CanalBuilder = require(game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("CanalBuilder"))

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
    DefaultLakeWidth = 10,
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

local function autoLink(newId: string)
    if not Policy.AutoLink then return end
    local A = S.snapshot.ponds[newId]; if not A then return end
    for id, B in pairs(S.snapshot.ponds) do
        if id ~= newId then
            local centerDist = (A.pos - B.pos).Magnitude
            local edgeGap = centerDist - (A.radius + B.radius)
            if edgeGap <= Policy.AutoLinkMaxGap and centerDist <= Policy.MaxLakeSpan then
                local key = pairKey(newId, id)
                if not S._linkedPairs[key] then
                    local lake = S.connectPonds(newId, id, Policy.DefaultLakeWidth)
                    if lake then
                        S._linkedPairs[key] = true
                        print(string.format("[PondNetwork] autoLink new=%s other=%s centerDist=%.1f edgeGap=%.1f", newId, id, centerDist, edgeGap))
                    end
                end
            end
        end
    end
end

function S.addPond(posXZ: Vector2, radius: number)
    radius = math.clamp(radius, Policy.MinPondRadius, Policy.MaxPondRadius)
    local id = newId("pond")
    local pond = { id = id, pos = posXZ, radius = radius }
    S.snapshot.ponds[id] = pond
    S.bump({ ponds = { created = { pond } } })
    -- Sculpt terrain: clear to Air only (no Water fill), build rim
    local yTop = WorldConfig.ISLANDS.DefaultHeightY
    local depth = (WorldConfig.ISLANDS.Pond and WorldConfig.ISLANDS.Pond.Depth) or 2
    local center = Vector3.new(posXZ.X, yTop - (depth * 0.5), posXZ.Y)
    local height = depth
    local clearR = radius + 1.5
    local okCarve1, err1 = pcall(function()
        Terrain:FillCylinder(CFrame.new(center, center + Vector3.yAxis), height, clearR, Enum.Material.Air)
    end)
    if not okCarve1 then
        warn("[PondNetwork] carve pond failed:", err1)
    else
        print(string.format("[PondNetwork] carved pond centerY=%.1f h=%.1f r=%.1f", center.Y, height, clearR))
    end
    pcall(function()
        local rims = workspace:FindFirstChild("PondRims") or Instance.new("Folder")
        rims.Name = "PondRims"; rims.Parent = workspace
        local pf = rims:FindFirstChild(id) or Instance.new("Folder")
        pf.Name = id; pf.Parent = rims
        RimBuilder.build(pf, posXZ, radius)
    end)
    print(string.format("[PondNetwork] addPond id=%s pos=(%.1f,%.1f) r=%.1f", id, posXZ.X, posXZ.Y, radius))
    autoLink(id)
    return pond
end

function S.connectPonds(aId: string, bId: string, width: number?)
    local A = S.snapshot.ponds[aId]; if not A then return nil end
    local B = S.snapshot.ponds[bId]; if not B then return nil end
    if (A.pos - B.pos).Magnitude > Policy.MaxLakeSpan then return nil end

    local path = sampleBezier(A.pos, B.pos, Policy.PathSampleStep)
    local id = newId("lake")
    local POND_SCALE = 0.5
    local PAD = 1.25
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
            local center = Vector3.new(p.X, yTop - (depth * 0.5), p.Y)
            Terrain:FillCylinder(CFrame.new(center, center + Vector3.yAxis), height, clearR, Enum.Material.Air)
        end
    end)
    if not okCarve2 then
        warn("[PondNetwork] carve canal failed:", err2)
    else
        print(string.format("[PondNetwork] carved canal steps=%d r=%.1f", #path, clearR))
    end
    print(string.format("[PondNetwork] connectPonds id=%s a=%s b=%s width=%.1f steps=%d", id, aId, bId, lake.width, #path))
    -- Build temporary canal Parts (body + parallel bounds) for visualization
    pcall(function()
        CanalBuilder.BuildFromCenterline(id, clipped, visW, aInfo, bInfo)
    end)
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
