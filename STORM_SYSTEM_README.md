# Enhanced Storm System for QuietWinds

## Overview
The Enhanced Storm System provides a mobile-optimized, violent storm experience with dynamic weather effects and lantern-based visibility mechanics. The system automatically adapts to device performance to maintain smooth gameplay.

## Features

### 1. **Violent Storm Effects**
- Heavy wind gusts with volumetric fog layers
- Dynamic particle system for rain/snow/dust
- Multi-layered wind sheets for depth perception
- Turbulent particle physics simulating chaotic weather

### 2. **Mobile Optimization**
- Automatic LOD (Level of Detail) system
- Dynamic quality adjustment based on FPS
- Object pooling to reduce memory allocation
- Configurable update rates for different subsystems

### 3. **Lantern Visibility System**
- Cone-based visibility enhancement
- Particles become transparent within lantern cone
- Fog density reduction in viewing direction
- Smooth transitions for immersive experience

### 4. **Performance Profiles**
- `MOBILE_LOW`: 30 particles, 3 wind layers, basic effects
- `MOBILE_MED`: 60 particles, 5 wind layers, medium quality
- `DESKTOP_LOW`: 100 particles, 8 wind layers, enhanced effects
- `DESKTOP_HIGH`: 200 particles, 12 wind layers, full effects

## Installation

### Files Added:
```
src/client/Storm/
├── WeatherSystem.client.luau          # Unified weather controller
├── EnhancedStormConfig.luau          # Configuration and parameters
├── EnhancedStormController.client.luau # Main storm controller
└── StormSystemLoader.client.luau     # System loader and selector
```

### Integration Steps:

1. **Enable the Enhanced System**
   - Open `StormSystemLoader.client.luau`
   - Set `USE_ENHANCED_STORM = true`

2. **Add Custom Sprites/Textures**
   Replace placeholder texture IDs in `EnhancedStormConfig.luau`:
   ```lua
   textures = {
       "rbxassetid://YOUR_WIND_TEXTURE_1", -- Wind gust sprite
       "rbxassetid://YOUR_WIND_TEXTURE_2", -- Secondary wind sprite
       "rbxassetid://YOUR_RAIN_TEXTURE",   -- Rain/snow texture
   }
   ```

3. **Configure Storm Parameters**
   Adjust values in `EnhancedStormConfig.luau`:
   ```lua
   ViolentStorm = {
       wind = {
           baseSpeed = 45,        -- Adjust wind speed
           gustMultiplier = 2.5,  -- Peak gust strength
           turbulenceScale = 5,   -- Chaos level
       },
       visibility = {
           minDistance = 20,      -- Minimum visibility
           fogDensity = 0.6,      -- Maximum fog thickness
       }
   }
   ```

## Sprite Requirements

### Wind Gust Sprites
- **Format**: Semi-transparent PNG with alpha channel
- **Recommended Size**: 512x512 or 1024x1024
- **Style**: Horizontal streaks or cloud-like formations
- **Color**: Light gray to white (will be tinted in-game)
- **Examples**: Fog wisps, dust clouds, rain sheets

### Rain/Snow Particles
- **Format**: Vertical streak or droplet shape
- **Size**: 64x256 for rain streaks, 128x128 for snow
- **Style**: Motion blur effect for rain, soft edges for snow
- **Alpha**: Gradient transparency from center to edges

## Usage

### Server-Side Control
The system integrates with your existing `StormService`:

```lua
-- Start a violent storm
StormService:InitStorm("RAIN_HEAVY", Vector3.new(1, 0, 0.5))

-- Adjust intensity dynamically
StormService:SetIntensity(0.8)

-- Stop the storm
StormService:StopStorm()
```

### Client-Side API

```lua
-- Get the weather controller
local weatherSystem = require(game.ReplicatedStorage.Client.Storm.WeatherSystem)

-- Manual control (for testing)
weatherSystem.setIntensity(0.9)
weatherSystem.setWind(Vector3.new(1, 0, 1))
weatherSystem.setLOD("MOBILE_LOW") -- Force specific quality
```

## Performance Tuning

### For Mobile Devices
1. **Reduce Particle Count**
   ```lua
   DeviceProfiles.MOBILE_LOW.maxParticles = 20
   ```

2. **Lower Update Rates**
   ```lua
   updateFrequency = {
       particles = 15,  -- Lower from 30
       windSheets = 10, -- Lower from 15
   }
   ```

3. **Simplify Effects**
   ```lua
   MobileOptimizations = {
       useSimpleTransparency = true,
       disableShadows = true,
       textureQuality = "Low",
   }
   ```

### FPS Monitoring
The system automatically adjusts quality based on FPS:
- < 20 FPS: Switches to ULTRA_LOW
- < 25 FPS: Switches to LOW
- < 30 FPS: Switches to MEDIUM
- > 50 FPS: Allows HIGH quality

## Troubleshooting

### Storm Not Appearing
1. Check if StormService is initialized on server
2. Verify remotes are properly connected
3. Ensure intensity > 0

### Poor Performance
1. Check device profile detection
2. Reduce particle counts
3. Lower wind layer count
4. Increase culling distances

### Particles Not Fading in Lantern Cone
1. Verify lantern state is being updated
2. Check cone angle configuration
3. Ensure camera direction is tracked

## Customization Examples

### Winter Storm (Blizzard)
```lua
EnhancedStormConfig.ViolentStorm = {
    wind = {
        baseSpeed = 30,        -- Slower for snow
        gustMultiplier = 3.0,  -- Stronger gusts
        turbulenceScale = 8,   -- More swirling
    },
    particles = {
        rainSpeed = 20,        -- Slow falling snow
        rainAngle = 35,        -- More horizontal
    }
}
```

### Sandstorm
```lua
EnhancedStormConfig.ViolentStorm = {
    visibility = {
        fogDensity = 0.8,      -- Very thick
        fogColor = Color3.new(0.8, 0.7, 0.5), -- Sandy color
    },
    wind = {
        baseSpeed = 60,        -- Fast sand movement
        turbulenceScale = 10,  -- Extreme chaos
    }
}
```

## Future Improvements

### Planned Features:
1. **Audio System Integration**
   - 3D positional wind sounds
   - Dynamic rain intensity audio
   - Thunder/lightning effects

2. **Advanced Particle Types**
   - Hail with bounce physics
   - Debris objects in extreme winds
   - Water puddle accumulation

3. **Weather Transitions**
   - Smooth transitions between weather types
   - Time-of-day integration
   - Seasonal weather patterns

4. **Networking Optimization**
   - Delta compression for state updates
   - Predictive particle spawning
   - Synchronized gust events

## Debug Commands

In Studio, you can test the storm system:
```
/storm start RAIN_HEAVY  -- Start heavy rain
/storm intensity 0.5     -- Set intensity to 50%
/storm vector 1 0 0     -- Set wind direction
/storm stop             -- Stop the storm
```

## Credits
Enhanced Storm System developed for QuietWinds
Optimized for mobile performance while maintaining visual fidelity
