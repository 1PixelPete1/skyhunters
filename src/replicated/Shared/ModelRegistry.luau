-- ModelRegistry.luau
-- Centralized registry for spawnable models with weighted selection
-- Updated to support BridgeMeshService integration

local ModelRegistry = {}

-- Configuration for bridge segment models (legacy Catalog models)
-- Format: { modelName = weight }
-- Higher weight = more likely to spawn
ModelRegistry.BRIDGE_MODELS = {
    bridge_pone_1 = 100,  -- Current default bridge model
    -- Add more bridge models here as they become available:
    -- bridge_stone_1 = 50,
    -- bridge_rope_1 = 25,
}

-- Bridge mesh configurations for BridgeMeshService
-- These are used when CONSTANTS.USE_BRIDGE_ASSETS = true
-- Each entry defines a mesh with proper scaling and material settings
ModelRegistry.BRIDGE_MESHES = {
    -- Default wooden plank bridge
    wooden_plank = {
        meshId = 104495133478682,  -- Replace with your actual mesh ID
        textureId = nil,  -- Optional texture ID
        baseScale = Vector3.new(0.04, 0.04, 0.04),
        maxStretch = 1.5,
        weight = 60,
        material = Enum.Material.Wood,
        color = Color3.fromRGB(139, 90, 43),
    },
    
    -- Stone bridge variant
    stone_bridge = {
        meshId = 104495133479,  -- Replace with your actual mesh ID
        textureId = nil,
        baseScale = Vector3.new(0.035, 0.035, 0.035),
        maxStretch = 1.3,
        weight = 30,
        material = Enum.Material.Concrete,
        color = Color3.fromRGB(163, 162, 165),
    },
    
    -- Rope bridge variant
    rope_bridge = {
        meshId = 104495133480,  -- Replace with your actual mesh ID
        textureId = nil,
        baseScale = Vector3.new(0.045, 0.045, 0.045),
        maxStretch = 1.8,
        weight = 10,
        material = Enum.Material.Fabric,
        color = Color3.fromRGB(188, 155, 93),
    },
    
    -- Legacy format support (for backward compatibility)
    bridge_pone_1 = { 
        meshId = 104495133478682,
        baseScale = Vector3.new(0.04, 0.04, 0.04),
        maxStretch = 1.5,
        weight = 100,
    },
}

-- Configuration for POI building models
ModelRegistry.POI_BUILDING_MODELS = {
    -- Future POI models will go here
    -- dungeon_entrance_1 = 100,
}

-- Configuration for decorative models
ModelRegistry.DECORATIVE_MODELS = {
    -- Future decorative models will go here
    -- floating_rock_1 = 100,
    -- crystal_cluster_1 = 50,
}

-- Get bridge mesh configurations formatted for BridgeMeshService
function ModelRegistry:GetBridgeMeshConfigs()
    local configs = {}
    
    for name, data in pairs(self.BRIDGE_MESHES) do
        if data.meshId then
            table.insert(configs, {
                name = name,
                meshId = data.meshId,
                textureId = data.textureId,
                baseScale = data.baseScale or Vector3.new(0.04, 0.04, 0.04),
                maxStretch = data.maxStretch or 1.5,
                weight = data.weight or 50,
                material = data.material,
                color = data.color,
            })
        end
    end
    
    -- Sort by weight for consistency
    table.sort(configs, function(a, b)
        return a.weight > b.weight
    end)
    
    return configs
end

-- Utility function to select a random model based on weights
function ModelRegistry:SelectWeightedRandom(modelTable)
    if not modelTable or next(modelTable) == nil then
        return nil, "No models available"
    end
    
    -- Calculate total weight
    local totalWeight = 0
    for _, weight in pairs(modelTable) do
        totalWeight = totalWeight + weight
    end
    
    if totalWeight <= 0 then
        return nil, "No valid weights"
    end
    
    -- Select random value
    local randomValue = math.random() * totalWeight
    
    -- Find the selected model
    local currentWeight = 0
    for modelName, weight in pairs(modelTable) do
        currentWeight = currentWeight + weight
        if randomValue <= currentWeight then
            return modelName, nil
        end
    end
    
    -- Fallback to first model (should not happen)
    local firstModel = next(modelTable)
    return firstModel, nil
end

-- Select a random bridge mesh configuration
function ModelRegistry:SelectRandomBridgeMesh()
    local configs = self:GetBridgeMeshConfigs()
    if #configs == 0 then
        return nil
    end
    
    -- Calculate total weight
    local totalWeight = 0
    for _, config in ipairs(configs) do
        totalWeight = totalWeight + config.weight
    end
    
    if totalWeight <= 0 then
        return configs[1]  -- Return first if weights are invalid
    end
    
    -- Select based on weight
    local roll = math.random() * totalWeight
    local currentWeight = 0
    
    for _, config in ipairs(configs) do
        currentWeight = currentWeight + config.weight
        if roll <= currentWeight then
            return config
        end
    end
    
    return configs[1]  -- Fallback
end

-- Get all available models of a type
function ModelRegistry:GetAvailableModels(modelType)
    local modelTable = self[modelType .. "_MODELS"]
    if not modelTable then
        return {}
    end
    
    local available = {}
    for modelName, _ in pairs(modelTable) do
        table.insert(available, modelName)
    end
    
    return available
end

-- Check if a specific model is available
function ModelRegistry:IsModelAvailable(modelType, modelName)
    local modelTable = self[modelType .. "_MODELS"]
    if not modelTable then
        return false
    end
    
    return modelTable[modelName] ~= nil
end

-- Get the weight of a specific model
function ModelRegistry:GetModelWeight(modelType, modelName)
    local modelTable = self[modelType .. "_MODELS"]
    if not modelTable then
        return 0
    end
    
    return modelTable[modelName] or 0
end

-- Add or update a model's weight
function ModelRegistry:SetModelWeight(modelType, modelName, weight)
    local modelTableKey = modelType .. "_MODELS"
    if not self[modelTableKey] then
        self[modelTableKey] = {}
    end
    
    self[modelTableKey][modelName] = weight
    print(string.format("[ModelRegistry] Set %s.%s weight to %d", modelType, modelName, weight))
end

-- Add or update a bridge mesh configuration
function ModelRegistry:SetBridgeMesh(name: string, config: {
    meshId: number | string,
    textureId: number | string?,
    baseScale: Vector3?,
    maxStretch: number?,
    weight: number?,
    material: Enum.Material?,
    color: Color3?,
})
    if not config.meshId then
        warn("[ModelRegistry] Cannot add bridge mesh without meshId")
        return
    end
    
    self.BRIDGE_MESHES[name] = {
        meshId = config.meshId,
        textureId = config.textureId,
        baseScale = config.baseScale or Vector3.new(0.04, 0.04, 0.04),
        maxStretch = config.maxStretch or 1.5,
        weight = config.weight or 50,
        material = config.material,
        color = config.color,
    }
    
    print(string.format("[ModelRegistry] Added/updated bridge mesh: %s", name))
end

-- Remove a model from the registry
function ModelRegistry:RemoveModel(modelType, modelName)
    local modelTable = self[modelType .. "_MODELS"]
    if modelTable then
        modelTable[modelName] = nil
        print(string.format("[ModelRegistry] Removed %s.%s from registry", modelType, modelName))
    end
end

-- Validate all mesh IDs (checks format and prints warnings)
function ModelRegistry:ValidateMeshIds()
    print("[ModelRegistry] Validating mesh IDs...")
    local issues = 0
    
    for name, data in pairs(self.BRIDGE_MESHES) do
        if data.meshId then
            local id = tostring(data.meshId)
            if not (tonumber(id) or string.match(id, "^rbxassetid://")) then
                warn(string.format("[ModelRegistry] Invalid mesh ID format for %s: %s", name, id))
                issues = issues + 1
            end
        else
            warn(string.format("[ModelRegistry] No mesh ID for %s", name))
            issues = issues + 1
        end
    end
    
    if issues == 0 then
        print("[ModelRegistry] All mesh IDs valid!")
    else
        warn(string.format("[ModelRegistry] Found %d issues with mesh IDs", issues))
    end
    
    return issues == 0
end

return ModelRegistry
