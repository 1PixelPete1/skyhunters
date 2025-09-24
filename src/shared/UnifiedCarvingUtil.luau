--!strict
-- UnifiedCarvingUtil: Single source of truth for terrain carving
-- Simplified to use reliable FillBall operations for bowl shape

local UnifiedCarvingUtil = {}

local RS = game:GetService("ReplicatedStorage")
local WorldConfig = require(RS.Config.WorldConfig)

-- Unified hemisphere/bowl carving function used by both default and dynamic pond creation
function UnifiedCarvingUtil.carveBowl(center: Vector3, radius: number, depth: number, shapeParams: any?)
    local params = shapeParams or {}
    local rimGap = params.rimGap or 0.5
    
    local carveRadius = radius + rimGap
    
    -- Use multiple FillBall operations to create a smooth bowl shape
    -- This is more reliable than voxel manipulation
    local steps = 8  -- Number of layers for smooth bowl
    for i = 1, steps do
        local t = i / steps
        local layerDepth = depth * t
        -- Parabolic profile for natural bowl shape
        local layerRadius = carveRadius * math.sqrt(1 - (t * 0.8)^2)
        
        local layerCenter = Vector3.new(center.X, center.Y - layerDepth, center.Z)
        
        -- Carve this layer with FillBall (much more reliable than voxels)
        local ok, err = pcall(function()
            workspace.Terrain:FillBall(layerCenter, layerRadius, Enum.Material.Air)
        end)
        
        if not ok then
            warn("[UnifiedCarving] FillBall failed at layer", i, ":", err)
        end
    end
    
    print(string.format("[UnifiedCarving] Carved bowl center=(%.1f,%.1f,%.1f) r=%.1f d=%.1f", 
        center.X, center.Y, center.Z, carveRadius, depth))
end

-- Get simple parameters that match default pond behavior
function UnifiedCarvingUtil.getDefaultBowlParams(): any
    return {
        rimGap = 0.5,  -- Same as TerrainIslandBuilder
    }
end

-- Get depth for pond type (default vs dynamic)
function UnifiedCarvingUtil.getPondDepth(pondType: string?): number
    local baseDepth = (WorldConfig.ISLANDS and WorldConfig.ISLANDS.Pond and WorldConfig.ISLANDS.Pond.Depth) or 2
    return baseDepth  -- Use same depth for all ponds for consistency
end

-- Carve a canal segment with consistent depth and smooth transitions
function UnifiedCarvingUtil.carveCanal(pathPoints: { Vector2 }, width: number, surfaceY: number?)
    local yTop = surfaceY or ((WorldConfig.ISLANDS and WorldConfig.ISLANDS.DefaultHeightY) or 1)
    local depth = math.min(1.5, UnifiedCarvingUtil.getPondDepth("dynamic") * 0.6)  -- Shallower canals
    local clearR = (width * 0.5) + 0.3  -- Slightly wider for clean edges
    
    -- Use FillBall operations along the path for reliable carving
    -- Overlap spheres for continuous canal
    local spacing = math.max(1, width * 0.3)  -- Dense overlap for smooth canal
    
    local carvePoints = {}
    
    -- Build list of carve points with proper spacing
    if #pathPoints >= 2 then
        -- Always include first point
        table.insert(carvePoints, pathPoints[1])
        
        -- Add intermediate points based on spacing
        local currentDist = 0
        for i = 1, #pathPoints - 1 do
            local p1 = pathPoints[i]
            local p2 = pathPoints[i + 1]
            local segmentLength = (p2 - p1).Magnitude
            
            if segmentLength > spacing then
                -- Add interpolated points along this segment
                local numInterp = math.floor(segmentLength / spacing)
                for j = 1, numInterp do
                    local t = j / (numInterp + 1)
                    local interpPoint = p1 + (p2 - p1) * t
                    table.insert(carvePoints, interpPoint)
                end
            end
            
            -- Add the segment end point if not too close to last carved point
            if i < #pathPoints - 1 then
                local lastCarved = carvePoints[#carvePoints]
                if (p2 - lastCarved).Magnitude > spacing * 0.5 then
                    table.insert(carvePoints, p2)
                end
            end
        end
        
        -- Always include last point
        table.insert(carvePoints, pathPoints[#pathPoints])
    else
        carvePoints = pathPoints
    end
    
    -- Carve with spheres along the path
    for _, p in ipairs(carvePoints) do
        local canalCenter = Vector3.new(p.X, yTop - (depth * 0.5), p.Y)
        
        local ok, err = pcall(function()
            workspace.Terrain:FillBall(canalCenter, clearR, Enum.Material.Air)
        end)
        
        if not ok then
            warn("[UnifiedCarving] Canal carve failed at point:", err)
        end
    end
    
    print(string.format("[UnifiedCarving] Carved canal points=%d (from %d path points) width=%.1f depth=%.1f", 
        #carvePoints, #pathPoints, width, depth))
end

return UnifiedCarvingUtil
