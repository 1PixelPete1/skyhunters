--!strict
-- SurroundingAirEffect.luau
-- Cylindrical storm overlay tracks that wrap around the camera and scroll with wind

local Workspace = game:GetService("Workspace")

local sharedRoot = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local StormTypes = require(sharedRoot:WaitForChild("StormTypes"))
local StormConfig = require(sharedRoot:WaitForChild("StormConfig"))

type StormState = StormTypes.StormState
export type PerfConfig = StormTypes.PerfConfig

type TrackSprite = {
    part: BasePart,
    textures: {Texture},
    angle: number,
    trackId: number,
    fadeWeight: number,
    scrollSign: number,
    scrollOffset: number,
    scrollPeriod: number,
}

type OverheadSprite = {
    part: BasePart,
    textures: {Texture},
    rotation: number,
    rotationSpeed: number,
    height: number,
    baseTransparency: number,
}

local config = StormConfig.WindOverlayTracks
local VECTOR_UP = Vector3.new(0, 1, 0)
local TRACK_DEFS = {
    { startAngle = -math.pi / 2, endAngle = math.pi / 2, id = 1 },
    { startAngle = math.pi / 2, endAngle = 3 * math.pi / 2, id = 2 },
}

local function createTexture(parent: BasePart, face: Enum.NormalId, transparency: number): Texture
    local texture = Instance.new("Texture")
    texture.Name = "StormTrackTexture"
    texture.Face = face
    texture.Texture = config.spriteTexture
    texture.StudsPerTileU = math.max(config.spriteSize.X, 0.01)
    texture.StudsPerTileV = math.max(config.spriteSize.Y, 0.01)
    texture.OffsetStudsU = 0
    texture.OffsetStudsV = 0
    texture.Transparency = transparency
    texture.Parent = parent
    return texture
end

local function defaultForward(): Vector3
    return Vector3.new(0, 0, -1)
end

local function safeUnit(vec: Vector3, fallback: Vector3): Vector3
    if vec.Magnitude < 1e-3 then
        return fallback
    end
    return vec.Unit
end

local SurroundingAirEffect = {}
SurroundingAirEffect.__index = SurroundingAirEffect

function SurroundingAirEffect.new(_perfConfig: PerfConfig, _perfTier: StormTypes.PerfTier?)
    local self = setmetatable({}, SurroundingAirEffect)

    self.Container = Instance.new("Folder")
    self.Container.Name = "StormCylindricalTracks"
    self.Container.Parent = Workspace

    self.TrackSprites = {} :: { TrackSprite }
    self.OverheadSprites = {} :: { OverheadSprite }
    self.Time = 0

    self:_buildTracks()
    self:_buildOverhead()

    return self
end

function SurroundingAirEffect:_buildTracks()
    local thickness = config.spriteThickness
    local segmentCount = math.max(config.segmentCount, 3)

    for _, track in ipairs(TRACK_DEFS) do
        for index = 0, segmentCount - 1 do
            local t = (index + 0.5) / segmentCount
            local angle = track.startAngle + (track.endAngle - track.startAngle) * t

            local part = Instance.new("Part")
            part.Name = string.format("TrackSprite_%d_%02d", track.id, index + 1)
            part.Anchored = true
            part.CanCollide = false
            part.CanQuery = false
            part.CanTouch = false
            part.Transparency = 1
            part.Size = Vector3.new(config.spriteSize.X, config.spriteSize.Y, thickness)
            part.Parent = self.Container

            local textures = {
                createTexture(part, Enum.NormalId.Front, 1),
                createTexture(part, Enum.NormalId.Back, 1),
            }

            local edgeWeight = math.min(t, 1 - t)
            local fadeWeight = edgeWeight ^ config.fadeExponent

            local sprite: TrackSprite = {
                part = part,
                textures = textures,
                angle = angle,
                trackId = track.id,
                fadeWeight = fadeWeight,
                scrollSign = 1,
                scrollOffset = 0,
                scrollPeriod = math.max(config.spriteSize.X, 0.01),
            }

            table.insert(self.TrackSprites, sprite)
        end
    end
end

function SurroundingAirEffect:_buildOverhead()
    local overheadConfig = config.overhead
    local heights = overheadConfig.heights
    local size = overheadConfig.size

    local rotationSpeeds = {
        overheadConfig.rotationSpeeds.slow,
        overheadConfig.rotationSpeeds.fast,
    }

    local baseTransparencies = {
        overheadConfig.baseTransparency.top,
        overheadConfig.baseTransparency.bottom,
    }

    for index = 1, math.min(#heights, 2) do
        local part = Instance.new("Part")
        part.Name = string.format("StormOverhead_%d", index)
        part.Anchored = true
        part.CanCollide = false
        part.CanTouch = false
        part.CanQuery = false
        part.Transparency = 1
        part.Size = Vector3.new(size, 0.2, size)
        part.Parent = self.Container

        local textures = {
            createTexture(part, Enum.NormalId.Bottom, baseTransparencies[index] or 0.6),
            createTexture(part, Enum.NormalId.Top, baseTransparencies[index] or 0.6),
        }

        local cloud: OverheadSprite = {
            part = part,
            textures = textures,
            rotation = 0,
            rotationSpeed = rotationSpeeds[index] or rotationSpeeds[#rotationSpeeds],
            height = heights[index],
            baseTransparency = baseTransparencies[index] or 0.6,
        }

        table.insert(self.OverheadSprites, cloud)
    end
end

local function alignPartToCamera(part: BasePart, position: Vector3, tangent: Vector3, cameraPos: Vector3)
    local up = VECTOR_UP
    local look = CFrame.lookAt(position, cameraPos, up)
    local currentRight = look.RightVector
    local targetRight = safeUnit(tangent, currentRight)
    local dot = math.clamp(currentRight:Dot(targetRight), -1, 1)
    local angle = math.acos(dot)
    if currentRight:Cross(targetRight):Dot(up) < 0 then
        angle = -angle
    end

    part.CFrame = look * CFrame.fromAxisAngle(up, angle)
end

function SurroundingAirEffect:Update(state: StormState, _conePose, _forbiddenAzimuth, lanternEnabled: boolean, dt: number?)
    local camera = Workspace.CurrentCamera
    if not camera then
        return
    end

    local delta = dt or (1 / 60)
    self.Time += delta

    local intensity = math.clamp(state.intensity, 0, 1)
    if intensity <= 0 then
        for _, sprite in ipairs(self.TrackSprites) do
            for _, texture in ipairs(sprite.textures) do
                texture.Transparency = 1
            end
        end
        for _, cloud in ipairs(self.OverheadSprites) do
            for _, texture in ipairs(cloud.textures) do
                texture.Transparency = 1
            end
        end
        return
    end

    local cameraCf = camera.CFrame
    local cameraPos = cameraCf.Position

    local horizontalWind = Vector3.new(state.vector.X, 0, state.vector.Z)
    local forward = safeUnit(horizontalWind, defaultForward())
    local right = safeUnit(forward:Cross(VECTOR_UP), cameraCf.RightVector)
    local up = VECTOR_UP
    local windSpeed = state.vector.Magnitude

    for _, sprite in ipairs(self.TrackSprites) do
        local angle = sprite.angle
        local circleVec = right * math.cos(angle) + forward * math.sin(angle)
        local centerPos = cameraPos + circleVec * config.trackRadius + up * config.trackHeight
        local tangent = safeUnit((-right * math.sin(angle)) + (forward * math.cos(angle)), right)

        alignPartToCamera(sprite.part, centerPos, tangent, cameraPos)

        local scrollSpeed = config.scrollSpeed.base + config.scrollSpeed.windScale * windSpeed
        sprite.scrollSign = (tangent:Dot(forward) >= 0) and 1 or -1
        sprite.scrollOffset += sprite.scrollSign * scrollSpeed * delta
        if sprite.scrollOffset > sprite.scrollPeriod then
            sprite.scrollOffset -= sprite.scrollPeriod
        elseif sprite.scrollOffset < -sprite.scrollPeriod then
            sprite.scrollOffset += sprite.scrollPeriod
        end

        local baseAlpha = config.intensityAlpha.min + (config.intensityAlpha.max - config.intensityAlpha.min) * intensity
        local alpha = math.clamp(baseAlpha * sprite.fadeWeight, 0, 1)
        if lanternEnabled then
            alpha *= (1 - config.lanternDim)
        end
        local transparency = 1 - alpha

        for _, texture in ipairs(sprite.textures) do
            texture.OffsetStudsU = sprite.scrollOffset
            texture.Transparency = transparency
        end
    end

    for _, cloud in ipairs(self.OverheadSprites) do
        cloud.rotation += cloud.rotationSpeed * delta

        local rotationCf = CFrame.fromAxisAngle(VECTOR_UP, cloud.rotation)
        local xAxis = rotationCf.XVector
        local zAxis = rotationCf.ZVector
        local position = cameraPos + up * cloud.height
        cloud.part.CFrame = CFrame.fromMatrix(position, xAxis, up, zAxis)

        local cloudAlpha = math.clamp(1 - cloud.baseTransparency, 0, 1) * intensity
        if lanternEnabled then
            cloudAlpha *= (1 - 0.4)
        end
        local cloudTransparency = math.clamp(1 - cloudAlpha, cloud.baseTransparency, 1)

        for _, texture in ipairs(cloud.textures) do
            texture.Transparency = cloudTransparency
        end
    end
end

function SurroundingAirEffect:Cleanup()
    for _, sprite in ipairs(self.TrackSprites) do
        if sprite.part then
            sprite.part:Destroy()
        end
    end
    self.TrackSprites = {}

    for _, cloud in ipairs(self.OverheadSprites) do
        if cloud.part then
            cloud.part:Destroy()
        end
    end
    self.OverheadSprites = {}

    if self.Container then
        self.Container:Destroy()
        self.Container = nil
    end
end

return SurroundingAirEffect
