local WorldConfig = require(game.ReplicatedStorage.Config.WorldConfig)
local WorldIndex = require(game.ReplicatedStorage.Shared.WorldIndex)
local TU = require(game.ReplicatedStorage.Shared.TransformUtil)
local Core = require(game.ReplicatedStorage.Shared.PlacementCore)

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

  -- Happy path: correct wedge, in-bounds, outside hub -> ok=true
  do
    local idx = 0
    local T = WorldIndex.getIslandTransform(idx, presetKey)
    local pWorld = TU.toWorld(T, Vector3.new(half*0.5, 0, 0))
    local res = Core.validate({ position = pWorld, slotIndex = idx, presetKey = presetKey })
    ok(res.ok and res.reason == nil, "happy path ok")
  end

  -- Wedge boundary: exactly at Â±half-angle -> ok=true
  do
    local idx = 2
    local center = WorldIndex.slotCenterYaw(idx)
    local halfA = math.pi / slots
    local r = (WorldConfig.PLOTS.RadialOffset or WorldConfig.HUB.Radius) + 10
    local c = WorldConfig.HUB.Center
    local y = WorldConfig.ISLANDS.DefaultHeightY
    local p1 = Vector3.new(c.X + r * math.cos(center + halfA), y, c.Z + r * math.sin(center + halfA))
    local p2 = Vector3.new(c.X + r * math.cos(center - halfA), y, c.Z + r * math.sin(center - halfA))
    ok(Core.validate({ position = p1, slotIndex = idx, presetKey = presetKey }).ok, "wedge +half ok")
    ok(Core.validate({ position = p2, slotIndex = idx, presetKey = presetKey }).ok, "wedge -half ok")
  end

  -- Island boundary: exactly on edge -> ok=true
  do
    local idx = 0
    local T = WorldIndex.getIslandTransform(idx, presetKey)
    local pWorld = TU.toWorld(T, Vector3.new(half, 0, 0))
    ok(Core.validate({ position = pWorld, slotIndex = idx, presetKey = presetKey }).ok, "island edge ok")
  end

  -- Hub boundary: exactly at radius -> ok=true; just inside -> in_hub_exclusion
  do
    local idx = 0
    local center = WorldIndex.slotCenterYaw(idx)
    local r = WorldConfig.PLOTS.RadialOffset or WorldConfig.HUB.Radius
    local c = WorldConfig.HUB.Center
    local y = WorldConfig.ISLANDS.DefaultHeightY
    local pOn = Vector3.new(c.X + r * math.cos(center), y, c.Z + r * math.sin(center))
    local pIn = Vector3.new(c.X + (r - CFG_EPS/2) * math.cos(center), y, c.Z + (r - CFG_EPS/2) * math.sin(center))
    local resOn = Core.validate({ position = pOn, slotIndex = idx, presetKey = presetKey })
    local resIn = Core.validate({ position = pIn, slotIndex = idx, presetKey = presetKey })
    ok(resOn.ok, "hub boundary ok")
    ok((not resIn.ok) and resIn.reason == "in_hub_exclusion", "hub just inside invalid")
  end

  -- Wrong wedge -> wrong_wedge
  do
    local idx = 0
    local wrong = 1
    local Tw = WorldIndex.getIslandTransform(wrong, presetKey)
    local pWorld = TU.toWorld(Tw, Vector3.new(0, 0, 0))
    local res = Core.validate({ position = pWorld, slotIndex = idx, presetKey = presetKey })
    ok((not res.ok) and res.reason == "wrong_wedge", "wrong wedge invalid")
  end

  -- Bad params
  do
    local res1 = Core.validate({})
    ok((not res1.ok) and res1.reason == "bad_params", "bad params empty")
    local res2 = Core.validate({ position = Vector3.new(), slotIndex = "0", presetKey = presetKey })
    ok((not res2.ok) and res2.reason == "bad_params", "bad params wrong types")
    local res3 = Core.validate({ position = Vector3.new(), slotIndex = 0, presetKey = "nope" })
    ok((not res3.ok) and res3.reason == "bad_params", "bad params unknown preset")
  end

  -- Round-trip sanity: world->local->world preserves classification
  do
    local idx = 5
    local T = WorldIndex.getIslandTransform(idx, presetKey)
    local pWorld = TU.toWorld(T, Vector3.new(10, 0, -7))
    local res = Core.validate({ position = pWorld, slotIndex = idx, presetKey = presetKey })
    ok(res.ok, "pre roundtrip ok")
    local pLocal = TU.toLocal(T, pWorld)
    local pWorld2 = TU.toWorld(T, pLocal)
    local res2 = Core.validate({ position = pWorld2, slotIndex = idx, presetKey = presetKey })
    ok(res2.ok, "post roundtrip ok")
    ok(approx(pWorld.X, pWorld2.X, EPS) and approx(pWorld.Z, pWorld2.Z, EPS), "roundtrip same point")
  end

  print(("PlacementCore tests: %d pass, %d fail"):format(pass, fail))
  return fail == 0
end

