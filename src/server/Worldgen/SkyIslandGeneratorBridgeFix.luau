-- SkyIslandGeneratorBridgeFix.luau
-- Integration patch for BridgeMeshService into SkyIslandGenerator

--[[
This file contains the updated _generatePathSegmentModel function that should replace
the existing one in SkyIslandGenerator.luau. It properly integrates the BridgeMeshService
for better mesh handling.

To apply this fix:
1. Add this near the top of SkyIslandGenerator.luau with other requires:
   local BridgeMeshService = require(script.Parent.BridgeMeshService)

2. In the SkyIslandGenerator.new function, add after self initialization:
   self.bridgeService = BridgeMeshService.new()
   
   -- Optional: Configure custom bridge types
   -- self.bridgeService = BridgeMeshService.new({
   --     {
   --         meshId = "17843185925", -- Your mesh ID
   --         baseScale = Vector3.new(0.04, 0.04, 0.04),
   --         maxStretch = 1.5,
   --         weight = 70,
   --         name = "CustomBridge",
   --         material = Enum.Material.Wood,
   --         color = Color3.fromRGB(139, 90, 43),
   --     },
   --     -- Add more bridge types...
   -- })

3. Replace the entire _generatePathSegmentModel function with the one below:
--]]

-- Updated function to use BridgeMeshService
function SkyIslandGenerator:_generatePathSegmentModel(segment)
    if segment.generated then return end
    
    local root = self:_ensureRoots()
    local segmentFolder = Instance.new("Folder")
    segmentFolder.Name = "PathSegment_" .. segment.id
    segmentFolder.Parent = root
    segmentFolder:SetAttribute("IsConstellation", true)
    self:_tagConstellationContent(segmentFolder, "PathSegment")
    
    if segment.segmentType == "organic" then
        -- Organic terrain segment (small island)
        local rock = Instance.new("Part")
        rock.Name = "RockChunk"
        rock.Size = Vector3.new(
            math.max(3, math.floor(segment.size/2)), 
            math.max(2, math.floor(segment.size/3)), 
            math.max(6, segment.size)
        )
        rock.CFrame = segment.rotation
        rock.Material = Enum.Material.Rock
        rock.BrickColor = BrickColor.new("Dark stone grey")
        rock.Anchored = true
        rock.Parent = segmentFolder
        
    elseif segment.segmentType == "lootable" then
        -- Lootable platform with barrel
        local platform = Instance.new("Part")
        platform.Name = "LootPlatform"
        platform.Size = Vector3.new(segment.size, 2, segment.size)
        platform.CFrame = segment.rotation
        platform.Material = Enum.Material.Concrete
        platform.BrickColor = BrickColor.new("Medium stone grey")
        platform.Anchored = true
        platform.Parent = segmentFolder
        
        -- Add barrel/loot container
        local barrel = Instance.new("Part")
        barrel.Name = "LootBarrel"
        barrel.Size = Vector3.new(3, 4, 3)
        barrel.Shape = Enum.PartType.Cylinder
        barrel.Position = platform.Position + Vector3.new(0, 3, 0)
        barrel.Material = Enum.Material.Metal
        barrel.BrickColor = BrickColor.new("Rust")
        barrel.Anchored = true
        barrel.Parent = segmentFolder
        
    elseif segment.segmentType == "long_bridge" then
        -- Single long bridge using BridgeMeshService
        if self.bridgeService then
            -- Calculate start and end positions from segment data
            local length = segment.size
            local startPos = segment.rotation.Position - segment.rotation.LookVector * (length/2)
            local endPos = segment.rotation.Position + segment.rotation.LookVector * (length/2)
            
            local bridge = self.bridgeService:CreateBridge({
                startPos = startPos,
                endPos = endPos,
                orientation = segment.rotation
            })
            
            if bridge then
                bridge.Parent = segmentFolder
                print(string.format("[SkyIslandGenerator] Created long bridge using BridgeMeshService: %s", segment.id))
            else
                -- Fallback to simple part
                local bridgePart = Instance.new("Part")
                bridgePart.Name = "LongBridge_Fallback"
                bridgePart.Size = Vector3.new(CONSTANTS.BRIDGE_WIDTH, CONSTANTS.BRIDGE_THICKNESS, segment.size)
                bridgePart.CFrame = segment.rotation
                bridgePart.Material = Enum.Material.Wood
                bridgePart.BrickColor = BrickColor.new("Brown")
                bridgePart.Anchored = true
                bridgePart.Parent = segmentFolder
                warn("[SkyIslandGenerator] BridgeMeshService failed, using fallback part")
            end
        else
            -- Fallback if service not available
            local bridge = Instance.new("Part")
            bridge.Name = "LongBridge"
            bridge.Size = Vector3.new(CONSTANTS.BRIDGE_WIDTH, CONSTANTS.BRIDGE_THICKNESS, segment.size)
            bridge.CFrame = segment.rotation
            bridge.Material = Enum.Material.Wood
            bridge.BrickColor = BrickColor.new("Brown")
            bridge.Anchored = true
            bridge.Parent = segmentFolder
        end
        
    elseif segment.segmentType == "bridge_beam" then
        -- Bridge plank segment using BridgeMeshService
        local length = segment.size * (segment.lengthMult or 8)
        
        if self.bridgeService and CONSTANTS.USE_BRIDGE_ASSETS then
            -- Calculate positions for the bridge segment
            local forward = segment.rotation.LookVector
            local startPos = segment.position - forward * (length/2)
            local endPos = segment.position + forward * (length/2)
            
            local bridge = self.bridgeService:CreateBridge({
                startPos = startPos,
                endPos = endPos,
                orientation = segment.rotation
            })
            
            if bridge then
                bridge.Parent = segmentFolder
                print(string.format("[SkyIslandGenerator] Created bridge_beam using BridgeMeshService: %s", segment.id))
                
                -- Add optional lighting
                if CONSTANTS.LIGHTS_ON_SEGMENTS then
                    local lightPos = segment.position + Vector3.new(
                        (CONSTANTS.BRIDGE_WIDTH or 16) * 0.4, 
                        3, 
                        0
                    )
                    self:_spawnStreetLight(lightPos, segmentFolder, segment.id)
                end
            else
                -- Fallback to simple wooden plank
                warn("[SkyIslandGenerator] BridgeMeshService failed for bridge_beam, using fallback")
                local plank = Instance.new("Part")
                plank.Name = "BridgePlank_Fallback"
                plank.Material = Enum.Material.Wood
                plank.BrickColor = BrickColor.new("Brown")
                plank.Anchored = true
                local width = CONSTANTS.BRIDGE_WIDTH or 16
                local thickness = CONSTANTS.BRIDGE_THICKNESS or 2
                plank.Size = Vector3.new(width, thickness, length)
                plank.CFrame = segment.rotation
                plank.Parent = segmentFolder
            end
        else
            -- Use simple wooden plank when assets are disabled
            local plank = Instance.new("Part")
            plank.Name = "BridgePlank"
            plank.Material = Enum.Material.Wood
            plank.BrickColor = BrickColor.new("Brown")
            plank.Anchored = true
            local width = CONSTANTS.BRIDGE_WIDTH or 16
            local thickness = CONSTANTS.BRIDGE_THICKNESS or 2
            plank.Size = Vector3.new(width, thickness, length)
            plank.CFrame = segment.rotation
            plank.Parent = segmentFolder
            
            if CONSTANTS.LIGHTS_ON_SEGMENTS then
                local lightPos = plank.Position + Vector3.new(width * 0.4, 3, 0)
                self:_spawnStreetLight(lightPos, segmentFolder, segment.id)
            end
        end
    end
    
    segment.generated = true
    CollectionService:AddTag(segmentFolder, "PathSegment")
end

--[[
Additional notes:

1. The BridgeMeshService handles:
   - Multiple mesh types with weighted random selection
   - Proper scaling to avoid distortion (base scale 0.04, max stretch 1.5x)
   - Automatic tiling when bridges exceed max stretch limit
   - Mesh caching for performance
   - Fallback to simple parts if mesh loading fails

2. To add custom bridge types, modify the DEFAULT_BRIDGE_CONFIGS table in BridgeMeshService.luau
   or pass custom configs when creating the service instance.

3. Bridge meshes should be uploaded as MeshParts to Roblox with these recommended dimensions:
   - Length (Z axis): 16-32 studs (will be scaled and stretched as needed)
   - Width (X axis): 8-16 studs
   - Height (Y axis): 1-2 studs
   
4. The service automatically handles:
   - Different mesh ID formats (numbers or rbxassetid:// strings)
   - Texture application if specified
   - Material and color customization
   - Proper collision and anchoring
--]]
