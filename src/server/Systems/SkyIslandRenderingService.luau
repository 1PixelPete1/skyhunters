-- SkyIslandRenderingService.luau
-- Handles dynamic rendering and LOD management for sky islands
-- Addresses terrain rendering distance issues by using Part-based islands with controlled visibility

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local SkyIslandRenderingService = {}

-- Configuration for rendering behavior
local RENDER_CONFIG = {
    UPDATE_INTERVAL = 1,      -- seconds between visibility updates (scheduling only)
    RENDER_DISTANCE = 800,    -- studs - maximum render distance
    LOW_LOD_DISTANCE = 400,   -- studs - distance at which to use low LOD
    CULL_DISTANCE = 1000,     -- studs - distance at which to completely remove islands
    MAX_VISIBLE_ISLANDS = 50, -- maximum number of islands visible per player
    CREATES_PER_FRAME = 5,    -- paced creation budget per frame per player
}

local activeConnections = {}
local islandsByPlayer = {} -- [player] = {visible islands}
local lastUpdateTimes = {} -- [player] = last update time
local pendingCreateByPlayer = {} -- [player] = queue of islands to create

-- Calculate LOD level based on distance
local function calculateLOD(distance: number): number
    if distance <= RENDER_CONFIG.LOW_LOD_DISTANCE then
        return 3 -- High detail
    elseif distance <= RENDER_CONFIG.RENDER_DISTANCE then
        return 2 -- Medium detail
    elseif distance <= RENDER_CONFIG.CULL_DISTANCE then
        return 1 -- Low detail
    else
        return 0 -- No rendering
    end
end

-- Apply LOD settings to an island model
local function applyLOD(island, lodLevel: number)
    if not island.model or not island.model.PrimaryPart then
        return
    end
    
    local part = island.model.PrimaryPart
    
    if lodLevel == 3 then
        -- High detail - full materials and effects
        part.Material = island.originalMaterial or Enum.Material.Rock
        part.Transparency = 0
        
        -- Enable lights for POIs
        if island.type == "POI" then
            local light = part:FindFirstChild("PointLight")
            if light then
                light.Enabled = true
                light.Brightness = 2
            end
        end
        
    elseif lodLevel == 2 then
        -- Medium detail - simplified materials
        part.Material = Enum.Material.SmoothPlastic
        part.Transparency = 0
        
        -- Dim lights for POIs
        if island.type == "POI" then
            local light = part:FindFirstChild("PointLight")
            if light then
                light.Enabled = true
                light.Brightness = 1
            end
        end
        
    elseif lodLevel == 1 then
        -- Low detail - basic representation
        part.Material = Enum.Material.SmoothPlastic
        part.Transparency = 0.3
        
        -- Disable lights
        local light = part:FindFirstChild("PointLight")
        if light then
            light.Enabled = false
        end
    end
end

-- Update visibility for a specific player
local function updatePlayerVisibility(player, allIslands)
    if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
        return
    end
    
    local playerPos = player.Character.HumanoidRootPart.Position
    local playerIslands = islandsByPlayer[player] or {}
    
    -- Calculate distances and sort islands by distance
    local islandDistances = {}
    for _, island in ipairs(allIslands) do
        local distance = (island.position - playerPos).Magnitude
        table.insert(islandDistances, {island = island, distance = distance})
    end
    
    -- Sort by distance (closest first)
    table.sort(islandDistances, function(a, b)
        return a.distance < b.distance
    end)
    
    -- Track which islands should be visible
    local newVisibleIslands = {}
    local visibleCount = 0
    
    for _, data in ipairs(islandDistances) do
        local island = data.island
        local distance = data.distance
        local lodLevel = calculateLOD(distance)
        
        if lodLevel > 0 and visibleCount < RENDER_CONFIG.MAX_VISIBLE_ISLANDS then
            -- Island should be visible
            if not island.visible then
                -- Schedule model creation to avoid frame spikes
                local q = pendingCreateByPlayer[player]
                if not q then q = {}; pendingCreateByPlayer[player] = q end
                table.insert(q, island)
            end
            
            -- Apply appropriate LOD
            applyLOD(island, lodLevel)
            table.insert(newVisibleIslands, island)
            visibleCount = visibleCount + 1
            
        else
            -- Island should not be visible
            if island.visible and island.model then
                island.model:Destroy()
                island.model = nil
                island.visible = false
            end
        end
    end
    
    -- Update the player's visible islands list
    islandsByPlayer[player] = newVisibleIslands
end

-- Start the rendering service for a set of islands
function SkyIslandRenderingService.startRendering(islands)
    if activeConnections.renderLoop then
        activeConnections.renderLoop:Disconnect()
    end
    
    print("[SkyIslandRenderingService] Starting dynamic rendering for", #islands, "islands")
    
    activeConnections.renderLoop = RunService.Heartbeat:Connect(function()
        local now = tick()
        
        for _, player in ipairs(Players:GetPlayers()) do
            local lastUpdate = lastUpdateTimes[player] or 0
            if now - lastUpdate >= RENDER_CONFIG.UPDATE_INTERVAL then
                -- Only schedule creates/hides here
                updatePlayerVisibility(player, islands)
                lastUpdateTimes[player] = now
            end

            -- Process a few island creations per frame per player
            local q = pendingCreateByPlayer[player]
            if q and #q > 0 then
                local n = math.min(RENDER_CONFIG.CREATES_PER_FRAME, #q)
                for i = 1, n do
                    local island = table.remove(q, 1)
                    if island and not island.visible then
                        local model = Instance.new("Model")
                        model.Name = string.format("SkyIsland_%s_%d", island.type, tick())
                        local part = Instance.new("Part")
                        part.Name = "IslandBase"
                        part.Size = Vector3.new(island.radius * 2, island.height * 0.3, island.radius * 2)
                        part.Position = island.position
                        part.Anchored = true
                        part.Material = Enum.Material.Rock
                        part.BrickColor = BrickColor.new("Brown")
                        if island.type == "Tiny" then
                            part.Shape = Enum.PartType.Ball
                        else
                            part.Shape = Enum.PartType.Cylinder
                            -- Default orientation keeps vertical axis for a circular top
                        end
                        part.Parent = model
                        island.originalMaterial = part.Material
                        if island.type == "POI" then
                            part.BrickColor = BrickColor.new("Bright blue")
                            part.Material = Enum.Material.Neon
                            island.originalMaterial = Enum.Material.Neon
                            local light = Instance.new("PointLight")
                            light.Color = Color3.fromRGB(0, 150, 255)
                            light.Brightness = 2
                            light.Range = island.radius * 3
                            light.Parent = part
                        end
                        model.PrimaryPart = part
                        model.Parent = workspace:FindFirstChild("SkyIslands") or workspace
                        island.model = model
                        island.visible = true
                        -- Apply initial LOD based on distance
                        local char = player.Character
                        if char and char:FindFirstChild("HumanoidRootPart") then
                            local dist = (island.position - char.HumanoidRootPart.Position).Magnitude
                            applyLOD(island, calculateLOD(dist))
                        end
                    end
                end
            end
        end
    end)
    
    -- Clean up when players leave
    activeConnections.playerRemoving = Players.PlayerRemoving:Connect(function(player)
        islandsByPlayer[player] = nil
        lastUpdateTimes[player] = nil
    end)
end

-- Stop the rendering service
function SkyIslandRenderingService.stopRendering()
    for _, connection in pairs(activeConnections) do
        if connection then
            connection:Disconnect()
        end
    end
    activeConnections = {}
    
    -- Clean up all player data
    islandsByPlayer = {}
    lastUpdateTimes = {}
    
    print("[SkyIslandRenderingService] Rendering stopped")
end

-- Update rendering configuration
function SkyIslandRenderingService.updateConfig(newConfig)
    for key, value in pairs(newConfig) do
        if RENDER_CONFIG[key] ~= nil then
            RENDER_CONFIG[key] = value
            print(string.format("[SkyIslandRenderingService] Updated %s to %s", key, tostring(value)))
        end
    end
end

-- Get current rendering statistics
function SkyIslandRenderingService.getStats()
    local totalVisible = 0
    local playerCount = 0
    
    for player, islands in pairs(islandsByPlayer) do
        if player.Parent then -- Player is still in game
            totalVisible = totalVisible + #islands
            playerCount = playerCount + 1
        end
    end
    
    return {
        playersTracked = playerCount,
        totalVisibleIslands = totalVisible,
        averagePerPlayer = playerCount > 0 and totalVisible / playerCount or 0,
        renderDistance = RENDER_CONFIG.RENDER_DISTANCE,
        updateInterval = RENDER_CONFIG.UPDATE_INTERVAL,
    }
end

return SkyIslandRenderingService
