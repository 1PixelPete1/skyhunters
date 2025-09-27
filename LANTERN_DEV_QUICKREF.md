# Dynamic Lantern System - Developer Quick Reference 🏮

## Quick Start

### Spawning a Lantern (Runtime)
```lua
local LanternSpawnService = require(game.ServerScriptService.LanternSpawnService)

-- Spawn with default archetype
local lantern = LanternSpawnService.SpawnDynamicLantern(
    "plot_001",           -- Plot ID (for deterministic seed)
    Vector3.new(0, 5, 0), -- Position
    "standard",           -- Kind
    "CommonA"             -- Archetype name (optional, defaults to CommonA)
)
```

### Using the Designer (Studio Only)
1. Press **Alt+D** to toggle Designer UI
2. Select **Style** from dropdown (straight/scurve/planar_spiral/helix)
3. Adjust parameters with sliders
4. **Lock** 🔒 params to prevent randomization
5. **Dice** 🎲 to reroll individual params
6. **Channel Reroll**: Reroll all Shape/Pose/Look params at once
7. **Save** 💾 to session storage
8. **Preview** 👁 to see ghost version
9. **Spawn** 🚀 to create test lantern

### Hotkeys
- **Alt+D**: Toggle Designer UI
- **Alt+L**: Save current lamp design
- **Alt+R**: Reroll all Pose params

---

## Architecture Overview

### Data Flow
```
Archetype (Design) → BitSlicer (RNG) → CurveEval (Geometry) → FrameTransport (Orientation) → LanternFactory (Assembly)
```

### Core Modules

| Module | Purpose |
|--------|---------|
| **LanternTypes** | Type definitions (Designer vs Runtime) |
| **LanternArchetypes** | Preset designs |
| **LanternFactory** | Main assembly logic |
| **CurveEval** | Curve generation (straight/scurve/spiral/helix) |
| **FrameTransport** | Parallel transport frames (orientation) |
| **BranchBuilder** | Branch spawning system |
| **BitSlicer** | Deterministic RNG from seed |
| **LanternValidator** | Validation & warnings |
| **LanternConverter** | Designer↔Runtime conversion |

---

## Key Concepts

### 1. Tangent-Aligned Frames ✅
**Problem**: Segments were "ladder-like" in spirals
**Solution**: Use parallel transport frames - segments follow curve tangent

```lua
-- Cylinder long axis (X) aligned with tangent
local right = midTangent
local up = (startFrame.up + endFrame.up).Unit
local forward = right:Cross(up).Unit
```

### 2. Style vs Style Weights
- **Designer**: Explicit style choice (`style = "spiral"`)
- **Runtime**: Weighted random (`style_weights = {spiral=0.7, helix=0.3}`)

### 3. twist_deg Clarification
- **ONLY** for curve plane initial yaw rotation
- NOT for decoration orientation
- NOT for branch rotation

```lua
-- Correct usage (in curve options)
local curveOpts = {
    bend_deg = params.bend_deg,
    twist_deg = params.twist_deg,  -- Curve plane rotation
    tip_drop = params.tip_drop
}
```

### 4. RNG Channels
Params grouped into channels for batch rerolling:
- **Shape**: height, arm_len, scales
- **Pose**: bend_deg, twist_deg, tip_drop, tilts
- **Look**: paint_wear, visual effects

### 5. Branch Adoption
Branches default to adopting parent end tangent:
```lua
-- Branch inherits parent orientation
local startFrame = originFrame  -- Parent end frame
cf = FrameTransport.cframeFrom(startFrame)
cf = cf * CFrame.Angles(pitch, yaw, 0)  -- Apply offsets
```

---

## Common Patterns

### Creating a New Archetype
```lua
local MyArchetype: Types.Archetype = {
    version = 1,
    
    -- Core params (use makeParam helper)
    height = makeParam(12, 1.5, "shape"),
    bend_deg = makeParam(15, 5, "pose"),
    twist_deg = makeParam(0, 10, "pose"),  -- Curve yaw only!
    -- ... other params ...
    
    -- Weighted model picks
    base_set = {["StoneDisk"] = 0.7, ["SquareBlock"] = 0.3},
    head_set = {["HeadA"] = 1.0},
    
    -- Style weights (sum can be any positive value)
    style_weights = {["straight"] = 0.5, ["scurve"] = 0.5},
    
    -- Branch specification
    branches = {
        origins = {
            base = {sockets = {"BaseTop"}, profiles = {}},
            trunk_mid = {sockets = {"S1", "S2"}, density = 0.3, profiles = {BRANCH_SIMPLE}},
            trunk_tip = {sockets = {"Tip"}, profiles = {BRANCH_SIMPLE}, require_one = true}
        },
        limits = {max_total_children = 3, max_depth = 1}
    }
}
```

### Creating a Branch Profile
```lua
local MyBranch: Types.BranchProfile = {
    id = "my_custom_branch",
    max_children = 1,
    len_frac = makeCurve(0.4, 0.05, 0.3, 0.5),
    pitch_deg = makeCurve(-20, 10, -45, 0),
    yaw_deg = makeCurve(0, 30, -60, 60),
    inherit_rotation = false,  -- Adopt parent tangent
    jitter_deg = makeCurve(0, 2, -5, 5),
    decorations = {
        {
            modelId = "FlagSmall",
            where = "Ends",
            mode = "TangentAligned",  -- Not WorldUpright in spirals!
            density = nil,
            jitter_deg = makeCurve(0, 5, -15, 15)
        }
    }
}
```

### Decoration Modes
| Mode | Description | Best For |
|------|-------------|----------|
| **Perpendicular** | Y = branch right | Hanging decorations |
| **LocalUpright** | Y = branch up | Flags on branches |
| **WorldUpright** | Y = world up | ⚠️ Avoid in spirals! |
| **TangentAligned** | Y = branch forward | Streamers along branch |

---

## Validation & Debugging

### Validate Archetype
```lua
local LanternValidator = require(game.ReplicatedStorage.Shared.LanternValidator)

-- Quick validation (logs to console)
LanternValidator.quickValidate(MyArchetype, "MyArchetype")

-- Detailed validation
local result = LanternValidator.validateArchetype(MyArchetype)
if not result.valid then
    for _, err in ipairs(result.errors) do
        warn(err)
    end
end
```

### Debug Attributes
Every spawned lantern has debug attributes:
```lua
local seed = lantern:GetAttribute("Seed")
local style = lantern:GetAttribute("Style")
local height = lantern:GetAttribute("Height")
local bendDeg = lantern:GetAttribute("BendDeg")
```

### Running Tests
```lua
local TestLanterns = require(game.ServerScriptService.TestDynamicLanterns)

-- Run all tests
TestLanterns.runAll()

-- Or individual tests
TestLanterns.testValidation()
TestLanterns.testSpiralAlignment()
TestLanterns.testBranchSystem()
```

---

## Common Issues & Solutions

### ❌ "Ladder Effect" in Spirals
**Cause**: Segments not following tangent
**Fix**: Already fixed in `LanternFactory.lua` - segments now tangent-aligned

### ❌ No Tip Branch Spawns
**Cause**: `require_one = true` but profiles empty or limit reached
**Fix**: Ensure `trunk_tip.profiles` has at least one profile
```lua
trunk_tip = {
    sockets = {"Tip"},
    profiles = {BRANCH_SIMPLE},  -- Must have at least one!
    require_one = true
}
```

### ❌ WorldUpright Decorations Look Wrong in Spirals
**Cause**: World-aligned decorations don't follow curve
**Fix**: Use `TangentAligned` or `LocalUpright` for spirals
```lua
-- BAD for spirals
mode = "WorldUpright"

-- GOOD for spirals
mode = "TangentAligned"
```

### ❌ twist_deg Not Working
**Cause**: twist_deg only affects curve plane, not other rotations
**Fix**: Use correct param for what you want to twist:
- Curve plane rotation: `twist_deg`
- Lantern head rotation: `lantern_yaw`
- Branch rotation: `yaw_deg` in branch profile

---

## Performance Tips

1. **LOD**: System auto-adjusts segments (3-8) based on platform
2. **Caching**: Same plotId + position = same lantern (deterministic)
3. **Batch Spawn**: Use `SpawnMultiple()` for many lanterns
4. **Clean Up**: Use `ClearAll()` to remove test lanterns

```lua
-- Efficient batch spawn
local positions = {...}
LanternSpawnService.SpawnMultiple(positions, "plot_batch", "CommonA")

-- Clean up tests
LanternSpawnService.ClearAll()
```

---

## File Organization

```
ReplicatedStorage/
  └─ Shared/
      ├─ LanternTypes.luau          # Type definitions
      ├─ LanternArchetypes.luau     # Preset designs
      ├─ CurveEval.luau             # Curve math
      ├─ FrameTransport.luau        # Orientation frames
      ├─ BitSlicer.luau             # RNG system
      ├─ LanternValidator.luau      # Validation
      └─ LanternConverter.luau      # Designer↔Runtime

ServerScriptService/
  ├─ LanternFactory.luau            # Assembly
  ├─ LanternSpawnService.luau       # Spawn API
  ├─ BranchBuilder.luau             # Branch system
  └─ TestDynamicLanterns.server.luau # Test suite

StarterPlayer/StarterPlayerScripts/
  └─ LanternDesigner.client.luau    # Studio UI
```

---

## API Reference

### LanternSpawnService

```lua
-- Spawn single lantern
SpawnDynamicLantern(plotId: string, pos: Vector3, kind: string, archetype: string?) -> Model?

-- Batch spawn
SpawnMultiple(positions: {Vector3}, plotId: string?, archetype: string?) -> {Model}

-- Clear all
ClearAll() -> number

-- Get stats
GetStats() -> {total: number, byArchetype: {}, byStyle: {}, averageHeight: number}
```

### LanternValidator

```lua
-- Validate archetype
validateArchetype(archetype) -> ValidationResult

-- Quick validate (logs)
quickValidate(archetype, name?) -> boolean

-- Validate all
validateAll(archetypes) -> {[string]: ValidationResult}

-- Print report
printReport(results)
```

### LanternConverter

```lua
-- Convert Designer → Runtime
designerToRuntime(designer: DesignerArchetype) -> Archetype

-- Convert Runtime → Designer
runtimeToDesigner(runtime: Archetype, style?) -> DesignerArchetype

-- Validate either type
validate(archetype) -> (boolean, string?)

-- Create mutation
mutate(archetype: Archetype, strength: number, seed: number) -> Archetype
```

---

## Next Steps

1. ✅ All core fixes applied
2. ✅ Test suite created
3. ✅ Validation system in place
4. 🚧 Complete Branch Mode in Designer
5. 🚧 Add visual curve preview
6. 🚧 Implement mutation system for procedural variation

---

*Happy lantern building! 🏮*
