# Dynamic Lantern System - Integration Guide

## Overview
This guide helps integrate the Dynamic Lantern System with your existing lantern infrastructure without breaking current functionality.

## Migration Strategy

### Phase 1: Parallel Testing (Current)
- Dynamic system runs alongside existing system
- Controlled by `Lanterns.DynamicEnabled` flag
- No changes to existing lantern code
- Test in isolated areas

### Phase 2: Gradual Rollout
1. Enable for new areas first
2. A/B test with feature flags
3. Monitor performance metrics
4. Gather feedback

### Phase 3: Full Migration
- Replace existing spawners
- Migrate old lantern data
- Remove legacy code
- Update documentation

## Integration Points

### 1. Existing Spawn Functions

#### Before:
```lua
-- Your existing lantern spawn
function SpawnLantern(position, type)
    local lantern = LanternModels[type]:Clone()
    lantern:SetPrimaryPartCFrame(CFrame.new(position))
    lantern.Parent = workspace
    return lantern
end
```

#### After:
```lua
-- Integrated spawn with fallback
local FeatureFlags = require(path.to.FeatureFlags)
local LanternSpawnService = require(path.to.LanternSpawnService)

function SpawnLantern(position, type, plotId)
    if FeatureFlags.get("Lanterns.DynamicEnabled") then
        -- Use dynamic system
        local archetype = mapTypeToArchetype(type)
        return LanternSpawnService.SpawnDynamicLantern(
            plotId or "legacy",
            position,
            type,
            archetype
        )
    else
        -- Fall back to existing system
        local lantern = LanternModels[type]:Clone()
        lantern:SetPrimaryPartCFrame(CFrame.new(position))
        lantern.Parent = workspace
        return lantern
    end
end
```

### 2. Light System Integration

The dynamic system exposes `LightSocket` attachments for existing light systems:

```lua
-- In your light merger/manager
local function findLightPoints(model)
    local lights = {}
    
    -- Check for dynamic lantern light socket
    local lightSocket = model:FindFirstChild("LightSocket", true)
    if lightSocket and lightSocket:IsA("Attachment") then
        table.insert(lights, {
            position = lightSocket.WorldPosition,
            attachment = lightSocket
        })
    end
    
    -- Also check legacy light parts
    for _, part in ipairs(model:GetDescendants()) do
        if part.Name == "LightPart" then
            table.insert(lights, {
                position = part.Position,
                part = part
            })
        end
    end
    
    return lights
end
```

### 3. Save/Load System

To maintain save compatibility:

```lua
-- Save system adapter
function saveLanternData(lantern)
    local data = {}
    
    if lantern:GetAttribute("Seed") then
        -- Dynamic lantern
        data.type = "dynamic"
        data.seed = lantern:GetAttribute("Seed")
        data.archetype = lantern:GetAttribute("Archetype")
        data.plotId = lantern:GetAttribute("PlotId")
    else
        -- Legacy lantern
        data.type = "legacy"
        data.modelName = lantern.Name
    end
    
    data.position = lantern:GetPivot().Position
    return data
end

function loadLanternData(data)
    if data.type == "dynamic" then
        return LanternSpawnService.SpawnDynamicLantern(
            data.plotId,
            data.position,
            "saved",
            data.archetype
        )
    else
        -- Load legacy lantern
        return spawnLegacyLantern(data.modelName, data.position)
    end
end
```

### 4. Network Replication

For multiplayer optimization:

```lua
-- Server: Send minimal data
RemoteEvents.LanternSpawn:FireAllClients({
    seed = lantern:GetAttribute("Seed"),
    position = position,
    archetype = archetype
})

-- Client: Reconstruct locally
RemoteEvents.LanternSpawn.OnClientEvent:Connect(function(data)
    -- Clients can generate the same lantern from seed
    local lantern = LanternFactory.assembleLantern(
        "client_" .. data.seed,
        data.position,
        data.archetype,
        data.seed
    )
end)
```

## Archetype Mapping

Map your existing lantern types to dynamic archetypes:

```lua
local TypeToArchetype = {
    ["BasicLantern"] = "CommonA",
    ["OrnateLantern"] = "OrnateB",
    ["TwistedLantern"] = "TestSpiral",
    -- Add more mappings
}

function mapTypeToArchetype(legacyType)
    return TypeToArchetype[legacyType] or "CommonA"
end
```

## Performance Comparison

| Metric | Legacy System | Dynamic System |
|--------|--------------|----------------|
| Memory per lantern | ~500 KB (cloned) | ~200 KB (generated) |
| Spawn time | 5-10ms | 15-25ms |
| Variety | Limited to prefabs | Infinite variations |
| Network data | Full model | Just seed + params |
| LOD support | Manual | Automatic |

## Testing Checklist

### Functionality Tests
- [ ] Lanterns spawn at correct positions
- [ ] Visual quality matches expectations
- [ ] Lights work correctly
- [ ] Decorations appear properly
- [ ] No z-fighting or gaps

### Performance Tests
- [ ] Spawn time acceptable (< 50ms)
- [ ] Memory usage reasonable
- [ ] No frame drops with 100+ lanterns
- [ ] LOD switching works

### Compatibility Tests
- [ ] Existing saves load correctly
- [ ] Legacy lanterns still work
- [ ] Network replication functions
- [ ] Mobile devices handle it

## Rollback Plan

If issues arise, quickly rollback:

```lua
-- Emergency rollback
FeatureFlags.set("Lanterns.DynamicEnabled", false)

-- Clear dynamic lanterns
LanternSpawnService.ClearAll()

-- Respawn as legacy
for _, data in ipairs(savedLanternData) do
    spawnLegacyLantern(data.type, data.position)
end
```

## Common Issues & Solutions

### Issue: Lanterns look different than legacy
**Solution:** Adjust archetype parameters to match legacy appearance more closely.

### Issue: Spawn performance too slow
**Solution:** 
- Reduce max segments (kMax)
- Simplify decorations
- Pre-generate common variants

### Issue: Save files incompatible
**Solution:** Use migration adapter shown above, version your save format.

### Issue: Lighting doesn't work
**Solution:** Ensure `Lanterns.UseLightSocket` is enabled and light system checks for attachments.

## Monitoring

Track these metrics during rollout:

```lua
-- Analytics to track
Analytics.track("lantern_spawned", {
    system = isDynamic and "dynamic" or "legacy",
    archetype = archetype,
    spawn_time = spawnTime,
    platform = platform,
})

-- Performance metrics
local stats = LanternSpawnService.GetStats()
Analytics.track("lantern_stats", {
    total = stats.total,
    average_height = stats.averageHeight,
    distribution = stats.byArchetype
})
```

## Timeline

### Week 1-2: Setup & Testing
- Install dynamic system
- Create LanternKit assets  
- Run test suite
- Verify in Studio

### Week 3-4: Integration
- Wire up spawn points
- Map legacy types
- Test save/load
- Fix compatibility issues

### Week 5-6: Rollout
- Enable for 10% of users
- Monitor metrics
- Fix reported issues
- Gradual increase to 100%

### Week 7-8: Cleanup
- Remove legacy code
- Update documentation
- Train team
- Celebrate! 🎉
