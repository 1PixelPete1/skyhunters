--!strict
-- RainShells.luau
-- Drifting mid/far rain curtains that surround the player with parallax motion
-- Enhanced to prevent spawning below screen edge

local Workspace = game:GetService("Workspace")

local sharedRoot = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local StormTypes = require(sharedRoot:WaitForChild("StormTypes"))
local StormConfig = require(sharedRoot:WaitForChild("StormConfig"))

type StormState = StormTypes.StormState
type ConePose = StormTypes.ConePose
type ForbiddenAzimuth = StormTypes.ForbiddenAzimuth
export type PerfConfig = StormTypes.PerfConfig

type ShellSegment = {
    part: Part,
    emitter: ParticleEmitter,
    attachment: Attachment,
    baseAngleDeg: number,
    wobblePhase: number,
    wobbleSpeed: number,
    radius: number,
}

local RainShells = {}
RainShells.__index = RainShells

function RainShells.new(perfConfig: PerfConfig, perfTier: StormTypes.PerfTier?)
    local self = setmetatable({}, RainShells)

    self.PerfConfig = perfConfig
    self.PerfTier = perfTier or "HIGH"
    self.Container = nil :: Folder?
    self.ShellSegments = {} :: { [number]: { ShellSegment } }
    self.LastUpdate = tick()
    self.Time = 0
    self.Random = Random.new(os.clock())

    self:Initialize()

    return self
end

function RainShells:Initialize()
    self.Container = Instance.new("Folder")
    self.Container.Name = "StormRainShells"
    self.Container.Parent = Workspace

    local shellCount = math.min(self.PerfConfig.shells, #StormConfig.Shells.radii)
    for shellIdx = 1, shellCount do
        local radius = StormConfig.Shells.radii[shellIdx]
        local segCount = self.PerfConfig.shellSegs
        local segments = {}
        for segIdx = 1, segCount do
            local segment = self:CreateShellSegment(radius, segIdx, segCount, shellIdx)
            table.insert(segments, segment)
        end
        self.ShellSegments[shellIdx] = segments
    end
end

function RainShells:CreateShellSegment(radius: number, segmentIndex: number, totalSegments: number, shellIndex: number): ShellSegment
    local part = Instance.new("Part")
    part.Name = string.format("RainShell_%d_%d", shellIndex, segmentIndex)
    part.Anchored = true
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.Transparency = 1
    part.Size = Vector3.new(0.5, 0.5, 0.5)
    part.CastShadow = false -- FIXED: No shadows from rain emitters
    part.Parent = self.Container

    local attachment = Instance.new("Attachment")
    attachment.Parent = part

    local emitter = Instance.new("ParticleEmitter")
    emitter.Texture = StormConfig.Shells.particleTexture
    emitter.Lifetime = StormConfig.Shells.particleLifetime
    emitter.Speed = StormConfig.Shells.particleSpeed
    emitter.SpreadAngle = StormConfig.Shells.particleSpread
    emitter.EmissionDirection = Enum.NormalId.Bottom
    emitter.Rate = 0
    emitter.Enabled = false
    -- FIXED: Reduce random rotation so particles align better with wind
    emitter.RotSpeed = NumberRange.new(-20, 20) -- Much less rotation
    emitter.Drag = 1.2
    emitter.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.55),
        NumberSequenceKeypoint.new(1, 1),
    })
    -- FIXED: Add size variation and orientation
    emitter.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.3),
        NumberSequenceKeypoint.new(0.5, 0.5),
        NumberSequenceKeypoint.new(1, 0.2),
    })
    emitter.Parent = attachment

    local segmentAngle = ((segmentIndex - 0.5) / totalSegments) * 360
    local wobblePhase = self.Random:NextNumber() * math.pi * 2
    local wobbleSpeed = 0.4 + self.Random:NextNumber() * 0.6

    return {
        part = part,
        emitter = emitter,
        attachment = attachment,
        baseAngleDeg = segmentAngle,
        wobblePhase = wobblePhase,
        wobbleSpeed = wobbleSpeed,
        radius = radius,
    }
end

local function isAngleInForbidden(angleDeg: number, forbidden: ForbiddenAzimuth, pad: number): boolean
    local minDeg = (forbidden.minDeg - pad) % 360
    local maxDeg = (forbidden.maxDeg + pad) % 360
    if minDeg == maxDeg then
        return false
    end
    if minDeg > maxDeg then
        return angleDeg >= minDeg or angleDeg <= maxDeg
    end
    return angleDeg >= minDeg and angleDeg <= maxDeg
end

local function makeTransparency(fadeFactor: number): NumberSequence
    local head = math.clamp(0.45 + (1 - fadeFactor) * 0.35, 0, 1)
    local tail = math.clamp(0.85 + (1 - fadeFactor) * 0.15, 0, 1)
    return NumberSequence.new({
        NumberSequenceKeypoint.new(0, head),
        NumberSequenceKeypoint.new(0.8, tail),
        NumberSequenceKeypoint.new(1, 1),
    })
end

function RainShells:Update(state: StormState, conePose: ConePose, forbidden: ForbiddenAzimuth, lanternEnabled: boolean, dt: number?)
    if not self.Container then return end

    local camera = Workspace.CurrentCamera
    if not camera then return end

    local now = tick()
    local delta = dt or math.clamp(now - self.LastUpdate, 0, 1/15)
    self.LastUpdate = now
    self.Time += delta

    local intensity = math.clamp(state.intensity, 0, 1)
    if intensity <= 0 then
        for _, segments in pairs(self.ShellSegments) do
            for _, segment in ipairs(segments) do
                segment.emitter.Enabled = false
                segment.emitter.Rate = 0
            end
        end
        return
    end

    local cameraCf = camera.CFrame
    local cameraPos = cameraCf.Position
    local forward = cameraCf.LookVector
    local right = cameraCf.RightVector
    local up = cameraCf.UpVector

    local shellConfig = StormConfig.Shells
    local windDir = state.vector.Magnitude > 0.01 and state.vector.Unit or forward
    
    -- ENHANCED: Increase camera up offset to ensure rain starts above screen
    -- Using viewport size to estimate screen bounds
    local viewportSize = camera.ViewportSize
    local fov = math.rad(camera.FieldOfView)
    local distance = StormConfig.Shells.radii[1] or 28
    local screenHeight = 2 * distance * math.tan(fov / 2)
    local safeUpOffset = math.max(18, screenHeight * 0.6) -- Ensure rain starts well above screen
    
    local upOffset = up * safeUpOffset
    local forwardOffset = forward * (shellConfig.forwardOffset or 0)
    local ringCenter = cameraPos + upOffset + forwardOffset

    for shellIdx, segments in pairs(self.ShellSegments) do
        local shellRate = StormConfig.Shells.rates[shellIdx] or 40
        local radius = StormConfig.Shells.radii[shellIdx] or 24
        for _, segment in ipairs(segments) do
            local dynamicAngle = segment.baseAngleDeg + math.sin(self.Time * segment.wobbleSpeed + segment.wobblePhase) * 8

            local fadeFactor = 1
            if lanternEnabled and isAngleInForbidden(dynamicAngle % 360, forbidden, StormConfig.Shells.wedgePadDeg) then
                fadeFactor = 0.25
            end

            fadeFactor *= intensity

            local emitter = segment.emitter
            if fadeFactor <= 0.05 then
                emitter.Enabled = false
                emitter.Rate = 0
            else
                local angleRad = math.rad(dynamicAngle)
                local radialDir = (right * math.cos(angleRad)) + (forward * math.sin(angleRad))
                local basePos = ringCenter + radialDir * radius

                local drift = windDir * (3.5 + shellIdx * 1.2)
                local lateralDrift = drift - up * drift:Dot(up)
                basePos += lateralDrift

                -- ENHANCED: Add additional vertical safety margin
                basePos += up * 5 -- Extra safety buffer to keep rain above screen

                -- FIXED: Orient the part and attachment to align with wind direction
                local windAngle = math.atan2(windDir.Z, windDir.X)
                local partOrientation = CFrame.new(basePos) * CFrame.Angles(0, windAngle, 0)
                segment.part.CFrame = partOrientation
                
                -- Orient attachment to emit in wind direction + gravity
                local windDownDir = (windDir + Vector3.new(0, -2, 0)).Unit
                segment.attachment.CFrame = CFrame.lookAt(Vector3.new(), windDownDir)

                emitter.Enabled = true
                emitter.Rate = shellRate * fadeFactor
                -- HARDCODED: Match rain direction exactly with RainBeams
                -- Rain falls at approximately 15-degree angle in wind direction
                local rainAngle = math.rad(15) -- Consistent rain tilt
                local lateralSpeed = 160 * math.tan(rainAngle) -- ~45
                emitter.Acceleration = Vector3.new(windDir.X * lateralSpeed, -160, windDir.Z * lateralSpeed)
                emitter.VelocityInheritance = 0 -- Don't inherit any physics
                emitter.LightEmission = 0.08 + (1 - fadeFactor) * 0.12
                emitter.Transparency = makeTransparency(fadeFactor)
            end
        end
    end
end

function RainShells:Cleanup()
    if self.Container then
        self.Container:Destroy()
        self.Container = nil
    end
    self.ShellSegments = {}
end

return RainShells
