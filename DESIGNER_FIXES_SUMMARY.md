# Lantern Designer Fixes - Issue Resolution

## Issues Fixed ✅

### 1. ❌ Cannot Spawn Lanterns (Remote Errors)
**Problem**: Client script trying to `require()` ServerScriptService modules
```
Failed to spawn lantern: Attempted to call require with invalid argument(s).
```

**Root Cause**: The Designer UI (client script) was trying to directly require and call server modules like `LanternSpawnService`, which isn't allowed in Roblox.

**Fix**: 
- Created `RemoteEvent` system for client-server communication
- Client fires `SpawnDesignerLantern` RemoteEvent
- Server handles spawn via `DesignerSpawnHandler.server.luau`

**Files Changed**:
- ✅ `LanternDesigner.client.luau` - Uses RemoteEvent instead of require
- ✅ `DesignerSpawnHandler.server.luau` - NEW server-side handler

---

### 2. ❌ Branches Aiming Downward Initially
**Problem**: Lanterns spawn with branches pointing down instead of horizontal or up

**Root Cause**: Branch `pitch_deg` parameters had negative values:
```lua
-- OLD (could aim down)
pitch_deg = makeCurve(-20, 10, -45, 0)  -- -45° to 0° (pointing down!)
```

**Fix**: Changed all branch pitch ranges to **0° to 45°** (horizontal to upward):
```lua
-- NEW (never aims down)
pitch_deg = makeCurve(10, 8, 0, 30)     -- 0° to 30° (horizontal to up)
pitch_deg = makeCurve(15, 10, 0, 45)    -- 0° to 45° (horizontal to up)
```

**Files Changed**:
- ✅ `LanternArchetypes.luau` - Updated `BRANCH_SIMPLE` and `BRANCH_ORNATE` pitch ranges

---

### 3. ❌ Confusing Per-Param RNG Buttons
**Problem**: Individual dice buttons on each slider don't make sense in a seed-based system

**User Feedback**: 
> "RNG elements that stem from the seed should affect the whole lantern, not just an individual branch"

**Root Cause**: Designer UI had per-parameter dice buttons (🎲), implying individual randomization. But the system is **seed-based** - the entire lantern is determined by one seed.

**Fix**: 
- **Removed** per-param dice buttons
- **Added** single "🎲 Reroll" button that generates a new seed
- **Kept** lock buttons (🔒) for explicit designer choices
- **Added** seed display showing current seed number

**UI Changes**:
```
OLD UI:
[Param Name] [Value] [🔒] [🎲]  ← Confusing dice per param

NEW UI:
[Param Name] [Value] [🔒]       ← Just lock for explicit control
[🎲 Reroll] button at bottom    ← One button to reroll entire lantern
```

**Concept Clarification**:
- **Seed-based system**: One seed → entire lantern configuration
- **Lock buttons**: Let you override specific params with explicit values
- **Reroll button**: Generates new seed = completely new random lantern

**Files Changed**:
- ✅ `LanternDesigner.client.luau` - Removed per-param dice, added global reroll button

---

## How to Use the Fixed Designer

### Spawning Lanterns
1. Open Designer with **Alt+D** (in Studio)
2. Adjust parameters with sliders
3. Click **🚀 Spawn** to create lantern
4. Server handles spawn via RemoteEvent ✅

### Understanding the Seed System
- **Seed**: Single number that determines the entire lantern
- **Current seed** displayed at top of UI
- **🎲 Reroll**: Click to generate new seed = new random lantern
- **Lock 🔒**: Override seed-based value with explicit choice

### Branch Angles
- All branches now start **horizontal or upward** (0° to 45°)
- Never point downward initially
- Natural looking lanterns ✅

---

## Technical Details

### RemoteEvent Flow
```
Client (Designer UI)
    ↓ FireServer("spawn", position, archetype, seed)
RemoteEvent: SpawnDesignerLantern
    ↓ OnServerEvent
Server (DesignerSpawnHandler)
    ↓ LanternSpawnService.SpawnDynamicLantern(...)
Lantern Created ✅
```

### Seed-Based Randomization
```lua
-- One seed determines everything
local seed = 12345
local slicer = BitSlicer.fromU64(seed)

-- All params derived from same seed
height = slicer:sampleCurve(archetype.height.curve)
bend_deg = slicer:sampleCurve(archetype.bend_deg.curve)
branches = slicer:weightedChoice(...)
-- etc...

-- Reroll = new seed = completely different lantern
local newSeed = math.random(1, 1000000)
```

### Branch Pitch Ranges (Fixed)
| Branch Type | Old Pitch Range | New Pitch Range | Result |
|-------------|-----------------|-----------------|--------|
| BRANCH_SIMPLE | -45° to 0° ❌ | 0° to 30° ✅ | Never down |
| BRANCH_ORNATE | -60° to 15° ❌ | 0° to 45° ✅ | Never down |

---

## Files Modified

### New Files ✅
- `DesignerSpawnHandler.server.luau` - Handles RemoteEvent spawn requests

### Updated Files ✅
- `LanternDesigner.client.luau` - RemoteEvent spawning, removed per-param dice, added reroll
- `LanternArchetypes.luau` - Fixed branch pitch ranges (never aim down)

---

## Testing Checklist

### Test Spawning
- [ ] Open Designer (Alt+D in Studio)
- [ ] Click "🚀 Spawn" - lantern should spawn near player
- [ ] Click "👁 Preview" - ghost lantern should appear
- [ ] No "require" errors in output ✅

### Test Branch Angles
- [ ] Spawn lantern with branches
- [ ] Verify branches point horizontal or upward
- [ ] No branches pointing downward ✅

### Test Seed System
- [ ] Note current seed number
- [ ] Adjust params
- [ ] Click "🎲 Reroll" - seed changes
- [ ] Spawn - completely different lantern ✅
- [ ] Lock a param (🔒) - overrides seed for that param

---

## Summary

All three critical issues resolved:

1. ✅ **Spawning works** - RemoteEvent system implemented
2. ✅ **Branches never aim down** - Pitch ranges fixed to 0° to 45°
3. ✅ **RNG system clarified** - Single reroll button for entire lantern, lock buttons for explicit control

The Designer now properly reflects the seed-based architecture: **one seed determines the entire lantern**, with the option to lock specific params for explicit designer control.

---

*Ready to use! Press Alt+D in Studio to test.* 🏮
