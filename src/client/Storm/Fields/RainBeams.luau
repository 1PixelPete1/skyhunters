--!strict
-- RainBeams.luau
-- Manages near-field rain visualization using randomized droplet beams

local Workspace = game:GetService("Workspace")

local sharedRoot = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local StormTypes = require(sharedRoot:WaitForChild("StormTypes"))
local StormConfig = require(sharedRoot:WaitForChild("StormConfig"))

type StormState = StormTypes.StormState
type ConePose = StormTypes.ConePose
type ForbiddenAzimuth = StormTypes.ForbiddenAzimuth
export type PerfConfig = StormTypes.PerfConfig

type RainDrop = {
    beam: Beam,
    host: Part,
    active: boolean,
    pos: Vector3,
    vel: Vector3,
    length: number,
    lifetime: number,
    age: number,
    swayPhase: number,
    swayFreq: number,
    baseTransparency: NumberSequence,
    fadeTransparency: NumberSequence,
    baseWidth0: number,
    baseWidth1: number,
}

local RainBeams = {}
RainBeams.__index = RainBeams

local BASE_ALPHA = 1 - StormConfig.Rings.beam.alpha
local function makeTransparencySequence(headAlpha: number, tailAlpha: number): NumberSequence
    return NumberSequence.new({
        NumberSequenceKeypoint.new(0, math.clamp(headAlpha, 0, 1)),
        NumberSequenceKeypoint.new(0.2, math.clamp(headAlpha, 0, 1)),
        NumberSequenceKeypoint.new(0.8, math.clamp(tailAlpha, 0, 1)),
        NumberSequenceKeypoint.new(1, 1),
    })
end

function RainBeams.new(perfConfig: PerfConfig, perfTier: StormTypes.PerfTier?)
    local self = setmetatable({}, RainBeams)

    self.PerfConfig = perfConfig
    self.PerfTier = perfTier or "HIGH"
    self.Random = Random.new(os.clock())
    self.Container = nil :: Folder?
    self.Drops = table.create(perfConfig.dropsMax)
    self.MaxDrops = perfConfig.dropsMax or 120
    self.SpawnRate = (perfConfig.dropsRatePerSec or 120) * (perfConfig.dropSpawnRateMultiplier or 1)
    self.SpawnAccumulator = self.Random:NextNumber()
    self.LastUpdate = tick()
    self.Time = 0

    self:Initialize()

    return self
end

local function createHost(parent: Instance?): Part
    local host = Instance.new("Part")
    host.Name = "RainDropHost"
    host.Anchored = true
    host.CanCollide = false
    host.CanQuery = false
    host.CanTouch = false
    host.Transparency = 1
    host.Size = Vector3.new(0.2, 0.2, 0.2)
    host.CastShadow = false -- No shadows from rain beams
    host.Parent = parent
    return host
end

function RainBeams:Initialize()
    self.Container = Instance.new("Folder")
    self.Container.Name = "StormRainDrops"
    self.Container.Parent = Workspace

    for i = 1, self.MaxDrops do
        local host = createHost(self.Container)

        local attTop = Instance.new("Attachment")
        attTop.Name = "Top"
        attTop.Parent = host

        local attBottom = Instance.new("Attachment")
        attBottom.Name = "Bottom"
        attBottom.Parent = host

        local baseTransparency = makeTransparencySequence(BASE_ALPHA, math.min(1, BASE_ALPHA + 0.25))
        local fadeTransparency = makeTransparencySequence(math.min(1, BASE_ALPHA + 0.6), 1)

        local beam = Instance.new("Beam")
        beam.Attachment0 = attTop
        beam.Attachment1 = attBottom
        beam.Texture = StormConfig.Rings.beam.texture
        beam.TextureMode = Enum.TextureMode.Wrap
        beam.TextureSpeed = StormConfig.Rings.beam.textureSpeed
        beam.Width0 = StormConfig.Rings.beam.width.min
        beam.Width1 = StormConfig.Rings.beam.width.max
        beam.LightEmission = 0
        beam.LightInfluence = 0
        beam.FaceCamera = false
        beam.Color = ColorSequence.new(Color3.new(0.82, 0.86, 1))
        beam.Transparency = baseTransparency
        beam.Enabled = false
        beam.Parent = self.Container

        self.Drops[i] = {
            beam = beam,
            host = host,
            active = false,
            pos = Vector3.new(0, 0, 0),
            vel = Vector3.new(0, 0, 0),
            length = 8,
            lifetime = 0.6,
            age = 0,
            swayPhase = 0,
            swayFreq = 0.5,
            baseTransparency = baseTransparency,
            fadeTransparency = fadeTransparency,
            baseWidth0 = StormConfig.Rings.beam.width.min,
            baseWidth1 = StormConfig.Rings.beam.width.max,
        }
    end
end

local function randomInRing(rng: Random, radius: number): Vector2
    local theta = rng:NextNumber() * math.pi * 2
    local r = radius * math.sqrt(rng:NextNumber())
    return Vector2.new(math.cos(theta) * r, math.sin(theta) * r)
end

local function perpendicular(v: Vector3): Vector3
    if math.abs(v.Y) < 0.99 then
        return v:Cross(Vector3.new(0, 1, 0)).Unit
    end
    return v:Cross(Vector3.new(1, 0, 0)).Unit
end

function RainBeams:ActivateDrop(drop: RainDrop, cameraCf: CFrame, state: StormState)
    local cfg = StormConfig.RainDrops
    local region = cfg.spawnRegion

    local lateral = randomInRing(self.Random, region.radius)
    local frontOffset = -self.Random:NextNumber() * region.front
    if self.Random:NextNumber() < 0.25 then
        frontOffset = self.Random:NextNumber() * region.back
    end
    local height = self.Random:NextNumber() * region.above

    local localOffset = Vector3.new(lateral.X, height, frontOffset)
    local worldPos = cameraCf.Position + cameraCf:VectorToWorldSpace(localOffset)

    local lenMin, lenMax = cfg.lengthRange[1], cfg.lengthRange[2]
    local spMin, spMax = cfg.speedRange[1], cfg.speedRange[2]
    local lifeMin, lifeMax = cfg.lifetimeRange[1], cfg.lifetimeRange[2]

    local length = lenMin + self.Random:NextNumber() * (lenMax - lenMin)
    local speed = spMin + self.Random:NextNumber() * (spMax - spMin)
    local lifetime = lifeMin + self.Random:NextNumber() * (lifeMax - lifeMin)

    local windDir = state.vector.Magnitude > 0.01 and state.vector.Unit or Vector3.new(0.2, 0, -0.8).Unit
    local vel = Vector3.new(0, -speed, 0) + windDir * (speed * cfg.tiltFactor)

    drop.pos = worldPos
    drop.vel = vel
    drop.length = length
    drop.lifetime = lifetime
    drop.age = self.Random:NextNumber() * (lifetime * 0.2)
    drop.swayPhase = self.Random:NextNumber() * math.pi * 2
    drop.swayFreq = cfg.sway.frequency[1] + self.Random:NextNumber() * (cfg.sway.frequency[2] - cfg.sway.frequency[1])
    drop.active = true
    drop.beam.Enabled = true
    drop.beam.Transparency = drop.baseTransparency
    drop.beam.Width0 = drop.baseWidth0
    drop.beam.Width1 = drop.baseWidth1
end

function RainBeams:DeactivateDrop(drop: RainDrop)
    drop.active = false
    drop.beam.Enabled = false
    drop.beam.Transparency = drop.baseTransparency
    drop.beam.Width0 = drop.baseWidth0
    drop.beam.Width1 = drop.baseWidth1
    drop.age = 0
end

function RainBeams:Update(state: StormState, conePose: ConePose, forbidden: ForbiddenAzimuth, lanternEnabled: boolean, dt: number?)
    if not self.Container then return end

    local camera = Workspace.CurrentCamera
    if not camera then return end

    local now = tick()
    local delta = dt or math.clamp(now - self.LastUpdate, 0, 1/20)
    self.LastUpdate = now
    self.Time += delta

    local intensity = math.clamp(state.intensity, 0, 1)
    local spawnRate = self.SpawnRate * intensity
    self.SpawnAccumulator += spawnRate * delta
    local toSpawn = math.floor(self.SpawnAccumulator)
    if toSpawn > 0 then
        self.SpawnAccumulator -= toSpawn
    end

    for _ = 1, toSpawn do
        for _, drop in ipairs(self.Drops) do
            if not drop.active then
                self:ActivateDrop(drop, camera.CFrame, state)
                break
            end
        end
    end

    local cfg = StormConfig.RainDrops
    local region = cfg.spawnRegion
    local swayAmplitude = cfg.sway.amplitude
    local windDir = state.vector.Magnitude > 0.01 and state.vector.Unit or Vector3.new(0, 0, -1)
    local windPerp = perpendicular(windDir)

    for _, drop in ipairs(self.Drops) do
        if drop.active then
            drop.age += delta
            if drop.age >= drop.lifetime then
                self:DeactivateDrop(drop)
                continue
            end

            drop.pos += drop.vel * delta

            local localPos = camera.CFrame:PointToObjectSpace(drop.pos)
            if localPos.Y < -region.belowCull or math.abs(localPos.X) > region.radius * 1.25 or localPos.Z > region.front * 1.4 then
                self:DeactivateDrop(drop)
                continue
            end

            local fadeFactor = 1
            if lanternEnabled then
                local angleDeg = math.deg(math.atan2(localPos.Z, localPos.X))
                local minDeg, maxDeg = forbidden.minDeg, forbidden.maxDeg
                local inWedge
                if minDeg == maxDeg then
                    inWedge = false
                elseif minDeg > maxDeg then
                    inWedge = angleDeg >= minDeg or angleDeg <= maxDeg
                else
                    inWedge = angleDeg >= minDeg and angleDeg <= maxDeg
                end
                if inWedge then
                    fadeFactor = 0.25
                end
            end

            local sway = math.sin(self.Time * drop.swayFreq + drop.swayPhase) * swayAmplitude
            local swayOffset = windPerp * sway
            local topPos = drop.pos + swayOffset
            local bottomPos = topPos - drop.vel.Unit * drop.length

            drop.host.CFrame = CFrame.new(topPos)
            local relativeBottom = drop.host.CFrame:PointToObjectSpace(bottomPos)
            if drop.beam.Attachment0 and drop.beam.Attachment1 then
                drop.beam.Attachment0.Position = Vector3.new(0, 0, 0)
                drop.beam.Attachment1.Position = relativeBottom

                if fadeFactor < 1 then
                    drop.beam.Transparency = drop.fadeTransparency
                    drop.beam.Width0 = drop.baseWidth0 * 0.65
                    drop.beam.Width1 = drop.baseWidth1 * 0.65
                else
                    drop.beam.Transparency = drop.baseTransparency
                    drop.beam.Width0 = drop.baseWidth0
                    drop.beam.Width1 = drop.baseWidth1
                end

                drop.beam.Enabled = true
            end
        end
    end
end

function RainBeams:Cleanup()
    if self.Container then
        self.Container:Destroy()
        self.Container = nil
    end
    table.clear(self.Drops)
end

return RainBeams
