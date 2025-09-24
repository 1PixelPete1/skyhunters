# 3D Storm Volumes System

## Overview

Completely redesigned the weather system to use **actual 3D storm cells** positioned in world space instead of camera-relative billboard effects. This creates the feeling of being **inside a real storm** rather than watching effects float past the camera.

## How It Works

### 🌪️ **Storm Volume Architecture**

Instead of effects that follow the camera, we now have **fixed storm cells** at specific world positions:

```lua
-- Distant horizon storm walls (400+ studs away)
HorizonWall_North: 600×120×80 studs at (0, 80, -400)
HorizonWall_East:  60×100×400 studs at (350, 60, -100)

-- Mid-distance rain bands (100-200 studs) 
RainBand_West:     40×80×200 studs at (-180, 40, 50)
RainBand_Southwest: 80×70×60 studs at (-120, 35, 150)

-- Near approaching cells (50-100 studs)
ApproachCell_1:    60×50×40 studs at (80, 25, -80)
ApproachCell_2:    40×45×50 studs at (-60, 30, -60)
```

### ⚡ **Key Differences from Billboard System**

**OLD SYSTEM:**
- Effects spawn relative to camera
- Always face camera (artificial looking)
- Move past player in straight lines
- Distance ≈ 55 studs (too close)

**NEW SYSTEM:**
- Storm volumes exist in world space
- Player moves **through** the storm
- Natural parallax from camera movement
- Distances: 50-400+ studs (realistic scale)
- 3D turbulence and wind physics

### 🎯 **Layered Storm Structure**

1. **Horizon Layer** (300-400 studs): Massive storm walls on the horizon
2. **Approach Layer** (100-200 studs): Rain bands sweeping toward player
3. **Immersion Layer** (50-100 studs): Dense storm cells around player
4. **Contact Layer** (20-50 studs): Near-field effects

### 🌊 **3D Turbulence System**

Particles now move with realistic 3D wind patterns:
```lua
-- Real turbulence calculation
turbulence = Vector3(
    sin(x + time) * cos(y + time*0.7) * 0.3,
    cos(x + time*1.3) * sin(z + time*0.9) * 0.2, 
    sin(y + time*0.8) * cos(z + time*1.1) * 0.4
)
```

- **X-axis**: Horizontal wind shear
- **Y-axis**: Vertical updrafts/downdrafts  
- **Z-axis**: Forward/backward wind bursts

### 📐 **Natural Perspective**

- **Distance Fade**: Particles become less visible with distance
- **Atmospheric Perspective**: Color shifts toward sky color at distance
- **Size Scaling**: Larger effects appear smaller when distant
- **Parallax Motion**: Distant volumes move slower than near ones

## Performance Benefits

- **More Efficient**: Fixed number of volumes, not constantly spawning/destroying
- **Better Culling**: Easy to disable volumes outside view frustum  
- **Scalable**: Can reduce volume count/complexity on lower-end devices
- **Predictable**: No sudden spawning bursts causing frame drops

## Visual Results

### What Players Experience:

1. **Immersion**: Feels like being inside a real storm system
2. **Scale**: Massive storm walls on horizon create sense of scale  
3. **Movement**: Walking around reveals storm from different angles
4. **Depth**: Clear layering from near to far effects
5. **Realism**: Storm moves and evolves naturally over time

### Lantern Integration:

- Storm particles fade in lantern cone (30% visibility)
- Volumes continue existing regardless of lantern state
- Natural depth perception makes lantern feel more valuable
- Player can see storm structure extending beyond lantern range

## Configuration

The system is fully configurable in `StormConfig.StormVolumes`:

```lua
-- Volume layout
layers = {
    horizon = { distance = 350, size = 600, intensity = 1.0 },
    approach = { distance = 150, size = 200, intensity = 0.8 },
    immersion = { distance = 80, size = 100, intensity = 0.6 },
    contact = { distance = 30, size = 50, intensity = 0.4 },
}

-- Physics
turbulenceStrength = 5
stormDriftSpeed = 2  
followCamera = 0.3  -- Slight camera following for gameplay
```

## Testing Notes

- Storm should feel **surrounding** rather than **approaching**
- Effects should have **realistic scale** (some volumes are 600+ studs wide)  
- **Parallax motion** should be obvious when moving camera
- **Depth layers** should be clearly distinguishable
- Storm should feel **persistent** and **immersive**

This creates the authentic "violent storm" experience you wanted - no more floating effects in front of the camera!
