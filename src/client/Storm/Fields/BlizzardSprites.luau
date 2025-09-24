--!strict
-- BlizzardSprites.luau
-- Simple but effective blizzard wind sprite system
-- Large sprites that move with the wind and fade properly

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local sharedRoot = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local StormTypes = require(sharedRoot:WaitForChild("StormTypes"))

type StormState = StormTypes.StormState
export type PerfConfig = StormTypes.PerfConfig

type WindSprite = {
    part: BasePart,
    billboard: BillboardGui,
    image: ImageLabel,
    position: Vector3,
    velocity: Vector3,
    size: number,
    lifetime: number,
    age: number,
    distance: number, -- Distance from camera for layering
    opacity: number,
    active: boolean,
}

local BlizzardSprites = {}
BlizzardSprites.__index = BlizzardSprites

function BlizzardSprites.new(perfConfig: PerfConfig, perfTier: StormTypes.PerfTier?)
    local self = setmetatable({}, BlizzardSprites)
    
    self.Container = Instance.new("Folder")
    self.Container.Name = "BlizzardSprites"
    self.Container.Parent = Workspace
    
    self.Sprites = {} :: {WindSprite}
    self.Enabled = true
    self.Random = Random.new(os.clock())
    self.Time = 0
    
    -- Configuration for blizzard effect
    self.Config = {
        -- Sprite counts by distance layer
        nearCount = 10,      -- Close, fast, small sprites
        midCount = 15,       -- Medium distance, medium size
        farCount = 20,       -- Far, slow, large sprites
        
        -- Size ranges by layer (studs)
        nearSize = {min = 15, max = 25},
        midSize = {min = 30, max = 50},
        farSize = {min = 60, max = 100},
        
        -- Speed multipliers by layer
        nearSpeed = 1.2,
        midSpeed = 1.0,
        farSpeed = 0.8,
        
        -- Distance ranges from camera
        nearDist = {min = 10, max = 30},
        midDist = {min = 30, max = 60},
        farDist = {min = 60, max = 120},
        
        -- General settings
        baseSpeed = 40,
        lifetime = {min = 2, max = 4},
        baseOpacity = 0.3,
        texture = "rbxasset://textures/particles/smoke_main.dds",
    }
    
    self:CreateSpritePool()
    
    print("[BlizzardSprites] Initialized proper blizzard effect system")
    
    return self
end

function BlizzardSprites:CreateSpritePool()
    local totalSprites = self.Config.nearCount + self.Config.midCount + self.Config.farCount
    
    for i = 1, totalSprites do
        local part = Instance.new("Part")
        part.Name = "BlizzardSprite_" .. i
        part.Anchored = true
        part.CanCollide = false
        part.CanQuery = false
        part.CanTouch = false
        part.Transparency = 1
        part.Size = Vector3.new(0.1, 0.1, 0.1)
        part.CastShadow = false -- No shadows from sprites
        part.Parent = self.Container
        
        local billboard = Instance.new("BillboardGui")
        billboard.Name = "SpriteBillboard"
        billboard.Adornee = part
        billboard.Size = UDim2.fromOffset(50, 50) -- Will be resized per sprite
        billboard.LightInfluence = 0
        billboard.AlwaysOnTop = false
        billboard.Parent = part
        
        local image = Instance.new("ImageLabel")
        image.Name = "SpriteImage"
        image.BackgroundTransparency = 1
        image.Size = UDim2.fromScale(1, 1)
        image.Image = self.Config.texture
        image.ImageColor3 = Color3.fromRGB(220, 230, 240)
        image.ImageTransparency = 1
        image.ScaleType = Enum.ScaleType.Stretch
        image.Parent = billboard
        
        local sprite: WindSprite = {
            part = part,
            billboard = billboard,
            image = image,
            position = Vector3.new(),
            velocity = Vector3.new(),
            size = 30,
            lifetime = 3,
            age = 0,
            distance = 50,
            opacity = 0,
            active = false,
        }
        
        table.insert(self.Sprites, sprite)
    end
end

function BlizzardSprites:SpawnSprite(sprite: WindSprite, cameraCf: CFrame, windDir: Vector3, layer: string)
    -- Determine layer parameters
    local sizeRange, speedMult, distRange
    if layer == "near" then
        sizeRange = self.Config.nearSize
        speedMult = self.Config.nearSpeed
        distRange = self.Config.nearDist
    elseif layer == "mid" then
        sizeRange = self.Config.midSize
        speedMult = self.Config.midSpeed
        distRange = self.Config.midDist
    else -- far
        sizeRange = self.Config.farSize
        speedMult = self.Config.farSpeed
        distRange = self.Config.farDist
    end
    
    -- Random size for this sprite
    sprite.size = sizeRange.min + self.Random:NextNumber() * (sizeRange.max - sizeRange.min)
    sprite.billboard.Size = UDim2.fromOffset(sprite.size * 10, sprite.size * 10)
    
    -- Spawn position: Start from behind/side of wind direction
    local distance = distRange.min + self.Random:NextNumber() * (distRange.max - distRange.min)
    sprite.distance = distance
    
    -- Spawn in a cone behind the wind direction
    local windAngle = math.atan2(windDir.Z, windDir.X)
    local spawnAngle = windAngle + math.pi + (self.Random:NextNumber() - 0.5) * math.pi/2
    
    local spawnX = math.cos(spawnAngle) * distance
    local spawnZ = math.sin(spawnAngle) * distance
    local spawnY = (self.Random:NextNumber() - 0.5) * distance * 0.5
    
    sprite.position = cameraCf.Position + Vector3.new(spawnX, spawnY, spawnZ)
    
    -- Set velocity based on wind
    local baseVel = windDir * self.Config.baseSpeed * speedMult
    -- Add some lateral variation
    local lateral = Vector3.new(
        (self.Random:NextNumber() - 0.5) * 10,
        (self.Random:NextNumber() - 0.5) * 5,
        (self.Random:NextNumber() - 0.5) * 10
    )
    sprite.velocity = baseVel + lateral
    
    -- Set lifetime
    sprite.lifetime = self.Config.lifetime.min + self.Random:NextNumber() * 
                     (self.Config.lifetime.max - self.Config.lifetime.min)
    sprite.age = 0
    
    -- Set initial opacity based on layer (farther = more opaque)
    if layer == "far" then
        sprite.opacity = self.Config.baseOpacity * 1.2
    elseif layer == "mid" then
        sprite.opacity = self.Config.baseOpacity
    else
        sprite.opacity = self.Config.baseOpacity * 0.7
    end
    
    sprite.active = true
    sprite.part.CFrame = CFrame.new(sprite.position)
end

function BlizzardSprites:Update(state: StormState, conePose, forbidden, lanternEnabled: boolean, dt: number?)
    local camera = Workspace.CurrentCamera
    if not camera or not self.Enabled then return end
    
    local delta = dt or (1/60)
    self.Time += delta
    
    local cameraCf = camera.CFrame
    local windDir = state.vector.Magnitude > 0.01 and state.vector.Unit or Vector3.new(0.3, 0, -0.8).Unit
    local intensity = state.intensity
    
    -- Count active sprites per layer
    local nearActive, midActive, farActive = 0, 0, 0
    for _, sprite in ipairs(self.Sprites) do
        if sprite.active then
            if sprite.distance < 30 then
                nearActive += 1
            elseif sprite.distance < 60 then
                midActive += 1
            else
                farActive += 1
            end
        end
    end
    
    -- Spawn new sprites as needed
    local spawnChance = intensity * delta * 5
    if self.Random:NextNumber() < spawnChance then
        -- Determine which layer needs sprites
        local layer
        if nearActive < self.Config.nearCount then
            layer = "near"
        elseif midActive < self.Config.midCount then
            layer = "mid"
        elseif farActive < self.Config.farCount then
            layer = "far"
        end
        
        if layer then
            -- Find inactive sprite to spawn
            for _, sprite in ipairs(self.Sprites) do
                if not sprite.active then
                    self:SpawnSprite(sprite, cameraCf, windDir, layer)
                    break
                end
            end
        end
    end
    
    -- Update active sprites
    for _, sprite in ipairs(self.Sprites) do
        if sprite.active then
            sprite.age += delta
            
            -- Check lifetime
            if sprite.age >= sprite.lifetime then
                sprite.active = false
                sprite.image.ImageTransparency = 1
                continue
            end
            
            -- Move sprite
            sprite.position += sprite.velocity * delta
            sprite.part.CFrame = CFrame.new(sprite.position)
            
            -- Calculate distance to camera
            local distToCamera = (sprite.position - cameraCf.Position).Magnitude
            
            -- Cull if too far or behind camera significantly
            local toCam = cameraCf:PointToObjectSpace(sprite.position)
            if distToCamera > 150 or toCam.Z > 20 then
                sprite.active = false
                sprite.image.ImageTransparency = 1
                continue
            end
            
            -- Calculate opacity
            local lifeProgress = sprite.age / sprite.lifetime
            local fadeIn = math.min(sprite.age * 3, 1)
            local fadeOut = math.max(1 - (lifeProgress - 0.7) * 3.33, 0)
            local lifeFade = fadeIn * fadeOut
            
            -- Distance-based opacity (farther sprites are more visible)
            local distFade = math.clamp(distToCamera / 100, 0.3, 1)
            
            -- Lantern effect - reduce opacity in cone
            local lanternFade = 1
            if lanternEnabled then
                local toSprite = (sprite.position - cameraCf.Position).Unit
                local angle = math.deg(math.acos(math.clamp(toSprite:Dot(cameraCf.LookVector), -1, 1)))
                if angle < 45 then
                    lanternFade = 0.2 + (angle / 45) * 0.5
                end
            end
            
            -- Final transparency
            local finalOpacity = sprite.opacity * lifeFade * distFade * intensity * lanternFade
            sprite.image.ImageTransparency = 1 - math.clamp(finalOpacity, 0, 0.7)
            
            -- Subtle size pulsing for organic feel
            local sizePulse = 1 + math.sin(self.Time * 2 + sprite.age * 3) * 0.05
            sprite.billboard.Size = UDim2.fromOffset(
                sprite.size * 10 * sizePulse,
                sprite.size * 10 * sizePulse
            )
        end
    end
end

function BlizzardSprites:SetEnabled(enabled: boolean)
    self.Enabled = enabled
    if not enabled then
        for _, sprite in ipairs(self.Sprites) do
            sprite.active = false
            sprite.image.ImageTransparency = 1
        end
    end
end

function BlizzardSprites:Cleanup()
    for _, sprite in ipairs(self.Sprites) do
        if sprite.part then
            sprite.part:Destroy()
        end
    end
    self.Sprites = {}
    
    if self.Container then
        self.Container:Destroy()
        self.Container = nil
    end
end

return BlizzardSprites
