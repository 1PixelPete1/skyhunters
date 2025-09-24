# Combat System Architecture v2 - Refined Design

## Executive Summary

Refined combat architecture focusing on shard-local round progression, precise island spacing for mobility-based progression, and detailed POI/dungeon generation. Maintains server-light validation while ensuring traversability through careful island field generation.

## Critical Design Refinements

### 1. **Shard-Local Round System (Default)**
```lua
-- RoundProgressionService changes from global to shard-local by default
RoundConfig = {
    mode = "shard_local", -- or "global_epoch" for special events
    shardSeed = game.JobId, -- unique per server
    globalEpochSeed = nil, -- optional MemoryStore sync
}
```

### 2. **Island Generation - Mobility-Aware Spacing**

## Island Field Generation Algorithm

### **Core Principle: Guaranteed Traversability**
Islands must be spaced based on player mobility tiers to ensure progression is skill/gear-based, not RNG.

```lua
-- MobilityTiers define max gap-crossing ability
MobilityTiers = {
    [1] = {name = "Basic", maxGap = 30, jumpHeight = 15},      -- Starting gear
    [2] = {name = "Enhanced", maxGap = 50, jumpHeight = 25},   -- Jumppack
    [3] = {name = "Advanced", maxGap = 80, jumpHeight = 40},   -- Jumppack + buffs
    [4] = {name = "Elite", maxGap = 120, jumpHeight = 60},     -- Endgame mobility
}

-- Island spacing algorithm
function GenerateIslandField(origin, distanceFromSpawn, playerMobilityTier)
    local mobilityData = MobilityTiers[playerMobilityTier]
    local maxGap = mobilityData.maxGap
    
    -- Core spacing rules:
    -- 1. Always have at least ONE reachable island within mobility range
    -- 2. Island density decreases with distance
    -- 3. Height variation increases with distance but respects jump height
    
    local islands = {}
    local seed = GetRoundSeed(distanceFromSpawn)
    
    -- Phase 1: Generate POI anchors (large islands)
    local poiSpacing = maxGap * 3.5 -- POIs are destinations, not stepping stones
    local pois = GeneratePOIGrid(origin, distanceFromSpawn, poiSpacing, seed)
    
    -- Phase 2: Generate traversal paths between POIs
    for i, poi in pairs(pois) do
        local nearestPOIs = GetNearestPOIs(poi, pois, 3)
        for _, targetPOI in pairs(nearestPOIs) do
            local path = GenerateTraversalPath(poi, targetPOI, maxGap, mobilityData.jumpHeight)
            table.insert(islands, path)
        end
    end
    
    -- Phase 3: Fill gaps with medium/small islands
    local gapFiller = GenerateGapFillers(islands, maxGap * 0.8) -- 80% of max gap for safety margin
    
    return CombineAndOptimize(pois, islands, gapFiller)
end
```

### **Traversal Path Generation**
```lua
function GenerateTraversalPath(startIsland, endIsland, maxGap, maxJumpHeight)
    local distance = (endIsland.Position - startIsland.Position).Magnitude
    local numSteppingStones = math.ceil(distance / (maxGap * 0.7)) -- 70% for overlap/safety
    
    local path = {}
    for i = 1, numSteppingStones do
        local t = i / (numSteppingStones + 1)
        local basePos = startIsland.Position:Lerp(endIsland.Position, t)
        
        -- Add height variation that respects jump limits
        local heightVariance = math.min(maxJumpHeight * 0.5, 20)
        local yOffset = math.sin(t * math.pi * 3) * heightVariance -- Sine wave for smooth variation
        
        -- Add lateral variation for interesting paths
        local lateralOffset = Vector3.new(
            math.sin(t * math.pi * 5) * 15,
            yOffset,
            math.cos(t * math.pi * 5) * 15
        )
        
        local island = {
            Position = basePos + lateralOffset,
            Size = SelectIslandSize("Small", distanceFromSpawn),
            Type = "SteppingStone"
        }
        
        table.insert(path, island)
    end
    
    return path
end
```

### **Height Variation Strategy**
```lua
function CalculateIslandHeight(baseHeight, distanceFromSpawn, islandType)
    -- Gradual height increase with distance
    local distanceHeight = math.sqrt(distanceFromSpawn) * 2 -- Very gentle rise
    
    -- Type-specific height modifiers
    local typeModifiers = {
        Small = {min = -5, max = 5},
        Medium = {min = -10, max = 15},
        Large = {min = 0, max = 30}, -- POIs tend to be higher
        SteppingStone = {min = -3, max = 3} -- Minimal variation for traversal
    }
    
    local modifier = typeModifiers[islandType]
    local variance = math.random() * (modifier.max - modifier.min) + modifier.min
    
    -- Apply wave pattern for visual interest
    local waveHeight = math.sin(distanceFromSpawn * 0.01) * 10
    
    return baseHeight + distanceHeight + variance + waveHeight
end
```

## POI (Large Island) Dungeon System

### **Dungeon Generation Architecture**
```lua
-- POI islands are semi-procedural dungeons with fixed room templates
POIDungeonConfig = {
    roomTypes = {
        "Entrance",    -- Always first, safe zone
        "Combat",      -- Enemy encounter room
        "Puzzle",      -- Environmental challenge
        "Treasure",    -- Loot room with chest/lantern
        "Boss",        -- MiniBoss encounter (optional)
        "Junction",    -- Multi-path choice point
    },
    
    layoutTemplates = {
        Linear = {"Entrance", "Combat", "Puzzle", "Treasure"},
        Branch = {"Entrance", "Junction", "Combat|Puzzle", "Treasure"},
        Complex = {"Entrance", "Combat", "Junction", "Puzzle", "Combat", "Boss", "Treasure"},
    }
}

function GeneratePOIDungeon(island, distanceFromSpawn, theme)
    local difficulty = CalculateDifficulty(distanceFromSpawn)
    local layout = SelectLayout(difficulty)
    local dungeon = {}
    
    -- Room generation with proper spacing
    local roomSpacing = 40 -- studs between room centers
    local currentPos = island.Position + Vector3.new(0, 10, 0) -- Start elevated
    
    for i, roomType in ipairs(layout) do
        local room = {
            type = roomType,
            position = currentPos,
            size = GetRoomSize(roomType),
            enemies = GenerateRoomEnemies(roomType, difficulty),
            loot = GenerateRoomLoot(roomType, difficulty, theme),
            connections = {}
        }
        
        -- Create physical room geometry
        room.model = BuildRoomGeometry(room, theme)
        
        -- Add traversal elements between rooms
        if i > 1 then
            local prevRoom = dungeon[i-1]
            local connection = CreateRoomConnection(prevRoom, room)
            table.insert(prevRoom.connections, connection)
        end
        
        -- Update position for next room with height variation
        local angle = (i / #layout) * math.pi * 2
        local heightStep = (roomType == "Boss") and 15 or 5
        currentPos = currentPos + Vector3.new(
            math.cos(angle) * roomSpacing,
            heightStep,
            math.sin(angle) * roomSpacing
        )
        
        table.insert(dungeon, room)
    end
    
    return dungeon
end
```

### **Room Types and Mechanics**
```lua
RoomMechanics = {
    Entrance = {
        -- Safe zone with visual preview of dungeon
        enemies = 0,
        features = {"HealingStation", "DungeonMap"},
        size = Vector3.new(30, 20, 30)
    },
    
    Combat = {
        -- Wave-based enemy encounters
        enemyWaves = function(difficulty)
            return {
                {count = 5 + difficulty * 2, types = {"Swarmer"}},
                {count = 3 + difficulty, types = {"BeamSniper", "Leaper"}},
            }
        end,
        size = Vector3.new(50, 25, 50)
    },
    
    Puzzle = {
        -- Environmental challenges
        types = {"PlatformJumping", "BeamDodging", "TimedSwitches"},
        size = Vector3.new(40, 30, 40)
    },
    
    Treasure = {
        -- Loot room with guaranteed rewards
        lootTable = function(difficulty, theme)
            return {
                guaranteed = {"LegendaryLantern"},
                chance = {
                    {item = "OilCanister", chance = 0.8},
                    {item = "MobilityUpgrade", chance = 0.3},
                    {item = "ThemeSpecificRare", chance = 0.5}
                }
            }
        end,
        size = Vector3.new(25, 20, 25)
    },
    
    Boss = {
        -- MiniBoss encounter
        boss = function(theme, difficulty)
            return {
                type = theme.bossType,
                health = 100 * difficulty,
                phases = math.min(3, 1 + math.floor(difficulty / 3))
            }
        end,
        size = Vector3.new(60, 35, 60)
    }
}
```

## Refined Enemy Behaviors

### **BeamSniper (Ranged Tracking)**
```lua
BeamSniperBehavior = {
    lockTime = 2.0, -- seconds to lock on
    beamColor = Color3.new(1, 0, 0), -- Red tracking beam
    
    -- Lock mechanics
    lockBreakTime = 0.5, -- seconds of LOS loss before lock breaks
    turnRateCap = math.rad(90), -- degrees per second max turn
    
    -- Visual feedback
    beamStages = {
        [0.0] = {transparency = 0.8, thickness = 0.1}, -- Initial tracking
        [1.0] = {transparency = 0.5, thickness = 0.2}, -- Locking
        [1.8] = {transparency = 0.2, thickness = 0.3}, -- Almost locked
        [2.0] = {transparency = 0.0, thickness = 0.5}, -- FIRE! Solid beam
    },
    
    -- Damage and cooldown
    damage = 15,
    cooldown = 3.0,
    range = 150
}
```

### **Leaper (Gap-Closing)**
```lua
LeaperBehavior = {
    -- Ballistic leap parameters
    leapVelocity = 80, -- studs/second
    leapCooldown = 3.0,
    leapDamage = 20,
    
    -- Targeting
    predictiveTargeting = true, -- Aim where player will be
    maxLeapDistance = 100,
    minLeapDistance = 20,
    
    -- Failover for void/unreachable
    failoverMode = "RangedSpit",
    spitProjectile = {
        speed = 60,
        damage = 10,
        arcHeight = 15 -- Projectile arc
    },
    
    -- Landing validation
    validateLanding = function(targetPos)
        local ray = workspace:Raycast(targetPos + Vector3.new(0, 50, 0), Vector3.new(0, -100, 0))
        if not ray or ray.Instance.Name == "VoidKillPart" then
            return false, "InvalidLanding"
        end
        return true
    end
}
```

### **Melee Swarmer (Adaptive)**
```lua
MeleeSwarmerBehavior = {
    -- Standard melee
    meleeRange = 8,
    meleeDamage = 8,
    attackSpeed = 1.5,
    
    -- Semi-ranged adaptation
    semiRangedThreshold = 15, -- Gap size that triggers semi-ranged
    semiRangedAttack = {
        type = "Lunge",
        range = 20,
        damage = 10,
        cooldown = 2.0
    },
    
    -- Group behavior
    swarmRadius = 30,
    sharedTargeting = true, -- Share target info with nearby swarmers
    maxSwarmSize = 8
}
```

## Network Optimization - Refined

### **Batch Window System**
```lua
NetworkBatcher = {
    windowSize = 100, -- milliseconds
    priorityQueues = {
        Critical = {}, -- Deaths, spawns
        High = {},     -- Damage, state changes
        Normal = {},   -- Movement updates
        Low = {}       -- Visual effects
    },
    
    -- Compression strategies per queue
    compression = {
        Critical = "None", -- Must be reliable
        High = "Delta",
        Normal = "Quantized", -- 0.1 stud grid
        Low = "Sampled" -- Drop 50% of updates if needed
    }
}
```

## Loading System - Forecast-Based

### **LoadingOverlay States**
```lua
LoadingStates = {
    Idle = {
        -- No loading needed
        overlay = false
    },
    
    Forecast = {
        -- Player approaching new content
        overlay = true,
        transparency = 0.7,
        message = "Discovering new islands...",
        showProgress = true,
        
        -- Preload actions
        actions = {
            "StreamIslandImpostors",
            "CacheEnemyModels",
            "PreloadThemeAssets"
        }
    },
    
    Active = {
        -- Loading critical content
        overlay = true,
        transparency = 0.3,
        message = "Entering new territory...",
        blockInput = true
    },
    
    Cooldown = {
        -- Fade out after load
        overlay = true,
        transparency = "fade_out",
        duration = 1.0
    }
}

function ForecastLoading(player)
    local position = player.Character.PrimaryPart.Position
    local lookAhead = position + (player.Character.PrimaryPart.CFrame.LookVector * 200)
    
    -- Check if approaching unloaded content
    local nearbyIslands = SkyIslandService:GetIslandsInRadius(lookAhead, 500)
    local unloadedCount = 0
    
    for _, island in pairs(nearbyIslands) do
        if not island.loaded then
            unloadedCount = unloadedCount + 1
        end
    end
    
    if unloadedCount > 3 then
        SetLoadingState(player, "Forecast")
        PreloadIslandContent(nearbyIslands)
    end
end
```

## Performance Scaling - Dynamic

```lua
PerformanceManager = {
    -- FPS-based scaling
    targetServerFPS = 30,
    targetClientFPS = 60,
    
    -- Scaling factors
    scalingRules = {
        {metric = "ServerFPS", threshold = 25, action = "ReduceEnemies", factor = 0.8},
        {metric = "ServerFPS", threshold = 20, action = "DisableLOD3", factor = 1.0},
        {metric = "ClientFPS", threshold = 30, action = "ReduceParticles", factor = 0.5},
        {metric = "NetworkBytes", threshold = 10000, action = "IncreaseQuantization", factor = 2.0}
    },
    
    -- Island LOD distances (adjusted dynamically)
    lodDistances = {
        Full = {min = 0, max = 200},
        Simplified = {min = 200, max = 500},
        Impostor = {min = 500, max = 1000},
        Culled = {min = 1000, max = math.huge}
    }
}
```

## Integration Boundaries - Clean Separation

```lua
-- Combat systems do NOT touch these existing services:
ExistingServices = {
    "PlacementService",     -- Building placement
    "LanternService",       -- Lantern management
    "OilService",          -- Oil management
    "PondNetworkService",   -- Pond/canal system
    "PlotService"          -- Plot boundaries
}

-- Combat has its own parallel services:
CombatServices = {
    "RoundProgressionService",  -- Round/theme management
    "SkyIslandService",        -- Island generation
    "EnemyOrchestrator",       -- Enemy spawning
    "CombatLootService",       -- Combat-specific loot
    "MobilityService"          -- Movement upgrades
}

-- Interaction points (one-way dependencies):
CombatToExisting = {
    -- Combat can READ from existing services
    ["CombatLootService"] = {
        reads = {"LanternService"}, -- To grant lantern fragments
        writes = {} -- Never writes directly
    },
    ["SkyIslandService"] = {
        reads = {"PlotService"}, -- To respect plot boundaries
        writes = {}
    }
}
```

## Minimal Build Plan - Revised

### **Phase A: Skeleton (Week 1)**
```lua
-- Core services with stubs
Tasks = {
    {file = "RoundProgressionService.luau", features = {"shard-local rounds", "distance triggers"}},
    {file = "SkyIslandService.luau", features = {"mobility-aware spacing", "POI anchoring"}},
    {file = "EnemyOrchestrator.luau", features = {"spawn waves", "enemy caps"}},
    {file = "EnemyBehaviorClient.luau", features = {"3 enemy stubs", "basic movement"}},
    {file = "LoadingOverlay.luau", features = {"forecast state", "progress bar"}}
}
```

### **Phase B: Feel Pass (Week 2)**
```lua
Tasks = {
    {file = "BeamSniperAI.luau", features = {"lock mechanics", "visual feedback", "dodge windows"}},
    {file = "LeaperAI.luau", features = {"ballistic leap", "failover spit", "landing validation"}},
    {file = "SwarmerAI.luau", features = {"group behavior", "semi-ranged adaptation"}},
    {file = "IslandLOD.luau", features = {"impostor generation", "distance-based switching"}},
    {file = "NetworkBatcher.luau", features = {"100ms windows", "priority queues"}}
}
```

### **Phase C: Theme & Loot (Week 3)**
```lua
Tasks = {
    {file = "ThemePackages.luau", features = {"material sets", "weather presets", "enemy modifiers"}},
    {file = "CombatLootTables.luau", features = {"distance scaling", "theme bonuses", "legendary drops"}},
    {file = "POIDungeonBuilder.luau", features = {"room templates", "traversal connections"}},
    {file = "MiniBossAI.luau", features = {"phase transitions", "special attacks"}}
}
```

## Distance → Spawn Curves

```lua
-- Enemy density formulas
function GetEnemyCount(distanceFromSpawn, islandSize, playerCount)
    local baseDensity = {
        Small = 0,  -- No enemies on stepping stones
        Medium = 2 + math.floor(distanceFromSpawn / 500),
        Large = 5 + math.floor(distanceFromSpawn / 300)
    }
    
    local islandDensity = baseDensity[islandSize] or 0
    local playerMultiplier = 1 + (playerCount - 1) * 0.3 -- +30% per additional player
    
    return math.floor(islandDensity * playerMultiplier)
end

-- Island rarity by distance
function GetIslandTypeChance(distanceFromSpawn)
    if distanceFromSpawn < 500 then
        return {Small = 0.7, Medium = 0.25, Large = 0.05}
    elseif distanceFromSpawn < 1500 then
        return {Small = 0.4, Medium = 0.4, Large = 0.2}
    else
        return {Small = 0.2, Medium = 0.45, Large = 0.35}
    end
end
```

## Theme Matrix Example

```lua
Themes = {
    Storm = {
        materials = {Enum.Material.Slate, Enum.Material.Basalt},
        weather = {
            fog = {density = 0.8, color = Color3.fromRGB(50, 50, 70)},
            wind = {strength = 30, direction = Vector3.new(1, 0.2, 0)},
            lightning = {frequency = 0.1}
        },
        enemyModifiers = {
            BeamSniper = {turnRate = 1.2, lockTime = 1.8}, -- Faster in storms
            Leaper = {cooldown = 2.5, velocity = 90},       -- More aggressive
            Swarmer = {speed = 1.1, damage = 1.0}
        },
        lootBonus = {
            electric = 1.5,  -- Electric-themed items
            standard = 1.0
        },
        hazards = {
            "LightningStrikes",  -- Random damage zones
            "WindPush"          -- Affects projectiles and jumps
        }
    },
    
    Crystal = {
        materials = {Enum.Material.Glass, Enum.Material.Neon},
        weather = {
            fog = {density = 0.3, color = Color3.fromRGB(150, 180, 200)},
            particles = {type = "CrystalShards", density = 0.5}
        },
        enemyModifiers = {
            BeamSniper = {turnRate = 0.8, lockTime = 2.5, damage = 1.3}, -- Slower but harder hitting
            Leaper = {cooldown = 3.5, arcHeight = 20},                   -- Higher jumps
            Swarmer = {speed = 0.9, health = 1.2}                        -- Tankier
        },
        lootBonus = {
            crystal = 2.0,  -- Crystal-themed items drop more
            standard = 0.8
        },
        hazards = {
            "CrystalBeams",    -- Environmental laser hazards
            "FragilePlatforms" -- Break after standing too long
        }
    }
}
```

## Conclusion

This refined architecture addresses your key concerns:

1. **Mobility-based progression** through careful island spacing algorithms
2. **Shard-local rounds** by default with optional global sync
3. **Detailed POI dungeons** with room-based layouts and traversal design
4. **Height variation** that's interesting but respects jump limits
5. **Clean separation** from existing building/economy systems
6. **Forecast-based loading** to replace the broken loader
7. **Precise enemy behaviors** with failover modes for aerial combat

The system maintains server-light validation while ensuring fair, skill-based progression through increasingly challenging sky territories.