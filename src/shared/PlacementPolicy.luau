-- Centralized placement policy: tolerance and boundary semantics
-- Pure; reads WorldConfig for numbers, exposes booleans/limits.

local WorldConfig = require(game.ReplicatedStorage.Config.WorldConfig)
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TransformUtil = require(RS.Shared.TransformUtil)
local TerrainUtil = require(RS.Shared.TerrainUtil)

local PlacementPolicy = {}

function PlacementPolicy.getEpsilon(): number
  return WorldConfig.EPSILON or 0
end

-- Boundary inclusivity
function PlacementPolicy.isWedgeInclusive(): boolean
  return true
end

function PlacementPolicy.isIslandEdgesInclusive(): boolean
  return true
end

function PlacementPolicy.isHubRadiusExclusive(): boolean
  return true
end

-- Optional query radius cap from config; return nil to disable.
function PlacementPolicy.getMaxQueryRadius(): number?
  local plots = WorldConfig.PLOTS
  local r: any = plots and (plots.MaxQueryRadius or plots.RadialOffset)
  if type(r) == "number" and r > 0 then
    -- If only RadialOffset is present, make it a generous cap (x4)
    local cap = (plots.MaxQueryRadius and r or (4 * r))
    return cap
  end
  return nil
end

-- Debug logging toggle (off by default)
function PlacementPolicy.debugLoggingEnabled(): boolean
  return false -- flip to true only in dev mode
end

-- Dev mode toggle (immutable by default)
function PlacementPolicy.isDevModeEnabled(): boolean
  return false
end

-- Quantization step for placement key (studs)
-- Quantization publishing for placement determinism
-- Op: "round" or "floor"; Decimals: integer >= 0
function PlacementPolicy.getQuantizationOp(): string
  -- Explicit policy: use rounding for stable keys
  return "round"
end

function PlacementPolicy.getQuantizationPrecisionDecimals(): number
  -- 2–3 decimals are typical; choose 2 for Phase-1
  return 2
end

-- Derived step from decimals; kept for backward compatibility
function PlacementPolicy.getQuantizationStep(): number
  local d = PlacementPolicy.getQuantizationPrecisionDecimals()
  local step = 10 ^ (-math.max(0, math.floor(d)))
  local eps = PlacementPolicy.getEpsilon()
  -- Never below 10*eps to avoid float dust
  return math.max(step, eps * 10)
end

-- Apply quantization op to scalar based on policy
function PlacementPolicy.quantizeScalar(x: number): number
  local step = PlacementPolicy.getQuantizationStep()
  local op = PlacementPolicy.getQuantizationOp()
  if op == "floor" then
    return math.floor(x / step) * step
  else -- default: round
    return math.floor(x / step + 0.5) * step
  end
end

-- Map/world version string for placement keys
function PlacementPolicy.getWorldVersion(): string
  local ok, Version = pcall(function()
    return require(game.ReplicatedStorage.Config.Version)
  end)
  if ok and type(Version) == "table" then
    if type(Version.GAME_VERSION) == "string" then return Version.GAME_VERSION end
    if type(Version.SCHEMA_VERSION) == "number" then return tostring(Version.SCHEMA_VERSION) end
  end
  return "0"
end

-- Get preset revision for keys; default 1
function PlacementPolicy.getPresetRevision(presetKey: string): number
  local p = WorldConfig.ISLANDS and WorldConfig.ISLANDS.Presets and WorldConfig.ISLANDS.Presets[presetKey]
  local r = p and p.Revision
  if type(r) == "number" and r > 0 then return r end
  return 1
end

-- Lantern-specific rules and validator (server-authoritative placement)
PlacementPolicy.Rules = PlacementPolicy.Rules or {}
PlacementPolicy.Rules.Lantern = {
  maxSlopeDeg = 18,
  minSpacing = 6,
  allowOn = { "island" },
  clearanceY = 0.2,
}

export type LanternRequest = {
  position: Vector3,
  islandPresetKey: string,
  islandCFrame: CFrame?,
  normal: Vector3?,
  existingLanternPositions: { Vector3 }?,
}

function PlacementPolicy.validateLantern(req: LanternRequest): (boolean, string?)
  if type(req) ~= "table" or typeof(req.position) ~= "Vector3" or type(req.islandPresetKey) ~= "string" then
    return false, "BAD_PARAMS"
  end

  -- 1) bounds via TransformUtil with optional island CFrame
  local islandCF = req.islandCFrame or CFrame.new()
  if not TransformUtil.inIslandBoundsAt(req.position, req.islandPresetKey, islandCF) then
    return false, "OUT_OF_BOUNDS"
  end

  -- 2) slope (if normal provided)
  if req.normal then
    local dot = math.clamp(req.normal:Dot(Vector3.yAxis), -1, 1)
    local slopeDeg = math.deg(math.acos(dot))
    if slopeDeg > PlacementPolicy.Rules.Lantern.maxSlopeDeg then
      return false, "TOO_STEEP"
    end
  end

  -- 2.5) disallow water placements (server-enforced)
  if RunService:IsServer() then
    local okWater = TerrainUtil.isWaterAt(req.position, 2)
    if okWater then
      return false, "ON_WATER"
    end
  end

  -- 3) spacing (server-supplied list)
  if req.existingLanternPositions then
    local minSpacing = PlacementPolicy.Rules.Lantern.minSpacing
    for _, p in req.existingLanternPositions do
      if (req.position - p).Magnitude < minSpacing then
        return false, "TOO_CLOSE"
      end
    end
  end

  return true
end

return PlacementPolicy
