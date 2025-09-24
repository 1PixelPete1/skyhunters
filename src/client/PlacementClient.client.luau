local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local PondFieldMath = require(RS.Shared.PondFieldMath)
local PlacementTransaction = require(RS.Shared.PlacementTransaction)
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
-- Make NetClient globally accessible for PlacementTransaction
_G.PondNetworkClient = NetClient
local Net = RS:WaitForChild("Net")
local RemotesFolder = Net:WaitForChild("Remotes")
local RF: RemoteFunction = RemotesFolder:WaitForChild("RF_PlaceLantern")
local NetApi = require(RS.Shared.Net)

local camera = workspace.CurrentCamera
local player = Players.LocalPlayer

-- Track authoritative player state from server
local currentPlayerState = "Neutral"
do
  local ok, ev = pcall(function() return RS:WaitForChild("PlayerStateRemote") end)
  if ok and ev and ev:IsA("RemoteEvent") then
    ev.OnClientEvent:Connect(function(eventType, data)
      if eventType == "StateChanged" and data and data.state then
        currentPlayerState = data.state
      end
    end)
    -- Ask server to send current state once
    pcall(function() ev:FireServer("RequestState") end)
  end
end

-- Placement mode and item info from equipped tool
local placementMode = nil  -- Start with no mode
local lanternPresetKey = "lantern_basic"  -- Default if no tool
local currentItemId = nil  -- Track the actual ItemId from tool
local plotCenter: Vector3? = nil
local halfSize: Vector3? = nil

local function computeHalfSize(): Vector3
  local WorldConfig = require(RS.Config.WorldConfig)
  local PresetUtil = require(RS.Shared.PresetUtil)
  local presetKey = WorldConfig.ISLANDS.MainPresetKey or "plane_64m"
  return PresetUtil.getPresetHalfSizeVector(presetKey)
end

local function setAssignment(assignment)
  if assignment and typeof(assignment) == "table" then
    local origin = assignment.origin
    if origin and typeof(origin) == "CFrame" then
      plotCenter = origin.Position
      halfSize = computeHalfSize()
    end
  end
end

-- Listen for plot assignment from server
task.spawn(function()
  local ok, ev = pcall(function() return NetApi:GetEvent("RE_BaseAssigned") end)
  if ok and ev then
    ev.OnClientEvent:Connect(function(assignment)
      setAssignment(assignment)
    end)
  end
end)

local function inPlotBounds(pos: Vector3): boolean
  if not plotCenter or not halfSize then return true end
  local dx = pos.X - plotCenter.X
  local dz = pos.Z - plotCenter.Z
  return math.abs(dx) <= halfSize.X and math.abs(dz) <= halfSize.Z
end

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

-- Check if player has a lantern item in their inventory (future implementation)
local function hasLanternItem(): boolean
    -- TODO: Check actual inventory system when implemented
    -- For now, return true to allow placement in dev mode
    -- This is where you'd check if player has lantern items
    return true
end

-- Check if player has permission to place ponds (usually dev-only)
local function canPlacePonds(): boolean
    -- Pond placement is typically restricted to Studio/dev mode
    return RunService:IsStudio()
end

local function detectPlacementMode(): string?
    -- CRITICAL FIX: Only detect placement mode if in Build state
    if currentPlayerState ~= "Build" then
        return nil  -- No placement mode allowed outside Build state
    end
    
    -- Check if player has a tool equipped and read its ItemId
    local char = player and player.Character
    if char then
        for _, inst in ipairs(char:GetChildren()) do
            if inst:IsA("Tool") then
                -- Read ItemId attribute from tool
                local itemId = inst:GetAttribute("ItemId")
                if itemId then
                    currentItemId = itemId
                    -- Parse item type from ItemId (e.g., "lantern_basic" -> "lantern")
                    local itemType = string.match(itemId, "^(%w+)_") or "unknown"
                    
                    if itemType == "pond" then
                        return canPlacePonds() and "pond" or nil
                    elseif itemType == "lantern" then
                        -- Set the specific lantern preset from the tool
                        lanternPresetKey = itemId  -- Use the actual ItemId as preset
                        return "lantern"
                    elseif itemType == "oil" then
                        -- Oil canisters place oil reservoirs anywhere on terrain
                        return "oil"
                    elseif itemType == "canal" then
                        return "canal"  -- For future canal tool support
                    elseif itemId == "removal_tool" then
                        return "removal"  -- For removal tool
                    end
                end
                
                -- Fallback to name-based detection for old tools
                local name = inst.Name:lower()
                if name:find("pond") then
                    currentItemId = "pond_basic"
                    return canPlacePonds() and "pond" or nil
                elseif name:find("lantern") then
                    currentItemId = "lantern_basic"
                    lanternPresetKey = "lantern_basic"
                    return "lantern"
                end
            end
        end
    end
    
    -- No tool equipped = no placement mode
    return nil  -- No valid placement mode
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
    -- Add extra height offset to keep marker above ground
    local heightOffset = lanternGhost.Size.Y * 0.5 + 0.5  -- Add 0.5 stud clearance
    lanternGhost.CFrame = cf * CFrame.new(0, heightOffset, 0)
    lanternGhost.Color = isValid and Color3.fromRGB(100, 255, 150) or Color3.fromRGB(255, 100, 100)
    lanternGhost.Parent = workspace
end

local function updatePondGhost(hit: RaycastResult?, isValid: boolean)
    if not hit then
        ghostFolder.Parent = nil
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
    
    -- FIXED: Color based on validity (was inverted)
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
  -- Detect current placement mode (returns nil if no valid mode or not in Build state)
  placementMode = detectPlacementMode()
  
  -- Hide all ghosts if disabled, no valid placement mode, or not in Build state
  if not enabled or not placementMode or currentPlayerState ~= "Build" then 
    ghostFolder.Parent = nil  -- Hide pond ghost
    lanternGhost.Parent = nil  -- Hide lantern ghost
    placeOk = false
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
    placeOk = false
    return
  end
  
  -- Show appropriate ghost based on mode
  -- Hard gate: only within assigned plot rectangle
  if hit and not inPlotBounds(hit.Position) then
    lanternGhost.Parent = nil
    ghostFolder.Parent = nil
    placeOk = false
    return
  end

  if placementMode == "pond" then
    -- Hide lantern ghost, show pond ghost
    lanternGhost.Parent = nil
    
    -- Enhanced pond validation using PlacementTransaction
    local isValid, reason = PlacementTransaction.quickValidateForGhost("pond", Vector2.new(hit.Position.X, hit.Position.Z), 10)
    
    -- Fallback to boundary mask if transaction validation passes
    if isValid then
      local mask = BoundaryMask
      if mask and mask.isInsideBoundary then
        isValid = mask.isInsideBoundary(Vector2.new(hit.Position.X, hit.Position.Z))
        if not isValid then
          reason = "OUT_OF_BOUNDS"
        end
      else
        -- Direct boundary check using BoundarySDF with current snapshot
        local BoundarySDF = require(RS.Shared.Boundary.BoundarySDF)
        local NetClient = _G.PondNetworkClient or { snapshot = { ponds = {}, lakes = {} } }
        isValid = BoundarySDF.isInside(Vector2.new(hit.Position.X, hit.Position.Z), NetClient.snapshot)
        if not isValid then
          reason = "OUT_OF_BOUNDS"
        end
      end
    end
    
    placeOk = isValid
    updatePondGhost(hit, isValid)
  elseif placementMode == "lantern" then
    -- Hide pond ghost, show lantern ghost
    ghostFolder.Parent = nil
    
    -- Enhanced lantern validation using PlacementTransaction
    local isValid, reason = PlacementTransaction.quickValidateForGhost("lantern", Vector2.new(hit.Position.X, hit.Position.Z))
    
    -- Additional check: are we on a rim stone?
    if not isValid and hit.Instance and hit.Instance.Name == "RimStone" then
      isValid = true
      reason = nil
    end
    
    placeOk = isValid
    updateLanternGhost(hit, isValid)
  elseif placementMode == "oil" then
    -- No ghost for oil; allow placement on any terrain (not water)
    lanternGhost.Parent = nil
    ghostFolder.Parent = nil

    local isValid = false
    if hit then
      local onTerrain = (hit.Instance == workspace.Terrain)
      local notWater = hit.Material ~= Enum.Material.Water
      isValid = onTerrain and notWater
    end
    placeOk = isValid
  end
end)

UIS.InputBegan:Connect(function(input, gpe)
  if gpe then return end
  if input.UserInputType == Enum.UserInputType.MouseButton1 and placeOk and lastHit and placementMode then
    -- CRITICAL: Double-check Build state at placement time
    if currentPlayerState ~= "Build" then 
      warn("[PlacementClient] Placement blocked: not in Build state")
      return 
    end
    if not inPlotBounds(lastHit.Position) then return end
    if placementMode == "pond" then
      -- Find the pond placement remote (only works in Studio)
      local RF_AddPond = RemotesFolder:FindFirstChild("RF_AddPond")
      if RF_AddPond and RunService:IsStudio() then
        local posXZ = Vector2.new(lastHit.Position.X, lastHit.Position.Z)
        local radius = (WorldConfig.ISLANDS.Pond and WorldConfig.ISLANDS.Pond.Radius) or 10
        local success = RF_AddPond:InvokeServer(posXZ, radius)
        if not success then
          warn("Pond place failed: validation failed or not in Studio")
        end
      else
        warn("Pond placement only available in Studio")
      end
    elseif placementMode == "lantern" then
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
      else
        print(string.format("[PlacementClient] Lantern placed successfully at (%.1f, %.1f)", pos.X, pos.Z))
      end
    elseif placementMode == "oil" then
      -- Place a small oil reservoir at the hit position
      local pos = lastHit.Position
      local normal = lastHit.Normal
      local lookDir = normal:Cross(Vector3.new(1, 0, 0))
      if lookDir.Magnitude < 0.01 then
        lookDir = normal:Cross(Vector3.new(0, 0, 1))
      end
      lookDir = lookDir.Unit
      local cf = CFrame.lookAt(pos, pos + lookDir, normal)
      local success, reason = RF:InvokeServer(cf, "oil_reservoir_small")
      if not success then
        warn("Oil reservoir place failed:", reason)
      else
        print(string.format("[PlacementClient] Oil reservoir placed at (%.1f, %.1f)", pos.X, pos.Z))
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
