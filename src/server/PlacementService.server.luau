local RS = game:GetService("ReplicatedStorage")
local CS = game:GetService("CollectionService")

local function ensureFolder(parent: Instance, name: string): Instance
  local f = parent:FindFirstChild(name) or Instance.new("Folder")
  f.Name = name
  f.Parent = parent
  return f
end

-- Ensure remotes are in the correct location (RS.Net.Remotes)
local Net = ensureFolder(RS, "Net")
local Remotes = ensureFolder(Net, "Remotes")
local RF: RemoteFunction = Remotes:FindFirstChild("RF_PlaceLantern") or Instance.new("RemoteFunction")
RF.Name = "RF_PlaceLantern"; RF.Parent = Remotes

-- Add pond placement remote for Studio testing
local RF_AddPond: RemoteFunction = Remotes:FindFirstChild("RF_AddPond") or Instance.new("RemoteFunction")
RF_AddPond.Name = "RF_AddPond"; RF_AddPond.Parent = Remotes

-- Add removal remotes
local RF_RemovePond: RemoteFunction = Remotes:FindFirstChild("RF_RemovePond") or Instance.new("RemoteFunction")
RF_RemovePond.Name = "RF_RemovePond"; RF_RemovePond.Parent = Remotes
local RF_RemoveLantern: RemoteFunction = Remotes:FindFirstChild("RF_RemoveLantern") or Instance.new("RemoteFunction")
RF_RemoveLantern.Name = "RF_RemoveLantern"; RF_RemoveLantern.Parent = Remotes

local Shared = RS:WaitForChild("Shared")
local Config = RS:WaitForChild("Config")

-- New path: under workspace.Plots/<pk>/Lanterns (managed by LanternService)

local PondFieldMath = require(Shared:WaitForChild("PondFieldMath"))
local BoundarySDF = require(Shared:WaitForChild("Boundary"):WaitForChild("BoundarySDF"))
local BoundaryConfig = require(Shared:WaitForChild("Boundary"):WaitForChild("BoundaryConfig"))
local PlacementTransaction = require(Shared:WaitForChild("PlacementTransaction"))
local ApplyCore = require(Shared:WaitForChild("ApplyCore"))
local SSS = game:GetService("ServerScriptService")
local SafeRequire = require(Shared:WaitForChild("SafeRequire"))
local function load(inst: Instance?)
  local r = SafeRequire.load(inst)
  if r.ok then return r.mod end
  warn("[PlacementService] require failed for", r.path or "[nil]", r.reason or "unknown")
  return nil
end
local LanternService = load(SSS:WaitForChild("Server"):WaitForChild("LanternService"))
local OilReservoirService = load(SSS:WaitForChild("Server"):WaitForChild("OilReservoirService")) -- NEW
local PondNetworkService = load(SSS:WaitForChild("Systems"):WaitForChild("PondNetworkService"))
local PlotService = load(SSS:WaitForChild("Systems"):WaitForChild("PlotService"))
local PlayerStateService = load(SSS:WaitForChild("Systems"):WaitForChild("PlayerStateService")) -- NEW
local WorldConfig = require(Config:WaitForChild("WorldConfig")) -- NEW
local PresetUtil = require(Shared:WaitForChild("PresetUtil"))

local function dependenciesReady(): boolean
  return LanternService ~= nil
    and OilReservoirService ~= nil
    and PondNetworkService ~= nil
    and PlotService ~= nil
end

-- Whitelist presets we allow from clients (derived from WorldConfig)
local function isAllowedPreset(presetKey: string): boolean
  local presets = WorldConfig.ISLANDS and WorldConfig.ISLANDS.Presets or {}
  local cfg = presets[presetKey]
  if not cfg then return false end
  -- Allow any lantern_* preset by name, or any preset explicitly marked as OilReservoir
  if string.match(presetKey, "^lantern_") then return true end
  if cfg.PlaceableType == "OilReservoir" then return true end
  return false
end

-- Pending placements to reduce "double place" races
local Pending: { { pos: Vector3, t: number } } = {}
local function now() return os.clock() end
local function addPending(pos: Vector3) table.insert(Pending, { pos = pos, t = now() }) end
local function collectPositionsWithPending(): { Vector3 }
  local out = {}
  for _, inst in CS:GetTagged("Lantern") do
    if inst:IsA("BasePart") then
      table.insert(out, inst.Position)
    elseif inst:IsA("Model") and inst.PrimaryPart then
      table.insert(out, inst.PrimaryPart.Position)
    end
  end
  -- include very recent pending positions (0.6s window)
  local cutoff = now() - 0.6
  local i = 1
  while i <= #Pending do
    local p = Pending[i]
    if p.t >= cutoff then
      table.insert(out, p.pos)
      i += 1
    else
      table.remove(Pending, i)
    end
  end
  return out
end

-- Phase-1: single island; resolve CF and preset safely on server
local function resolveIslandContext(): (string, CFrame)
  local islandModel = workspace:FindFirstChild("Islands")
    and workspace.Islands:FindFirstChild("Island_01")
  if islandModel and islandModel.PrimaryPart then
    local key = islandModel:GetAttribute("PresetKey") or "plane_64m"
    return key, islandModel.PrimaryPart.CFrame
  end
  return "plane_64m", CFrame.new()
end

local function serverAllowed(posXZ: Vector2): boolean
  -- Use unified BoundarySDF for parity with current pond network snapshot
  local snapshot = PondNetworkService.getSnapshot()
  return BoundarySDF.isInside(posXZ, snapshot)
end

RF.OnServerInvoke = function(player, cframe: CFrame, presetKey: string?)
  if typeof(cframe) ~= "CFrame" then
    return false, "BAD_PARAMS"
  end

  if not dependenciesReady() then
    warn("[PlacementService] missing dependency; rejecting placement")
    return false, "SERVICE_UNAVAILABLE"
  end

  -- Check player state - must be in Build state to place
  if PlayerStateService then
    local playerState = PlayerStateService:GetPlayerState(player)
    if playerState ~= "Build" then
      return false, "NOT_IN_BUILD_STATE"
    end
  end
  
  -- INVENTORY VALIDATION: Check if player has the item
  local InventoryIntegration = load(SSS:WaitForChild("Systems"):WaitForChild("InventoryIntegrationService"))
  if InventoryIntegration then
    local hasItem = InventoryIntegration:ValidatePlacement(player, presetKey or "lantern_basic", cframe.Position)
    if not hasItem then
      warn("[PlacementService] Player", player.Name, "lacks inventory item:", presetKey)
      return false, "NO_INVENTORY_ITEM"
    end
  end
  
  presetKey = presetKey or "lantern_basic"
  if not isAllowedPreset(presetKey) then
    return false, "PRESET_FORBIDDEN"
  end

  -- Normalize CFrame (guard NaNs)
  local pos = cframe.Position
  if not (pos.X == pos.X and pos.Y == pos.Y and pos.Z == pos.Z) then
    return false, "BAD_POSITION"
  end

  -- Quick hard gate: must be inside player's plot rectangle
  local assignment = PlotService and PlotService.ClaimPlot(player)
  if assignment and typeof(assignment) == "table" and typeof(cframe) == "CFrame" then
    local center = (assignment.origin and assignment.origin.Position) or Vector3.new()
    local half = PresetUtil.getPresetHalfSizeVector(WorldConfig.ISLANDS.MainPresetKey or "plane_64m")
    local p = cframe.Position
    if math.abs(p.X - center.X) > half.X or math.abs(p.Z - center.Z) > half.Z then
      return false, "OUT_OF_BOUNDS"
    end
  end

  -- Use PlacementTransaction for comprehensive validation
  local request: PlacementTransaction.PlacementRequest = {
    posXZ = Vector2.new(pos.X, pos.Z),
    placementType = "lantern",
    presetKey = presetKey,  -- Keep original lantern preset for lantern validation
    playerUserId = player.UserId,
  }
  
  -- Execute transactional placement (validate first, then create)
  local success, reason, result = PlacementTransaction.executePlacement(request, function(req)
    -- This callback only runs if validation passes
    
    -- Additional server-side validation: must be on Terrain and respect min spacing
    do
      -- Vertical ray from above, to robustly find Terrain under the intended point
      local origin = pos + Vector3.new(0, 200, 0)
      local params = RaycastParams.new()
      params.FilterType = Enum.RaycastFilterType.Blacklist
      params.IgnoreWater = true
      local ignore = {}
      for _, inst in CS:GetTagged("Lantern") do table.insert(ignore, inst) end
      local rim = workspace:FindFirstChild("PondRim"); if rim then table.insert(ignore, rim) end
      local oil = workspace:FindFirstChild("Oil"); if oil then table.insert(ignore, oil) end
      local boundary = workspace:FindFirstChild("PlacementBoundary"); if boundary then table.insert(ignore, boundary) end
      params.FilterDescendantsInstances = ignore
      local hit = workspace:Raycast(origin, Vector3.new(0, -500, 0), params)
      if not hit or hit.Instance ~= workspace.Terrain then
        -- Fall back: include water to distinguish water vs. no-surface
        params.IgnoreWater = false
        hit = workspace:Raycast(origin, Vector3.new(0, -500, 0), params)
        if hit and hit.Instance == workspace.Terrain and hit.Material == Enum.Material.Water then
          return false, "ON_WATER"
        end
        return false, "BAD_SURFACE"
      end
      local upDot = hit.Normal:Dot(Vector3.yAxis)
      if upDot < 0.85 then
        return false, "TOO_STEEP"
      end

      -- spacing check: min 6 studs from existing lanterns
      local MIN_SPACING = 6.0
      for _, inst in CS:GetTagged("Lantern") do
        if inst:IsA("BasePart") then
          if (inst.Position - pos).Magnitude < MIN_SPACING then
            return false, "TOO_CLOSE"
          end
        elseif inst:IsA("Model") and inst.PrimaryPart then
          if (inst.PrimaryPart.Position - pos).Magnitude < MIN_SPACING then
            return false, "TOO_CLOSE"
          end
        end
      end
    end

    -- race guard: mark pending before spawn
    addPending(pos)

    -- Determine placement type from preset and delegate appropriately
    local assignment = PlotService and PlotService.ClaimPlot(player)
    if not (assignment and assignment.plotId) then
      return false, "NO_PLOT"
    end
    
    -- Check preset configuration to determine placement type
    local presetConfig = WorldConfig.ISLANDS.Presets[presetKey]
    local placementType = presetConfig and presetConfig.PlaceableType
    
    if placementType == "OilReservoir" then
      -- Handle oil reservoir placement
      local okPlace, reasonOrId = OilReservoirService.ApplyPlacement(player, assignment.plotId, pos, presetKey)
      if not okPlace then
        return false, reasonOrId or "CREATE_FAILED"
      end
      -- Consume inventory item on success
      if InventoryIntegration and InventoryIntegration.OnItemPlaced then
        InventoryIntegration:OnItemPlaced(player, presetKey, true)
      end
      return true, reasonOrId
    else
      -- Handle lantern placement (default)
      local yaw = select(2, cframe:ToOrientation())
      local okPlace, reasonOrId = LanternService.ApplyPlacement(player, assignment.plotId, pos, yaw, presetKey)
      if not okPlace then
        return false, reasonOrId or "CREATE_FAILED"
      end
      -- Consume inventory item on success
      if InventoryIntegration and InventoryIntegration.OnItemPlaced then
        InventoryIntegration:OnItemPlaced(player, presetKey, true)
      end
      return true, reasonOrId
    end
  end)
  
  return success, reason
end

-- Pond removal handler (FIXED to use RemovalSystem)
RF_RemovePond.OnServerInvoke = function(player, pondId: string)
  if type(pondId) ~= "string" then
    return false, "BAD_PARAMS"
  end
  
  -- Use the proper RemovalSystem instead of direct PondNetworkService call
  local RemovalSystem = require(SSS:WaitForChild("Systems"):WaitForChild("RemovalSystem"))
  if RemovalSystem and RemovalSystem.removePond then
    local success, reason = RemovalSystem.removePond(player, pondId)
    return success, reason
  else
    warn("[PlacementService] RemovalSystem not available")
    return false, "SERVICE_UNAVAILABLE"
  end
end

-- Lantern removal handler (FIXED to use RemovalSystem)
RF_RemoveLantern.OnServerInvoke = function(player, lanternId: string)
  if type(lanternId) ~= "string" then
    return false, "BAD_PARAMS"
  end
  
  -- Use the proper RemovalSystem
  local RemovalSystem = require(SSS:WaitForChild("Systems"):WaitForChild("RemovalSystem"))
  if RemovalSystem and RemovalSystem.removeLantern then
    local success, reason = RemovalSystem.removeLantern(player, lanternId)
    return success, reason
  else
    warn("[PlacementService] RemovalSystem not available")
    return false, "SERVICE_UNAVAILABLE"
  end
end

-- Add pond placement handler for Studio testing and dynamic pond creation
RF_AddPond.OnServerInvoke = function(player, posXZ: Vector2, radius: number)
  if typeof(posXZ) ~= "Vector2" or type(radius) ~= "number" then
    return false, "BAD_PARAMS"
  end
  
  -- Check player state - must be in Build state to place
  if PlayerStateService then
    local playerState = PlayerStateService:GetPlayerState(player)
    if playerState ~= "Build" then
      return false, "NOT_IN_BUILD_STATE"
    end
  end
  
  -- Quick hard gate: pond must be inside player's plot rectangle
  do
    local assignment = PlotService and PlotService.ClaimPlot(player)
    if not (assignment and typeof(assignment) == "table") then
      return false, "NO_PLOT"
    end
    local center = (assignment.origin and assignment.origin.Position) or Vector3.new()
    local half = PresetUtil.getPresetHalfSizeVector(WorldConfig.ISLANDS.MainPresetKey or "plane_64m")
    local dx = posXZ.X - center.X
    local dz = posXZ.Y - center.Z
    if math.abs(dx) > half.X or math.abs(dz) > half.Z then
      return false, "OUT_OF_BOUNDS"
    end
  end
  
  -- Only allow in Studio for now
  if not game:GetService("RunService"):IsStudio() then
    return false, "STUDIO_ONLY"
  end
  
  -- Validate placement
  local request: PlacementTransaction.PlacementRequest = {
    posXZ = posXZ,
    radius = radius,
    placementType = "pond",
    playerUserId = player.UserId,
  }
  
  local success, reason, result = PlacementTransaction.executePlacement(request, function(req)
    -- Create the pond using PondNetworkService
    local pondId = PondNetworkService.addPond(req.posXZ, req.radius)
    if pondId then
      print(string.format("[PlacementService] Created dynamic pond: %s at (%.1f, %.1f) radius=%.1f", tostring(pondId), req.posXZ.X, req.posXZ.Y, req.radius or radius))
      return true, pondId
    else
      return false, "CREATE_FAILED"
    end
  end)
  
  return success, reason
end






