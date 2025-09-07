--!strict
-- Apply Gateway: authoritative idempotent spawner path for base lanterns

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ApplyCore = require(ReplicatedStorage.Shared.ApplyCore)
local Authorizer = require(ReplicatedStorage.Shared.Authorizer)
local Policy = require(ReplicatedStorage.Shared.PlacementPolicy)

local ApplyGateway = {}
local _health = { bound = false, reason = nil :: string? }

type ApplyCounters = {
  apply_ok: number,
  apply_dedup: number,
  validation_failed: number,
  bad_params: number,
}

local counters: ApplyCounters = {
  apply_ok = 0,
  apply_dedup = 0,
  validation_failed = 0,
  bad_params = 0,
}

local byKey: { [string]: { placementId: string, ownerUserId: number, slotIndex: number, presetKey: string, position: Vector3, requestId: string, createdAt: number } } = {}
local inflight: { [string]: number } = {}

type ReqCacheEntry = { res: any, at: number }
local byUserReq: { [number]: { order: { string }, map: { [string]: ReqCacheEntry } } } = {}

local APPLY_RATE_WINDOW = 1.0
local APPLY_RATE_LIMIT = 2
local REQ_TTL = 300.0 -- seconds
local REQ_MAX = 100 -- per player

local function now()
  return os.clock()
end

local function makeId(userId: number): string
  return string.format("plc_%d_%d", userId, math.floor(now() * 1000))
end

local function parseReq(a: any)
  if type(a) ~= "table" then return false, nil end
  if type(a.requestId) ~= "string" or typeof(a.position) ~= "Vector3" or type(a.slotIndex) ~= "number" or type(a.presetKey) ~= "string" then
    return false, nil
  end
  return true, a
end

local function trackApplyRate(userId: number)
  local key = -userId -- reuse recent store per player via separate structure? keep simple local table
  -- Use byUserReq[userId] as anchor for rate tracking with a small separate field
  local bucket = (byUserReq[userId] or { order = {}, map = {}, _rate = {} })
  byUserReq[userId] = bucket
  local list = bucket._rate :: any
  list = list or {}
  bucket._rate = list
  local t = os.clock()
  local j = 1
  for i = 1, #list do
    if t - list[i] <= APPLY_RATE_WINDOW then
      list[j] = list[i]
      j += 1
    end
  end
  for k = #list, j, -1 do list[k] = nil end
  table.insert(list, t)
  if #list > APPLY_RATE_LIMIT then
    warn(("[ApplyGateway] rate soft-cap exceeded user=%d count=%d"):format(userId, #list))
  end
end

local function pruneReqCache(userId: number)
  local bucket = byUserReq[userId]
  if not bucket then return end
  local nowt = os.clock()
  local order = bucket.order
  local map = bucket.map
  local i = 1
  while i <= #order do
    local id = order[i]
    local ent = map[id]
    if not ent or (nowt - ent.at) > REQ_TTL then
      map[id] = nil
      table.remove(order, i)
    else
      i += 1
    end
  end
  while #order > REQ_MAX do
    local old = table.remove(order, 1)
    map[old] = nil
  end
end

-- latency tracking for observability
local LAT_WIN = 300.0
local latencies: { { t: number, d: number } } = {}
local function noteLatency(d: number)
  local t = os.clock()
  table.insert(latencies, { t = t, d = d })
  -- prune
  local i = 1
  while i <= #latencies do
    if t - latencies[i].t > LAT_WIN then
      table.remove(latencies, i)
    else
      break
    end
  end
end
local function p95()
  if #latencies == 0 then return 0 end
  local arr = {}
  for i = 1, #latencies do arr[i] = latencies[i].d end
  table.sort(arr)
  local idx = math.max(1, math.floor(0.95 * #arr + 0.5))
  return arr[idx]
end

function ApplyGateway.Bind(services)
  local Net = services and services.Net or nil
  if Net == nil then
    _health.bound = false
    _health.reason = "missing_dependency"
    warn("[ApplyGateway] Missing dependency Net; skipping bind")
    return
  end
  local ok, rem = pcall(function()
    return Net:GetFunction("RF_ApplyBaseLantern")
  end)
  if not ok or rem == nil then
    _health.bound = false
    _health.reason = "missing_dependency"
    warn("[ApplyGateway] Missing remote RF_ApplyBaseLantern; skipping bind")
    return
  end
  rem.OnServerInvoke = function(player: Player, req: any)
    local t0 = os.clock()
    local okShape, areq = parseReq(req)
    if not okShape then
      counters.bad_params += 1
      return { ok = false, reason = "bad_params" }
    end

    trackApplyRate(player.UserId)
    pruneReqCache(player.UserId)

    -- Request idempotency
    local bucket = byUserReq[player.UserId]
    if not bucket then bucket = { order = {}, map = {} }; byUserReq[player.UserId] = bucket end
    local cached = bucket.map[areq.requestId]
    if cached then
      counters.apply_dedup += 1
      if Policy.debugLoggingEnabled() then
        print("[ApplyGateway] request dedup", player.Name, areq.requestId)
      end
      noteLatency(os.clock() - t0)
      return cached.res
    end

    -- Plan & validate
    local planRes = ApplyCore.plan(player, areq)
    if not planRes.ok then
      counters.validation_failed += 1
      local res = { ok = false, reason = planRes.reason }
      table.insert(bucket.order, areq.requestId)
      bucket.map[areq.requestId] = { res = res, at = os.clock() }
      noteLatency(os.clock() - t0)
      return res
    end
    local plan = planRes.plan :: any

    -- Single-flight per placementKey (best effort)
    if inflight[plan.placementKey] then
      counters.apply_dedup += 1
      local existing = byKey[plan.placementKey]
      if existing then
        local res = { ok = false, reason = "already_exists", placementId = existing.placementId }
        table.insert(bucket.order, areq.requestId)
        bucket.map[areq.requestId] = { res = res, at = os.clock() }
        noteLatency(os.clock() - t0)
        return res
      end
      -- In-flight but not recorded yet; suggest retry without charging
      local res = { ok = false, reason = "already_exists" }
      table.insert(bucket.order, areq.requestId)
      bucket.map[areq.requestId] = { res = res, at = os.clock() }
      noteLatency(os.clock() - t0)
      return res
    end
    inflight[plan.placementKey] = os.clock()

    -- Authorize
    local auth = Authorizer.check(player, areq)
    if not auth.ok then
      local res = { ok = false, reason = auth.reason or "not_authorized" }
      table.insert(bucket.order, areq.requestId)
      bucket.map[areq.requestId] = { res = res, at = os.clock() }
      inflight[plan.placementKey] = nil
      noteLatency(os.clock() - t0)
      return res
    end

    -- Dedupe by placement key
    local existing = byKey[plan.placementKey]
    if existing then
      counters.apply_dedup += 1
      local res = { ok = false, reason = "already_exists", placementId = existing.placementId }
      table.insert(bucket.order, areq.requestId)
      bucket.map[areq.requestId] = { res = res, at = os.clock() }
      inflight[plan.placementKey] = nil
      noteLatency(os.clock() - t0)
      return res
    end

    -- Apply (upsert in-memory world record)
    local pid = makeId(player.UserId)
    byKey[plan.placementKey] = {
      placementId = pid,
      ownerUserId = player.UserId,
      slotIndex = plan.normalizedSlot,
      presetKey = areq.presetKey,
      position = areq.position,
      requestId = areq.requestId,
      createdAt = now(),
    }

    local res = { ok = true, placementId = pid, state = { slotIndex = plan.normalizedSlot, presetKey = areq.presetKey } }
    counters.apply_ok += 1
    table.insert(bucket.order, areq.requestId)
    bucket.map[areq.requestId] = { res = res, at = os.clock() }

    if Policy.debugLoggingEnabled() then
      print(("[ApplyGateway] ok player=%s key=%s id=%s"):format(player.Name, plan.placementKey, pid))
    end
    inflight[plan.placementKey] = nil
    noteLatency(os.clock() - t0)
    return res
  end
  _health.bound = true
  _health.reason = nil
return { bound = _health.bound, reason = _health.reason }
end

function ApplyGateway.GetCounters()
  local snap = {
    apply_ok = counters.apply_ok,
    apply_dedup = counters.apply_dedup,
    validation_failed = counters.validation_failed,
    bad_params = counters.bad_params,
    p95_latency_sec = p95(),
    window_sec = 300,
    samples = #latencies,
  }
  return snap
end

function ApplyGateway.GetHealth()
  return { bound = _health.bound, reason = _health.reason }
end

return ApplyGateway
