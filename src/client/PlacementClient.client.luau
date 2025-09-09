local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local PondFieldMath = require(RS.Shared.PondFieldMath)
local BoundaryMask = (function()
  local ok, m = pcall(function() return require(script.Parent:FindFirstChild("Boundary") and script.Parent.Boundary:FindFirstChild("BoundaryMask") or error("no mask")) end)
  if ok then return m else
    warn("[Boundary/Mask] missing; Placement will fallback")
    return nil
  end
end)()
local WorldConfig = require(RS.Config.WorldConfig)
local BoundaryState = (function()
  local ok, m = pcall(function() return require(script.Parent:FindFirstChild("Boundary") and script.Parent.Boundary:FindFirstChild("BoundaryState") or error("no state")) end)
  return ok and m or nil
end)()
local NetClient do
  local m = script.Parent:FindFirstChild("PondNetworkClient")
  if m and m:IsA("ModuleScript") then
    NetClient = require(m)
  else
    warn("[PlacementClient] PondNetworkClient missing; using empty snapshot")
    NetClient = { snapshot = { ponds = {}, lakes = {} } }
  end
end
local RemotesFolder = RS:FindFirstChild("Remotes") or RS:WaitForChild("Net"):WaitForChild("Remotes")
local RF: RemoteFunction = RemotesFolder:WaitForChild("RF_PlaceLantern")

local camera = workspace.CurrentCamera

-- Placement mode: "lantern" or "pond"
local placementMode = "lantern"
local lanternPresetKey = "lantern_basic"

-- Create separate ghost systems for different placement types
-- Lantern ghost
local lanternGhost = Instance.new("Part")
lanternGhost.Name = "LanternGhost"
lanternGhost.Anchored = true
lanternGhost.CanCollide = false
lanternGhost.Transparency = 0.5
lanternGhost.Material = Enum.Material.Neon
lanternGhost.Color = Color3.fromRGB(255, 200, 100)  -- Warm lantern color
lanternGhost.Size = Vector3.new(1, 2, 1)  -- Basic lantern size
lanternGhost.Parent = nil  -- Start hidden

-- Pond ghost system
local ghostFolder = Instance.new("Folder")
ghostFolder.Name = "PondGhost"
ghostFolder.Parent = nil  -- Start hidden

-- Main pond cylinder (squashed)
local pondGhost = Instance.new("Part")
pondGhost.Name = "PondCylinder"
pondGhost.Anchored = true
pondGhost.CanCollide = false
pondGhost.Transparency = 0.6
pondGhost.Material = Enum.Material.ForceField
pondGhost.Color = Color3.fromRGB(100, 150, 255)  -- Blue-ish for water
pondGhost.Shape = Enum.PartType.Cylinder
pondGhost.Parent = ghostFolder

-- Boundary ring cylinder (larger, lower)
local boundaryGhost = Instance.new("Part")
boundaryGhost.Name = "BoundaryRing"
boundaryGhost.Anchored = true
boundaryGhost.CanCollide = false
boundaryGhost.Transparency = 0.8
boundaryGhost.Material = Enum.Material.ForceField
boundaryGhost.Color = Color3.fromRGB(255, 255, 0)  -- Yellow for boundary
boundaryGhost.Shape = Enum.PartType.Cylinder
boundaryGhost.Parent = ghostFolder

local function detectPlacementMode(): string
    -- Check if player has a tool equipped
    local player = Players.LocalPlayer
    local char = player and player.Character
    if char then
        for _, inst in ipairs(char:GetChildren()) do
            if inst:IsA("Tool") then
                local name = inst.Name:lower()
                if name:find("pond") then
                    return "pond"
                elseif name:find("lantern") then
                    return "lantern"
                end
            end
        end
    end
    -- Default to lantern placement when no tool
    return "lantern"
end

-- Store last valid hit for rotation
local lastHit = nil

local function updateLanternGhost(hit: RaycastResult?, isValid: boolean)
    if not hit then
        lanternGhost.Parent = nil
        return
    end
    
    -- Position lantern on actual hit surface with proper rotation
    local pos = hit.Position
    local normal = hit.Normal
    
    -- Calculate rotation to align with surface normal
    local lookDir = normal:Cross(Vector3.new(1, 0, 0))
    if lookDir.Magnitude < 0.01 then
        lookDir = normal:Cross(Vector3.new(0, 0, 1))
    end
    lookDir = lookDir.Unit
    
    local cf = CFrame.lookAt(pos, pos + lookDir, normal)
    lanternGhost.CFrame = cf * CFrame.new(0, lanternGhost.Size.Y * 0.5, 0)
    lanternGhost.Color = isValid and Color3.fromRGB(100, 255, 150) or Color3.fromRGB(255, 100, 100)
    lanternGhost.Parent = workspace
end

local function updatePondGhost(hit: RaycastResult?, isValid: boolean)
    if not hit then
        ghostFolder.Parent = workspace
        pondGhost.Position = Vector3.new(0, -1000, 0)
        boundaryGhost.Position = Vector3.new(0, -1000, 0)
        return
    end
    
    -- Get pond configuration
    local pondConfig = WorldConfig.ISLANDS.Pond
    local pondRadius = pondConfig.Radius or 15
    local pondDepth = pondConfig.Depth or 2
    
    -- Calculate boundary radius (same as boundary system)
    local BoundaryConfig = require(RS.Shared.Boundary.BoundaryConfig)
    local boundaryRadius = pondRadius * (1 + (BoundaryConfig.pond_scale or 0.5)) + (BoundaryConfig.pad or 1.25)
    
    local adjustedPos = hit.Position
    
    -- Main pond cylinder (squashed, represents actual pond)
    local pondHeight = pondDepth * 0.3  -- Squashed representation
    pondGhost.Size = Vector3.new(pondHeight, pondRadius * 2, pondRadius * 2)  -- X is height for cylinder
    pondGhost.CFrame = CFrame.new(adjustedPos + Vector3.new(0, -pondDepth * 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90))  -- Rotate to lay flat
    
    -- Boundary ring (larger, at surface)
    local ringHeight = 0.2
    boundaryGhost.Size = Vector3.new(ringHeight, boundaryRadius * 2, boundaryRadius * 2)
    boundaryGhost.CFrame = CFrame.new(adjustedPos + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90))  -- Slightly above surface
    
    -- Color based on validity
    pondGhost.Color = isValid and Color3.fromRGB(100, 255, 150) or Color3.fromRGB(255, 100, 100)
    boundaryGhost.Color = isValid and Color3.fromRGB(150, 255, 150) or Color3.fromRGB(255, 150, 150)
    
    ghostFolder.Parent = workspace
end

local function screenRay()
  local m = UIS:GetMouseLocation()
  return camera:ViewportPointToRay(m.X, m.Y)
end

local function rayToWorld(): RaycastResult?
  local r = screenRay()
  local params = RaycastParams.new()
  params.FilterType = Enum.RaycastFilterType.Blacklist
  params.FilterDescendantsInstances = { ghostFolder, lanternGhost }
  params.IgnoreWater = false  -- We want to detect water placement
  
  local hit = workspace:Raycast(r.Origin, r.Direction * 1000, params)
  return hit
end

local placeOk = false
local enabled = true
local probe = false

-- Simple toggle: press B to enable/disable placement ghost
UIS.InputBegan:Connect(function(input, gpe)
  if gpe then return end
  if input.KeyCode == Enum.KeyCode.B then
    enabled = not enabled
    if not enabled then
      ghostFolder.Parent = nil  -- Hide pond ghost
      lanternGhost.Parent = nil  -- Hide lantern ghost
    end
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
      if not enabled then
        ghostFolder.Parent = nil  -- Hide pond ghost
        lanternGhost.Parent = nil  -- Hide lantern ghost
      end
    end)
  end
end

RunService.RenderStepped:Connect(function()
  -- Detect current placement mode
  placementMode = detectPlacementMode()
  
  if not enabled then 
    ghostFolder.Parent = nil  -- Hide pond ghost
    lanternGhost.Parent = nil  -- Hide lantern ghost
    return 
  end
  
  local hit = rayToWorld()
  lastHit = hit  -- Store for placement
  
  if not hit then
    -- Hide ghosts when no valid position
    if placementMode == "pond" then
        updatePondGhost(nil, false)
    else
        updateLanternGhost(nil, false)
    end
    return
  end
  
  -- Show appropriate ghost based on mode
  if placementMode == "pond" then
    -- Hide lantern ghost, show pond ghost
    lanternGhost.Parent = nil
    
    -- Validate pond placement
    local ok = true
    local mask = BoundaryMask
    if mask and mask.isInsideBoundary then
      ok = mask.isInsideBoundary(Vector2.new(hit.Position.X, hit.Position.Z))
    end
    placeOk = ok
    updatePondGhost(hit, ok)
  else
    -- Hide pond ghost, show lantern ghost
    ghostFolder.Parent = nil
    
    -- Validate lantern placement
    local ok = true
    -- Check if on water
    if hit.Material == Enum.Material.Water then
      ok = false
    end
    -- Check slope
    if hit.Normal:Dot(Vector3.yAxis) < 0.85 then
      ok = false
    end
    placeOk = ok
    updateLanternGhost(hit, ok)
  end
end)

UIS.InputBegan:Connect(function(input, gpe)
  if gpe then return end
  if input.UserInputType == Enum.UserInputType.MouseButton1 and placeOk and lastHit then
    if placementMode == "pond" then
      -- Place pond using pond ghost position
      local success, reason = RF:InvokeServer(pondGhost.CFrame, "pond")
      if not success then
        warn("Pond place failed:", reason)
      end
    else
      -- Place lantern at actual hit position with rotation
      -- Build CFrame from hit position and normal
      local pos = lastHit.Position
      local normal = lastHit.Normal
      
      -- Calculate rotation to align with surface normal
      local lookDir = normal:Cross(Vector3.new(1, 0, 0))
      if lookDir.Magnitude < 0.01 then
        lookDir = normal:Cross(Vector3.new(0, 0, 1))
      end
      lookDir = lookDir.Unit
      
      local cf = CFrame.lookAt(pos, pos + lookDir, normal)
      local success, reason = RF:InvokeServer(cf, lanternPresetKey)
      if not success then
        warn("Lantern place failed:", reason)
      end
    end
  end
end)

-- Probe toggle and loop
Players.LocalPlayer.Chatted:Connect(function(msg)
  local lower = msg:lower()
  local onoff = lower:match("^boundary%.probe%s+(%a+)")
  if onoff then
    probe = (onoff == "on")
    print(string.format("[Boundary/SDF] probe=%s", tostring(probe)))
  end
end)

local BoundarySDF = (function()
  local ok, m = pcall(function() return require(RS.Shared.Boundary.BoundarySDF) end)
  return ok and m or nil
end)()

task.spawn(function()
  while true do
    task.wait(0.2)
    if not probe then continue end
    local hit = rayToWorld()
    if hit and BoundarySDF then
      local inside = BoundarySDF.isInside(Vector2.new(hit.Position.X, hit.Position.Z), NetClient.snapshot)
      -- Approx dist sample via SDF on current point only (offsets optional)
      local d = 0
      -- expose signed distance only if BoundarySDF exports; else approximate via inside flag
      -- For now, print 0 for dist placeholder
      print(string.format("[Boundary/SDF] inside=%s dist=%.2f onWater=%s slopeBad=%s", 
        tostring(inside), d, 
        tostring(hit.Material == Enum.Material.Water), 
        tostring(hit.Normal:Dot(Vector3.yAxis) < 0.85)))
    end
  end
end)
