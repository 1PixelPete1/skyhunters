--!strict
-- Dev Pond placement tool (Studio-only via server guard)

local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Net = RS:WaitForChild("Net")
local Remotes = Net:WaitForChild("Remotes")
local RF_Add: RemoteFunction = Remotes:WaitForChild("RF_AddPond")
local NetClient = require(script.Parent.Parent:WaitForChild("PondNetworkClient"))

local tool = script:FindFirstAncestorOfClass("Tool") :: Tool?
if not tool then script.Disabled = true; return end

local folder = Instance.new("Folder"); folder.Name = "PondPreview"; folder.Parent = workspace
local radius = 10
local pos = Vector3.new(0,0,0)
local ring = Instance.new("Part"); ring.Shape = Enum.PartType.Cylinder; ring.Anchored = true; ring.CanCollide = false
ring.Material = Enum.Material.Neon; ring.Color = Color3.fromRGB(255, 0, 0); ring.Transparency = 0.6; ring.Parent = folder
local boundary = Instance.new("Part"); boundary.Shape = Enum.PartType.Cylinder; boundary.Anchored = true; boundary.CanCollide = false
boundary.Material = Enum.Material.Neon; boundary.Color = Color3.fromRGB(255,255,255); boundary.Transparency = 0.5; boundary.Parent = folder
local canalFolder = Instance.new("Folder"); canalFolder.Name = "CanalPreview"; canalFolder.Parent = folder
local THICK = 0.2
local POND_SCALE = 0.5
local PAD = 1.25

local function updatePreview()
    local size = Vector3.new(math.max(0.2, radius*2), THICK, math.max(0.2, radius*2))
    ring.Size = size
    ring.CFrame = CFrame.new(pos + Vector3.new(0, 0.1, 0)) * CFrame.fromEulerAnglesXYZ(math.rad(90), 0, 0)
    local grow = radius * POND_SCALE + PAD
    local br = radius + grow
    boundary.Size = Vector3.new(math.max(0.2, br*2), THICK, math.max(0.2, br*2))
    boundary.CFrame = CFrame.new(pos + Vector3.new(0, 0.12, 0)) * CFrame.fromEulerAnglesXYZ(math.rad(90), 0, 0)
end

local function nearestPond(posXZ: Vector2)
    local ponds = NetClient.snapshot and NetClient.snapshot.ponds or {}
    local minD = math.huge; local best
    for _, p in pairs(ponds) do
        local d = (posXZ - p.pos).Magnitude
        if d < minD then minD = d; best = p end
    end
    return best
end

local function sampleBezier(a: Vector2, b: Vector2)
    local mid = (a + b) * 0.5
    local dir = b - a
    if dir.Magnitude > 0 then
        local n = Vector2.new(-dir.Y, dir.X).Unit
        mid += n * math.min(30, dir.Magnitude * 0.2)
    end
    local dist = dir.Magnitude
    local count = math.clamp(math.floor(dist / math.max(6, 8)), 2, 64)
    local pts = table.create(count + 1)
    for i = 0, count do
        local t = i / count
        pts[i+1] = (1-t)*(1-t)*a + 2*(1-t)*t*mid + t*t*b
    end
    return pts
end

local function updateCanalPreview()
    for _, c in ipairs(canalFolder:GetChildren()) do c:Destroy() end
    local a = nearestPond(Vector2.new(pos.X, pos.Z))
    if not a then return end
    local path = sampleBezier(a.pos, Vector2.new(pos.X, pos.Z))
    for i = 1, #path-1 do
        local pa = path[i]
        local pb = path[i+1]
        local mid = (pa + pb) * 0.5
        local p3 = Vector3.new(mid.X, 0.12, mid.Y)
        local seg = Instance.new("Part")
        seg.Name = "CanalSeg"; seg.Anchored = true; seg.CanCollide = false
        seg.Material = Enum.Material.Neon; seg.Color = Color3.fromRGB(30, 220, 60); seg.Transparency = 0.6
        local len = (pb - pa).Magnitude
        seg.Size = Vector3.new(math.max(0.1, len), 0.12, 1.0)
        local dir = (pb - pa).Unit
        local angle = math.atan2(dir.Y, dir.X)
        seg.CFrame = CFrame.new(p3) * CFrame.Angles(0, angle, 0)
        seg.Parent = canalFolder
    end
end

local function mouseWorld(): Vector3?
    local cam = workspace.CurrentCamera
    if not cam then return nil end
    local m = UIS:GetMouseLocation()
    local r = cam:ViewportPointToRay(m.X, m.Y)
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = { folder }
    params.FilterType = Enum.RaycastFilterType.Blacklist
    local hit = workspace:Raycast(r.Origin, r.Direction * 1000, params)
    return hit and hit.Position or nil
end

tool.Equipped:Connect(function()
    RunService.RenderStepped:Connect(function()
        local p = mouseWorld()
        if p then
            pos = p
            updatePreview()
            updateCanalPreview()
        end
    end)
end)

tool.Activated:Connect(function()
    local v2 = Vector2.new(pos.X, pos.Z)
    RF_Add:InvokeServer(v2, radius)
end)

UIS.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.Equals or input.KeyCode == Enum.KeyCode.Plus then
        radius += 1
    elseif input.KeyCode == Enum.KeyCode.Minus then
        radius = math.max(2, radius - 1)
    end
end)
