--!strict
-- EdgeBand.luau
-- Shimmering edge band used to visualize the lantern safe zone boundary

local Workspace = game:GetService("Workspace")

local sharedRoot = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local StormTypes = require(sharedRoot:WaitForChild("StormTypes"))
local StormConfig = require(sharedRoot:WaitForChild("StormConfig"))

type StormState = StormTypes.StormState
type ConePose = StormTypes.ConePose
type ForbiddenAzimuth = StormTypes.ForbiddenAzimuth
type PerfConfig = StormTypes.PerfConfig

type EdgeEntry = {
    beam: Beam,
    hostA: Part,
    hostB: Part,
    phase: number,
}

local EdgeBand = {}
EdgeBand.__index = EdgeBand

local function createHost(parent: Instance): Part
    local host = Instance.new("Part")
    host.Name = "EdgeBandHost"
    host.Anchored = true
    host.CanCollide = false
    host.CanQuery = false
    host.CanTouch = false
    host.Transparency = 1
    host.Size = Vector3.new(0.2, 0.2, 0.2)
    host.Parent = parent
    return host
end

function EdgeBand.new(perfConfig: PerfConfig, perfTier: StormTypes.PerfTier?)
    local self = setmetatable({}, EdgeBand)

    self.PerfConfig = perfConfig
    self.PerfTier = perfTier or "HIGH"
    self.Container = nil :: Folder?
    self.EdgeBeams = {} :: { EdgeEntry }
    self.Time = 0
    self.LastUpdate = tick()
    self.Random = Random.new(os.clock())

    self:Initialize()

    return self
end

function EdgeBand:Initialize()
    self.Container = Instance.new("Folder")
    self.Container.Name = "StormEdgeBand"
    self.Container.Parent = Workspace

    for i = 1, 2 do
        local entry = self:CreateEdgeBeam()
        table.insert(self.EdgeBeams, entry)
    end
end

function EdgeBand:CreateEdgeBeam(): EdgeEntry
    local hostA = createHost(self.Container)
    local hostB = createHost(self.Container)

    local attA = Instance.new("Attachment")
    attA.Parent = hostA

    local attB = Instance.new("Attachment")
    attB.Parent = hostB

    local beam = Instance.new("Beam")
    beam.Attachment0 = attA
    beam.Attachment1 = attB
    beam.Texture = StormConfig.EdgeBand.texture
    beam.TextureMode = Enum.TextureMode.Wrap
    beam.TextureSpeed = StormConfig.EdgeBand.scroll
    beam.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(0.08, 1 - StormConfig.EdgeBand.alpha),
        NumberSequenceKeypoint.new(0.92, 1 - StormConfig.EdgeBand.alpha),
        NumberSequenceKeypoint.new(1, 1),
    })
    beam.Width0 = 0.6
    beam.Width1 = 1.4
    beam.LightEmission = 0.15
    beam.LightInfluence = 0
    beam.FaceCamera = true
    beam.Enabled = false
    beam.Parent = self.Container

    return {
        beam = beam,
        hostA = hostA,
        hostB = hostB,
        phase = self.Random:NextNumber() * math.pi * 2,
    }
end

local function lerp(a: number, b: number, t: number): number
    return a + (b - a) * t
end

function EdgeBand:Update(state: StormState, conePose: ConePose, forbidden: ForbiddenAzimuth, lanternEnabled: boolean, dt: number?)
    if not self.Container then return end

    local camera = Workspace.CurrentCamera
    if not camera then return end

    local now = tick()
    local delta = dt or math.clamp(now - self.LastUpdate, 0, 1/30)
    self.LastUpdate = now
    self.Time += delta

    if not (lanternEnabled and state.intensity > 0) then
        for _, entry in ipairs(self.EdgeBeams) do
            entry.beam.Enabled = false
        end
        return
    end

    local radius = conePose.outerSoft
    local windDir = state.vector.Magnitude > 0.01 and state.vector.Unit or Vector3.new(0, 0, 0)
    local windOffset = windDir * state.intensity * 3
    local pad = StormConfig.EdgeBand.widthOscHz
    local oscFreq = lerp(pad[1], pad[2], 0.6)
    local widthOsc = math.sin(self.Time * oscFreq + self.Random:NextNumber()) * 0.25 + 1
    local intensityAlpha = StormConfig.EdgeBand.alpha * state.intensity

    for idx, entry in ipairs(self.EdgeBeams) do
        local beam = entry.beam
        local arcWidth = math.rad(90)
        local extra = (idx - 1) * 6
        local arcStart = math.rad(forbidden.minDeg - StormConfig.Cone.forbiddenPadDeg - extra)
        local arcEnd = math.rad(forbidden.maxDeg + StormConfig.Cone.forbiddenPadDeg + extra)

        local startPos = camera.CFrame.Position + Vector3.new(math.cos(arcStart) * radius, 10, math.sin(arcStart) * radius) + windOffset
        local endPos = camera.CFrame.Position + Vector3.new(math.cos(arcEnd) * radius, 10, math.sin(arcEnd) * radius) + windOffset

        entry.hostA.CFrame = CFrame.new(startPos)
        entry.hostB.CFrame = CFrame.new(endPos)

        beam.Enabled = true
        beam.Width0 = 0.55 * widthOsc
        beam.Width1 = 1.4 * widthOsc
        beam.TextureSpeed = StormConfig.EdgeBand.scroll * (1 + state.intensity * 0.4)
        beam.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.08, 1 - intensityAlpha),
            NumberSequenceKeypoint.new(0.92, 1 - intensityAlpha),
            NumberSequenceKeypoint.new(1, 1),
        })
    end
end

function EdgeBand:Cleanup()
    if self.Container then
        self.Container:Destroy()
        self.Container = nil
    end
    self.EdgeBeams = {}
end

return EdgeBand

