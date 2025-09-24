--!strict
-- GroundSplashes.luau
-- Handles splash particles that trigger where rain meets the ground near the player

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local sharedRoot = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local StormTypes = require(sharedRoot:WaitForChild("StormTypes"))
local StormConfig = require(sharedRoot:WaitForChild("StormConfig"))

type StormState = StormTypes.StormState
type ConePose = StormTypes.ConePose
type ForbiddenAzimuth = StormTypes.ForbiddenAzimuth
type PerfConfig = StormTypes.PerfConfig

type SplashEntry = {
    part: Part,
    emitter: ParticleEmitter,
    active: boolean,
    startedAt: number,
}

local GroundSplashes = {}
GroundSplashes.__index = GroundSplashes

function GroundSplashes.new(perfConfig: PerfConfig, perfTier: StormTypes.PerfTier?)
    local self = setmetatable({}, GroundSplashes)

    self.PerfConfig = perfConfig
    self.PerfTier = perfTier or "HIGH"
    self.Enabled = perfConfig.splashes and (StormConfig.Splashes.ratePerSec[self.PerfTier] or 0) > 0
    self.RatePerSec = StormConfig.Splashes.ratePerSec[self.PerfTier] or 0
    self.Container = nil :: Folder?
    self.SplashPool = {} :: { SplashEntry }
    self.LastSpawn = 0
    self.LastUpdate = tick()
    self.Random = Random.new(os.clock())
    self.RaycastParams = RaycastParams.new()
    self.RaycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    self.RaycastParams.IgnoreWater = false

    self:Initialize()

    return self
end

local function createSplashPart(parent: Instance): SplashEntry
    local part = Instance.new("Part")
    part.Name = "SplashEmitter"
    part.Anchored = true
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.Transparency = 1
    part.Size = Vector3.new(0.6, 0.2, 0.6)
    part.Parent = parent

    local attachment = Instance.new("Attachment")
    attachment.Parent = part

    local emitter = Instance.new("ParticleEmitter")
    emitter.Texture = "rbxasset://textures/particles/splash_main.dds"
    emitter.Lifetime = NumberRange.new(0.18, StormConfig.Splashes.lifetime)
    emitter.Speed = NumberRange.new(3, 7)
    emitter.SpreadAngle = Vector2.new(40, 40)
    emitter.EmissionDirection = Enum.NormalId.Top
    emitter.LightEmission = 0
    emitter.LightInfluence = 0
    emitter.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.45),
        NumberSequenceKeypoint.new(0.5, 0.7),
        NumberSequenceKeypoint.new(1, 1),
    })
    emitter.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.25),
        NumberSequenceKeypoint.new(0.4, 0.55),
        NumberSequenceKeypoint.new(1, 0.1),
    })
    emitter.Rate = 0
    emitter.Enabled = false
    emitter.Parent = attachment

    return {
        part = part,
        emitter = emitter,
        active = false,
        startedAt = 0,
    }
end

function GroundSplashes:Initialize()
    if not self.Enabled then
        return
    end

    self.Container = Instance.new("Folder")
    self.Container.Name = "StormGroundSplashes"
    self.Container.Parent = Workspace

    for _ = 1, 18 do
        table.insert(self.SplashPool, createSplashPart(self.Container))
    end
end

function GroundSplashes:GetAvailableSplash(): SplashEntry?
    for _, entry in ipairs(self.SplashPool) do
        if not entry.active then
            return entry
        end
    end
    return nil
end

function GroundSplashes:SpawnSplash(position: Vector3, intensity: number)
    local entry = self:GetAvailableSplash()
    if not entry then
        return
    end

    entry.part.CFrame = CFrame.new(position)
    entry.emitter.Enabled = true
    entry.emitter.Rate = math.clamp(intensity, 0.3, 1) * 140
    entry.active = true
    entry.startedAt = tick()
end

function GroundSplashes:Update(state: StormState, conePose: ConePose, forbidden: ForbiddenAzimuth, lanternEnabled: boolean, dt: number?)
    if not self.Enabled or not self.Container then
        return
    end

    local player = Players.LocalPlayer
    if not player or not player.Character then
        return
    end

    local root = player.Character:FindFirstChild("HumanoidRootPart")
    if not root then
        return
    end

    self.RaycastParams.FilterDescendantsInstances = { player.Character }

    local now = tick()
    local delta = dt or math.clamp(now - self.LastUpdate, 0, 1/20)
    self.LastUpdate = now

    for _, entry in ipairs(self.SplashPool) do
        if entry.active and now - entry.startedAt >= StormConfig.Splashes.lifetime then
            entry.emitter.Enabled = false
            entry.emitter.Rate = 0
            entry.active = false
        end
    end

    if state.intensity <= 0 then
        return
    end

    local interval = 1 / (self.RatePerSec * math.max(state.intensity, 0.1))
    if now - self.LastSpawn < interval then
        return
    end

    self.LastSpawn = now

    local cfg = StormConfig.Splashes
    local angle = self.Random:NextNumber() * math.pi * 2
    local distance = cfg.ringInner + self.Random:NextNumber() * (cfg.ringOuter - cfg.ringInner)
    local offset = Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)

    local rayOrigin = root.Position + offset + Vector3.new(0, 6, 0)
    local raycast = Workspace:Raycast(rayOrigin, Vector3.new(0, -16, 0), self.RaycastParams)
    if not raycast then
        return
    end

    local hitPos = raycast.Position + Vector3.new(0, 0.05, 0)

    if lanternEnabled then
        local flat = Vector2.new(hitPos.X - root.Position.X, hitPos.Z - root.Position.Z)
        local dist = flat.Magnitude
        if dist < conePose.innerClear then
            return
        end
        if dist < conePose.innerSoft then
            local span = math.max(conePose.innerSoft - conePose.innerClear, 0.01)
            local t = (dist - conePose.innerClear) / span
            if self.Random:NextNumber() > t then
                return
            end
        end
    end

    self:SpawnSplash(hitPos, state.intensity)
end

function GroundSplashes:Cleanup()
    if self.Container then
        self.Container:Destroy()
        self.Container = nil
    end
    self.SplashPool = {}
end

return GroundSplashes





