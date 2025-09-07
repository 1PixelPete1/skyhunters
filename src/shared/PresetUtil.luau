--!strict
-- Preset utilities: canonical conversions and lookups

local WorldConfig = require(game.ReplicatedStorage.Config.WorldConfig)

local PresetUtil = {}

-- Returns HalfSize as a Vector3 (XZ), accepting number or Vector3 in config
function PresetUtil.getPresetHalfSizeVector(presetKey: string): Vector3
  local presets = WorldConfig.ISLANDS and WorldConfig.ISLANDS.Presets
  local preset = presets and presets[presetKey]
  if not preset then
    return Vector3.new(0, 0, 0)
  end
  local h: any = preset.HalfSize
  if typeof(h) == "Vector3" then
    return Vector3.new(h.X, 0, h.Z)
  end
  if type(h) == "number" then
    return Vector3.new(h, 0, h)
  end
  return Vector3.new(0, 0, 0)
end

return PresetUtil

