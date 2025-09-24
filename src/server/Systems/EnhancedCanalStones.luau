-- EnhancedCanalStones.server.luau
-- Improved canal stone system with proper positioning and rotation along canal paths

local Workspace = Workspace or game:GetService("Workspace")
local ReplicatedStorage = ReplicatedStorage or game:GetService("ReplicatedStorage")

-- Try to use existing BoundaryHeightUtil, fall back to basic implementation
local BoundaryHeightUtil
do
    local success, module = pcall(function()
        return require(ReplicatedStorage.Shared.BoundaryHeightUtil)
    end)
    if success then
        BoundaryHeightUtil = module
    else
        -- Fallback implementation
        BoundaryHeightUtil = {
            getGroundHeight = function(position)
                -- Basic raycast down to find ground
                local raycast = workspace:Raycast(
                    Vector3.new(position.X, 100, position.Z),
                    Vector3.new(0, -200, 0)
                )
                return raycast and raycast.Position.Y or 0
            end,
            getCanalStoneY = function(canalId, position)
                -- Basic implementation - just use ground height
                local raycast = workspace:Raycast(
                    Vector3.new(position.X, 100, position.Y),
                    Vector3.new(0, -200, 0)
                )
                return raycast and raycast.Position.Y + 0.5 or 0.5
            end
        }
    end
end

local EnhancedCanalStones = {}

-- Stone configuration
local STONE_CONFIG = {
    spacing = 6, -- Distance between stones (closer for better coverage)
    heightVariation = 1, -- Random height variation
    sizeVariation = 0.2, -- Random size variation (0.8 to 1.2 scale)
    rotationVariation = 15, -- Random rotation variation in degrees
    minSize = Vector3.new(1.8, 1.2, 3.5), -- Longer stones for canal coverage
    maxSize = Vector3.new(2.4, 1.8, 4.2),
    materials = {
        Enum.Material.Rock,
        Enum.Material.Concrete,
        Enum.Material.Cobblestone
    },
    colors = {
        Color3.fromRGB(120, 120, 120), -- Gray
        Color3.fromRGB(100, 100, 100), -- Dark gray
        Color3.fromRGB(140, 130, 120), -- Brown-gray
        Color3.fromRGB(90, 85, 80),    -- Dark brown-gray
    }
}

-- Calculate positions along a path with proper spacing
local function calculateStonePositionsAlongPath(path, spacing)
    if not path or #path < 2 then
        return {}
    end
    
    -- Calculate total path length
    local totalLength = 0
    local segmentLengths = {}
    
    for i = 1, #path - 1 do
        local segLength = (path[i + 1] - path[i]).Magnitude
        table.insert(segmentLengths, segLength)
        totalLength = totalLength + segLength
    end
    
    if totalLength < spacing then
        return {path[1], path[#path]} -- Just start and end
    end
    
    -- Calculate number of stones needed
    local numStones = math.max(2, math.floor(totalLength / spacing) + 1)
    
    local positions = {}
    local directions = {}
    
    -- Generate evenly spaced positions along path
    for i = 0, numStones - 1 do
        local targetDistance = (i / (numStones - 1)) * totalLength
        
        -- Find which segment this distance falls in
        local currentDistance = 0
        local segmentIndex = 1
        
        for j = 1, #segmentLengths do
            if currentDistance + segmentLengths[j] >= targetDistance then
                segmentIndex = j
                break
            end
            currentDistance = currentDistance + segmentLengths[j]
        end
        
        -- Calculate position within the segment
        local remainingDistance = targetDistance - currentDistance
        local segmentLength = segmentLengths[segmentIndex]
        local t = segmentLength > 0 and (remainingDistance / segmentLength) or 0
        
        local segmentStart = path[segmentIndex]
        local segmentEnd = path[segmentIndex + 1]
        
        -- Interpolate position
        local position = segmentStart:Lerp(segmentEnd, t)
        
        -- Calculate direction (for rotation)
        local direction = (segmentEnd - segmentStart).Unit
        
        table.insert(positions, position)
        table.insert(directions, direction)
    end
    
    return positions, directions
end

-- Create a single stone with proper rotation
local function createStone(position, direction, seed, stoneIndex)
    local random = Random.new(seed + stoneIndex)
    
    -- Calculate ground height - handle both Vector2 and Vector3 positions
    local worldPos = position
    if typeof(position) == "Vector2" then
        worldPos = Vector3.new(position.X, 0, position.Y)
    end
    
    local groundY = BoundaryHeightUtil.getGroundHeight(worldPos)
    local stonePosition = Vector3.new(
        worldPos.X,
        groundY + random:NextNumber(0, STONE_CONFIG.heightVariation),
        worldPos.Z
    )
    
    -- Create stone part
    local stone = Instance.new("Part")
    stone.Name = "CanalStone_" .. stoneIndex
    stone.Material = STONE_CONFIG.materials[random:NextInteger(1, #STONE_CONFIG.materials)]
    stone.Color = STONE_CONFIG.colors[random:NextInteger(1, #STONE_CONFIG.colors)]
    stone.Anchored = true
    stone.CanCollide = true
    stone.CanTouch = false
    
    -- Size variation
    local baseSize = STONE_CONFIG.minSize:Lerp(
        STONE_CONFIG.maxSize,
        random:NextNumber(0, 1)
    )
    local sizeMultiplier = 1 + random:NextNumber(-STONE_CONFIG.sizeVariation, STONE_CONFIG.sizeVariation)
    stone.Size = baseSize * sizeMultiplier
    
    -- Position stone
    stone.Position = stonePosition
    
    -- Calculate rotation to align with canal direction
    local rotationY = 0
    if direction and direction.Magnitude > 0 then
        -- Calculate angle from direction vector
        rotationY = math.atan2(direction.Z, direction.X) -- Facing along the canal
        rotationY = math.deg(rotationY)
    end
    
    -- Add random variation to rotation
    local rotationVariation = random:NextNumber(-STONE_CONFIG.rotationVariation, STONE_CONFIG.rotationVariation)
    
    -- Set rotation
    stone.Rotation = Vector3.new(
        random:NextNumber(-3, 3), -- Slight X tilt
        rotationY + rotationVariation, -- Y rotation aligned with canal + variation
        random:NextNumber(-3, 3)  -- Slight Z tilt
    )
    
    -- Shape (mostly blocks for canal stones)
    if random:NextNumber(0, 1) > 0.8 then
        stone.Shape = Enum.PartType.Ball
    else
        stone.Shape = Enum.PartType.Block
    end
    
    return stone, stonePosition
end

-- Create canal stones from a path with proper positioning and rotation
function EnhancedCanalStones:CreateCanalStones(canalId, pointA, pointB, seed, pathPoints)
    -- Use provided path or create simple path from A to B
    local path = pathPoints
    if not path then
        -- Convert Vector2 to Vector3 if needed
        if typeof(pointA) == "Vector2" then
            pointA = Vector3.new(pointA.X, 0, pointA.Y)
        end
        if typeof(pointB) == "Vector2" then
            pointB = Vector3.new(pointB.X, 0, pointB.Y)
        end
        path = {pointA, pointB}
    else
        -- Convert Vector2 path to Vector3 if needed
        local convertedPath = {}
        for _, point in ipairs(path) do
            if typeof(point) == "Vector2" then
                table.insert(convertedPath, Vector3.new(point.X, 0, point.Y))
            else
                table.insert(convertedPath, point)
            end
        end
        path = convertedPath
    end
    
    -- Calculate stone positions along the path
    local positions, directions = calculateStonePositionsAlongPath(path, STONE_CONFIG.spacing)
    local stoneData = {}
    
    -- Create folder if it doesn't exist
    local canalFolder = Workspace:FindFirstChild("CanalStones")
    if not canalFolder then
        canalFolder = Instance.new("Folder")
        canalFolder.Name = "CanalStones"
        canalFolder.Parent = Workspace
    end
    
    -- Create canal-specific folder
    local thisCanalFolder = Instance.new("Folder")
    thisCanalFolder.Name = "Canal_" .. canalId
    thisCanalFolder.Parent = canalFolder
    
    -- Create stones and collect their data
    for i, position in ipairs(positions) do
        local direction = directions and directions[i] or Vector3.new(1, 0, 0)
        local stone, actualPosition = createStone(position, direction, seed, i)
        stone.Name = "Stone_" .. i
        stone.Parent = thisCanalFolder
        
        -- Store stone data for persistence
        table.insert(stoneData, {
            position = actualPosition,
            rotation = stone.Rotation,
            size = stone.Size,
            material = stone.Material.Name,
            color = {
                R = stone.Color.R,
                G = stone.Color.G,
                B = stone.Color.B
            },
            shape = stone.Shape.Name,
            stoneIndex = i,
            direction = direction -- Store direction for reconstruction
        })
    end
    
    print(string.format("[EnhancedCanalStones] Created %d stones for canal %s along path", #stoneData, canalId))
    
    return stoneData
end

-- Create canal stones from Bezier path (for compatibility with PondNetworkService)
function EnhancedCanalStones:CreateCanalStonesFromBezierPath(canalId, bezierPath, seed)
    if not bezierPath or #bezierPath < 2 then
        return {}
    end
    
    -- Convert Vector2 bezier path to Vector3 if needed
    local convertedPath = {}
    for _, point in ipairs(bezierPath) do
        if typeof(point) == "Vector2" then
            table.insert(convertedPath, Vector3.new(point.X, 0, point.Y))
        else
            table.insert(convertedPath, point)
        end
    end
    
    return self:CreateCanalStones(canalId, nil, nil, seed, convertedPath)
end

-- Reconstruct canal stones from saved data
function EnhancedCanalStones:ReconstructCanalStones(canalId, stoneData)
    if not stoneData or #stoneData == 0 then
        return
    end
    
    -- Create folder if it doesn't exist
    local canalFolder = Workspace:FindFirstChild("CanalStones")
    if not canalFolder then
        canalFolder = Instance.new("Folder")
        canalFolder.Name = "CanalStones"
        canalFolder.Parent = Workspace
    end
    
    -- Remove existing canal folder if it exists
    local existingFolder = canalFolder:FindFirstChild("Canal_" .. canalId)
    if existingFolder then
        existingFolder:Destroy()
    end
    
    -- Create new canal folder
    local thisCanalFolder = Instance.new("Folder")
    thisCanalFolder.Name = "Canal_" .. canalId
    thisCanalFolder.Parent = canalFolder
    
    -- Recreate stones from saved data
    for _, data in ipairs(stoneData) do
        local stone = Instance.new("Part")
        stone.Name = "Stone_" .. data.stoneIndex
        stone.Position = data.position
        stone.Rotation = data.rotation
        stone.Size = data.size
        stone.Material = Enum.Material[data.material]
        stone.Color = Color3.new(data.color.R, data.color.G, data.color.B)
        stone.Shape = Enum.PartType[data.shape]
        stone.Anchored = true
        stone.CanCollide = true
        stone.CanTouch = false
        stone.Parent = thisCanalFolder
    end
    
    print(string.format("[EnhancedCanalStones] Reconstructed %d stones for canal %s", #stoneData, canalId))
end

-- Remove canal stones
function EnhancedCanalStones:RemoveCanalStones(canalId)
    local canalFolder = Workspace:FindFirstChild("CanalStones")
    if canalFolder then
        local thisCanalFolder = canalFolder:FindFirstChild("Canal_" .. canalId)
        if thisCanalFolder then
            thisCanalFolder:Destroy()
        end
    end
end

-- Get all canal stone data for a specific canal (for persistence)
function EnhancedCanalStones:GetCanalStoneData(canalId)
    local canalFolder = Workspace:FindFirstChild("CanalStones")
    if not canalFolder then
        return {}
    end
    
    local thisCanalFolder = canalFolder:FindFirstChild("Canal_" .. canalId)
    if not thisCanalFolder then
        return {}
    end
    
    local stoneData = {}
    for _, stone in pairs(thisCanalFolder:GetChildren()) do
        if stone:IsA("Part") then
            table.insert(stoneData, {
                position = stone.Position,
                rotation = stone.Rotation,
                size = stone.Size,
                material = stone.Material.Name,
                color = {
                    R = stone.Color.R,
                    G = stone.Color.G,
                    B = stone.Color.B
                },
                shape = stone.Shape.Name,
                stoneIndex = tonumber(stone.Name:match("Stone_(%d+)")) or 1
            })
        end
    end
    
    return stoneData
end

-- Legacy compatibility function for existing CanalBuilder
function EnhancedCanalStones.CreateCanalStonesLegacy(canalId, path, width)
    if not path or #path < 2 then
        return {}
    end
    
    -- Use deterministic seed based on path
    local seed = 12345
    if #path >= 2 then
        local pointA = path[1]
        local pointB = path[#path]
        
        -- Convert to Vector3 for seed calculation
        if typeof(pointA) == "Vector2" then
            pointA = Vector3.new(pointA.X, 0, pointA.Y)
        end
        if typeof(pointB) == "Vector2" then
            pointB = Vector3.new(pointB.X, 0, pointB.Y)
        end
        
        seed = math.floor(pointA.X + pointA.Z * 1000 + pointB.X * 100 + pointB.Z * 10000)
    end
    
    return EnhancedCanalStones:CreateCanalStones(canalId, nil, nil, seed, path)
end

return EnhancedCanalStones