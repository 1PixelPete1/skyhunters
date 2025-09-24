--!strict
-- BridgeMeshService.luau (v2)
-- Handles bridge mesh placement with proper transformations and weighted selection
-- Fixed for Studio-uploaded meshes and better error handling

local InsertService = game:GetService("InsertService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BridgeMeshService = {}
BridgeMeshService.__index = BridgeMeshService

type BridgeConfig = {
    meshId: number | string | Instance?,  -- Can be ID or direct reference
    baseScale: Vector3,
    maxStretch: number,
    weight: number,
    name: string,
    textureId: number | string | nil,
    material: Enum.Material?,
    color: Color3?,
    useCatalogModel: boolean?,  -- If true, look for model in Catalog
}

type BridgePlacementParams = {
    startPos: Vector3,
    endPos: Vector3,
    width: number?,
    orientation: CFrame?,
    parent: Instance?,
}

-- Default bridge configurations
local DEFAULT_BRIDGE_CONFIGS: {BridgeConfig} = {
    {
        meshId = "bridge_pone_1",  -- Will look for this in Catalog/Models
        baseScale = Vector3.new(0.04, 0.04, 0.04),
        maxStretch = 1.5,
        weight = 60,
        name = "WoodenBridge",
        material = Enum.Material.Wood,
        color = Color3.fromRGB(139, 90, 43),
        useCatalogModel = true,  -- Use Catalog model instead of mesh ID
    },
    {
        meshId = nil,  -- Will use fallback Part
        baseScale = Vector3.new(1, 1, 1),
        maxStretch = 2.0,
        weight = 40,
        name = "SimplePlank",
        material = Enum.Material.WoodPlanks,
        color = Color3.fromRGB(160, 100, 50),
        useCatalogModel = false,
    },
}

function BridgeMeshService.new(customConfigs: {BridgeConfig}?)
    local self = setmetatable({}, BridgeMeshService)
    
    self.bridgeConfigs = customConfigs or DEFAULT_BRIDGE_CONFIGS
    self._meshCache = {}
    self._totalWeight = 0
    
    -- Calculate total weight (simple sum of all weights)
    for _, config in ipairs(self.bridgeConfigs) do
        self._totalWeight += config.weight
    end
    
    -- Validate configs
    if self._totalWeight <= 0 then
        warn("[BridgeMeshService] Total weight is 0, setting all weights to 1")
        for _, config in ipairs(self.bridgeConfigs) do
            config.weight = 1
        end
        self._totalWeight = #self.bridgeConfigs
    end
    
    return self
end

-- Select a bridge config based on simple relative weights
function BridgeMeshService:_selectBridgeConfig(): BridgeConfig
    if #self.bridgeConfigs == 0 then
        error("[BridgeMeshService] No bridge configurations available")
    end
    
    -- Simple weighted selection based on relative weights
    local roll = math.random() * self._totalWeight
    local currentWeight = 0
    
    for _, config in ipairs(self.bridgeConfigs) do
        currentWeight += config.weight
        if roll <= currentWeight then
            return config
        end
    end
    
    -- Fallback to first config
    return self.bridgeConfigs[1]
end

-- Try to find mesh in Catalog/Models
function BridgeMeshService:_findCatalogModel(modelName: string): Instance?
    local shared = ReplicatedStorage:FindFirstChild("Shared")
    local catalog = shared and shared:FindFirstChild("Catalog")
    local models = catalog and catalog:FindFirstChild("Models")
    
    if not models then
        return nil
    end
    
    -- Try exact match first
    local model = models:FindFirstChild(modelName)
    if model then
        return model
    end
    
    -- Try case-insensitive match
    for _, child in ipairs(models:GetChildren()) do
        if child.Name:lower() == modelName:lower() then
            return child
        end
    end
    
    return nil
end

-- Create or get mesh part from various sources
function BridgeMeshService:_getMeshPart(config: BridgeConfig): BasePart?
    local cacheKey = config.name
    
    -- Check cache first
    if self._meshCache[cacheKey] then
        return self._meshCache[cacheKey]:Clone()
    end
    
    local part: BasePart? = nil
    
    -- Option 1: Use Catalog model
    if config.useCatalogModel and config.meshId and typeof(config.meshId) == "string" then
        local catalogModel = self:_findCatalogModel(config.meshId)
        if catalogModel then
            print(string.format("[BridgeMeshService] Found catalog item '%s' (type: %s)", config.meshId, catalogModel.ClassName))
            
            if catalogModel:IsA("Model") then
                print(string.format("[BridgeMeshService] Processing Model with %d children", #catalogModel:GetChildren()))
                
                -- Extract primary part from model
                local primaryPart = catalogModel.PrimaryPart
                if not primaryPart then
                    print("[BridgeMeshService] No PrimaryPart set, searching for first BasePart...")
                    for _, child in ipairs(catalogModel:GetChildren()) do
                        if child:IsA("BasePart") then
                            primaryPart = child
                            print(string.format("[BridgeMeshService] Found suitable part: %s (%s)", child.Name, child.ClassName))
                            break
                        end
                    end
                else
                    print(string.format("[BridgeMeshService] Using PrimaryPart: %s (%s)", primaryPart.Name, primaryPart.ClassName))
                end
                
                if primaryPart then
                    local success, cloneResult = pcall(function()
                        return primaryPart:Clone()
                    end)
                    
                    if success then
                        part = cloneResult
                        print(string.format("[BridgeMeshService] ✅ Successfully using Catalog model: %s", config.meshId))
                        if part:IsA("MeshPart") then
                            print(string.format("[BridgeMeshService] MeshPart details - MeshId: %s, Size: %s", part.MeshId, tostring(part.Size)))
                        end
                    else
                        warn(string.format("[BridgeMeshService] ❌ Failed to clone part from %s: %s", config.meshId, tostring(cloneResult)))
                    end
                else
                    warn(string.format("[BridgeMeshService] ❌ No suitable BasePart found in model %s", config.meshId))
                    print("[BridgeMeshService] Model children:")
                    for _, child in ipairs(catalogModel:GetChildren()) do
                        print(string.format("  - %s (%s)", child.Name, child.ClassName))
                    end
                end
                
            elseif catalogModel:IsA("BasePart") then
                local success, cloneResult = pcall(function()
                    return catalogModel:Clone()
                end)
                
                if success then
                    part = cloneResult
                    print(string.format("[BridgeMeshService] ✅ Successfully using Catalog part: %s", config.meshId))
                else
                    warn(string.format("[BridgeMeshService] ❌ Failed to clone BasePart %s: %s", config.meshId, tostring(cloneResult)))
                end
            else
                warn(string.format("[BridgeMeshService] ❌ Catalog item %s is neither Model nor BasePart (type: %s)", config.meshId, catalogModel.ClassName))
            end
        else
            warn(string.format("[BridgeMeshService] ❌ Catalog model %s not found", config.meshId))
        end
    end
    
    -- Option 2: Direct Instance reference
    if not part and typeof(config.meshId) == "Instance" and config.meshId:IsA("BasePart") then
        part = config.meshId:Clone()
        print(string.format("[BridgeMeshService] Using direct instance: %s", config.name))
    end
    
    -- Option 3: Try InsertService with mesh ID (for public assets)
    if not part and config.meshId and not config.useCatalogModel then
        local meshIdStr = tostring(config.meshId)
        local assetId: string?
        
        if string.match(meshIdStr, "^rbxassetid://") then
            assetId = meshIdStr
        elseif tonumber(meshIdStr) then
            assetId = "rbxassetid://" .. meshIdStr
        end
        
        if assetId then
            local success, result = pcall(function()
                return InsertService:CreateMeshPartAsync(
                    assetId,
                    Enum.CollisionFidelity.Box,
                    Enum.RenderFidelity.Automatic
                )
            end)
            
            if success and result then
                part = result
                print(string.format("[BridgeMeshService] Loaded mesh via InsertService: %s", config.name))
            else
                warn(string.format("[BridgeMeshService] InsertService failed for %s: %s", 
                    config.name, tostring(result)))
            end
        end
    end
    
    -- Option 4: Fallback to simple Part
    if not part then
        part = Instance.new("Part")
        part.Size = Vector3.new(16, 2, 16)  -- Default bridge dimensions
        print(string.format("[BridgeMeshService] Using fallback Part for: %s", config.name))
    end
    
    -- Apply material and color
    if part then
        if config.material then
            part.Material = config.material
        end
        if config.color then
            part.Color = config.color
        end
        
        -- Apply texture if specified and part is MeshPart
        if config.textureId and part:IsA("MeshPart") then
            local textureStr = tostring(config.textureId)
            local textureAsset: string?
            if string.match(textureStr, "^rbxassetid://") then
                textureAsset = textureStr
            elseif tonumber(textureStr) then
                textureAsset = "rbxassetid://" .. textureStr
            end
            
            if textureAsset then
                pcall(function()
                    part.TextureID = textureAsset
                end)
            end
        end
        
        -- Cache the template
        self._meshCache[cacheKey] = part:Clone()
    end
    
    return part
end

-- Calculate proper scaling to avoid distortion
function BridgeMeshService:_calculateProperScale(meshSize: Vector3, targetLength: number, config: BridgeConfig): Vector3
    if not meshSize or meshSize.Magnitude <= 0 then
        return config.baseScale
    end
    
    local scale = config.baseScale
    local originalLength = meshSize.Z * scale.Z
    
    if originalLength <= 0 then
        return scale
    end
    
    local stretchFactor = targetLength / originalLength
    stretchFactor = math.clamp(stretchFactor, 0.5, config.maxStretch)
    
    return Vector3.new(
        scale.X,
        scale.Y,
        scale.Z * stretchFactor
    )
end

-- Tile bridges if needed
function BridgeMeshService:_tileBridge(
    config: BridgeConfig,
    meshPart: BasePart,
    startPos: Vector3,
    endPos: Vector3,
    parent: Instance,
    orientation: CFrame?
): Model
    local model = Instance.new("Model")
    model.Name = config.name .. "_Bridge"
    
    local bridgeVector = endPos - startPos
    local totalLength = bridgeVector.Magnitude
    
    if totalLength <= 0 then
        warn("[BridgeMeshService] Zero length bridge")
        return model
    end
    
    local bridgeDirection = bridgeVector.Unit
    
    -- Calculate base dimensions
    local meshSize = if meshPart:IsA("MeshPart") and meshPart.MeshSize 
        then meshPart.MeshSize 
        else meshPart.Size
    
    local baseLength = meshSize.Z * config.baseScale.Z
    if baseLength <= 0 then
        baseLength = 16  -- Default length
    end
    
    local maxLength = baseLength * config.maxStretch
    local tileCount = math.max(1, math.ceil(totalLength / maxLength))
    local tileLength = totalLength / tileCount
    
    -- Create orientation
    local up = if orientation then orientation.UpVector else Vector3.new(0, 1, 0)
    local right = bridgeDirection:Cross(up)
    if right.Magnitude < 0.001 then
        right = if orientation then orientation.RightVector else Vector3.new(1, 0, 0)
        up = bridgeDirection:Cross(right)
    end
    if right.Magnitude < 0.001 then
        right = Vector3.new(1, 0, 0)
    end
    if up.Magnitude < 0.001 then
        up = Vector3.new(0, 1, 0)
    end
    right = right.Unit
    up = up.Unit

    local orientationCFrame = CFrame.fromMatrix(
        startPos,
        right,
        up,
        -bridgeDirection
    )
    
    -- Create tiles
    for i = 1, tileCount do
        local tile = meshPart:Clone()
        tile.Name = "BridgeTile" .. i
        
        -- Calculate scale for this tile
        if tile:IsA("MeshPart") and tile.MeshSize then
            local tileScale = self:_calculateProperScale(tile.MeshSize, tileLength, config)
            -- For MeshParts, we scale the Size property
            tile.Size = tile.MeshSize * tileScale
        else
            -- For regular Parts, just set the size directly
            local widthScale = config.baseScale.X
            local heightScale = config.baseScale.Y
            -- FIXED: Don't reset small scale values - allow proper 0.04 scaling
            if widthScale <= 0 then widthScale = 1 end
            if heightScale <= 0 then heightScale = 1 end
            tile.Size = Vector3.new(
                meshPart.Size.X * widthScale,
                meshPart.Size.Y * heightScale,
                tileLength
            )
        end
        
        -- Position tile
        local offset = (i - 0.5) * tileLength
        tile.CFrame = orientationCFrame * CFrame.new(0, 0, -offset)
        
        -- Ensure anchored and collidable
        tile.Anchored = true
        tile.CanCollide = true
        tile.CanQuery = true
        tile.CanTouch = true
        
        tile.Parent = model
    end
    
    model.Parent = parent
    return model
end

-- Main function to create a bridge
function BridgeMeshService:CreateBridge(params: BridgePlacementParams): Model?
    local startPos = params.startPos
    local endPos = params.endPos
    
    if not startPos or not endPos then
        warn("[BridgeMeshService] Invalid start or end position")
        return nil
    end
    
    local distance = (endPos - startPos).Magnitude
    if distance <= 0 then
        warn("[BridgeMeshService] Zero distance between start and end")
        return nil
    end
    
    local parent = params.parent or workspace
    
    -- Select bridge type
    local config = self:_selectBridgeConfig()
    
    -- Get mesh part
    local meshPart = self:_getMeshPart(config)
    if not meshPart then
        warn(string.format("[BridgeMeshService] Failed to get mesh for %s", config.name))
        return nil
    end
    
    -- Create the bridge
    local bridge = self:_tileBridge(config, meshPart, startPos, endPos, parent, params.orientation)
    
    -- Tag the bridge
    if bridge then
        CollectionService:AddTag(bridge, "BridgeMesh")
        CollectionService:AddTag(bridge, config.name)
        bridge:SetAttribute("BridgeType", config.name)
        bridge:SetAttribute("BridgeLength", distance)
        
        print(string.format(
            "[BridgeMeshService] Created %s bridge: length=%.1f tiles=%d",
            config.name,
            distance,
            #bridge:GetChildren()
        ))
    end
    
    -- Clean up template
    if meshPart and meshPart.Parent == nil then
        meshPart:Destroy()
    end
    
    return bridge
end

-- Add a mesh directly from workspace (for Studio-uploaded meshes)
function BridgeMeshService:AddMeshFromWorkspace(part: BasePart, configName: string, weight: number?)
    if not part or not part:IsA("BasePart") then
        warn("[BridgeMeshService] Invalid part provided")
        return
    end
    
    local newConfig: BridgeConfig = {
        meshId = part,  -- Direct reference
        baseScale = Vector3.new(0.04, 0.04, 0.04),
        maxStretch = 1.5,
        weight = weight or 50,
        name = configName,
        material = part.Material,
        color = part.Color,
        useCatalogModel = false,
    }
    
    table.insert(self.bridgeConfigs, newConfig)
    self._totalWeight += newConfig.weight
    
    print(string.format("[BridgeMeshService] Added mesh from workspace: %s", configName))
end

-- Clear cache
function BridgeMeshService:ClearCache()
    for _, mesh in pairs(self._meshCache) do
        if mesh and mesh.Parent == nil then
            mesh:Destroy()
        end
    end
    self._meshCache = {}
    print("[BridgeMeshService] Cache cleared")
end

return BridgeMeshService











