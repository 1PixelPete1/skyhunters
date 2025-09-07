local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local PondFieldMath = require(RS.Shared.PondFieldMath)
local NetClient = require(script.Parent:WaitForChild("PondNetworkClient"))
local RemotesFolder = RS:FindFirstChild("Remotes") or RS:WaitForChild("Net"):WaitForChild("Remotes")
local RF: RemoteFunction = RemotesFolder:WaitForChild("RF_PlaceLantern")

local camera = workspace.CurrentCamera

-- TEMP ghost: replace with your actual model later
local ghost = Instance.new("Part")
ghost.Name = "LanternGhost"
ghost.Anchored = true
ghost.CanCollide = false
ghost.Transparency = 0.5
ghost.Size = Vector3.new(1, 2, 1)
ghost.Material = Enum.Material.ForceField
ghost.Color = Color3.fromRGB(255, 0, 0)
ghost.Parent = workspace

local function screenRay()
  local m = UIS:GetMouseLocation()
  return camera:ViewportPointToRay(m.X, m.Y)
end

local function rayToWorld(): (Vector3?, Vector3?)
  local r = screenRay()
  local params = RaycastParams.new()
  params.FilterType = Enum.RaycastFilterType.Blacklist
  params.FilterDescendantsInstances = { ghost }
  local hit = workspace:Raycast(r.Origin, r.Direction * 1000, params)
  if not hit then return nil, nil end
  return hit.Position, hit.Normal
end

local placeOk = false
local enabled = true

-- Simple toggle: press B to enable/disable placement ghost
UIS.InputBegan:Connect(function(input, gpe)
  if gpe then return end
  if input.KeyCode == Enum.KeyCode.B then
    enabled = not enabled
    ghost.Transparency = enabled and 0.5 or 1
    ghost.CanCollide = false
    ghost.Anchored = true
  end
end)

-- Dev toggle via remote
do
  local RS = game:GetService("ReplicatedStorage")
  local Net = RS:FindFirstChild("Net")
  local Remotes = Net and Net:FindFirstChild("Remotes")
  local RE = Remotes and Remotes:FindFirstChild("RE_DevToggleGhost")
  if RE and RE:IsA("RemoteEvent") then
    RE.OnClientEvent:Connect(function(on)
      enabled = on and true or false
      ghost.Transparency = enabled and 0.5 or 1
    end)
  end
end

local function resolveIslandCF(): (string, CFrame)
  local islands = workspace:FindFirstChild("Islands")
  local islandModel = islands and islands:FindFirstChild("Island_01")
  if islandModel and islandModel.PrimaryPart then
    local key = islandModel:GetAttribute("PresetKey") or "plane_64m"
    return key, islandModel.PrimaryPart.CFrame
  end
  return "plane_64m", CFrame.new()
end
RunService.RenderStepped:Connect(function()
  if not enabled then return end
  local p, n = rayToWorld()
  if not p then
    ghost.Color = Color3.fromRGB(255, 0, 0)
    return
  end
  -- Align up to surface normal; forward faces camera projected to plane
  local up = n
  local camF = camera.CFrame.LookVector
  local forward = (camF - camF:Dot(up) * up)
  if forward.Magnitude > 0 then
    forward = forward.Unit
  else
    forward = Vector3.zAxis
  end
  local right = forward:Cross(up).Unit
  ghost.CFrame = CFrame.fromMatrix(p, right, up, -forward)

  -- New rule: inside pond network SDF
  local ok = PondFieldMath.isInside(Vector2.new(p.X, p.Z), NetClient.snapshot, 1.25)
  placeOk = ok
  ghost.Color = ok and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
end)

UIS.InputBegan:Connect(function(input, gpe)
  if gpe then return end
  if input.UserInputType == Enum.UserInputType.MouseButton1 and placeOk then
    local success, reason = RF:InvokeServer(ghost.CFrame, "lantern_basic")
    if not success then
      warn("Place failed:", reason)
    end
  end
end)
