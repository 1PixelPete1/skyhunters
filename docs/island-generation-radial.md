# Island Generation - Efficient Radial System

## Core Concept: Build Traversability Into Generation

Instead of generating islands randomly then validating, we generate islands in **radial bands** with guaranteed spacing. This ensures traversability by construction.

## The Radial Band Algorithm

```lua
-- Islands generate in concentric rings around the hub
-- Each ring guarantees at least one path to the next ring

function GenerateRadialIslandField(hubPosition, maxRadius, mobilityTier, roundSeed)
    local rng = Random.new(roundSeed)
    local mobilityData = MobilityTiers[mobilityTier]
    local islands = {}
    
    -- Define ring parameters
    local ringSpacing = mobilityData.maxGap * 0.8 -- 80% of max gap for safety
    local numRings = math.ceil(maxRadius / ringSpacing)
    
    -- Generate rings from inside out
    for ring = 1, numRings do
        local ringRadius = ring * ringSpacing
        local ringIslands = GenerateRing(hubPosition, ringRadius, ring, mobilityData, rng)
        
        -- Ensure each island in this ring can reach at least one island in previous ring
        if ring > 1 then
            ConnectToInnerRing(ringIslands, islands, mobilityData)
        end
        
        -- Add islands to master list
        for _, island in ipairs(ringIslands) do
            table.insert(islands, island)
        end
    end
    
    -- Place POIs at strategic points (no validation needed)
    PlacePOIsOnRings(islands, numRings, rng)
    
    return islands
end
```

## Ring Generation Strategy

```lua
function GenerateRing(center, radius, ringIndex, mobilityData, rng)
    local islands = {}
    
    -- Calculate island count for this ring
    -- More islands as rings get larger to maintain density
    local circumference = 2 * math.pi * radius
    local islandSpacing = mobilityData.maxGap * 0.7 -- Overlap for redundancy
    local baseCount = math.max(6, math.floor(circumference / islandSpacing))
    
    -- Add variety to count
    local countVariance = math.floor(baseCount * 0.2)
    local islandCount = baseCount + rng:NextInteger(-countVariance, countVariance)
    
    -- Distribute islands around the ring
    local angleStep = (2 * math.pi) / islandCount
    
    for i = 1, islandCount do
        -- Base angle with jitter
        local angle = (i - 1) * angleStep + rng:NextNumber(-angleStep * 0.3, angleStep * 0.3)
        
        -- Radius with variation (keeps islands roughly on ring)
        local radiusVariation = ringIndex * 5 -- More variation in outer rings
        local actualRadius = radius + rng:NextNumber(-radiusVariation, radiusVariation)
        
        -- Calculate position
        local x = center.X + math.cos(angle) * actualRadius
        local z = center.Z + math.sin(angle) * actualRadius
        
        -- Height increases with distance but with variety
        local baseHeight = 100 + math.sqrt(radius) * 2
        local heightVar = rng:NextNumber(-10, 20) -- Slight upward bias
        local y = baseHeight + heightVar
        
        -- Determine island type based on probability
        local islandType = DetermineIslandType(ringIndex, rng)
        
        local island = {
            position = Vector3.new(x, y, z),
            radius = GetIslandRadius(islandType, rng),
            type = islandType,
            ring = ringIndex,
            angle = angle
        }
        
        table.insert(islands, island)
    end
    
    return islands
end
```

## Smart POI Placement

```lua
function PlacePOIsOnRings(allIslands, numRings, rng)
    -- Place POIs at strategic intervals, not random positions
    -- This guarantees they're reachable without validation
    
    local poiRings = {} -- Which rings get POIs
    
    -- Start placing POIs after first few rings
    for ring = 3, numRings, 2 do -- Every other ring starting from ring 3
        table.insert(poiRings, ring)
    end
    
    for _, ring in ipairs(poiRings) do
        -- Find islands in this ring
        local ringIslands = {}
        for _, island in ipairs(allIslands) do
            if island.ring == ring then
                table.insert(ringIslands, island)
            end
        end
        
        -- Convert 2-4 islands per ring to POIs (evenly distributed)
        local poiCount = math.min(4, math.max(2, math.floor(#ringIslands / 8)))
        local poiStep = math.floor(#ringIslands / poiCount)
        
        for i = 1, poiCount do
            local index = ((i - 1) * poiStep) + 1
            if ringIslands[index] then
                -- Upgrade to POI
                ringIslands[index].type = "POI"
                ringIslands[index].radius = rng:NextNumber(60, 100)
                
                -- Slightly elevate POIs
                ringIslands[index].position = ringIslands[index].position + Vector3.new(0, 15, 0)
            end
        end
    end
end
```

## Efficient Connection Strategy

```lua
function ConnectToInnerRing(currentRing, allPreviousIslands, mobilityData)
    -- Each island just needs ONE connection to inner ring
    -- No need to validate entire graph
    
    local maxGap = mobilityData.maxGap
    
    for _, island in ipairs(currentRing) do
        local closest = nil
        local closestDist = math.huge
        
        -- Find closest island from any inner ring
        for _, innerIsland in ipairs(allPreviousIslands) do
            local dist = (island.position - innerIsland.position).Magnitude
            if dist < closestDist then
                closest = innerIsland
                closestDist = dist
            end
        end
        
        -- If closest is too far, add a bridge island
        if closestDist > maxGap * 0.9 then
            local bridgePos = island.position:Lerp(closest.position, 0.5)
            local bridge = {
                position = bridgePos,
                radius = 15, -- Small stepping stone
                type = "Bridge",
                ring = island.ring - 0.5 -- Between rings
            }
            table.insert(allPreviousIslands, bridge)
        end
    end
end
```

## Island Type Distribution

```lua
function DetermineIslandType(ringIndex, rng)
    -- Type probability changes with distance
    
    if ringIndex <= 2 then
        -- Inner rings: mostly small/medium
        local roll = rng:NextNumber()
        if roll < 0.7 then return "Small"
        else return "Medium" end
        
    elseif ringIndex <= 5 then
        -- Mid rings: balanced
        local roll = rng:NextNumber()
        if roll < 0.4 then return "Small"
        elseif roll < 0.8 then return "Medium"
        else return "Large" end -- Large but not POI yet
        
    else
        -- Outer rings: fewer small, more medium/large
        local roll = rng:NextNumber()
        if roll < 0.2 then return "Small"
        elseif roll < 0.7 then return "Medium"
        else return "Large" end
    end
end

function GetIslandRadius(islandType, rng)
    local ranges = {
        Small = {10, 20},
        Medium = {25, 45},
        Large = {50, 80},
        POI = {60, 100},
        Bridge = {12, 18}
    }
    
    local range = ranges[islandType]
    return rng:NextNumber(range[1], range[2])
end
```

## Directional Paths (Corridors)

To create more interesting traversal and ensure specific paths between POIs:

```lua
function CreateDirectionalCorridors(islands, mobilityData, rng)
    -- Create "highways" in cardinal/diagonal directions
    -- These are guaranteed paths with regular spacing
    
    local corridors = {
        {angle = 0, name = "East"},
        {angle = math.pi/2, name = "North"},
        {angle = math.pi, name = "West"},
        {angle = 3*math.pi/2, name = "South"},
        -- Optional diagonals
        {angle = math.pi/4, name = "NorthEast"},
        {angle = 3*math.pi/4, name = "NorthWest"},
    }
    
    local hubPos = Vector3.new(0, 100, 0)
    local maxGap = mobilityData.maxGap
    
    for _, corridor in ipairs(corridors) do
        local stepDistance = maxGap * 0.75 -- Reliable spacing
        local maxSteps = 20 -- Corridor length
        
        for step = 1, maxSteps do
            local distance = step * stepDistance
            
            -- Position along corridor
            local x = hubPos.X + math.cos(corridor.angle) * distance
            local z = hubPos.Z + math.sin(corridor.angle) * distance
            local y = hubPos.Y + math.sqrt(distance) * 2
            
            -- Check if island already exists nearby
            local tooClose = false
            for _, island in ipairs(islands) do
                if (island.position - Vector3.new(x, y, z)).Magnitude < 30 then
                    tooClose = true
                    break
                end
            end
            
            if not tooClose then
                -- Add corridor island
                local corridorIsland = {
                    position = Vector3.new(x, y, z),
                    radius = 20, -- Consistent medium size
                    type = "Corridor",
                    corridor = corridor.name
                }
                table.insert(islands, corridorIsland)
            end
        end
    end
    
    return islands
end
```

## Performance Optimizations

```lua
-- Spatial hashing for island queries
IslandSpatialHash = {
    cellSize = 100, -- studs
    cells = {}, -- [hashKey] = {island1, island2, ...}
    
    hash = function(self, position)
        local x = math.floor(position.X / self.cellSize)
        local z = math.floor(position.Z / self.cellSize)
        return x .. "," .. z
    end,
    
    insert = function(self, island)
        local key = self:hash(island.position)
        if not self.cells[key] then
            self.cells[key] = {}
        end
        table.insert(self.cells[key], island)
    end,
    
    getNearby = function(self, position, radius)
        local nearby = {}
        local cellRadius = math.ceil(radius / self.cellSize)
        
        local centerX = math.floor(position.X / self.cellSize)
        local centerZ = math.floor(position.Z / self.cellSize)
        
        for x = -cellRadius, cellRadius do
            for z = -cellRadius, cellRadius do
                local key = (centerX + x) .. "," .. (centerZ + z)
                if self.cells[key] then
                    for _, island in ipairs(self.cells[key]) do
                        if (island.position - position).Magnitude <= radius then
                            table.insert(nearby, island)
                        end
                    end
                end
            end
        end
        
        return nearby
    end
}
```

## Complete Generation Flow

```lua
function GenerateCompleteIslandField(config)
    local hubPos = config.hubPosition or Vector3.new(0, 100, 0)
    local maxRadius = config.maxRadius or 2000
    local mobilityTier = config.mobilityTier or 1
    local roundSeed = config.seed or tick()
    
    -- Step 1: Generate radial rings (guaranteed traversable)
    local islands = GenerateRadialIslandField(hubPos, maxRadius, mobilityTier, roundSeed)
    
    -- Step 2: Add directional corridors for reliable paths
    islands = CreateDirectionalCorridors(islands, MobilityTiers[mobilityTier], Random.new(roundSeed))
    
    -- Step 3: Build spatial hash for fast queries
    local spatialHash = IslandSpatialHash
    for _, island in ipairs(islands) do
        spatialHash:insert(island)
    end
    
    -- Step 4: Generate dungeon layouts for POIs (can be async)
    task.spawn(function()
        for _, island in ipairs(islands) do
            if island.type == "POI" then
                island.dungeonLayout = GenerateDungeonLayout(island, roundSeed)
            end
        end
    end)
    
    return {
        islands = islands,
        spatialHash = spatialHash,
        metadata = {
            totalIslands = #islands,
            rings = math.ceil(maxRadius / (MobilityTiers[mobilityTier].maxGap * 0.8)),
            seed = roundSeed
        }
    }
end
```

## Why This Works

1. **No Validation Needed**: Islands are placed with guaranteed spacing by construction
2. **Radial Expansion**: Natural progression outward from hub
3. **Predictable Performance**: O(n) generation, no graph traversal needed
4. **Flexible Paths**: Multiple routes via rings + corridors
5. **Scalable**: Can generate hundreds of islands efficiently

## Configuration Examples

```lua
-- Easy mode: close spacing, many bridges
EasyConfig = {
    mobilityTier = 1,
    ringSpacingMultiplier = 0.6, -- Rings closer together
    bridgeFrequency = 0.8, -- More bridge islands
    corridorCount = 8 -- More directional paths
}

-- Hard mode: far spacing, fewer bridges
HardConfig = {
    mobilityTier = 1, -- Same gear, harder traversal
    ringSpacingMultiplier = 0.9, -- Rings at 90% of max gap
    bridgeFrequency = 0.3, -- Fewer bridges
    corridorCount = 4 -- Only cardinal directions
}

-- Endgame: requires high mobility
EndgameConfig = {
    mobilityTier = 4,
    ringSpacingMultiplier = 0.85,
    bridgeFrequency = 0.1, -- Almost no bridges
    corridorCount = 0 -- No guaranteed corridors
}
```

This approach is much more efficient and naturally creates the radial expansion pattern you want, with guaranteed traversability built into the generation rather than checked afterward.