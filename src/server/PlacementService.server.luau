local RS = game:GetService("ReplicatedStorage")
local CS = game:GetService("CollectionService")

local function ensureFolder(parent: Instance, name: string): Instance
  local f = parent:FindFirstChild(name) or Instance.new("Folder")
  f.Name = name
  f.Parent = parent
  return f
end

local Remotes = ensureFolder(RS, "Remotes")
local RF: RemoteFunction = Remotes:FindFirstChild("RF_PlaceLantern") or Instance.new("RemoteFunction")
RF.Name = "RF_PlaceLantern"; RF.Parent = Remotes

-- New path: under workspace.Plots/<pk>/Lanterns (managed by LanternService)

local PondFieldMath = require(RS.Shared.PondFieldMath)
local BoundarySDF = require(RS.Shared.Boundary.BoundarySDF)
local BoundaryConfig = require(RS.Shared.Boundary.BoundaryConfig)
local Config = require(RS.Shared.Config)
local ApplyCore = require(RS.Shared.ApplyCore)
local SSS = game:GetService("ServerScriptService")
local LanternService = require(SSS:WaitForChild("Server"):WaitForChild("LanternService"))
local PondNetworkService = require(SSS:WaitForChild("Systems"):WaitForChild("PondNetworkService"))
local PlotService = require(SSS:WaitForChild("Systems"):WaitForChild("PlotService"))

-- Whitelist presets we allow from clients
local ALLOWED_PRESETS = { lantern_basic = true }

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
  -- Use unified BoundarySDF for parity
  return BoundarySDF.isInside(posXZ, PondNetworkService.getSnapshot())
end

RF.OnServerInvoke = function(player, cframe: CFrame, presetKey: string?)
  if typeof(cframe) ~= "CFrame" then
    return false, "BAD_PARAMS"
  end
  presetKey = presetKey or "lantern_basic"
  if not ALLOWED_PRESETS[presetKey] then
    return false, "PRESET_FORBIDDEN"
  end

  -- Normalize CFrame (guard NaNs)
  local pos = cframe.Position
  if not (pos.X == pos.X and pos.Y == pos.Y and pos.Z == pos.Z) then
    return false, "BAD_POSITION"
  end

  if not Config.UseLegacyLanternPlacement then
    local ok = serverAllowed(Vector2.new(pos.X, pos.Z))
    if not ok then return false, "OUT_OF_BOUNDS" end
  end

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

  -- Delegate to LanternService for spawn + persist
  local assignment = PlotService and PlotService.ClaimPlot(player)
  if not (assignment and assignment.plotId) then
    return false, "NO_PLOT"
  end
  local yaw = select(2, cframe:ToOrientation())
  local okPlace, reasonOrId = LanternService.ApplyPlacement(player, assignment.plotId, pos, yaw)
  if not okPlace then
    return false, reasonOrId or "CREATE_FAILED"
  end
  return true
end
