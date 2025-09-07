--!strict
-- Placement Gateway: thin server entry that answers placement validation
-- Binds to RF_PlaceBaseLantern without changing existing placement behavior.
-- If payload matches validation shape, returns envelope { ok, reason? }.
-- Otherwise, forwards to LanternService.PlaceBaseLantern(player, pondId, style).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlacementCore = require(ReplicatedStorage.Shared.PlacementCore)
local Policy = require(ReplicatedStorage.Shared.PlacementPolicy)

local PlacementGateway = {}
local _health = { bound = false, reason = nil :: string? }

type Counters = {
  ok: number,
  bad_params: number,
  in_hub_exclusion: number,
  wrong_wedge: number,
  out_of_bounds: number,
}

local counters: Counters = {
  ok = 0,
  bad_params = 0,
  in_hub_exclusion = 0,
  wrong_wedge = 0,
  out_of_bounds = 0,
}

local RATE_WINDOW = 1.0
local RATE_LIMIT = 5
local recent: { [number]: { number } } = {}

local function now()
  return os.clock()
end

local function trackRate(userId: number)
  local list = recent[userId]
  if not list then
    list = {}
    recent[userId] = list
  end
  local t = now()
  -- prune
  local j = 1
  for i = 1, #list do
    if t - list[i] <= RATE_WINDOW then
      list[j] = list[i]
      j += 1
    end
  end
  for k = #list, j, -1 do list[k] = nil end
  table.insert(list, t)
  if #list > RATE_LIMIT then
    warn(("[PlacementGateway] rate soft-cap exceeded user=%d count=%d"):format(userId, #list))
  end
end

local function parseRequest(a: any, b: any, c: any)
  local isTable = type(a) == "table"
  local isTriple = typeof(a) == "Vector3" and type(b) == "number" and type(c) == "string"
  if isTable and (b ~= nil or c ~= nil) then
    return false, nil, "bad_params"
  end
  if isTable then
    local req = a
    if typeof(req.position) == "Vector3" and type(req.slotIndex) == "number" and type(req.presetKey) == "string" then
      return true, req, nil
    end
    return false, nil, "bad_params"
  end
  if isTriple then
    return true, { position = a :: Vector3, slotIndex = b :: number, presetKey = c :: string }, nil
  end
  return false, nil, "bad_params"
end

function PlacementGateway.Bind(services)
  local Net = services and services.Net or nil
  if Net == nil then
    _health.bound = false
    _health.reason = "missing_dependency"
    warn("[PlacementGateway] Missing dependency Net; skipping bind")
    return _health
  end
  -- Verify remote exists by name defensively
  local okRem, rem = pcall(function()
    return Net:GetFunction("RF_PlaceBaseLantern")
  end)
  if not okRem or rem == nil then
    _health.bound = false
    _health.reason = "missing_dependency"
    warn("[PlacementGateway] Missing remote RF_PlaceBaseLantern; skipping bind")
    return _health
  end
  local LanternService = services and services.LanternService or nil
  rem.OnServerInvoke = function(player: Player, a, b, c)
    local isVal, req, parseErr = parseRequest(a, b, c)
    if isVal then
      trackRate(player.UserId)
      local res = PlacementCore.validate(req)
      if res.ok then counters.ok += 1 else
        local r = res.reason or "bad_params"
        counters[r] = (counters[r] or 0) + 1
      end
      if Policy.debugLoggingEnabled() then
        print(("[PlacementGateway] player=%s slot=%s preset=%s ok=%s reason=%s"):format(player.Name, tostring(req.slotIndex), tostring(req.presetKey), tostring(res.ok), tostring(res.reason)))
      end
      return res
    end
    if parseErr then
      counters.bad_params += 1
      if Policy.debugLoggingEnabled() then
        warn(("[PlacementGateway] bad_params parse player=%s"):format(player.Name))
      end
      return { ok = false, reason = "bad_params" }
    end
    if LanternService and LanternService.PlaceBaseLantern then
      return LanternService.PlaceBaseLantern(player, a, b)
    end
    return { ok = false, err = "UNBOUND" }
  end
  _health.bound = true
  _health.reason = nil
  return { bound = _health.bound, reason = _health.reason }
end

function PlacementGateway.GetCounters()
  local snap: Counters = {
    ok = counters.ok,
    bad_params = counters.bad_params,
    in_hub_exclusion = counters.in_hub_exclusion,
    wrong_wedge = counters.wrong_wedge,
    out_of_bounds = counters.out_of_bounds,
  }
  return snap
end

function PlacementGateway.GetHealth()
  return { bound = _health.bound, reason = _health.reason }
end

return PlacementGateway