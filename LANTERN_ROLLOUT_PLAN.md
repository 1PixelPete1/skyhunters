# Lantern System Rollout Plan

## Current Implementation Status

### ✅ Completed Modules

#### Server-Side
- `LanternService.lua` - Core resource generation with depreciation
- `VoyageService.lua` - 30-second voyages with tiered loot tables
- `MachineService.lua` - Machine placement with diminishing returns
- `HeadLanternService.lua` - Plucking system with curses and durability
- `ProfileTemplate_M0.lua` - Save data structure

#### Client-Side
- `LightMergerController.lua` - Greedy seed-and-absorb clustering
- `LightLODController.lua` - Distance-based rendering (Near/Mid/Far)
- `ReservoirUI.lua` - Selling interface with depreciation warnings
- `VoyageUI.lua` - Three-option popup with progress tracking
- `LanternFruitVisuals.lua` - Opal shimmer fruit growth/burst effects
- `WeatherBlackoutController.lua` - Black-out lighting (guarded toggle)
- `HeadLanternController.lua` - Flashlight cone and curse UI

#### Integration
- `MainIntegration.lua` - Central orchestrator with remote events

---

## Milestone Rollout Plan

### **M0: Foundation (Week 1)**
*Goal: Replace placeholder lanterns with working lights and basic economy*

#### Day 1-2: Light System
1. Deploy `LightMergerController` to production
2. Test with 50, 100, 200 lanterns for performance
3. Tune merge radius (start R=30) and cluster diameter (D_max=80)
4. Verify proxy light calculations

#### Day 3-4: Resource Generation
1. Enable `LanternService` generation tick
2. Implement offline generation calculation
3. Test depreciation curve (100+ units = 95% value)
4. Deploy `ReservoirUI` with sell functionality

#### Day 5-6: Testing & Polish
1. Test weather blackout in controlled environment (keep disabled by default)
2. Verify save/load with ProfileService integration
3. Monitor server performance with generation ticks
4. Gather feedback on light visuals

**Success Metrics:**
- Server tick rate stays under 5ms with 1000 lanterns
- Light count reduced by 60-80% via merger
- Players understand depreciation mechanic

---

### **M1: Engagement Loop (Week 2)**
*Goal: Add risk/reward voyages and progression via machines*

#### Day 1-2: Voyage System
1. Deploy voyage UI with Cancel/Sell/Voyage options
2. Implement 30-second voyage timer
3. Start with simple loot table (just gold)
4. Test voyage interruption handling

#### Day 3-4: Fruit Visuals
1. Enable fruit growth tied to reservoir percentage
2. Test burst effects at 100% maturity
3. Ensure particle budget compliance (50 mobile, 200 PC)
4. Add opal shimmer animation

#### Day 5-6: Machines
1. Roll out Condenser first (radius boost)
2. Add Collector (global generation)
3. Finally Amplifier (generation + brightness)
4. Test diminishing returns (0.85^n effectiveness)
5. Verify multiplier stacking math

**Success Metrics:**
- 60% of players attempt a voyage
- Average 2-3 machines placed per plot
- Fruit visuals run at 60fps on target devices

---

### **M2: Depth & Polish (Week 3)**
*Goal: Add strategic depth with head lanterns and optimize performance*

#### Day 1-2: Head Lantern System
1. Enable plucking with source lantern penalty
2. Test 5 curse types with clear buff/debuff display
3. Implement durability (1-5 deaths based on rarity)
4. Verify regrow timer (5 minutes)

#### Day 3-4: Light LOD
1. Enable distance-based quality transitions
2. Test LOD ranges (Near≤70, Mid≤220, Far=off)
3. Monitor particle budget on mobile
4. Profile performance improvements

#### Day 5-6: Final Integration
1. Enable weather blackout system (if stable)
2. Tune all parameters based on Week 1-2 data
3. Add tooltips and tutorials
4. Performance optimization pass

**Success Metrics:**
- 30% of players use head lanterns
- Mobile maintains 30+ fps with full systems
- Player retention increases by 15%

---

## Risk Mitigation Strategies

### Performance Risks
- **Light Merger Overhead**: Pre-calculate clusters, cache results for 1 second
- **Generation Tick Cost**: Batch updates, use sparse updates for distant plots
- **Particle Overload**: Strict LOD enforcement, platform-specific budgets

### Clarity Risks
- **Depreciation Confusion**: Add animated graph in UI showing value curve
- **Voyage Risk**: Clear "ALL OR NOTHING" warning before voyage start
- **Machine Stacking**: Visual range indicators, diminishing returns tooltip

### Balance Risks
- **Machine Meta**: A/B test multiplier values, have hotfix variables ready
- **Curse Imbalance**: Track curse selection rates, buff underused ones
- **Voyage Rewards**: Server-controlled loot tables for easy adjustment

---

## Implementation Checklist

### Pre-Launch Requirements
- [ ] ProfileService integration for all new data fields
- [ ] Remote event security (validate all inputs)
- [ ] Admin commands for spawning items/debugging
- [ ] Analytics events for all major actions
- [ ] Fallback states for network failures

### Testing Requirements
- [ ] Load test with 20 concurrent players
- [ ] Mobile performance profiling
- [ ] Edge cases (plot boundaries, max lanterns)
- [ ] Save/load reliability across server restarts
- [ ] Exploit prevention (resource duplication)

### Documentation Needs
- [ ] Player tutorial for resource/voyage system
- [ ] Wiki page explaining machines/curses
- [ ] Admin guide for tuning parameters
- [ ] Troubleshooting guide for common issues

---

## Configuration Variables

```lua
-- Tunable parameters for live adjustment
Config = {
    -- M0
    MergeRadius = 30,
    MaxClusterDiameter = 80,
    DepreciationStart = 100,
    DepreciationRate = 0.95,
    GenerationRate = 0.1,
    
    -- M1
    VoyageDuration = 30,
    MachineDiminishing = 0.85,
    FruitMatureThreshold = 100,
    
    -- M2
    PluckPenaltyMultiplier = 0.5,
    RegrowTime = 300,
    HeadLanternDurability = {1, 2, 3, 4, 5}, -- by rarity
    
    -- LOD
    LODNearRange = 70,
    LODMidRange = 220,
    ParticleBudgetMobile = 50,
    ParticleBudgetPC = 200
}
```

---

## Post-Launch Monitoring

### Key Metrics to Track
1. **Performance**: Frame rate, server tick time, memory usage
2. **Engagement**: Voyage attempts, machine placements, head lantern usage
3. **Economy**: Gold inflation, resource accumulation rates
4. **Retention**: D1/D7/D30 retention with new systems

### Adjustment Triggers
- If server tick >10ms → Increase batch sizes, reduce tick rate
- If <40% voyage attempts → Reduce duration or increase rewards
- If curse imbalance >60/40 → Buff weak curses, nerf popular ones
- If mobile fps <25 → Reduce LOD ranges, lower particle budgets

---

## Next Systems to Consider
1. **Lantern Trading** - Player marketplace for rare lanterns
2. **Seasonal Curses** - Time-limited curse types
3. **Machine Upgrades** - Enhance existing machines with materials
4. **Cooperative Voyages** - Multi-player expeditions
5. **Lantern Breeding** - Combine lanterns for new variants