# Dense Storm Wall System

## Overview

Completely rebuilt the weather system to create **THICK, OPPRESSIVE STORM** conditions where players **cannot see without the lantern**. Uses high particle density + screen overlays for maximum visual impact with reasonable performance.

## 🌪️ **Dense Storm Architecture**

### **Multi-Layer Particle System**
```lua
Layer 1 (Close):     25 studs - High detail, fast movement, size 4-6
Layer 2 (Mid):       60 studs - Medium detail, medium speed, size 6-9  
Layer 3 (Far):      120 studs - Low detail, slow speed, size 8-12
Layer 4 (Background): 200 studs - Very low detail, drift, size 12-18
```

### **Massive Particle Count**
- **HIGH Performance**: 300+ active particles (20 × 15 multiplier)
- **MED Performance**: 225+ active particles (15 × 15 multiplier)  
- **LOW Performance**: 150+ active particles (10 × 15 multiplier)
- **Spawn Rate**: 250 particles/second at full storm intensity

### **Background Texture Planes**
- 4 large texture planes at 150-350 stud distances
- Animated scrolling shows wind direction clearly
- Creates visual "wall" of storm in background
- Sizes: 300×200 to 600×350 studs (massive scale)

## ⚡ **Key Features for Thick Weather**

### **1. Visibility Reduction**
- **Without Lantern**: Dense particle layers block vision beyond 30-50 studs
- **With Lantern**: 90% particle transparency in cone, fog reduction
- **Screen Fog Overlays**: Multiple animated fog layers on screen
- **Vignette Overlay**: Dark edges simulate storm closing in

### **2. Clear Wind Motion** 
- All particles move with realistic wind physics
- Background planes scroll to show wind direction
- 3D turbulence creates swirling, chaotic movement
- Layer-specific speeds create depth parallax

### **3. Oppressive Atmosphere**
- Dense particle spawning around player in 360°
- Screen-space fog overlays reduce overall visibility
- Dark vignette effect simulates being surrounded
- Animated elements create living, breathing storm

## 🎯 **Performance Optimizations**

### **Simple Particles**
- Tiny Part objects (0.1×0.1×0.1 studs)
- Fixed 64×64 pixel billboards
- Basic transparency animations only
- No complex physics or collision

### **Efficient Rendering**
- Distance-based culling (2-300 studs)
- Layer-based opacity scaling
- Simple billboard sprites vs complex meshes
- Texture reuse across particles

### **Smart Spawning**
- Spawn around camera, not globally
- Layer-based spawn distribution
- Automatic cleanup when particles move too far
- Rate limiting prevents frame drops

## 📊 **Lantern Integration**

### **Visibility System**
```lua
-- Without lantern: Full storm opacity
particleAlpha = layerOpacity * stormIntensity

-- With lantern: Heavy reduction in cone
if inLanternCone then
    particleAlpha *= 0.1  -- 90% transparency reduction
    fogAlpha *= 0.4       -- 60% fog reduction
    vignetteAlpha *= 0.5  -- 50% vignette reduction
end
```

### **Cone Detection**
- Particles within 1.5× lantern cone angle get transparency boost
- Screen fog layers reduce opacity when lantern active
- Vignette overlay lessens with lantern
- Creates clear "bubble" of visibility

## 🌊 **Visual Results**

### **Storm Thickness**
- **360° Particle Wall**: Dense effects surround player completely
- **Layered Depth**: 4 distinct particle layers create volume
- **Background Density**: Large texture planes fill distant areas
- **Screen Effects**: Fog overlays add atmospheric thickness

### **Wind Clarity** 
- **Directional Movement**: All effects move with wind vector
- **Speed Variation**: Different layers move at different speeds
- **Texture Scrolling**: Background planes clearly show wind direction
- **Turbulence**: Chaotic 3D movement patterns

### **Lantern Impact**
- **Dramatic Difference**: Clear visibility bubble vs storm wall
- **Progressive Fade**: Smooth transition at cone edges
- **Essential Tool**: Player truly needs lantern to navigate
- **Immersive Effect**: Feels like cutting through dense weather

## ⚙️ **Configuration**

All settings tunable in `StormConfig.DenseStorm`:

```lua
spawnRate = 250,              -- Particles/second at full intensity
layers = {                    -- 4 depth layers with individual settings
    {distance=25, opacity=0.8, speed=45, size=4},
    {distance=60, opacity=0.7, speed=35, size=6}, 
    {distance=120, opacity=0.6, speed=25, size=8},
    {distance=200, opacity=0.5, speed=15, size=12},
}
lanternVisibilityReduction = 0.1,  -- 90% transparency in lantern cone
```

## 🎮 **Player Experience**

### **Without Lantern**
- Vision severely limited to ~30 studs
- Dense storm wall blocks distant objects
- Screen fog creates claustrophobic feeling
- Wind motion clearly visible but chaotic

### **With Lantern** 
- Clear visibility bubble cuts through storm
- Can see 80+ studs in lantern direction
- Fog and vignette effects reduced
- Storm still visible at edges, maintaining atmosphere

### **Movement Through Storm**
- Storm feels like environment, not effect
- Dense particles create sense of pushing through weather
- Background texture planes provide scale reference
- Layered movement creates realistic depth

## 🚀 **Performance Notes**

- **Target**: 60 FPS with 300+ particles on HIGH settings
- **Optimization**: Simple rendering, distance culling, efficient spawning
- **Scaling**: Automatic reduction on MED/LOW performance tiers
- **Memory**: Pre-allocated particle pool prevents garbage collection

This system creates the **violent, thick storm** experience you wanted - players truly cannot see without the lantern, wind motion is clear and dramatic, and the storm feels oppressive and immersive!
