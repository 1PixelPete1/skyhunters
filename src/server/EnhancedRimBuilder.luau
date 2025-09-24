-- EnhancedRimBuilder.server.luau
-- Improved rim stone system with better spacing and visual variation

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
            end
        }
    end
end

local EnhancedRimBuilder = {}

-- Enhanced configuration for better visual appeal
local RIM_CONFIG = {
    stoneSize = {
        min = Vector3.new(2, 1.5, 2),
        max = Vector3.new(4, 3, 4)
    },
    spacing = {
        min = 3.5, -- Minimum distance between stone centers
        max = 5.5, -- Maximum distance between stone centers
    },
    positioning = {
        radiusOffset = 1.5, -- How far from pond edge to place stones
        heightVariation = 1, -- Random height variation
        shoulderToShoulder = true, -- Ensure stones touch/nearly touch
    },
    variation = {
        sizeJitter = 0.4, -- Size variation multiplier
        rotationRange = 60, -- Random rotation in degrees
        tiltRange = 8, -- Random tilt in degrees
        colorVariation = true,
    },
    materials = {
        Enum.Material.Rock,
        Enum.Material.Cobblestone,
        Enum.Material.Concrete,
    },
    colors = {
        Color3.fromRGB(130, 125, 120), -- Light gray-brown
        Color3.fromRGB(110, 105, 100), -- Medium gray-brown
        Color3.fromRGB(90, 85, 80),    -- Dark gray-brown
        Color3.fromRGB(140, 130, 115),  -- Warm gray
        Color3.fromRGB(125, 120, 110),  -- Cool gray
    }
}

-- Calculate optimal stone placement for shoulder-to-shoulder effect
local function calculateStonePositions(center, radius, seed)
    local random = Random.new(seed)
    local positions = {}
    
    -- Calculate circumference and estimate number of stones needed
    local circumference = 2 * math.pi * (radius + RIM_CONFIG.positioning.radiusOffset)
    local avgSpacing = (RIM_CONFIG.spacing.min + RIM_CONFIG.spacing.max) / 2
    local estimatedStones = math.floor(circumference / avgSpacing)
    
    -- Ensure minimum number of stones for visual appeal
    local numStones = math.max(8, estimatedStones)
    
    -- Calculate actual spacing
    local angleStep = (2 * math.pi) / numStones
    
    for i = 0, numStones - 1 do
        -- Base angle with small random variation
        local baseAngle = i * angleStep
        local angleVariation = random:NextNumber(-angleStep * 0.2, angleStep * 0.2)
        local angle = baseAngle + angleVariation
        
        -- Calculate position
        local stoneRadius = radius + RIM_CONFIG.positioning.radiusOffset + random:NextNumber(-0.5, 0.5)
        local x = center.X + math.cos(angle) * stoneRadius
        local z = center.Z + math.sin(angle) * stoneRadius
        
        table.insert(positions, {
            worldPos = Vector3.new(x, 0, z), -- Y will be set by ground height
            angle = angle,
            stoneIndex = i
        })
    end
    
    return positions
end

-- Create a single rim stone with enhanced variation
local function createRimStone(stoneData, pondCenter, seed)
    local random = Random.new(seed + stoneData.stoneIndex * 1000)
    
    -- Calculate ground height
    local groundY = BoundaryHeightUtil.getGroundHeight(stoneData.worldPos)
    local finalY = groundY + random:NextNumber(0, RIM_CONFIG.positioning.heightVariation)
    local finalPosition = Vector3.new(stoneData.worldPos.X, finalY, stoneData.worldPos.Z)
    
    -- Create stone part
    local stone = Instance.new("Part")
    stone.Name = "RimStone_" .. stoneData.stoneIndex
    stone.Anchored = true
    stone.CanCollide = true
    stone.CanTouch = false
    
    -- Material and color
    stone.Material = RIM_CONFIG.materials[random:NextInteger(1, #RIM_CONFIG.materials)]
    stone.Color = RIM_CONFIG.colors[random:NextInteger(1, #RIM_CONFIG.colors)]
    
    -- Size with variation
    local baseSize = RIM_CONFIG.stoneSize.min:Lerp(RIM_CONFIG.stoneSize.max, random:NextNumber(0, 1))
    local sizeMultiplier = 1 + random:NextNumber(-RIM_CONFIG.variation.sizeJitter, RIM_CONFIG.variation.sizeJitter)
    stone.Size = baseSize * sizeMultiplier
    
    -- Position
    stone.Position = finalPosition
    
    -- Rotation with variation
    local faceAngle = stoneData.angle + random:NextNumber(-RIM_CONFIG.variation.rotationRange/2, RIM_CONFIG.variation.rotationRange/2)
    stone.Rotation = Vector3.new(
        random:NextNumber(-RIM_CONFIG.variation.tiltRange, RIM_CONFIG.variation.tiltRange), -- X tilt
        math.deg(faceAngle), -- Y rotation (facing pond)
        random:NextNumber(-RIM_CONFIG.variation.tiltRange, RIM_CONFIG.variation.tiltRange)  -- Z tilt
    )
    
    -- Shape variation
    if random:NextNumber(0, 1) > 0.3 then
        stone.Shape = Enum.PartType.Block
        
        -- Add corner rounding for more natural look
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, random:NextNumber(2, 6))
        corner.Parent = stone
    else
        stone.Shape = Enum.PartType.Ball
    end
    
    -- Add mesh for additional variation on blocks
    if stone.Shape == Enum.PartType.Block and random:NextNumber(0, 1) > 0.5 then
        local mesh = Instance.new("SpecialMesh")
        mesh.MeshType = Enum.MeshType.Brick
        mesh.Scale = Vector3.new(
            random:NextNumber(0.8, 1.0),
            random:NextNumber(0.9, 1.0),
            random:NextNumber(0.8, 1.0)
        )
        mesh.Parent = stone
    end
    
    return stone, finalPosition
end

-- Create rim stones with enhanced positioning
function EnhancedRimBuilder:CreateRimStones(pondId, center, radius, seed)
    -- Calculate stone positions
    local stonePositions = calculateStonePositions(center, radius, seed)
    local rimData = {}
    
    -- Create folder structure
    local rimFolder = Workspace:FindFirstChild("PondRims")
    if not rimFolder then
        rimFolder = Instance.new("Folder")
        rimFolder.Name = "PondRims"
        rimFolder.Parent = Workspace
    end
    
    -- Create pond-specific folder
    local pondFolder = Instance.new("Folder")
    pondFolder.Name = "Pond_" .. pondId
    pondFolder.Parent = rimFolder
    
    -- Create stones
    for _, stoneData in ipairs(stonePositions) do
        local stone, actualPosition = createRimStone(stoneData, center, seed)
        stone.Parent = pondFolder
        
        -- Store rim data for persistence
        table.insert(rimData, {
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
            stoneIndex = stoneData.stoneIndex
        })
    end
    
    return rimData
end

-- Reconstruct rim stones from saved data
function EnhancedRimBuilder:ReconstructRimStones(pondId, rimData)
    if not rimData or #rimData == 0 then
        return
    end
    
    -- Create folder structure
    local rimFolder = Workspace:FindFirstChild("PondRims")
    if not rimFolder then
        rimFolder = Instance.new("Folder")
        rimFolder.Name = "PondRims"
        rimFolder.Parent = Workspace
    end
    
    -- Remove existing pond folder if it exists
    local existingFolder = rimFolder:FindFirstChild("Pond_" .. pondId)
    if existingFolder then
        existingFolder:Destroy()
    end
    
    -- Create new pond folder
    local pondFolder = Instance.new("Folder")
    pondFolder.Name = "Pond_" .. pondId
    pondFolder.Parent = rimFolder
    
    -- Recreate stones from saved data
    for _, data in ipairs(rimData) do
        local stone = Instance.new("Part")
        stone.Name = "RimStone_" .. data.stoneIndex
        stone.Position = data.position
        stone.Rotation = data.rotation
        stone.Size = data.size
        stone.Material = Enum.Material[data.material]
        stone.Color = Color3.new(data.color.R, data.color.G, data.color.B)
        stone.Shape = Enum.PartType[data.shape]
        stone.Anchored = true
        stone.CanCollide = true
        stone.CanTouch = false
        stone.Parent = pondFolder
        
        -- Add corner rounding for blocks
        if stone.Shape == Enum.PartType.Block then
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, 4)
            corner.Parent = stone
        end
    end
end

-- Remove rim stones for a pond
function EnhancedRimBuilder:RemoveRimStones(pondId)
    local rimFolder = Workspace:FindFirstChild("PondRims")
    if rimFolder then
        local pondFolder = rimFolder:FindFirstChild("Pond_" .. pondId)
        if pondFolder then
            pondFolder:Destroy()
        end
    end
end

-- Get rim stone data for persistence
function EnhancedRimBuilder:GetRimStoneData(pondId)
    local rimFolder = Workspace:FindFirstChild("PondRims")
    if not rimFolder then
        return {}
    end
    
    local pondFolder = rimFolder:FindFirstChild("Pond_" .. pondId)
    if not pondFolder then
        return {}
    end
    
    local rimData = {}
    for _, stone in pairs(pondFolder:GetChildren()) do
        if stone:IsA("Part") then
            table.insert(rimData, {
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
                stoneIndex = tonumber(stone.Name:match("RimStone_(%d+)")) or 1
            })
        end
    end
    
    return rimData
end

-- Update existing rim stones (for live editing)
function EnhancedRimBuilder:UpdateRimAppearance(pondId, newSeed)
    local rimFolder = Workspace:FindFirstChild("PondRims")
    if not rimFolder then
        return
    end
    
    local pondFolder = rimFolder:FindFirstChild("Pond_" .. pondId)
    if not pondFolder then
        return
    end
    
    local random = Random.new(newSeed)
    
    for _, stone in pairs(pondFolder:GetChildren()) do
        if stone:IsA("Part") then
            -- Update color
            stone.Color = RIM_CONFIG.colors[random:NextInteger(1, #RIM_CONFIG.colors)]
            
            -- Update material
            stone.Material = RIM_CONFIG.materials[random:NextInteger(1, #RIM_CONFIG.materials)]
        end
    end
end

-- Legacy compatibility function (bridges to your existing RimBuilder)
function EnhancedRimBuilder.build(parent, center, radius, segments, rimSpacing)
    -- Convert Vector3 center to Vector2 if needed
    local centerVec2 = Vector3.new(center.X, center.Y, center.Z)
    if typeof(center) == "Vector3" then
        centerVec2 = center
    end
    
    -- Use a deterministic seed based on position
    local seed = math.floor(center.X + center.Z * 1000)
    
    -- Create rim stones with enhanced system
    local rimData = EnhancedRimBuilder:CreateRimStones("legacy_" .. seed, centerVec2, radius, seed)
    
    print(string.format("[EnhancedRimBuilder] Created %d rim stones for pond at (%.1f, %.1f)", #rimData, center.X, center.Z))
    
    return rimData
end

return EnhancedRimBuilder