-- Pure placement validation core
-- Request: { position: Vector3, slotIndex: number, presetKey: string }
-- Response: { ok: boolean, reason: string? }
-- Boundary semantics:
--   - Hub radius: exclusive
--   - Wedge: inclusive
--   - Island edges: inclusive

local WorldConfig = require(game.ReplicatedStorage.Config.WorldConfig)
local PlaceValidator = require(game.ReplicatedStorage.Shared.PlaceValidator)
local WorldIndex = require(game.ReplicatedStorage.Shared.WorldIndex)
local Policy = require(game.ReplicatedStorage.Shared.PlacementPolicy)

export type PlacementRequest = {
  position: Vector3,
  slotIndex: number,
  presetKey: string,
}

export type PlacementResponse = {
  ok: boolean,
  reason: string?,
}

local PlacementCore = {}

local function hasPreset(key: string): boolean
  return WorldConfig.ISLANDS.Presets[key] ~= nil
end

local function isVector3(v: any): boolean
  return typeof(v) == "Vector3"
end

local function isString(v: any): boolean
  return type(v) == "string"
end

local function isNumber(v: any): boolean
  return type(v) == "number"
end

function PlacementCore.validate(req: PlacementRequest): PlacementResponse
  if type(req) ~= "table" then
    return { ok = false, reason = "bad_params" }
  end
  local pos = req.position
  local slot = req.slotIndex
  local preset = req.presetKey
  if not (isVector3(pos) and isNumber(slot) and isString(preset) and hasPreset(preset)) then
    return { ok = false, reason = "bad_params" }
  end

  -- Normalize and sanity-check slot index
  local slots = WorldIndex.getSlotCount()
  if slots <= 0 or slot ~= slot or slot == math.huge or slot == -math.huge then
    return { ok = false, reason = "bad_params" }
  end
  local normSlot = ((math.floor(slot) % slots) + slots) % slots

  -- Optional max query radius
  local maxR = Policy.getMaxQueryRadius()
  if maxR then
    local c = WorldConfig.HUB.Center
    local dx, dz = pos.X - c.X, pos.Z - c.Z
    local r = math.sqrt(dx*dx + dz*dz)
    if r > maxR + Policy.getEpsilon() then
      return { ok = false, reason = "bad_params" }
    end
  end

  if PlaceValidator.isInHubExclusion(pos) then
    return { ok = false, reason = "in_hub_exclusion" }
  end
  if not PlaceValidator.isInSlotWedge(pos, normSlot) then
    return { ok = false, reason = "wrong_wedge" }
  end
  if not PlaceValidator.isInIslandBoundsWorld(pos, normSlot, preset) then
    return { ok = false, reason = "out_of_bounds" }
  end
  return { ok = true }
end

return PlacementCore
