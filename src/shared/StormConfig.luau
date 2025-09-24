--!strict
-- Shared configuration for storm visuals and profiles (pure; data only)
-- Enhanced for Dense Storm Wall System

local StormConfig = {}

StormConfig.Cone = {
    halfAngleDeg = 28,
    innerClear = 5,
    innerSoft = 9,
    outerSoft = 14,
    forbiddenPadDeg = 6,
}

-- NEW: Dense Storm System for thick, oppressive weather
StormConfig.DenseStorm = {
    -- Configurable scale multiplier (user can adjust gust size)
    scaleMultiplier = 3.0, -- Default 3x scaling as requested
    
    -- High spawn rate for thick weather
    spawnRate = 250, -- Particles per second at full intensity
    
    -- Particle appearance  
    particleTexture = "rbxasset://textures/particles/smoke_main.dds",
    
    -- Layered particle system for depth
    layers = {
        -- Layer 1: Close particles (high detail, low count)
        {
            distance = 25,
            spread = 15,
            height = 30,
            speed = 45,
            speedVariation = 20,
            turbulence = 15,
            size = 4,
            sizeVariation = 2,
            lifetime = 1.2,
            lifetimeVariation = 0.8,
            baseTransparency = 0.3,
            opacity = 0.8,
        },
        -- Layer 2: Mid particles (medium detail, medium count)
        {
            distance = 60,
            spread = 30,
            height = 40,
            speed = 35,
            speedVariation = 15,
            turbulence = 12,
            size = 6,
            sizeVariation = 3,
            lifetime = 2.0,
            lifetimeVariation = 1.0,
            baseTransparency = 0.4,
            opacity = 0.7,
        },
        -- Layer 3: Far particles (low detail, high count)
        {
            distance = 120,
            spread = 60,
            height = 60,
            speed = 25,
            speedVariation = 10,
            turbulence = 8,
            size = 8,
            sizeVariation = 4,
            lifetime = 3.0,
            lifetimeVariation = 1.5,
            baseTransparency = 0.5,
            opacity = 0.6,
        },
        -- Layer 4: Background particles (very low detail, very high count)
        {
            distance = 200,
            spread = 100,
            height = 80,
            speed = 15,
            speedVariation = 8,
            turbulence = 5,
            size = 12,
            sizeVariation = 6,
            lifetime = 4.0,
            lifetimeVariation = 2.0,
            baseTransparency = 0.6,
            opacity = 0.5,
        },
    },
    
    -- Background texture planes for visual density
    backgroundTextures = {
        "rbxasset://textures/particles/smoke_main.dds",
        "rbxasset://textures/particles/sparkles_main.dds",
    },
    planeScrollSpeed = 8, -- Speed of texture scrolling to show wind
    
    -- Lantern interaction
    lanternVisibilityReduction = 0.1, -- 90% transparency in lantern cone
}

StormConfig.WindOverlayTracks = {
    trackRadius = 120,
    trackHeight = 18,
    segmentCount = 14,
    spriteSize = Vector2.new(36, 48),
    spriteThickness = 0.2,
    spriteTexture = "rbxasset://textures/particles/smoke_main.dds",
    scrollSpeed = { base = 4, windScale = 0.45 },
    fadeExponent = 2.2,
    intensityAlpha = { min = 0.05, max = 0.65 },
    lanternDim = 0.35,
    overhead = {
        heights = { 85, 120 },
        size = 260,
        rotationSpeeds = { slow = math.rad(3), fast = math.rad(5) },
        baseTransparency = { top = 0.62, bottom = 0.48 },
        texture = "rbxasset://textures/particles/smoke_main.dds",
    },
}

StormConfig.RainDrops = {
    lengthRange = { 5.5, 13 },
    speedRange = { 52, 95 },
    lifetimeRange = { 0.45, 0.9 },
    tiltFactor = 0.28,
    sway = {
        amplitude = 2.2,
        frequency = { 0.35, 0.8 },
    },
    spawnRegion = {
        radius = 18,
        back = 6,
        front = 26,
        above = 14,
        belowCull = 4,
    },
}

StormConfig.EdgeBand = {
    texture = "rbxasset://textures/particles/laser.dds",
    scroll = 1.1,
    alpha = 0.35,
    widthOscHz = { 0.2, 0.55 },
}

StormConfig.Splashes = {
    lifetime = 0.32,
    ringInner = 4.2,
    ringOuter = 9.5,
    ratePerSec = {
        HIGH = 8,
        MED = 5,
        LOW = 0,
    },
}

StormConfig.Shells = {
    radii = { 28, 42, 58 },
    speeds = { 36, 28, 22 },
    rates = { 85, 60, 38 },
    particleTexture = "rbxasset://textures/particles/rain_main.dds",
    particleLifetime = NumberRange.new(0.5, 0.9),
    particleSpeed = NumberRange.new(36, 48),
    particleSpread = Vector2.new(6, 12),
    wedgePadDeg = 6,
    cameraUpOffset = 18,
    forwardOffset = 4,
}

StormConfig.Overlays = {
    vignette = "rbxassetid://0",
    lens = "rbxassetid://0",
}

-- LEGACY: Original WindGusts config (keeping for fallback)
StormConfig.WindGusts = {
    lifetime = { min = 0.6, max = 1.2 }, 
    spawnDistance = 220,
    lateralJitter = Vector2.new(15, 10), 
    verticalOffset = { min = -8, max = 12 }, 
    speedRange = { 35, 50 }, 
    texture = "rbxasset://textures/particles/smoke_main.dds",
    widthRange = { 15, 28 }, 
    fadeFraction = 0.25, 
    alpha = 0.75, 
}

StormConfig.Fog = {
    densityScale = 0.18,
    offsetScale = 0.3,
    smoothing = 0.35,
    pulseInterval = { 6, 10 },
    pulseStrength = 0.12,
}

local maxShellRadius = StormConfig.Shells.radii[#StormConfig.Shells.radii]

StormConfig.DistantWind = {
    radius = maxShellRadius + 35, 
    radiusJitter = 15, 
    heightRange = { 22, 36 },
    texture = "rbxasset://textures/particles/smoke_main.dds",
    alpha = 0.45, 
    followLerp = 0.18,
    swaySpeed = { 0.05, 0.12 },
    jitterAmplitude = { lateral = 10, vertical = 5 },
    jitterSpeed = { 0.3, 0.6 },
    widthRange = { 25, 40 }, 
    heightRange = { 30, 50 }, 
}

-- ENHANCED: Higher particle counts for dense storm
StormConfig.Perf = {
    HIGH = {
        beamsRingCount = 4,
        beamsPerRing = 24,
        shells = 3,
        shellSegs = 24,
        overlays = true,
        splashes = false,
        dropsMax = 170,
        dropsRatePerSec = 240,
        dropSpawnRateMultiplier = 1.0,
        splashRate = StormConfig.Splashes.ratePerSec.HIGH,
        gustsMax = 20, -- MUCH higher for dense storm (was 8)
        fogLayers = 2,
        distantSheets = 3,
    },
    MED = {
        beamsRingCount = 3,
        beamsPerRing = 16,
        shells = 2,
        shellSegs = 18,
        overlays = true,
        splashes = false,
        dropsMax = 110,
        dropsRatePerSec = 150,
        dropSpawnRateMultiplier = 0.75,
        splashRate = StormConfig.Splashes.ratePerSec.MED,
        gustsMax = 15, -- Higher for dense storm (was 6)
        fogLayers = 1,
        distantSheets = 2,
    },
    LOW = {
        beamsRingCount = 2,
        beamsPerRing = 12,
        shells = 1,
        shellSegs = 12,
        overlays = false,
        splashes = false,
        dropsMax = 70,
        dropsRatePerSec = 85,
        dropSpawnRateMultiplier = 0.55,
        splashRate = StormConfig.Splashes.ratePerSec.LOW,
        gustsMax = 10, -- Higher for dense storm (was 4)
        fogLayers = 1,
        distantSheets = 1,
    },
}

StormConfig.Rings = {
    radii = { 10, 18, 26, 34 },
    widthJitterHz = { 0.6, 1.1 },
    beam = {
        texture = "rbxasset://textures/particles/rain_main.dds",
        textureLength = 1.1,
        textureSpeed = 1.4,
        width = { min = 0.025, max = 0.07 },
        alpha = 0.46,
    },
}

StormConfig.Profiles = {
    RAIN_HEAVY = { intensity = 0.8, gusts = {} },
    RAIN_LIGHT = { intensity = 0.4, gusts = {} },
    SNOW =       { intensity = 0.5, gusts = {} },
    DUST =       { intensity = 0.6, gusts = {} },
}

return StormConfig
