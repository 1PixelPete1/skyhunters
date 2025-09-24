--!strict
-- EnhancedStormConfig.luau
-- Optimized storm configuration for mobile with violent storm parameters

local EnhancedStormConfig = {}

-- Feature toggles
EnhancedStormConfig.Features = {
    enableParticles = false, -- Use legacy rain/beams by default
    enableWindSheets = false, -- Disable billboard wind sheets to avoid screen-tracking fog
    enableGusts = true, -- Enable large sand/snow gust cards
    enableMidRainSprites = true, -- Use mid-distance rain sprite quads
    enableFarRainCurtain = true, -- Use distant rain curtain cards
};

-- Performance profiles for different devices
EnhancedStormConfig.DeviceProfiles = {
    MOBILE_LOW = {
        maxParticles = 30,
        maxWindLayers = 3,
        fogLayers = 1,
        updateRate = 0.1, -- 10 FPS for effects
        renderDistance = 60,
        shadowsEnabled = false,
    },
    MOBILE_MED = {
        maxParticles = 60,
        maxWindLayers = 5,
        fogLayers = 2,
        updateRate = 0.05, -- 20 FPS for effects
        renderDistance = 100,
        shadowsEnabled = false,
    },
    DESKTOP_LOW = {
        maxParticles = 100,
        maxWindLayers = 8,
        fogLayers = 3,
        updateRate = 0.033, -- 30 FPS
        renderDistance = 150,
        shadowsEnabled = true,
    },
    DESKTOP_HIGH = {
        maxParticles = 200,
        maxWindLayers = 12,
        fogLayers = 5,
        updateRate = 0.016, -- 60 FPS
        renderDistance = 250,
        shadowsEnabled = true,
    },
};
-- Violent storm parameters
EnhancedStormConfig.ViolentStorm = {
    -- Wind configuration for heavy gusts
    wind = {
        baseSpeed = 45, -- Base wind speed in studs/sec
        gustMultiplier = 2.5, -- Peak gust strength
        gustFrequency = 0.3, -- How often gusts occur
        turbulenceScale = 5, -- Chaos in particle movement
        directionVariance = 30, -- Degrees of wind direction change
    },
    
    -- Visibility reduction
    visibility = {
        minDistance = 20, -- Minimum visibility in heavy storm
        maxDistance = 100, -- Maximum visibility with lantern
        fogDensity = 0.6, -- Maximum fog density
        fogColor = Color3.new(0.5, 0.55, 0.6), -- Dark grey-blue fog
    },
    
    -- Particle behavior
    particles = {
        rainSpeed = 80, -- Fast rain/snow fall speed
        rainAngle = 25, -- Degrees from vertical due to wind
        spawnRadius = 30, -- Spawn area around player
        lifetime = 1.0, -- Particle lifetime in seconds
        sizeVariance = 0.5, -- Size variation factor
    },
    
    -- Sound parameters (for future implementation)
    sound = {
        windVolume = 0.8,
        rainVolume = 0.7,
        thunderChance = 0.1, -- Chance per second
        thunderVolumeRange = {0.6, 1.0},
    },
}

-- Lantern visibility system
EnhancedStormConfig.Lantern = {
    -- Cone parameters
    cone = {
        angle = 35, -- Cone angle in degrees
        nearDistance = 10, -- Clear visibility distance
        farDistance = 40, -- Maximum enhanced visibility
        falloffPower = 2, -- How sharply visibility falls off
    },
    
    -- Particle transparency in cone
    particleVisibility = {
        inCone = 0.1, -- 90% transparent in cone
        outCone = 0.7, -- 30% transparent outside
        transitionSpeed = 5, -- Lerp speed for smooth transitions
    },
    
    -- Fog modulation
    fogModulation = {
        coneReduction = 0.6, -- Reduce fog by 60% in cone
        transitionWidth = 10, -- Degrees of soft transition
    },
}

-- Wind sheet/sprite configuration
EnhancedStormConfig.WindSheets = {
    -- Layer configuration
    layers = {
        {distance = 30, size = 20, opacity = 0.3, speed = 1.0},
        {distance = 50, size = 30, opacity = 0.25, speed = 0.8},
        {distance = 80, size = 45, opacity = 0.2, speed = 0.6},
        {distance = 120, size = 60, opacity = 0.15, speed = 0.4},
        {distance = 180, size = 80, opacity = 0.1, speed = 0.2},
    },
    
    -- Animation parameters
    animation = {
        swayAmount = 10, -- Horizontal sway in studs
        swaySpeed = 0.5, -- Sway frequency
        rotationSpeed = 0.1, -- Slow rotation for variety
        scaleOscillation = 0.2, -- Size pulsing
    },
    
    -- Texture placeholders (replace with actual asset IDs)
    textures = {
        "rbxasset://textures/particles/smoke_main.dds", -- Placeholder 1
        "rbxasset://textures/particles/sparkles_main.dds", -- Placeholder 2
        "rbxasset://textures/particles/fire_main.dds", -- Placeholder 3
    },
}

-- Gust sheet configuration
EnhancedStormConfig.Gusts = {
    poolSize = 8,
    maxActive = 5,
    baseOpacity = 0.65,
    cardWidth = 18,
    cardHeight = 26,
    cardThickness = 0.4,
    cardColor = Color3.fromRGB(225, 208, 186),
    cardTransparency = 0.35,
    spawnInterval = 0.75,
    distanceRange = { min = 35, max = 80 },
    lateralJitter = 24,
    verticalOffset = 6,
    verticalJitter = 6,
    speedRange = { min = 28, max = 40 },
    lifetimeRange = { min = 3.5, max = 5.5 },
    fadeIn = 0.25,
    fadeOut = 0.35,
    swayAmplitude = 8,
    swaySpeed = 0.8,
    verticalSwayAmplitude = 2,
    verticalSwaySpeed = 0.6,
    lanternFadeMultiplier = 0.18,
    perspective = {
        forwardPush = 8,
        sideOffset = 6,
        sideCurve = 0.4,
        verticalLift = 1.5,
        cameraFollow = 0.35,
    },
    textures = {
        "",
    },
};

-- Rain layer configuration
EnhancedStormConfig.RainLayers = {
    mid = {
        poolSize = 40,
        spawnRate = 30,
        spawnRadius = 45,
        spawnHeight = 18,
        fallSpeed = 40,
        windDrift = 12,
        lifeSeconds = 2.6,
        sizeRange = { min = 2.5, max = 5.0 },
        killPlaneOffset = 6,
        color = Color3.fromRGB(198, 209, 224),
        baseTransparency = 0.4,
        textures = {
            "",
        },
    },
    far = {
        enabled = true,
        distance = 140,
        size = { width = 220, height = 140 },
        color = Color3.fromRGB(184, 194, 209),
        transparency = 0.55,
        swapInterval = 1.8,
        jitterAmplitude = 6,
        jitterSpeed = 0.7,
        textures = {
            "",
            "",
        },
    },
};

-- Optimization settings
EnhancedStormConfig.Optimization = {
    -- Culling distances by LOD
    cullDistance = {
        MOBILE_LOW = 80,
        MOBILE_MED = 120,
        DESKTOP_LOW = 180,
        DESKTOP_HIGH = 300,
    },
    
    -- Update frequencies (times per second)
    updateFrequency = {
        particles = 30, -- Particle physics
        windSheets = 15, -- Wind sheet animation
        fog = 5, -- Fog density changes
        lantern = 60, -- Lantern cone updates
    },
    
    -- Memory pools
    poolSizes = {
        particles = 200, -- Pre-allocate this many particles
        windSheets = 15, -- Pre-allocate wind sheets
        soundEmitters = 10, -- For positional audio
    },

    maxParticleCatchup = 0.2, -- Seconds of catch-up allowed when spawning particles
    maxParticleBurst = 25, -- Max new particles spawned per update step
}

-- Storm intensity levels
EnhancedStormConfig.IntensityLevels = {
    CLEAR = {
        intensity = 0,
        fogDensity = 0,
        particleRate = 0,
        windStrength = 0,
    },
    LIGHT = {
        intensity = 0.3,
        fogDensity = 0.15,
        particleRate = 0.3,
        windStrength = 0.2,
    },
    MODERATE = {
        intensity = 0.6,
        fogDensity = 0.35,
        particleRate = 0.6,
        windStrength = 0.5,
    },
    HEAVY = {
        intensity = 0.85,
        fogDensity = 0.55,
        particleRate = 0.85,
        windStrength = 0.8,
    },
    VIOLENT = {
        intensity = 1.0,
        fogDensity = 0.75,
        particleRate = 1.0,
        windStrength = 1.0,
    },
}

-- Dynamic weather transitions
EnhancedStormConfig.Transitions = {
    -- Transition speeds (0-1 per second)
    speeds = {
        intensity = 0.1, -- Slow intensity changes
        wind = 0.2, -- Faster wind changes
        fog = 0.05, -- Very slow fog changes
    },
    
    -- Gust patterns
    gustPatterns = {
        {duration = 2, strength = 1.5, fadeIn = 0.5, fadeOut = 1.0},
        {duration = 3, strength = 2.0, fadeIn = 0.3, fadeOut = 1.5},
        {duration = 1, strength = 2.5, fadeIn = 0.2, fadeOut = 0.5},
        {duration = 4, strength = 1.8, fadeIn = 1.0, fadeOut = 2.0},
    },
}

-- Mobile-specific optimizations
EnhancedStormConfig.MobileOptimizations = {
    -- Reduce particle count dynamically
    dynamicParticleScaling = true,
    minParticleScale = 0.3, -- Minimum particle count multiplier
    
    -- Simplify shaders
    useSimpleTransparency = true,
    disableReflections = true,
    disableShadows = true,
    
    -- Reduce texture resolution
    textureQuality = "Low", -- Low, Medium, High
    
    -- Batch rendering
    batchSize = 10, -- Group particles for rendering
    
    -- Frame skipping
    allowFrameSkip = true,
    maxFrameSkip = 2, -- Skip up to 2 frames if needed
}

return EnhancedStormConfig










