local WorldConfig = require(game.ReplicatedStorage.Config.WorldConfig)
local TU = require(game.ReplicatedStorage.Shared.TransformUtil)

return function()
  local function approx(a: number, b: number, eps: number)
    return math.abs(a - b) <= eps
  end

  local pass, fail = 0, 0
  local function ok(cond: boolean, label: string)
    if cond then
      pass += 1
    else
      fail += 1
      print("[FAIL] " .. label)
    end
  end

  local EPS = 1e-4
  local CFG_EPS = WorldConfig.EPSILON

  -- Round-trip (5 yaws Ã— 10 random points)
  do
    local deg = math.pi / 180
    local yaws = { 0, 15 * deg, 45 * deg, 90 * deg, 180 * deg }
    local Y_MAIN = WorldConfig.ISLANDS.DefaultHeightY
    local presetKey = WorldConfig.ISLANDS.MainPresetKey
    local half = WorldConfig.ISLANDS.Presets[presetKey].HalfSize
    math.randomseed(12345)

    for _, yaw in ipairs(yaws) do
      local T = {
        pos = Vector3.new(100, Y_MAIN, -50),
        yaw = yaw,
        scale = 1,
        heightY = Y_MAIN,
        presetKey = presetKey,
      }
      for i = 1, 10 do
        local x = (math.random() * 2 - 1) * half
        local z = (math.random() * 2 - 1) * half
        local pLocal = Vector3.new(x, 0, z)
        local pWorld = TU.toWorld(T, pLocal)
        local pLocal2 = TU.toLocal(T, pWorld)
        ok(approx(pLocal.X, pLocal2.X, EPS), ("roundtrip X yaw=%g idx=%d"):format(yaw, i))
        ok(approx(pLocal.Z, pLocal2.Z, EPS), ("roundtrip Z yaw=%g idx=%d"):format(yaw, i))
      end
    end
  end

  -- Bounds edges
  do
    local presetKey = "plane_64m"
    local half = WorldConfig.ISLANDS.Presets[presetKey].HalfSize -- 32
    local eps = CFG_EPS
    local inside = {
      Vector3.new( half, 0, 0),
      Vector3.new(-half, 0, 0),
      Vector3.new(0, 0,  half),
      Vector3.new(0, 0, -half),
    }
    for i, p in ipairs(inside) do
      ok(TU.inIslandBounds(p, presetKey), ("bounds inside #%d"):format(i))
    end

    local outside = {
      Vector3.new( half + eps + 1e-6, 0, 0),
      Vector3.new(-half - eps - 1e-6, 0, 0),
      Vector3.new(0, 0,  half + eps + 1e-6),
      Vector3.new(0, 0, -half - eps - 1e-6),
    }
    for i, p in ipairs(outside) do
      ok(not TU.inIslandBounds(p, presetKey), ("bounds outside #%d"):format(i))
    end
  end

  -- Scale round-trip (0.5, 2.0)
  do
    local deg = math.pi / 180
    local yaws = { 0, 45 * deg, 90 * deg }
    local Y_MAIN = WorldConfig.ISLANDS.DefaultHeightY
    local presetKey = WorldConfig.ISLANDS.MainPresetKey
    local half = WorldConfig.ISLANDS.Presets[presetKey].HalfSize
    local scales = { 0.5, 2.0 }
    math.randomseed(54321)

    for _, s in ipairs(scales) do
      for _, yaw in ipairs(yaws) do
        local T = {
          pos = Vector3.new(-25, Y_MAIN, 40),
          yaw = yaw,
          scale = s,
          heightY = Y_MAIN,
          presetKey = presetKey,
        }
        for i = 1, 8 do
          local x = (math.random() * 2 - 1) * half
          local z = (math.random() * 2 - 1) * half
          local pLocal = Vector3.new(x, 0, z)
          local pWorld = TU.toWorld(T, pLocal)
          local pLocal2 = TU.toLocal(T, pWorld)
          ok(approx(pLocal.X, pLocal2.X, EPS), ("scale roundtrip X s=%g yaw=%g #%d"):format(s, yaw, i))
          ok(approx(pLocal.Z, pLocal2.Z, EPS), ("scale roundtrip Z s=%g yaw=%g #%d"):format(s, yaw, i))
        end
      end
    end
  end

  -- Sector wedge
  do
    local slots = WorldConfig.PLOTS.Slots
    local indices = {0, 5, 12}
    local R = 500
    for _, idx in ipairs(indices) do
      local center = TU.slotCenterYaw(idx)
      local insideYaw = center
      local outsideYaw = center + (math.pi / slots) + 0.01
      local cx = WorldConfig.HUB.Center.X
      local cz = WorldConfig.HUB.Center.Z

      local pIn = Vector3.new(cx + R * math.cos(insideYaw), 0, cz + R * math.sin(insideYaw))
      local pOut = Vector3.new(cx + R * math.cos(outsideYaw), 0, cz + R * math.sin(outsideYaw))
      ok(TU.inSectorWedge(pIn, idx), ("sector inside idx=%d"):format(idx))
      ok(not TU.inSectorWedge(pOut, idx), ("sector outside idx=%d"):format(idx))
    end
  end

  -- Wedge boundary inclusive
  do
    local slots = WorldConfig.PLOTS.Slots
    local idx = 3
    local center = TU.slotCenterYaw(idx)
    local halfA = math.pi / slots
    local cx = WorldConfig.HUB.Center.X
    local cz = WorldConfig.HUB.Center.Z
    local R = 600
    local yawA = center + halfA
    local yawB = center - halfA
    local pA = Vector3.new(cx + R * math.cos(yawA), 0, cz + R * math.sin(yawA))
    local pB = Vector3.new(cx + R * math.cos(yawB), 0, cz + R * math.sin(yawB))
    ok(TU.inSectorWedge(pA, idx), "wedge boundary +half")
    ok(TU.inSectorWedge(pB, idx), "wedge boundary -half")
  end

  -- Hub exclusion (exclusive at boundary)
  do
    local hub = WorldConfig.HUB
    local cx, cz, r = hub.Center.X, hub.Center.Z, hub.Radius
    local pIn = Vector3.new(cx + (r - (CFG_EPS/2)), 0, cz)
    local pOn = Vector3.new(cx + r, 0, cz)
    local pOut = Vector3.new(cx + (r + (CFG_EPS/2)), 0, cz)
    ok(TU.inHubExclusion(pIn), "hub exclusion just inside")
    ok(not TU.inHubExclusion(pOn), "hub exclusion exactly at radius is outside")
    ok(not TU.inHubExclusion(pOut), "hub exclusion outside")
  end

  -- Height Y invariant
  do
    local Y_MAIN = WorldConfig.ISLANDS.DefaultHeightY
    local presetKey = WorldConfig.ISLANDS.MainPresetKey
    local T = {
      pos = Vector3.new(100, Y_MAIN, -50),
      yaw = 0,
      scale = 1,
      heightY = Y_MAIN,
      presetKey = presetKey,
    }
    for i = 1, 5 do
      local pLocal = Vector3.new(i * 3, 123, -i * 2)
      local pWorld = TU.toWorld(T, pLocal)
      ok(pWorld.Y == Y_MAIN, ("height invariant #%d"):format(i))
    end
  end

  print(("TransformUtil tests: %d pass, %d fail"):format(pass, fail))
  return fail == 0
end
