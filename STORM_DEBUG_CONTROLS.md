# Enhanced Storm System Debug Controls

## Overview
The enhanced storm system now includes comprehensive debug controls accessible through player attributes. These allow real-time adjustment of all storm effects without code changes.

## How to Access Debug Controls
1. Run the game in Roblox Studio
2. During play, select your player in the Explorer (game.Players.LocalPlayer)
3. Look in the Properties window under "Attributes"
4. All storm debug controls start with "Storm_"

## Quick Test Options
1. **Run TestRotatingSprites** - Enable the `TestRotatingSprites.client.luau` script for a 30-second demo of rotating sprites
2. **Enable Debug View** - Set `Storm_DebugView` to true to see green ring showing sprite placement
3. **Adjust Orbit Speed** - Change `Storm_RingOrbitSpeed` (try 1.0 for faster, -0.5 for reverse)

## Ring of Sprites Controls (SurroundingAirEffect)
These control the cylindrical ring of sprites that circle the camera:

- **Storm_RingEnabled** (boolean): Toggle the ring system on/off
- **Storm_RingRadius** (number): Distance from camera (default: 40, was 120)
- **Storm_RingHeight** (number): Height above camera (default: 8, was 18)
- **Storm_RingSegments** (number): Number of sprites per half-ring (default: 14)
- **Storm_RingSpriteWidth** (number): Width of each sprite (default: 12, was 36)
- **Storm_RingSpriteHeight** (number): Height of each sprite (default: 16, was 48)
- **Storm_RingAlphaMin** (number): Minimum opacity (default: 0.1)
- **Storm_RingAlphaMax** (number): Maximum opacity (default: 0.4)
- **Storm_RingScrollSpeed** (number): Texture scroll speed (default: 8)
- **Storm_RingWindScale** (number): Wind influence factor (default: 0.6)
- **Storm_RingOrbitSpeed** (number): How fast sprites orbit around camera (default: 0.5, negative reverses)

## Vignette Corner Effects
Controls the corner fog vignettes with wind-based jittering:

- **Storm_VignetteMode** (string): "corners" or "full" (default: "corners")
- **Storm_VignetteSize** (number): Size of corner vignettes (0.1-1.0, default: 0.3)
- **Storm_VignetteAlpha** (number): Opacity of vignettes (0-1, default: 0.4)
- **Storm_VignetteJitterAmount** (number): Pixels of jitter movement (default: 5)
- **Storm_VignetteJitterSpeed** (number): Jitter frequency multiplier (default: 2)

## Wind Gust System
Controls the volumetric wind gust effects:

- **Storm_GustStyle** (string): "smudge", "volumetric", or "sheets" (default: "volumetric")
- **Storm_GustScale** (number): Size multiplier for gusts (default: 1.5)
- **Storm_GustVariation** (boolean): Enable varied gust types (default: true)
- **Storm_GustTurbulence** (number): Turbulence intensity (0-1, default: 0.7)
- **Storm_GustLayerCount** (number): Number of depth layers (1-6, default: 4)

## Global Controls
Overall storm system controls:

- **Storm_GlobalIntensity** (number): Overall storm intensity multiplier (0-1, default: 0.8)
- **Storm_DebugView** (boolean): Show debug visualization helpers (default: false)

## Key Improvements

### 1. Ring of Sprites (COMPLETELY FIXED)
- **TRUE 3D SPRITES** - Uses Parts with Decals/Textures, NOT BillboardGuis
- **FOLLOWS CAMERA** - Entire ring system moves with the camera position
- **CONTINUOUS ORBIT** - Sprites physically rotate around the camera
- **TANGENTIAL ORIENTATION** - Key feature: Sprites face perpendicular to the radius
  - When in front: You see them straight-on
  - When on sides: You see them at an angle
  - Creates proper 3D volumetric effect
- **Counter-rotating rings** - Front and back halves rotate in opposite directions
- **Configurable speed** - Adjust `Storm_RingOrbitSpeed` (negative values reverse)
- **Wind influence** - Sprites wobble and lean based on wind
- **Debug visualization** - Green ring shows actual sprite positions

### 2. Corner Vignettes (New)
- **Corner-based placement** instead of full-screen overlay
- **Wind-based jittering** with multi-frequency movement
- **Size pulsing** based on wind gusts
- **Directional bias** following wind direction
- **Separate corner control** for asymmetric effects

### 3. Volumetric Wind Gusts (New Alternative)
- **5 different gust types**: swirl, sheet, ribbon, cloud, vortex
- **True 3D volumes** using Part geometry instead of billboards
- **Varied behaviors** per type (spinning, tumbling, twisting)
- **Turbulence system** for organic movement
- **Layer-based spawning** for depth perception

## What Makes the Sprites Work Now

The key difference is **tangential orientation**:
- Sprites are positioned in a ring around the camera
- Each sprite faces PERPENDICULAR to the radius (not toward the camera)
- This means sprites on the sides appear at an angle to your view
- Creates the proper "moving through weather" effect
- Combined with continuous rotation, gives convincing storm atmosphere

## Performance Considerations

### Optimized Features
- Sprites only render within configured MaxDistance
- Lantern cone dramatically reduces particle visibility (90% reduction)
- Distance-based culling for all effects
- Smooth LOD transitions based on device performance
- Configurable layer counts for performance scaling

### Testing Different Configurations

**Heavy Blizzard Effect:**
```
Storm_GlobalIntensity = 1.0
Storm_RingEnabled = true
Storm_RingRadius = 30
Storm_RingOrbitSpeed = 0.8
Storm_GustStyle = "volumetric"
Storm_GustScale = 2.0
Storm_VignetteMode = "corners"
Storm_VignetteAlpha = 0.6
```

**Light Storm Effect:**
```
Storm_GlobalIntensity = 0.4
Storm_RingEnabled = true
Storm_RingRadius = 50
Storm_RingOrbitSpeed = 0.3
Storm_GustStyle = "smudge"
Storm_GustScale = 1.0
Storm_VignetteMode = "corners"
Storm_VignetteAlpha = 0.2
```

**Clear Visibility (Lantern Test):**
```
Storm_GlobalIntensity = 0.8
Storm_RingEnabled = false
Storm_GustStyle = "volumetric"
Storm_VignetteMode = "corners"
Storm_VignetteAlpha = 0.3
```

## Troubleshooting

**Can't see ring sprites:**
- Check Storm_RingEnabled is true
- Reduce Storm_RingRadius (try 20-40)
- Increase Storm_RingAlphaMax (try 0.6-0.8)
- Enable Storm_DebugView to see the ring placement
- Run TestRotatingSprites.client.luau for basic test

**Sprites not moving:**
- Check Storm_RingOrbitSpeed is not 0
- Ensure Storm_GlobalIntensity > 0
- Try increasing orbit speed to 1.0 or higher

**Vignettes not showing:**
- Check Storm_VignetteMode is set correctly
- Increase Storm_VignetteAlpha
- Increase Storm_VignetteSize for larger corner coverage

**Performance issues:**
- Reduce Storm_GustLayerCount
- Switch Storm_GustStyle to "smudge"
- Disable Storm_RingEnabled
- Lower Storm_GlobalIntensity

## Notes
- All changes apply in real-time during gameplay
- Settings are not persistent between sessions
- Original storm systems remain as fallback
- Test storm automatically activates in Studio for debugging
- TestRotatingSprites script provides standalone verification
