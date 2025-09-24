--!strict
-- WindGusts.luau
-- Dense Storm Wall System - Thick, oppressive weather with clear wind motion

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local sharedRoot = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local StormTypes = require(sharedRoot:WaitForChild("StormTypes"))
local StormConfig = require(sharedRoot:WaitForChild("StormConfig"))

type StormState = StormTypes.StormState
type ConePose = StormTypes.ConePose
type ForbiddenAzimuth = StormTypes.ForbiddenAzimuth
export type PerfConfig = StormTypes.PerfConfig

-- Fast, simple particle for dense weather
type WeatherParticle = {
    part: BasePart,
    billboard: BillboardGui,
    image: ImageLabel,
    pos: Vector3,
    vel: Vector3,
    size: number,
    lifetime: number,
    age: number,
    layer: number, -- 1=close, 2=mid, 3=far, 4=background
    active: boolean,
}

-- Background texture plane for density - SIMPLIFIED
type StormPlane = {
    part: BasePart,
    texture: BillboardGui,
    image: ImageLabel,
    distance: number,
    scrollOffset: Vector2,
    active: boolean,
}

local config = StormConfig.DenseStorm

-- Configurable gust scale multiplier (user requested 3x scaling)
local GUST_SCALE_MULTIPLIER = config.scaleMultiplier or 3.0

local WindGusts = {}
WindGusts.__index = WindGusts

function WindGusts.new(perfConfig: PerfConfig, perfTier: StormTypes.PerfTier?)
    local self = setmetatable({}, WindGusts)
    self.PerfConfig = perfConfig
    self.PerfTier = perfTier or "HIGH"

    self.Container = Instance.new("Folder")
    self.Container.Name = "DenseStormSystem"
    self.Container.Parent = Workspace

    self.Random = Random.new(os.clock())
    self.Time = 0
    
    -- Particle pools for different layers
    self.WeatherParticles = {}
    self.StormPlanes = {}
    
    -- Dense particle counts
    local maxParticles = perfConfig.gustsMax * 15 -- MUCH higher particle count
    
    self:InitializeParticlePool(maxParticles)
    self:InitializeStormPlanes()
    
    return self
end

function WindGusts:InitializeParticlePool(maxParticles: number)
    for i = 1, maxParticles do
        local part = Instance.new("Part")
        part.Name = string.format("WeatherParticle_%d", i)
        part.Anchored = true
        part.CanCollide = false
        part.CanQuery = false
        part.CanTouch = false
        part.Transparency = 1
        part.Size = Vector3.new(0.1, 0.1, 0.1) -- Tiny for performance
        part.CastShadow = false -- No shadows from particles
        part.Parent = self.Container

        local billboard = Instance.new("BillboardGui")
        billboard.Name = "ParticleBillboard"
        billboard.Adornee = part
        billboard.LightInfluence = 0
        billboard.Size = UDim2.fromOffset(64, 64) -- Fixed small size
        billboard.MaxDistance = 250
        billboard.Parent = part

        local image = Instance.new("ImageLabel")
        image.Name = "Sprite"
        image.BackgroundTransparency = 1
        image.Size = UDim2.fromScale(1, 1)
        image.Image = config.particleTexture
        image.ImageColor3 = Color3.fromRGB(180, 190, 200)
        image.ImageTransparency = 1
        image.ScaleType = Enum.ScaleType.Stretch
        image.Parent = billboard

        local particle: WeatherParticle = {
            part = part,
            billboard = billboard,
            image = image,
            pos = Vector3.new(),
            vel = Vector3.new(),
            size = 1,
            lifetime = 0,
            age = 0,
            layer = 1,
            active = false,
        }
        
        table.insert(self.WeatherParticles, particle)
    end
end

function WindGusts:InitializeStormPlanes()
    -- SIMPLIFIED: Just create a few background fog planes for depth
    -- The main surrounding air effect is now handled by SurroundingAirEffect.luau
    local baseDistance = 80 * GUST_SCALE_MULTIPLIER
    local baseWidth = 200 * GUST_SCALE_MULTIPLIER
    local baseHeight = 150 * GUST_SCALE_MULTIPLIER
    
    local planeConfigs = {
        {distance = baseDistance, size = Vector3.new(baseWidth, baseHeight, 1), opacity = 0.2},
        {distance = baseDistance * 1.5, size = Vector3.new(baseWidth * 1.3, baseHeight * 1.2, 1), opacity = 0.15},
    }
    
    for i, planeConfig in ipairs(planeConfigs) do
        local part = Instance.new("Part")
        part.Name = string.format("BackgroundFog_%d", i)
        part.Anchored = true
        part.CanCollide = false
        part.CanQuery = false
        part.CanTouch = false
        part.Transparency = 1
        part.Size = planeConfig.size
        part.Material = Enum.Material.ForceField
        part.CastShadow = false -- No shadows from fog planes
        part.Parent = self.Container

        local billboard = Instance.new("BillboardGui")
        billboard.Name = "FogBillboard"
        billboard.Adornee = part
        billboard.Size = UDim2.fromOffset(planeConfig.size.X * 15, planeConfig.size.Y * 15)
        billboard.StudsOffset = Vector3.new(0, 0, 0)
        billboard.LightInfluence = 0
        billboard.AlwaysOnTop = false
        billboard.Parent = part

        local imageLabel = Instance.new("ImageLabel")
        imageLabel.Size = UDim2.fromScale(1, 1)
        imageLabel.BackgroundTransparency = 1
        imageLabel.Image = config.backgroundTextures[1]
        imageLabel.ImageColor3 = Color3.fromRGB(160, 170, 180)
        imageLabel.ImageTransparency = 1 - planeConfig.opacity
        imageLabel.ScaleType = Enum.ScaleType.Tile
        imageLabel.TileSize = UDim2.fromOffset(100 * GUST_SCALE_MULTIPLIER, 100 * GUST_SCALE_MULTIPLIER)
        imageLabel.Parent = billboard

        local plane: StormPlane = {
            part = part,
            texture = billboard,
            image = imageLabel,
            distance = planeConfig.distance,
            scrollOffset = Vector2.new(),
            active = true,
        }
        
        table.insert(self.StormPlanes, plane)
    end
end

function WindGusts:SpawnParticle(particle: WeatherParticle, cameraCf: CFrame, windDir: Vector3, layer: number)
    local layerConfig = config.layers[layer]
    if not layerConfig then return end
    
    -- Spawn around camera in dense formation
    local angle = self.Random:NextNumber() * math.pi * 2
    local distance = layerConfig.distance + self.Random:NextNumber() * layerConfig.spread
    local height = (self.Random:NextNumber() - 0.5) * layerConfig.height
    
    local spawnDir = Vector3.new(math.cos(angle), 0, math.sin(angle))
    local spawnPos = cameraCf.Position + spawnDir * distance + Vector3.new(0, height, 0)
    
    -- Wind velocity with layer-specific speed
    local speed = layerConfig.speed + self.Random:NextNumber() * layerConfig.speedVariation
    local velocity = windDir * speed + Vector3.new(
        (self.Random:NextNumber() - 0.5) * layerConfig.turbulence,
        (self.Random:NextNumber() - 0.5) * layerConfig.turbulence * 0.5,
        (self.Random:NextNumber() - 0.5) * layerConfig.turbulence
    )
    
    particle.pos = spawnPos
    particle.vel = velocity
    particle.size = layerConfig.size + self.Random:NextNumber() * layerConfig.sizeVariation
    particle.lifetime = layerConfig.lifetime + self.Random:NextNumber() * layerConfig.lifetimeVariation
    particle.age = 0
    particle.layer = layer
    particle.active = true
    
    particle.part.CFrame = CFrame.new(spawnPos)
    particle.billboard.Size = UDim2.fromOffset(particle.size * 12 * GUST_SCALE_MULTIPLIER, particle.size * 12 * GUST_SCALE_MULTIPLIER)
    particle.image.ImageTransparency = layerConfig.baseTransparency
end

function WindGusts:UpdateStormPlanes(cameraCf: CFrame, windDir: Vector3, intensity: number, dt: number)
    -- SIMPLIFIED: Just basic fog planes that fade in distance
    for _, plane in ipairs(self.StormPlanes) do
        if plane.active then
            -- Simple positioning in front of camera
            local forward = cameraCf.LookVector
            local planePos = cameraCf.Position + forward * plane.distance + Vector3.new(0, 30, 0)
            plane.part.CFrame = CFrame.new(planePos)
            
            -- Basic texture scrolling
            local scrollSpeed = intensity * config.planeScrollSpeed
            plane.scrollOffset += Vector2.new(windDir.X, windDir.Z) * scrollSpeed * dt
            
            local tileSize = 100 * GUST_SCALE_MULTIPLIER
            plane.image.Position = UDim2.fromOffset(
                plane.scrollOffset.X % tileSize,
                plane.scrollOffset.Y % tileSize
            )
            
            -- Simple distance-based transparency
            local distanceFade = math.clamp(1 - plane.distance / (300 * GUST_SCALE_MULTIPLIER), 0.1, 1)
            local finalOpacity = 0.3 * intensity * distanceFade
            plane.image.ImageTransparency = 1 - math.clamp(finalOpacity, 0, 0.5)
        end
    end
end

function WindGusts:Update(state: StormState, conePose: ConePose, forbidden: ForbiddenAzimuth, lanternEnabled: boolean, dt: number?)
    local camera = Workspace.CurrentCamera
    if not camera then return end
    
    local delta = dt or (1/60)
    local cameraCf = camera.CFrame
    local windDir = state.vector.Magnitude > 0.01 and state.vector.Unit or Vector3.new(0.3, 0, -0.8).Unit
    
    self.Time += delta
    
    -- Update background storm planes for density
    self:UpdateStormPlanes(cameraCf, windDir, state.intensity, delta)
    
    -- Aggressive particle spawning for thick weather (scaled up)
    local spawnRate = state.intensity * config.spawnRate * delta * GUST_SCALE_MULTIPLIER
    local spawnCount = math.floor(spawnRate + self.Random:NextNumber())
    
    -- Spawn particles in all layers
    for _ = 1, spawnCount do
        for layerIdx = 1, #config.layers do
            for _, particle in ipairs(self.WeatherParticles) do
                if not particle.active then
                    self:SpawnParticle(particle, cameraCf, windDir, layerIdx)
                    break
                end
            end
        end
    end
    
    -- Update active particles
    for _, particle in ipairs(self.WeatherParticles) do
        if particle.active then
            particle.age += delta
            
            if particle.age >= particle.lifetime then
                particle.active = false
                particle.image.ImageTransparency = 1
                continue
            end
            
            -- Move particle
            particle.pos += particle.vel * delta
            particle.part.CFrame = CFrame.new(particle.pos)
            
            -- Distance culling
            local distToCamera = (particle.pos - cameraCf.Position).Magnitude
            if distToCamera > 300 or distToCamera < 2 then
                particle.active = false
                particle.image.ImageTransparency = 1
                continue
            end
            
            -- Layer-specific transparency and behavior
            local layerConfig = config.layers[particle.layer]
            local ageFactor = 1 - (particle.age / particle.lifetime)
            local distanceFactor = math.clamp(1 - distToCamera / 200, 0, 1)
            local intensityFactor = state.intensity
            
            -- Lantern cone effect - HEAVY reduction in visibility
            local lanternFactor = 1
            if lanternEnabled then
                local toParticle = (particle.pos - cameraCf.Position).Unit
                local angle = math.deg(math.acos(math.clamp(toParticle:Dot(cameraCf.LookVector), -1, 1)))
                if angle < conePose.halfAngleDeg * 1.5 then
                    lanternFactor = 0.1 -- 90% transparency in lantern area
                end
            end
            
            local finalAlpha = ageFactor * distanceFactor * intensityFactor * lanternFactor * layerConfig.opacity
            particle.image.ImageTransparency = 1 - math.clamp(finalAlpha, 0, 0.95)
        end
    end
end

function WindGusts:Cleanup()
    for _, particle in ipairs(self.WeatherParticles) do
        if particle.part then
            particle.part:Destroy()
        end
    end
    
    for _, plane in ipairs(self.StormPlanes) do
        if plane.part then
            plane.part:Destroy()
        end
    end
    
    self.WeatherParticles = {}
    self.StormPlanes = {}
    
    if self.Container then
        self.Container:Destroy()
        self.Container = nil
    end
end

return WindGusts
