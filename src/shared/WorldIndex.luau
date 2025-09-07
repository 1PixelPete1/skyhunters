-- Pure world indexing helpers
-- No side effects; uses WorldConfig + TransformUtil

local WorldConfig = require(game.ReplicatedStorage.Config.WorldConfig)
local PresetUtil = require(game.ReplicatedStorage.Shared.PresetUtil)

local WorldIndex = {}

function WorldIndex.getSlotCount(): number
  return WorldConfig.PLOTS.Slots
end

function WorldIndex.slotCenterYaw(slotIndex: number): number
  local slots = WorldConfig.PLOTS.Slots
  local offset = WorldConfig.PLOTS.SlotOffsetYaw
  local step = (2 * math.pi) / slots
  return offset + (slotIndex % slots) * step
end

function WorldIndex.slotCenterPosition(slotIndex: number): Vector3
  local yaw = WorldIndex.slotCenterYaw(slotIndex)
  local r = WorldConfig.PLOTS.RadialOffset or WorldConfig.HUB.Radius
  local c = WorldConfig.HUB.Center
  local islands = WorldConfig.ISLANDS
  local y = (islands and islands.DefaultHeightY) or (islands and (islands :: any).DefaultHeight) or 0
  local x = c.X + r * math.cos(yaw)
  local z = c.Z + r * math.sin(yaw)
  return Vector3.new(x, y, z)
end

export type Transform = {
  pos: Vector3,
  yaw: number,
  scale: number,
  heightY: number,
  presetKey: string,
}

function WorldIndex.getIslandTransform(slotIndex: number, presetKey: string): Transform
  return {
    pos = WorldIndex.slotCenterPosition(slotIndex),
    yaw = WorldIndex.slotCenterYaw(slotIndex),
    heightY = ((WorldConfig.ISLANDS and WorldConfig.ISLANDS.DefaultHeightY) or (WorldConfig.ISLANDS and (WorldConfig.ISLANDS :: any).DefaultHeight) or 0),
    scale = 1,
    presetKey = presetKey,
  }
end

-- Canonical HalfSize as Vector3; accepts number or Vector3 in config
function WorldIndex.getPresetHalfSize(presetKey: string): Vector3
  return PresetUtil.getPresetHalfSizeVector(presetKey)
end

return WorldIndex
