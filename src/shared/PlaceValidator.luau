-- Placement validator utilities
-- Edge behavior: inclusive island edges; inclusive wedge boundary; hub radius exclusive

local WorldConfig = require(game.ReplicatedStorage.Config.WorldConfig)
local TransformUtil = require(game.ReplicatedStorage.Shared.TransformUtil)
local WorldIndex = require(game.ReplicatedStorage.Shared.WorldIndex)

local PlaceValidator = {}

function PlaceValidator.isInHubExclusion(pWorld: Vector3): boolean
  return TransformUtil.inHubExclusion(pWorld)
end

function PlaceValidator.isInSlotWedge(pWorld: Vector3, slotIndex: number): boolean
  return TransformUtil.inSectorWedge(pWorld, slotIndex)
end

function PlaceValidator.isInIslandBoundsWorld(pWorld: Vector3, slotIndex: number, presetKey: string): boolean
  local T = WorldIndex.getIslandTransform(slotIndex, presetKey)
  local pLocal = TransformUtil.toLocal(T, pWorld)
  return TransformUtil.inIslandBounds(pLocal, presetKey)
end

-- Returns (ok: boolean, reason: string|nil)
-- Reasons: "in_hub_exclusion", "wrong_wedge", "out_of_bounds"
function PlaceValidator.validatePlacement(pWorld: Vector3, slotIndex: number, presetKey: string)
  if PlaceValidator.isInHubExclusion(pWorld) then
    return false, "in_hub_exclusion"
  end
  if not PlaceValidator.isInSlotWedge(pWorld, slotIndex) then
    return false, "wrong_wedge"
  end
  if not PlaceValidator.isInIslandBoundsWorld(pWorld, slotIndex, presetKey) then
    return false, "out_of_bounds"
  end
  return true, nil
end

return PlaceValidator

