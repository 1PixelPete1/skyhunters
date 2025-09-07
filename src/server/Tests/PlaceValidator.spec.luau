local WorldConfig = require(game.ReplicatedStorage.Config.WorldConfig)
local WorldIndex = require(game.ReplicatedStorage.Shared.WorldIndex)
local TU = require(game.ReplicatedStorage.Shared.TransformUtil)
local PV = require(game.ReplicatedStorage.Shared.PlaceValidator)

return function()
  local function approx(a: number, b: number, eps: number)
    return math.abs(a - b) <= eps
  end
  local pass, fail = 0, 0
  local function ok(cond: boolean, label: string)
    if cond then pass += 1 else fail += 1; print("[FAIL] " .. label) end
  end

  local EPS = 1e-4
  local CFG_EPS = WorldConfig.EPSILON
  local presetKey = WorldConfig.ISLANDS.MainPresetKey
  local half = WorldConfig.ISLANDS.Presets[presetKey].HalfSize
  local slots = WorldConfig.PLOTS.Slots

  -- Helper to build a reference transform for a slot
  local function T(slotIndex: number)
    return WorldIndex.getIslandTransform(slotIndex, presetKey)
  end

  -- Case: point in correct slot, inside bounds, outside hub -> valid
  do
    local idx = 0
    local t = T(idx)
    -- Move slightly outward along +X in local space (yaw=0 for idx=0)
    local pWorld = TU.toWorld(t, Vector3.new(5, 0, 0))
    local okv, reason = PV.validatePlacement(pWorld, idx, presetKey)
    ok(okv and reason == nil, "valid placement basic")
  end

  -- Exactly on wedge boundary -> valid
  do
    local idx = 0
    local centerYaw = WorldIndex.slotCenterYaw(idx)
    local halfA = math.pi / slots
    local r = WorldConfig.PLOTS.RadialOffset or WorldConfig.HUB.Radius
    local c = WorldConfig.HUB.Center
    local y = WorldConfig.ISLANDS.DefaultHeightY
    -- Put the point at radius r on the boundary angle
    local yaw = centerYaw + halfA
    local pWorld = Vector3.new(c.X + r * math.cos(yaw), y, c.Z + r * math.sin(yaw))
    local okv, reason = PV.validatePlacement(pWorld, idx, presetKey)
    ok(okv and reason == nil, "wedge boundary valid")
  end

  -- Exactly on island edge -> valid
  do
    local idx = 0
    local t = T(idx)
    local pWorld = TU.toWorld(t, Vector3.new(half, 0, 0))
    local okv = PV.validatePlacement(pWorld, idx, presetKey)
    ok(okv, "island edge valid")
  end

  -- Exactly on hub radius -> valid; just inside -> invalid
  do
    local idx = 0
    local r = WorldConfig.PLOTS.RadialOffset or WorldConfig.HUB.Radius
    local c = WorldConfig.HUB.Center
    local y = WorldConfig.ISLANDS.DefaultHeightY
    -- pick the center direction (center yaw)
    local yaw = WorldIndex.slotCenterYaw(idx)
    local pOn = Vector3.new(c.X + r * math.cos(yaw), y, c.Z + r * math.sin(yaw))
    local pIn = Vector3.new(c.X + (r - CFG_EPS/2) * math.cos(yaw), y, c.Z + (r - CFG_EPS/2) * math.sin(yaw))
    local okOn, reasonOn = PV.validatePlacement(pOn, idx, presetKey)
    local okIn, reasonIn = PV.validatePlacement(pIn, idx, presetKey)
    ok(okOn and reasonOn == nil, "on hub radius valid")
    ok((not okIn) and reasonIn == "in_hub_exclusion", "just inside hub invalid")
  end

  -- Wrong slot wedge -> invalid
  do
    local idx = 0
    local wrong = 1
    local tWrong = T(wrong)
    local pWorld = TU.toWorld(tWrong, Vector3.new(0, 0, 0))
    local okv, reason = PV.validatePlacement(pWorld, idx, presetKey)
    ok((not okv) and reason == "wrong_wedge", "wrong wedge invalid")
  end

  -- World->local->world round-trip sanity
  do
    local idx = 5
    local t = T(idx)
    local pLocal = Vector3.new(10, 0, -7)
    local pWorld = TU.toWorld(t, pLocal)
    local okv = PV.validatePlacement(pWorld, idx, presetKey)
    ok(okv, "roundtrip validity")
    local pLocal2 = TU.toLocal(t, pWorld)
    ok(approx(pLocal.X, pLocal2.X, EPS) and approx(pLocal.Z, pLocal2.Z, EPS), "roundtrip coords")
  end

  print(("PlaceValidator tests: %d pass, %d fail"):format(pass, fail))
  return fail == 0
end

