-- Apply Core (pure-ish): validates and prepares a placement plan

local WorldIndex = require(game.ReplicatedStorage.Shared.WorldIndex)
local TU = require(game.ReplicatedStorage.Shared.TransformUtil)
local PlacementCore = require(game.ReplicatedStorage.Shared.PlacementCore)
local Policy = require(game.ReplicatedStorage.Shared.PlacementPolicy)

export type ApplyRequest = {
  requestId: string,
  position: Vector3,
  slotIndex: number,
  presetKey: string,
  styleId: string?,
  previewHash: string?,
}

export type ApplyPlan = {
  normalizedSlot: number,
  transform: TU.Transform,
  localPoint: Vector3,
  placementKey: string,
}

local ApplyCore = {}

local function isString(v: any): boolean
  return type(v) == "string"
end

local function normalizeSlot(slotIndex: number): number
  local slots = WorldIndex.getSlotCount()
  return ((math.floor(slotIndex) % slots) + slots) % slots
end

function ApplyCore.plan(player: Player, req: ApplyRequest): { ok: boolean, reason: string? , plan: ApplyPlan? }
  if type(req) ~= "table" or not isString(req.requestId) then
    return { ok = false, reason = "bad_params" }
  end

  -- Reuse placement validation
  local vres = PlacementCore.validate({ position = req.position, slotIndex = req.slotIndex, presetKey = req.presetKey })
  if not vres.ok then
    return { ok = false, reason = "validation_failed:" .. tostring(vres.reason or "bad_params") }
  end

  local normSlot = normalizeSlot(req.slotIndex)
  local T = WorldIndex.getIslandTransform(normSlot, req.presetKey)
  local localP = TU.toLocal(T, req.position)
  -- Quantize using policy-op + precision to avoid drift
  local qx = Policy.quantizeScalar(localP.X)
  local qz = Policy.quantizeScalar(localP.Z)
  local worldV = Policy.getWorldVersion()
  local presetRev = Policy.getPresetRevision(req.presetKey)
  local key = string.format("%s|%d|%s|r%d|%.3f|%.3f|u%d", worldV, normSlot, tostring(req.presetKey), presetRev, qx, qz, player.UserId)

  return { ok = true, plan = {
    normalizedSlot = normSlot,
    transform = T,
    localPoint = localP,
    placementKey = key,
  } }
end

-- Server-side helper: spawn a basic model for preset at cframe
function ApplyCore.place(presetKey: string, cframe: CFrame): Instance?
  -- Minimal placeholder implementation until content pipeline is wired
  local model = Instance.new("Model")
  model.Name = "Lantern_" .. tostring(presetKey)

  local part = Instance.new("Part")
  part.Name = "Body"
  part.Anchored = true
  part.CanCollide = true
  part.Size = Vector3.new(1, 2, 1)
  part.CFrame = cframe
  part.Material = Enum.Material.Metal
  part.Color = Color3.fromRGB(255, 200, 50)
  part.Parent = model

  model.PrimaryPart = part
  -- Parent is assigned by caller for tidy hierarchy control
  return model
end

return ApplyCore
