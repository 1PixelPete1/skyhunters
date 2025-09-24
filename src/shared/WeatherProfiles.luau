--!strict
-- WeatherProfiles.luau
-- Modular weather configuration system for different weather types and intensities
-- Optimized for different performance tiers

export type WeatherComponent = {
    enabled: boolean,
    intensity: number, -- 0-1 multiplier
    config: {[string]: any}?, -- Component-specific config overrides
}

export type WeatherProfile = {
    name: string,
    description: string,
    
    -- Component toggles and intensities
    blizzardSprites: WeatherComponent,
    rainWall: WeatherComponent,
    rotatingWindSprites: WeatherComponent,
    rainShells: WeatherComponent,
    rainBeams: WeatherComponent,
    windGusts: WeatherComponent,
    
    -- Global weather parameters
    windDirection: Vector3,
    windSpeed: number,
    rainAngle: number, -- Degrees from vertical
    
    -- Atmosphere settings
    atmosphere: {
        densityAdd: number,
        offsetAdd: number,
        hazeAdd: number,
        color: Color3,
        colorBlend: number, -- 0-1 blend with original
    },
    
    -- Performance scaling
    mobileScale: number, -- 0-1 scale for mobile devices
}

local WeatherProfiles = {}

-- Performance tier configurations
WeatherProfiles.PerformanceScaling = {
    HIGH = {
        particleScale = 1.0,
        distanceScale = 1.0,
        updateRate = 60, -- Hz
    },
    MED = {
        particleScale = 0.6,
        distanceScale = 0.8,
        updateRate = 30,
    },
    LOW = {
        particleScale = 0.3,
        distanceScale = 0.6,
        updateRate = 20,
    },
}

-- PRESET WEATHER PROFILES

WeatherProfiles.Profiles = {}

-- Clear weather (no effects)
WeatherProfiles.Profiles.CLEAR = {
    name = "Clear",
    description = "Clear skies, no weather effects",
    
    blizzardSprites = {enabled = false, intensity = 0},
    rainWall = {enabled = false, intensity = 0},
    rotatingWindSprites = {enabled = false, intensity = 0},
    rainShells = {enabled = false, intensity = 0},
    rainBeams = {enabled = false, intensity = 0},
    windGusts = {enabled = false, intensity = 0},
    
    windDirection = Vector3.new(0.1, 0, -0.1),
    windSpeed = 5,
    rainAngle = 0,
    
    atmosphere = {
        densityAdd = 0,
        offsetAdd = 0,
        hazeAdd = 0,
        color = Color3.fromRGB(200, 210, 255),
        colorBlend = 0,
    },
    
    mobileScale = 1.0,
}

-- Light rain
WeatherProfiles.Profiles.RAIN_LIGHT = {
    name = "Light Rain",
    description = "Gentle rainfall with minimal wind",
    
    blizzardSprites = {enabled = false, intensity = 0},
    rainWall = {enabled = true, intensity = 0.3},
    rotatingWindSprites = {enabled = false, intensity = 0},
    rainShells = {enabled = true, intensity = 0.4},
    rainBeams = {enabled = true, intensity = 0.4},
    windGusts = {enabled = false, intensity = 0},
    
    windDirection = Vector3.new(0.2, 0, -0.8).Unit,
    windSpeed = 15,
    rainAngle = 10,
    
    atmosphere = {
        densityAdd = 0.2,
        offsetAdd = -0.1,
        hazeAdd = 1,
        color = Color3.fromRGB(150, 160, 170),
        colorBlend = 0.3,
    },
    
    mobileScale = 0.8,
}

-- Heavy rain
WeatherProfiles.Profiles.RAIN_HEAVY = {
    name = "Heavy Rain",
    description = "Intense rainfall with strong winds",
    
    blizzardSprites = {enabled = true, intensity = 0.3, config = {
        nearCount = 5,
        midCount = 8,
        farCount = 10,
    }},
    rainWall = {enabled = true, intensity = 0.8},
    rotatingWindSprites = {enabled = true, intensity = 0.5},
    rainShells = {enabled = true, intensity = 0.9},
    rainBeams = {enabled = true, intensity = 0.9},
    windGusts = {enabled = false, intensity = 0},
    
    windDirection = Vector3.new(0.4, 0, -0.7).Unit,
    windSpeed = 35,
    rainAngle = 15,
    
    atmosphere = {
        densityAdd = 0.5,
        offsetAdd = -0.2,
        hazeAdd = 3,
        color = Color3.fromRGB(100, 110, 120),
        colorBlend = 0.6,
    },
    
    mobileScale = 0.5, -- Reduce effects on mobile
}

-- Thunderstorm
WeatherProfiles.Profiles.THUNDERSTORM = {
    name = "Thunderstorm",
    description = "Violent storm with heavy rain and wind",
    
    blizzardSprites = {enabled = true, intensity = 0.7},
    rainWall = {enabled = true, intensity = 1.0},
    rotatingWindSprites = {enabled = true, intensity = 0.8},
    rainShells = {enabled = true, intensity = 1.0},
    rainBeams = {enabled = true, intensity = 1.0},
    windGusts = {enabled = true, intensity = 0.5},
    
    windDirection = Vector3.new(0.5, -0.1, -0.6).Unit,
    windSpeed = 50,
    rainAngle = 20,
    
    atmosphere = {
        densityAdd = 0.7,
        offsetAdd = -0.3,
        hazeAdd = 4,
        color = Color3.fromRGB(70, 80, 90),
        colorBlend = 0.8,
    },
    
    mobileScale = 0.3, -- Heavy reduction for mobile
}

-- Blizzard
WeatherProfiles.Profiles.BLIZZARD = {
    name = "Blizzard",
    description = "Heavy snow with strong winds",
    
    blizzardSprites = {enabled = true, intensity = 1.0, config = {
        texture = "rbxasset://textures/particles/sparkle_main.dds", -- Snow texture
        nearCount = 15,
        midCount = 20,
        farCount = 25,
    }},
    rainWall = {enabled = false, intensity = 0}, -- No rain wall for snow
    rotatingWindSprites = {enabled = true, intensity = 1.0},
    rainShells = {enabled = false, intensity = 0}, -- No rain for blizzard
    rainBeams = {enabled = false, intensity = 0},
    windGusts = {enabled = true, intensity = 0.8},
    
    windDirection = Vector3.new(0.6, 0, -0.5).Unit,
    windSpeed = 45,
    rainAngle = 25, -- Snow drifts more
    
    atmosphere = {
        densityAdd = 0.8,
        offsetAdd = -0.4,
        hazeAdd = 5,
        color = Color3.fromRGB(200, 210, 220),
        colorBlend = 0.7,
    },
    
    mobileScale = 0.4,
}

-- Fog
WeatherProfiles.Profiles.FOG = {
    name = "Fog",
    description = "Dense fog with minimal wind",
    
    blizzardSprites = {enabled = true, intensity = 0.2, config = {
        nearCount = 3,
        midCount = 5,
        farCount = 8,
        baseSpeed = 5, -- Very slow movement
    }},
    rainWall = {enabled = false, intensity = 0},
    rotatingWindSprites = {enabled = false, intensity = 0},
    rainShells = {enabled = false, intensity = 0},
    rainBeams = {enabled = false, intensity = 0},
    windGusts = {enabled = false, intensity = 0},
    
    windDirection = Vector3.new(0.1, 0, -0.1).Unit,
    windSpeed = 5,
    rainAngle = 0,
    
    atmosphere = {
        densityAdd = 1.0,
        offsetAdd = -0.5,
        hazeAdd = 8,
        color = Color3.fromRGB(150, 155, 160),
        colorBlend = 0.5,
    },
    
    mobileScale = 0.7,
}

-- Dust storm
WeatherProfiles.Profiles.DUST_STORM = {
    name = "Dust Storm",
    description = "Swirling dust and sand",
    
    blizzardSprites = {enabled = true, intensity = 0.8, config = {
        texture = "rbxasset://textures/particles/smoke_main.dds",
        color1 = Color3.fromRGB(180, 150, 100), -- Sandy color
        color2 = Color3.fromRGB(160, 130, 80),
    }},
    rainWall = {enabled = false, intensity = 0},
    rotatingWindSprites = {enabled = true, intensity = 0.7},
    rainShells = {enabled = false, intensity = 0},
    rainBeams = {enabled = false, intensity = 0},
    windGusts = {enabled = true, intensity = 0.6},
    
    windDirection = Vector3.new(0.7, 0, -0.4).Unit,
    windSpeed = 40,
    rainAngle = 0,
    
    atmosphere = {
        densityAdd = 0.6,
        offsetAdd = -0.2,
        hazeAdd = 6,
        color = Color3.fromRGB(180, 150, 100),
        colorBlend = 0.6,
    },
    
    mobileScale = 0.5,
}

-- Helper function to blend between profiles
function WeatherProfiles.BlendProfiles(profile1: WeatherProfile, profile2: WeatherProfile, blend: number): WeatherProfile
    blend = math.clamp(blend, 0, 1)
    
    local blended = {
        name = string.format("%s-%s", profile1.name, profile2.name),
        description = "Blended weather",
        
        blizzardSprites = {
            enabled = profile1.blizzardSprites.enabled or profile2.blizzardSprites.enabled,
            intensity = profile1.blizzardSprites.intensity * (1-blend) + profile2.blizzardSprites.intensity * blend,
            config = profile2.blizzardSprites.config, -- Use second profile's config
        },
        rainWall = {
            enabled = profile1.rainWall.enabled or profile2.rainWall.enabled,
            intensity = profile1.rainWall.intensity * (1-blend) + profile2.rainWall.intensity * blend,
        },
        rotatingWindSprites = {
            enabled = profile1.rotatingWindSprites.enabled or profile2.rotatingWindSprites.enabled,
            intensity = profile1.rotatingWindSprites.intensity * (1-blend) + profile2.rotatingWindSprites.intensity * blend,
        },
        rainShells = {
            enabled = profile1.rainShells.enabled or profile2.rainShells.enabled,
            intensity = profile1.rainShells.intensity * (1-blend) + profile2.rainShells.intensity * blend,
        },
        rainBeams = {
            enabled = profile1.rainBeams.enabled or profile2.rainBeams.enabled,
            intensity = profile1.rainBeams.intensity * (1-blend) + profile2.rainBeams.intensity * blend,
        },
        windGusts = {
            enabled = profile1.windGusts.enabled or profile2.windGusts.enabled,
            intensity = profile1.windGusts.intensity * (1-blend) + profile2.windGusts.intensity * blend,
        },
        
        windDirection = profile1.windDirection:Lerp(profile2.windDirection, blend),
        windSpeed = profile1.windSpeed * (1-blend) + profile2.windSpeed * blend,
        rainAngle = profile1.rainAngle * (1-blend) + profile2.rainAngle * blend,
        
        atmosphere = {
            densityAdd = profile1.atmosphere.densityAdd * (1-blend) + profile2.atmosphere.densityAdd * blend,
            offsetAdd = profile1.atmosphere.offsetAdd * (1-blend) + profile2.atmosphere.offsetAdd * blend,
            hazeAdd = profile1.atmosphere.hazeAdd * (1-blend) + profile2.atmosphere.hazeAdd * blend,
            color = profile1.atmosphere.color:Lerp(profile2.atmosphere.color, blend),
            colorBlend = profile1.atmosphere.colorBlend * (1-blend) + profile2.atmosphere.colorBlend * blend,
        },
        
        mobileScale = profile1.mobileScale * (1-blend) + profile2.mobileScale * blend,
    }
    
    return blended :: WeatherProfile
end

-- Get profile with performance scaling
function WeatherProfiles.GetScaledProfile(profileName: string, perfTier: string): WeatherProfile?
    local profile = WeatherProfiles.Profiles[profileName]
    if not profile then
        warn("[WeatherProfiles] Unknown profile:", profileName)
        return nil
    end
    
    local scaling = WeatherProfiles.PerformanceScaling[perfTier] or WeatherProfiles.PerformanceScaling.MED
    
    -- Clone and scale the profile
    local scaled = table.clone(profile) :: any
    
    -- Apply performance scaling
    local particleScale = scaling.particleScale
    
    -- Scale sprite counts
    if scaled.blizzardSprites.config then
        if scaled.blizzardSprites.config.nearCount then
            scaled.blizzardSprites.config.nearCount = math.ceil(scaled.blizzardSprites.config.nearCount * particleScale)
        end
        if scaled.blizzardSprites.config.midCount then
            scaled.blizzardSprites.config.midCount = math.ceil(scaled.blizzardSprites.config.midCount * particleScale)
        end
        if scaled.blizzardSprites.config.farCount then
            scaled.blizzardSprites.config.farCount = math.ceil(scaled.blizzardSprites.config.farCount * particleScale)
        end
    end
    
    -- Apply mobile scaling if on mobile
    if perfTier == "LOW" then
        local mobileScale = profile.mobileScale
        scaled.blizzardSprites.intensity *= mobileScale
        scaled.rainWall.intensity *= mobileScale
        scaled.rotatingWindSprites.intensity *= mobileScale
        scaled.rainShells.intensity *= mobileScale
        scaled.rainBeams.intensity *= mobileScale
        scaled.windGusts.intensity *= mobileScale
    end
    
    return scaled :: WeatherProfile
end

return WeatherProfiles
