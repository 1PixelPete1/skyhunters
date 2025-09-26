# Dynamic Lantern System Documentation

## Overview
The Dynamic Lantern System is a deterministic, one-draw procedural generation system for creating varied lantern models in Roblox. It features adaptive curve-based pole generation, branch grammar, decoration placement, and a Studio-only designer UI for authoring presets.

## Quick Start

### 1. Setup
```lua
-- Run these scripts in order:
1. src/server/SetupLanternKit.server.luau  -- Creates test assets
2. src/server/TestLanternSystem.server.luau -- Runs test suite
```

### 2. Enable Feature Flags
```lua
-- In console or code:
FeatureFlags.set("Lanterns.DynamicEnabled", true)
FeatureFlags.set("Lanterns.UseLightSocket", true)
```

### 3. Spawn a Lantern
```lua
local LanternSpawnService = require(path.to.LanternSpawnService)
local lantern = LanternSpawnService.SpawnDynamicLantern(
    "plot_id",           -- Unique plot identifier
    Vector3.new(0, 0, 0), -- Position
    "standard",          -- Kind/type
    "CommonA"            -- Archetype (optional)
)
```

## Console Commands (Studio Only)

| Command | Description |
|---------|-------------|
| `/lantern spawn [archetype]` | Spawn lantern at look point |
| `/lantern seed <number>` | Set override seed for testing |
| `/lantern design` | Toggle designer UI |
| `/lantern clear` | Clear all dynamic lanterns |
| `/lantern stats` | Show statistics |
| `/lantern flags` | Show all feature flags |
| `/lantern flag <name> <true/false>` | Set feature flag |
| `/lantern clear_session` | Clear designer session |

## Designer UI (Studio Only)

### Hotkeys
- **Alt+D** - Toggle Designer UI
- **Alt+B** - Save Branch preset
- **Alt+L** - Save Lamp preset  
- **Alt+R** - Reroll Pose channel

### Modes

#### Branch Mode
Author individual branch presets with:
- Length fraction relative to parent
- Pitch and yaw angles
- Rotation inheritance
- Jitter for variation
- Decoration rules (placement and orientation)

#### Lamp Mode
Assemble full lantern archetypes with:
- Core parameters (height, bend, twist, etc.)
- Base and head weighted selections
- Style weights (straight, S-curve, spiral, helix)
- Branch specifications
- LOD settings

### Session Storage
Presets are saved in `Workspace.__LanternDesignerSession` during the session:
- `Branches/Branch_<n>` - Branch profile JSONs
- `Lamps/Lamp_<n>` - Full archetype JSONs

## Architecture

### Core Modules

#### LanternTypes.luau
Type definitions for the entire system:
- `Curve` - Gaussian distribution parameters
- `ParamSpec` - Parameter with RNG control
- `DecorationRule` - Decoration placement rules
- `BranchProfile` - Branch generation profile
- `Archetype` - Complete lantern specification

#### BitSlicer.luau
Deterministic RNG from single 64-bit seed:
- `take(bits)` - Extract uniform [0,1) value
- `gaussian(mu, sigma)` - Sample from normal distribution
- `weightedChoice(weights)` - Weighted random selection
- `bernoulli(p)` - Boolean probability trial

#### CurveEval.luau
Centerline generation and adaptive sampling:
- Curve styles: straight, S-curve, planar spiral, helix
- Adaptive sampling based on curvature tolerance
- Arc length computation
- Interpolation along samples

#### FrameTransport.luau
Parallel transport frames for smooth orientation:
- Builds orthonormal frames along curves
- Handles frame interpolation
- Socket frame extraction
- CFrame conversion

#### LanternFactory.server.luau
Main assembly module:
- Deterministic seed generation from plot + position
- Parameter resolution from archetypes
- Pole segmentation with micro-overlaps
- Socket placement (S1, S2, Tip, BaseTop)
- Head and base attachment

#### BranchBuilder.server.luau
Branch grammar system:
- Origin-based spawning (base, trunk_mid, trunk_tip)
- Decoration placement modes:
  - **Perpendicular** - Normal to branch
  - **LocalUpright** - Branch-relative up
  - **WorldUpright** - World Y-up aligned
  - **TangentAligned** - Along branch direction
- Density-based placement for "Along" decorations
- Global and per-branch child limits

## Archetypes

### CommonA
Simple lantern with minimal branches:
- Height: 12 ± 1.5 studs
- Bend: 15° ± 5°
- 3 max branches
- 50% straight, 40% S-curve, 10% spiral

### OrnateB
Decorative with multiple branches:
- Height: 14 ± 2 studs
- More twist and bend variation
- 5 max branches
- Includes chimes and flags

### TestSpiral
Testing archetype for spiral styles:
- Fixed height: 10 studs
- Heavy twist: 180° ± 30°
- 70% planar spiral, 30% helix

## Determinism

Each lantern is deterministically generated from:
```
seed = hash64(plotId, quantizedPos, version, archetypeName)
```

This ensures:
- Same inputs → identical geometry
- Reproducible across sessions
- No additional RNG state required

## Performance Considerations

### LOD Settings
- Mobile: Max 6 segments
- PC: Max 8 segments
- Studio: Max 8 segments

### Optimization
- Adaptive sampling with tolerance τ = 0.08 studs
- Micro-overlaps (0.02 studs) to prevent gaps
- Single-draw RNG (no state updates)
- Anchored parts (no physics)

## Integration Points

### Light System
When `Lanterns.UseLightSocket` is enabled:
- Head models expose `LightSocket` attachment
- Tagged with `"LanternLightSocket"`
- Compatible with existing LightMerger

### Existing Systems
The `MainIntegration` module provides hooks:
```lua
-- Replace existing spawn function
_G.SpawnLantern = function(plotId, position, ...)
    return LanternSpawnService.SpawnDynamicLantern(...)
end
```

## Extending the System

### Adding New Archetypes
1. Define in `LanternArchetypes.luau`
2. Set parameter ranges and locks
3. Configure branch profiles
4. Add decoration rules

### Adding New Curve Styles
1. Implement in `CurveEval.luau`
2. Add to `CURVE_STYLES` table
3. Update archetype style weights

### Adding New Decorations
1. Create models in LanternKit/Decor
2. Add `Mount` attachment
3. Define `DecorationRule` in archetypes
4. Choose orientation mode

## Troubleshooting

### Lanterns Not Spawning
1. Check feature flag: `Lanterns.DynamicEnabled`
2. Verify LanternKit exists in ReplicatedStorage
3. Check console for errors

### Gaps in Pole Segments
- Increase `POLE_OVERLAP` constant
- Check adaptive sampling tolerance

### Decorations Misaligned
- Verify attachment positions in prefabs
- Check orientation mode selection
- Adjust jitter parameters

### Performance Issues
- Reduce `max_total_children` in archetypes
- Lower adaptive sampling `kMax`
- Simplify decoration models

## Best Practices

1. **Always use deterministic seeds** for reproducibility
2. **Lock parameters** in Designer for consistent elements
3. **Test with different archetypes** to verify variety
4. **Use session storage** for iterative design
5. **Profile performance** with large counts
6. **Gate features** behind flags during development

## Future Enhancements

- [ ] Recursive branching (depth > 1)
- [ ] Dynamic LOD switching
- [ ] Weathering/damage states
- [ ] Seasonal decoration sets
- [ ] Network replication optimization
- [ ] Datastore persistence for presets
- [ ] Runtime archetype switching
- [ ] Advanced curve blending
