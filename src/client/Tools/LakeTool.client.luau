--!strict
-- Dev Lake linking tool: select two existing ponds; server links them (Studio-only guard server-side)

local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Net = RS:WaitForChild("Net")
local Remotes = Net:WaitForChild("Remotes")
local RF_Link: RemoteFunction = Remotes:WaitForChild("RF_LinkPonds")

local NetClient = require(script.Parent.Parent:FindFirstChild("PondNetworkClient") or RS.Client:FindFirstChild("PondNetworkClient"))

local tool = script:FindFirstAncestorOfClass("Tool") :: Tool?
if not tool then script.Disabled = true; return end

local width = 10
local selectA: string? = nil
local selectB: string? = nil

local markerA = Instance.new("Part")
markerA.Anchored = true; markerA.CanCollide = false; markerA.Material = Enum.Material.Neon
markerA.Color = Color3.fromRGB(0,255,0); markerA.Size = Vector3.new(1,0.3,1); markerA.Parent = workspace; markerA.Transparency = 1
local markerB = Instance.new("Part")
markerB.Anchored = true; markerB.CanCollide = false; markerB.Material = Enum.Material.Neon
markerB.Color = Color3.fromRGB(255,200,0); markerB.Size = Vector3.new(1,0.3,1); markerB.Parent = workspace; markerB.Transparency = 1

local function nearestPond(posXZ: Vector2): (string?, Vector2?)
    local minD = math.huge; local bestId: string? = nil; local bestPos: Vector2? = nil
    for id, p in pairs(NetClient.snapshot.ponds or {}) do
        local d = (posXZ - p.pos).Magnitude
        if d < minD then minD = d; bestId = id; bestPos = p.pos end
    end
    if minD < 99999 then return bestId, bestPos end
    return nil, nil
end

local function mouseWorld(): Vector3?
    local cam = workspace.CurrentCamera
    if not cam then return nil end
    local m = UIS:GetMouseLocation()
    local r = cam:ViewportPointToRay(m.X, m.Y)
    local hit = workspace:Raycast(r.Origin, r.Direction * 1000)
    return hit and hit.Position or nil
end

tool.Equipped:Connect(function()
    selectA = nil; selectB = nil
    markerA.Transparency = 1; markerB.Transparency = 1
end)

tool.Activated:Connect(function()
    local p3 = mouseWorld(); if not p3 then return end
    local p2 = Vector2.new(p3.X, p3.Z)
    local id, pos = nearestPond(p2)
    if not id or not pos then return end
    if not selectA then
        selectA = id
        markerA.CFrame = CFrame.new(pos.X, p3.Y + 0.2, pos.Y)
        markerA.Transparency = 0
    else
        selectB = id
        markerB.CFrame = CFrame.new(pos.X, p3.Y + 0.2, pos.Y)
        markerB.Transparency = 0
        RF_Link:InvokeServer(selectA, selectB, width)
        selectA = nil; selectB = nil
    end
end)

UIS.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.Equals or input.KeyCode == Enum.KeyCode.Plus then
        width += 1
    elseif input.KeyCode == Enum.KeyCode.Minus then
        width = math.max(2, width - 1)
    end
end)
