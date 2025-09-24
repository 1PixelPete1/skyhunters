# Combat System Architecture Design

## Executive Summary

The combat system introduces distance-based progression through themed rounds, featuring swarm-based enemies on floating sky islands. The architecture prioritizes server-light validation, client-predicted visuals, and macroscopic cheat prevention while maintaining the established patterns from QuietWinds' existing systems.

## Core Architectural Principles

### 1. **Round-Based World Generation**
- **Global Round Seed**: Synchronized across all servers via MemoryStore
- **Deterministic Island Generation**: Use round seed + distance for consistent world layout
- **Theme Cohesion**: Each round locks material, weather, enemy types, and loot tables together

### 2. **Server-Light Enemy Management**
- **Macroscopic Validation**: Server validates spawn points, death events, and loot drops only
- **Client Authority**: Enemies move/attack on client with server reconciliation for damage
- **Batch Processing**: Server processes enemy state in waves, not per-tick

### 3. **Swarm Architecture**
- **Enemy Pooling**: Pre-allocate enemy instances, recycle on death
- **Group Behaviors**: Enemies share targeting data to reduce computation
- **Network Optimization**: Delta compression for position updates, predictive movement

## System Components

### **RoundProgressionService** (Server)
```lua
-- Core responsibility: Manage round transitions and theme enforcement
-- Location: src/server/Systems/RoundProgressionService.luau

Functions:
- GetCurrentRound() → RoundData
- GetRoundAtDistance(distance: number) → RoundData
- GenerateRoundSeed(roundId: string) → number
- PublishRoundTransition(player: Player, newRound: RoundData)

Data Structure:
RoundData = {
    id: string,           -- "storm_1", "crystal_2"
    seed: number,         -- Global deterministic seed
    theme: ThemeData,     -- Materials, weather, colors
    distanceRange: {min, max},
    enemyConfig: EnemyRoundConfig,
    lootTables: LootTableRef[]
}
```

### **SkyIslandService** (Server)
```lua
-- Core responsibility: Generate and stream floating islands
-- Location: src/server/Systems/SkyIslandService.luau

Functions:
- GenerateIslandField(origin: Vector3, round: RoundData) → IslandManifest
- StreamIslandsForPlayer(player: Player, position: Vector3)
- GetIslandAtPosition(position: Vector3) → Island?

Island Categories:
- Small: {radius: 10-20, lootChance: 0.1, enemyDensity: 0}
- Medium: {radius: 30-50, lootChance: 0.4, enemyDensity: 2-5}
- Large: {radius: 60-100, lootChance: 1.0, enemyDensity: 10-20, hasDungeon: true}

Generation Algorithm:
1. Use Poisson disk sampling for island placement
2. Scale density inversely with distance (fewer islands farther out)
3. Height increases logarithmically with distance
4. Large islands placed first, then medium, then small fill gaps
```

### **EnemyOrchestrator** (Server)
```lua
-- Core responsibility: Spawn waves and validate macro behaviors
-- Location: src/server/Systems/EnemyOrchestrator.luau

Functions:
- SpawnWave(island: Island, waveConfig: WaveConfig) → EnemyWave
- ValidateEnemyDeath(enemyId: string, killer: Player) → boolean
- ProcessLootDrop(enemyId: string, position: Vector3)
- ReconcilePositions(enemyBatch: EnemyPosition[])

Validation Strategy:
- Check spawn point validity (on island, not in void)
- Verify death within reasonable time window
- Validate loot drops against enemy type
- Detect teleport hacks via position delta thresholds
```

### **EnemyBehaviorClient** (Client)
```lua
-- Core responsibility: Local enemy AI and movement
-- Location: src/client/Combat/EnemyBehaviorClient.luau

Enemy Types:
1. BeamSniper:
   - Stationary/slow movement
   - Red tracking beam with 2-second lock time
   - Predictive targeting based on player velocity
   
2. Leaper:
   - Straight-line leap attacks
   - 3-second cooldown between leaps
   - Falls if leap misses (respawns on nearest island)
   
3. Swarmer:
   - Basic pathfinding to player
   - Groups share target data
   - Melee attack with lunge animation

Client Prediction:
- Interpolate enemy positions between server updates
- Run AI locally, server corrects if divergence > threshold
- Visual-only effects (beams, particles) fully client-side
```

### **CombatNetworkOptimizer** (Shared)
```lua
-- Core responsibility: Compress and batch combat network traffic
-- Location: src/shared/Combat/CombatNetworkOptimizer.luau

Techniques:
1. Position Quantization:
   - Snap positions to 0.1 stud grid
   - Send deltas instead of absolutes
   - Use 16-bit integers for relative positions

2. Batch Windows:
   - Collect updates for 100ms windows
   - Send single compressed packet per window
   - Priority queue for important events (deaths, spawns)

3. Interest Management:
   - Only sync enemies within 500 studs
   - LOD system: full updates near, sparse updates far
   - Cull invisible enemies from updates
```

### **DungeonController** (Server + Client)
```lua
-- Core responsibility: Manage large island semi-dungeons
-- Location: src/server/Systems/DungeonController.luau

Dungeon Features:
- Multi-stage encounters with checkpoints
- Environmental hazards (storm walls, crystal beams)
- MiniBoss at completion
- Guaranteed high-tier loot

Server Responsibilities:
- Validate checkpoint progression
- Spawn boss when conditions met
- Distribute loot on completion

Client Responsibilities:
- Render dungeon-specific effects
- Local puzzle mechanics
- UI for dungeon progress
```

## Data Flow Architecture

### **Combat Loop Data Flow**
```
1. Player Movement
   ↓
2. SkyIslandService.StreamIslandsForPlayer()
   ↓
3. Client receives island manifest
   ↓
4. EnemyOrchestrator.SpawnWave() [Server]
   ↓
5. Enemies replicated to client
   ↓
6. EnemyBehaviorClient runs AI locally
   ↓
7. Combat events (damage, death) sent to server
   ↓
8. Server validates and processes loot
   ↓
9. Client receives loot/rewards
```

### **Round Progression Flow**
```
1. Player crosses distance threshold
   ↓
2. RoundProgressionService detects transition
   ↓
3. New round theme applied
   ↓
4. Weather system updates
   ↓
5. Enemy spawn tables switch
   ↓
6. Client receives theme update
   ↓
7. Visual transition (fade, particles)
```

## Integration Points

### **With Existing Systems**

1. **LanternService Integration**
   - Loot tables drop lantern fragments
   - Combine fragments at crafting stations
   - Special lanterns from dungeon bosses

2. **OilService Integration**
   - Oil wells spawn on certain islands
   - Enemies drop oil canisters
   - Oil powers combat abilities

3. **PlotService Extension**
   - Sky plots for building sky bases
   - Portal system between ground and sky
   - Persistent sky structures

4. **PondNetworkService Interaction**
   - Sky ponds for aerial navigation
   - Canal bridges between floating islands
   - Water-based combat mechanics

## Performance Optimization Strategy

### **Enemy Count Scaling**
```lua
MaxEnemiesPerPlayer = 50
MaxEnemiesPerServer = 500
EnemyDespawnDistance = 600 -- studs

-- Dynamic scaling based on server performance
if ServerFPS < 30 then
    ReduceEnemyCount(0.8)
elseif ServerFPS > 50 then
    IncreaseEnemyCount(1.2)
end
```

### **Island LOD System**
- **Near (0-200 studs)**: Full detail, all decorations
- **Medium (200-500 studs)**: Simplified geometry, no small props
- **Far (500-1000 studs)**: Billboard imposters
- **Culled (>1000 studs)**: Removed from workspace

### **Network Bandwidth Management**
- Target: <5 KB/s per player for combat data
- Compression: ~70% reduction via delta encoding
- Priority: Deaths > Spawns > Damage > Movement

## Security Considerations

### **Anti-Cheat Measures**
1. **Movement Validation**
   - Max velocity checks (300 studs/second)
   - Teleport detection (>50 stud instant movement)
   - Island boundary validation

2. **Combat Validation**
   - Damage dealt must match weapon stats
   - Fire rate limiting
   - Line-of-sight checks for ranged attacks

3. **Loot Security**
   - Server determines all drops
   - Encrypted loot tables
   - Drop position validation

### **Exploit Mitigation**
```lua
-- Macroscopic validation example
function ValidateEnemyKill(player, enemyId, damageDealt)
    local enemy = GetEnemy(enemyId)
    if not enemy then return false end
    
    -- Check if player could reach enemy
    local distance = (player.Position - enemy.Position).Magnitude
    if distance > MAX_WEAPON_RANGE then
        return false -- Impossible kill
    end
    
    -- Check damage is reasonable
    if damageDealt > player.WeaponDamage * 2 then
        return false -- Damage hack
    end
    
    return true
end
```

## Implementation Phases

### **Phase 1: Foundation (Week 1-2)**
- [ ] RoundProgressionService with MemoryStore sync
- [ ] Basic SkyIslandService with 3 island types
- [ ] Simple enemy spawning (no AI yet)

### **Phase 2: Combat Core (Week 3-4)**
- [ ] EnemyBehaviorClient with 3 enemy types
- [ ] Client-side combat with server validation
- [ ] Basic loot system

### **Phase 3: Polish (Week 5-6)**
- [ ] DungeonController for large islands
- [ ] Network optimization pass
- [ ] Theme system with weather integration

### **Phase 4: Integration (Week 7-8)**
- [ ] Connect to lantern/oil economy
- [ ] Performance profiling and optimization
- [ ] Anti-cheat hardening

## Configuration Schema

```lua
-- In WorldConfig.luau, add:

COMBAT_CONFIG = {
    Rounds = {
        {
            id = "storm_1",
            distanceStart = 0,
            distanceEnd = 1000,
            theme = {
                materials = {Enum.Material.Slate, Enum.Material.Basalt},
                weather = "Thunderstorm",
                fogColor = Color3.fromRGB(50, 50, 70),
                ambientLight = Color3.fromRGB(100, 100, 120)
            },
            enemyMix = {
                BeamSniper = 0.5,
                Leaper = 0.3,
                Swarmer = 0.2
            },
            lootTier = 1
        },
        -- More rounds...
    },
    
    Islands = {
        Small = {
            radiusRange = {10, 20},
            heightVariance = 5,
            decorationDensity = 0.1
        },
        Medium = {
            radiusRange = {30, 50},
            heightVariance = 10,
            decorationDensity = 0.3
        },
        Large = {
            radiusRange = {60, 100},
            heightVariance = 20,
            decorationDensity = 0.5,
            dungeonChance = 0.8
        }
    },
    
    Performance = {
        maxEnemiesPerPlayer = 50,
        maxEnemiesPerServer = 500,
        islandStreamDistance = 1000,
        enemyDespawnDistance = 600,
        networkBatchWindow = 0.1 -- seconds
    }
}
```

## Testing Strategy

### **Unit Tests**
- Round progression logic
- Enemy spawn distribution
- Loot table validation

### **Integration Tests**
- Client-server combat sync
- Island streaming performance
- Theme transition smoothness

### **Load Tests**
- 500 enemies active
- 20 players in combat
- Network bandwidth monitoring

### **Exploit Tests**
- Teleport hack detection
- Damage multiplier detection
- Impossible movement validation

## Monitoring & Analytics

### **Key Metrics**
- Enemies killed per minute
- Average time to kill (TTK)
- Loot drops per hour
- Server FPS during combat
- Network bytes per player

### **Performance Alerts**
- Server FPS < 20
- Network usage > 10 KB/s per player
- Enemy count > 600
- Memory usage > 2 GB

## Conclusion

This architecture provides a scalable, secure, and performant combat system that aligns with QuietWinds' existing patterns. The server-light validation approach with client-side prediction ensures smooth gameplay while preventing major exploits. The round-based progression with themed content creates variety without complexity, and the swarm-based enemy design delivers intense combat without overwhelming server resources.