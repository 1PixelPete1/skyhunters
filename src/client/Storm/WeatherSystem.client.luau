--!strict
-- WeatherSystem.client.luau
-- Unified, performance-optimized weather system for mobile with violent storm effects
-- Manages all weather effects with LOD system and lantern-based visibility

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

-- Feature gate so the script can be left in the repo without running by default.
local ENABLE_WEATHER_SYSTEM = false
if not ENABLE_WEATHER_SYSTEM then
    return
end

local Lighting = game:GetService("Lighting")

-- Performance monitoring
local PerformanceMonitor = {
    frameCount = 0,
    frameTime = 0,
    fps = 60,
    targetFps = 30, -- Mobile target
    adaptiveQuality = true,
}

-- LOD (Level of Detail) settings for mobile optimization
local LODSettings = {
    ULTRA_LOW = {
        maxParticles = 20,
        maxWindSheets = 2,
        fogUpdateRate = 0.5,
        renderDistance = 50,
        particleDetail = 0.3,
    },
    LOW = {
        maxParticles = 40,
        maxWindSheets = 4,
        fogUpdateRate = 0.25,
        renderDistance = 80,
        particleDetail = 0.5,
    },
    MEDIUM = {
        maxParticles = 80,
        maxWindSheets = 6,
        fogUpdateRate = 0.1,
        renderDistance = 120,
        particleDetail = 0.7,
    },
    HIGH = {
        maxParticles = 150,
        maxWindSheets = 10,
        fogUpdateRate = 0.05,
        renderDistance = 200,
        particleDetail = 1.0,
    },
}

-- Current LOD level
local currentLOD = "LOW"
local currentLODSettings = LODSettings[currentLOD]

-- Weather state
local WeatherState = {
    intensity = 0,
    windDirection = Vector3.new(1, 0, 0.5).Unit,
    gustStrength = 0,
    visibility = 1.0,
    lanternActive = false,
    lanternCone = {
        direction = Vector3.new(0, 0, -1),
        angle = 30,
    },
}

-- Object pools for performance
local ParticlePool = {}
local WindSheetPool = {}

-- Container for all weather effects
local weatherContainer: Folder?

-- Initialize performance monitor
local function updatePerformance(dt: number)
    PerformanceMonitor.frameCount += 1
    PerformanceMonitor.frameTime += dt
    
    if PerformanceMonitor.frameTime >= 1 then
        PerformanceMonitor.fps = PerformanceMonitor.frameCount / PerformanceMonitor.frameTime
        PerformanceMonitor.frameCount = 0
        PerformanceMonitor.frameTime = 0
        
        -- Adaptive quality based on FPS
        if PerformanceMonitor.adaptiveQuality then
            if PerformanceMonitor.fps < 20 and currentLOD ~= "ULTRA_LOW" then
                currentLOD = "ULTRA_LOW"
                currentLODSettings = LODSettings[currentLOD]
                print("[Weather] Switching to ULTRA_LOW quality (FPS:", PerformanceMonitor.fps, ")")
            elseif PerformanceMonitor.fps < 25 and currentLOD == "MEDIUM" then
                currentLOD = "LOW"
                currentLODSettings = LODSettings[currentLOD]
                print("[Weather] Switching to LOW quality (FPS:", PerformanceMonitor.fps, ")")
            elseif PerformanceMonitor.fps < 30 and currentLOD == "HIGH" then
                currentLOD = "MEDIUM"
                currentLODSettings = LODSettings[currentLOD]
                print("[Weather] Switching to MEDIUM quality (FPS:", PerformanceMonitor.fps, ")")
            elseif PerformanceMonitor.fps > 50 and currentLOD == "LOW" then
                currentLOD = "MEDIUM"
                currentLODSettings = LODSettings[currentLOD]
                print("[Weather] Switching to MEDIUM quality (FPS:", PerformanceMonitor.fps, ")")
            elseif PerformanceMonitor.fps > 55 and currentLOD == "MEDIUM" then
                currentLOD = "HIGH"
                currentLODSettings = LODSettings[currentLOD]
                print("[Weather] Switching to HIGH quality (FPS:", PerformanceMonitor.fps, ")")
            end
        end
    end
end

-- Create fog/storm atmosphere effect
local function setupAtmosphere()
    local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
    if not atmosphere then
        atmosphere = Instance.new("Atmosphere")
        atmosphere.Parent = Lighting
    end
    
    -- Store original values
    local originalDensity = atmosphere.Density
    local originalOffset = atmosphere.Offset
    local originalHaze = atmosphere.Haze
    local originalGlare = atmosphere.Glare
    
    return {
        atmosphere = atmosphere,
        original = {
            density = originalDensity,
            offset = originalOffset,
            haze = originalHaze,
            glare = originalGlare,
        },
        current = {
            density = originalDensity,
            offset = originalOffset,
            haze = originalHaze,
            glare = originalGlare,
        },
    }
end

local atmosphereSystem = setupAtmosphere()

-- Create volumetric fog layers for depth
local function createFogLayer(index: number, distance: number)
    local part = Instance.new("Part")
    part.Name = "FogLayer_" .. index
    part.Anchored = true
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.Size = Vector3.new(300, 50, 300)
    part.Transparency = 0.7 + (index * 0.05)
    part.Material = Enum.Material.ForceField
    part.Color = Color3.new(0.8, 0.85, 0.9)
    part.CastShadow = false
    
    -- Add subtle animation
    local floatHeight = distance * 0.1
    task.spawn(function()
        local time = 0
        while part.Parent do
            time += task.wait(0.05)
            local camera = Workspace.CurrentCamera
            if camera then
                part.CFrame = CFrame.new(
                    camera.CFrame.Position + camera.CFrame.LookVector * distance
                    + Vector3.new(0, math.sin(time * 0.3 + index) * floatHeight, 0)
                )
            end
        end
    end)
    
    return part
end

-- Wind sheet for volumetric wind effect (using sprites as placeholders)
local function createWindSheet(index: number)
    local part = Instance.new("Part")
    part.Name = "WindSheet_" .. index
    part.Anchored = true
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.Transparency = 1
    part.Size = Vector3.one
    
    local billboard = Instance.new("BillboardGui")
    billboard.Size = UDim2.new(15, 0, 10, 0)
    billboard.LightInfluence = 0
    billboard.AlwaysOnTop = false
    billboard.Parent = part
    
    local image = Instance.new("ImageLabel")
    image.Size = UDim2.fromScale(1, 1)
    image.BackgroundTransparency = 1
    -- PLACEHOLDER: Replace with your wind gust sprite texture
    image.Image = "rbxasset://textures/particles/smoke_main.dds"
    image.ImageColor3 = Color3.new(0.9, 0.95, 1)
    image.ImageTransparency = 0.6
    image.ScaleType = Enum.ScaleType.Stretch
    image.Parent = billboard
    
    return {
        part = part,
        billboard = billboard,
        image = image,
        velocity = Vector3.new(),
        age = 0,
        maxAge = 5 + math.random() * 3,
        opacity = 0,
        targetOpacity = 0.3 + math.random() * 0.3,
        swayPhase = math.random() * math.pi * 2,
        swaySpeed = 0.5 + math.random() * 0.5,
    }
end

-- Near-field particle system for rain/snow (optimized for mobile)
local function createWeatherParticle(index: number)
    local part = Instance.new("Part")
    part.Name = "WeatherParticle_" .. index
    part.Anchored = true
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.Size = Vector3.new(0.1, 2, 0.1)
    part.Material = Enum.Material.Neon
    part.Color = Color3.new(0.8, 0.85, 0.95)
    part.Transparency = 0.3
    part.CastShadow = false
    
    return {
        part = part,
        position = Vector3.new(),
        velocity = Vector3.new(),
        age = 0,
        maxAge = 1,
        active = false,
    }
end

-- Initialize object pools
local function initializePools()
    weatherContainer = Instance.new("Folder")
    weatherContainer.Name = "WeatherSystem"
    weatherContainer.Parent = Workspace
    
    -- Create particle pool
    for i = 1, LODSettings.HIGH.maxParticles do
        local particle = createWeatherParticle(i)
        particle.part.Parent = weatherContainer
        table.insert(ParticlePool, particle)
    end
    
    -- Create wind sheet pool
    for i = 1, LODSettings.HIGH.maxWindSheets do
        local sheet = createWindSheet(i)
        sheet.part.Parent = weatherContainer
        table.insert(WindSheetPool, sheet)
    end
end

-- Spawn a weather particle
local function spawnParticle(camera: Camera)
    local maxActive = math.floor(currentLODSettings.maxParticles * WeatherState.intensity)
    local activeCount = 0
    
    for _, particle in ipairs(ParticlePool) do
        if particle.active then
            activeCount += 1
        end
    end
    
    if activeCount >= maxActive then
        return
    end
    
    for _, particle in ipairs(ParticlePool) do
        if not particle.active then
            -- Spawn in front/around camera
            local angle = math.random() * math.pi * 2
            local distance = 10 + math.random() * 20
            local height = 10 + math.random() * 10
            
            particle.position = camera.CFrame.Position 
                + camera.CFrame.LookVector * distance
                + camera.CFrame.RightVector * math.cos(angle) * distance * 0.5
                + Vector3.new(0, height, 0)
            
            -- Set velocity based on wind
            particle.velocity = Vector3.new(0, -20 - math.random() * 20, 0)
                + WeatherState.windDirection * WeatherState.gustStrength * 30
            
            particle.age = 0
            particle.maxAge = 0.5 + math.random() * 0.5
            particle.active = true
            particle.part.CFrame = CFrame.new(particle.position)
            
            break
        end
    end
end

-- Update wind sheets for volumetric effect
local function updateWindSheets(camera: Camera, dt: number)
    local activeSheets = math.floor(currentLODSettings.maxWindSheets * WeatherState.intensity)
    
    for i, sheet in ipairs(WindSheetPool) do
        if i <= activeSheets then
            -- Position sheets in layers
            local layerDistance = 30 + (i - 1) * 20
            local targetPos = camera.CFrame.Position 
                + camera.CFrame.LookVector * layerDistance
                + WeatherState.windDirection * WeatherState.gustStrength * 10
            
            -- Add sway motion
            local sway = math.sin(tick() * sheet.swaySpeed + sheet.swayPhase) * 5
            targetPos = targetPos + camera.CFrame.RightVector * sway
            
            -- Smooth movement
            sheet.part.CFrame = sheet.part.CFrame:Lerp(
                CFrame.new(targetPos),
                math.min(dt * 2, 1)
            )
            
            -- Update opacity based on lantern cone
            local targetOpacity = sheet.targetOpacity * WeatherState.intensity
            
            if WeatherState.lanternActive then
                local toSheet = (sheet.part.Position - camera.CFrame.Position).Unit
                local dot = toSheet:Dot(WeatherState.lanternCone.direction)
                local angleDeg = math.deg(math.acos(math.clamp(dot, -1, 1)))
                
                if angleDeg < WeatherState.lanternCone.angle then
                    -- Inside cone - reduce opacity
                    targetOpacity *= 0.2
                end
            end
            
            sheet.opacity = sheet.opacity + (targetOpacity - sheet.opacity) * dt * 3
            sheet.image.ImageTransparency = 1 - sheet.opacity
            
            -- Scale based on distance for perspective
            local distance = (sheet.part.Position - camera.CFrame.Position).Magnitude
            local scale = math.clamp(distance / 50, 0.5, 2)
            sheet.billboard.Size = UDim2.new(15 * scale, 0, 10 * scale, 0)
        else
            -- Hide inactive sheets
            sheet.image.ImageTransparency = 1
        end
    end
end

-- Update weather particles
local function updateParticles(camera: Camera, dt: number)
    for _, particle in ipairs(ParticlePool) do
        if particle.active then
            particle.age += dt
            
            if particle.age >= particle.maxAge then
                particle.active = false
                particle.part.Transparency = 1
                continue
            end
            
            -- Update position
            particle.position += particle.velocity * dt
            
            -- Add turbulence
            local turbulence = Vector3.new(
                math.sin(tick() * 3 + particle.position.X * 0.1) * 2,
                0,
                math.cos(tick() * 3 + particle.position.Z * 0.1) * 2
            )
            particle.position += turbulence * dt
            
            particle.part.CFrame = CFrame.lookAt(
                particle.position,
                particle.position + particle.velocity
            )
            
            -- Update transparency based on age and lantern
            local fadeIn = math.min(particle.age * 4, 1)
            local fadeOut = math.max(1 - (particle.age / particle.maxAge - 0.7) * 3, 0)
            local fade = fadeIn * fadeOut
            
            if WeatherState.lanternActive then
                local toParticle = (particle.position - camera.CFrame.Position).Unit
                local dot = toParticle:Dot(WeatherState.lanternCone.direction)
                local angleDeg = math.deg(math.acos(math.clamp(dot, -1, 1)))
                
                if angleDeg < WeatherState.lanternCone.angle then
                    fade *= 0.1 -- Nearly invisible in cone
                end
            end
            
            particle.part.Transparency = 1 - fade * 0.7
            
            -- Cull if too far or below ground
            local distance = (particle.position - camera.CFrame.Position).Magnitude
            if distance > currentLODSettings.renderDistance or particle.position.Y < -10 then
                particle.active = false
                particle.part.Transparency = 1
            end
        else
            particle.part.Transparency = 1
        end
    end
end

-- Update atmosphere/fog
local lastFogUpdate = 0
local function updateAtmosphere(dt: number)
    lastFogUpdate += dt
    if lastFogUpdate < currentLODSettings.fogUpdateRate then
        return
    end
    lastFogUpdate = 0
    
    local targetDensity = atmosphereSystem.original.density + WeatherState.intensity * 0.3
    local targetOffset = atmosphereSystem.original.offset - WeatherState.intensity * 0.2
    local targetHaze = atmosphereSystem.original.haze + WeatherState.intensity * 2
    
    -- Smooth transitions
    atmosphereSystem.current.density = atmosphereSystem.current.density + 
        (targetDensity - atmosphereSystem.current.density) * 0.1
    atmosphereSystem.current.offset = atmosphereSystem.current.offset + 
        (targetOffset - atmosphereSystem.current.offset) * 0.1
    atmosphereSystem.current.haze = atmosphereSystem.current.haze + 
        (targetHaze - atmosphereSystem.current.haze) * 0.1
    
    atmosphereSystem.atmosphere.Density = atmosphereSystem.current.density
    atmosphereSystem.atmosphere.Offset = atmosphereSystem.current.offset
    atmosphereSystem.atmosphere.Haze = atmosphereSystem.current.haze
    
    -- Reduce glare in storm
    atmosphereSystem.atmosphere.Glare = atmosphereSystem.original.glare * (1 - WeatherState.intensity * 0.5)
end

-- Main update loop
local function onHeartbeat(dt: number)
    updatePerformance(dt)
    
    local camera = Workspace.CurrentCamera
    if not camera then return end
    
    -- Update weather subsystems based on LOD
    updateAtmosphere(dt)
    updateWindSheets(camera, dt)
    updateParticles(camera, dt)
    
    -- Spawn new particles
    if WeatherState.intensity > 0 then
        local spawnRate = currentLODSettings.maxParticles * WeatherState.intensity * 2
        local spawnsThisFrame = math.floor(spawnRate * dt)
        for i = 1, spawnsThisFrame do
            spawnParticle(camera)
        end
    end
end

-- Handle storm state updates
local function updateStormState(state: any)
    if not state then return end
    
    WeatherState.intensity = math.clamp(state.intensity or 0, 0, 1)
    WeatherState.windDirection = (state.vector and state.vector.Unit) or Vector3.new(1, 0, 0.5).Unit
    
    -- Calculate gust strength from intensity
    WeatherState.gustStrength = WeatherState.intensity * (0.5 + math.sin(tick() * 0.5) * 0.5)
    
    print("[Weather] Storm updated - Intensity:", WeatherState.intensity, "Wind:", WeatherState.windDirection)
end

-- Handle lantern state
local function updateLanternState()
    local player = Players.LocalPlayer
    if not player then return end
    
    -- Check various possible locations for lantern state
    WeatherState.lanternActive = player:GetAttribute("LanternEnabled") or false
    
    -- Update cone direction based on camera
    local camera = Workspace.CurrentCamera
    if camera then
        WeatherState.lanternCone.direction = camera.CFrame.LookVector
    end
end

-- Initialize the weather system
local function initialize()
    print("[Weather] Initializing enhanced weather system...")
    
    initializePools()
    
    -- Connect to server storm state
    local remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
    if remotes then
        local stormRemote = remotes:WaitForChild("StormState", 10) :: RemoteEvent?
        if stormRemote then
            stormRemote.OnClientEvent:Connect(updateStormState)
        end
    end
    
    -- Monitor lantern state
    task.spawn(function()
        while true do
            updateLanternState()
            task.wait(0.1)
        end
    end)
    
    -- Start render loop
    RunService.Heartbeat:Connect(onHeartbeat)
    
    -- Test storm (remove in production)
    if RunService:IsStudio() then
        task.wait(2)
        updateStormState({
            intensity = 0.8,
            vector = Vector3.new(1, 0, 0.5),
            profile = "RAIN_HEAVY",
            gusts = {}
        })
    end
    
    print("[Weather] Weather system initialized with LOD:", currentLOD)
end

-- Cleanup on shutdown
local function cleanup()
    if weatherContainer then
        weatherContainer:Destroy()
    end
    
    -- Restore atmosphere
    if atmosphereSystem and atmosphereSystem.atmosphere then
        atmosphereSystem.atmosphere.Density = atmosphereSystem.original.density
        atmosphereSystem.atmosphere.Offset = atmosphereSystem.original.offset
        atmosphereSystem.atmosphere.Haze = atmosphereSystem.original.haze
        atmosphereSystem.atmosphere.Glare = atmosphereSystem.original.glare
    end
end

-- Auto-initialize
task.spawn(initialize)

-- Export for testing
return {
    setIntensity = function(intensity: number)
        WeatherState.intensity = math.clamp(intensity, 0, 1)
    end,
    setWind = function(direction: Vector3)
        WeatherState.windDirection = direction.Unit
    end,
    setLOD = function(lod: string)
        if LODSettings[lod] then
            currentLOD = lod
            currentLODSettings = LODSettings[lod]
            print("[Weather] LOD changed to:", lod)
        end
    end,
    cleanup = cleanup,
}
