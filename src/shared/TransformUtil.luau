-- Pure math utilities for island/world transforms
-- Angles are radians; uniform scale

export type IslandTransform = {
  pos: Vector3,       -- world anchor of local origin
  yaw: number,        -- radians; rotation about +Y
  scale: number,      -- uniform scale (Phase-1: 1.0)
  heightY: number,    -- world Y for island plane
  presetKey: string,  -- e.g., "plane_64m"
}

export type Transform = IslandTransform

local WorldConfig = require(game.ReplicatedStorage.Config.WorldConfig)
local PresetUtil = require(game.ReplicatedStorage.Shared.PresetUtil)

local TransformUtil = {}

-- Local policy defaults to avoid require cycles
local function getEpsilon(): number
  return WorldConfig.EPSILON or 0
end
local function isIslandEdgesInclusive(): boolean
  return true
end
local function isHubRadiusExclusive(): boolean
  return true
end
local function isWedgeInclusive(): boolean
  return true
end

-- Compose an island CFrame (translation * yaw). Ignores scale in CFrame.
function TransformUtil.makeCFrame(T: Transform): CFrame
  return CFrame.new(T.pos) * CFrame.Angles(0, T.yaw, 0)
end

-- Local -> World. Keeps XZ; forces Y to island height (Phase-1 flat plane).
function TransformUtil.toWorld(T: Transform, pLocal: Vector3): Vector3
  local s = T.scale or 1
  local pLocalXZ = Vector3.new(pLocal.X * s, 0, pLocal.Z * s)
  local cf = TransformUtil.makeCFrame(T)
  local pWorld = cf:PointToWorldSpace(pLocalXZ)
  return Vector3.new(pWorld.X, T.heightY, pWorld.Z)
end

-- World -> Local. Returns local XZ; local Y is 0 for Phase-1.
function TransformUtil.toLocal(T: Transform, pWorld: Vector3): Vector3
  local s = T.scale or 1
  local projected = Vector3.new(pWorld.X, T.heightY, pWorld.Z)
  local cf = TransformUtil.makeCFrame(T)
  local localV = cf:PointToObjectSpace(projected)
  if s ~= 0 then
    return Vector3.new(localV.X / s, 0, localV.Z / s)
  end
  -- Defensive: avoid divide by zero, though Phase-1 uses scale=1
  return Vector3.new(localV.X, 0, localV.Z)
end

-- Is point within the island preset square in LOCAL space (XZ).
function TransformUtil.inIslandBounds(pLocal: Vector3, presetKey: string): boolean
  local hVec = PresetUtil.getPresetHalfSizeVector(presetKey)
  local eps = getEpsilon()
  local inclusive = isIslandEdgesInclusive()
  if inclusive then
    return (math.abs(pLocal.X) <= hVec.X + eps) and (math.abs(pLocal.Z) <= hVec.Z + eps)
  else
    return (math.abs(pLocal.X) < hVec.X - eps) and (math.abs(pLocal.Z) < hVec.Z - eps)
  end
end

-- New: island-relative bounds check using world-space position and island CFrame
function TransformUtil.inIslandBoundsAt(pos: Vector3, presetKey: string, islandCF: CFrame): boolean
  local half = PresetUtil.getPresetHalfSizeVector(presetKey)
  local localPos = islandCF:PointToObjectSpace(pos)
  local eps = getEpsilon()
  local inclusive = isIslandEdgesInclusive()
  if inclusive then
    return math.abs(localPos.X) <= half.X + eps and math.abs(localPos.Z) <= half.Z + eps
  else
    return math.abs(localPos.X) < half.X - eps and math.abs(localPos.Z) < half.Z - eps
  end
end

-- Is WORLD point inside hub exclusion disc (XZ plane).
function TransformUtil.inHubExclusion(pWorld: Vector3): boolean
  local hub = WorldConfig.HUB
  local dx = pWorld.X - hub.Center.X
  local dz = pWorld.Z - hub.Center.Z
  local distSq = dx * dx + dz * dz
  local exclusive = isHubRadiusExclusive()
  if exclusive then
    return distSq < (hub.Radius * hub.Radius)
  else
    return distSq <= (hub.Radius * hub.Radius)
  end
end

-- Helper: returns the center yaw (radians) of a slotIndex.
function TransformUtil.slotCenterYaw(slotIndex: number): number
  local slots = WorldConfig.PLOTS.Slots
  local offset = WorldConfig.PLOTS.SlotOffsetYaw
  local step = (2 * math.pi) / slots
  return offset + (slotIndex % slots) * step
end

-- Angle difference in [-Ï€, Ï€]
function TransformUtil.shortestAngleDiff(a: number, b: number): number
  -- Robust approach using atan2 of sine/cosine of difference
  return math.atan2(math.sin(a - b), math.cos(a - b))
end

-- Is WORLD point inside the player's sector wedge.
-- slotIndex: 0..(Slots-1), center angle = offset + slotIndex*(2Ï€/Slots).
-- half-angle = Ï€ / Slots.
function TransformUtil.inSectorWedge(pWorld: Vector3, slotIndex: number): boolean
  local hub = WorldConfig.HUB
  local slots = WorldConfig.PLOTS.Slots
  local centerYaw = TransformUtil.slotCenterYaw(slotIndex)
  local v = Vector2.new(pWorld.X - hub.Center.X, pWorld.Z - hub.Center.Z)
  if v.Magnitude == 0 then
    return true
  end
  local ang = math.atan2(v.Y, v.X) -- note: Vector2 uses XY, map to XZ
  local delta = TransformUtil.shortestAngleDiff(ang, centerYaw)
  local halfAngle = math.pi / slots
  local eps = getEpsilon()
  local inclusive = isWedgeInclusive()
  if inclusive then
    return math.abs(delta) <= (halfAngle + eps)
  else
    return math.abs(delta) < (halfAngle - eps)
  end
end

return TransformUtil
