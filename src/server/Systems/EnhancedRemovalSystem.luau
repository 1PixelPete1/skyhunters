-- EnhancedRemovalSystem.server.luau
-- Improved removal system with terrain restoration and validation

local ReplicatedStorage = ReplicatedStorage or game:GetService("ReplicatedStorage")
local Workspace = Workspace or game:GetService("Workspace")

local EnhancedRemovalSystem = {}

-- Safe require helper
local function safeRequire(modulePath)
    local success, module = pcall(function()
        return require(modulePath)
    end)
    if success then
        return module
    else
        warn("Failed to require:", modulePath)
        return nil
    end
end

-- Import services with fallbacks
local PondNetworkService = safeRequire(game.ServerScriptService:WaitForChild("Systems"):WaitForChild("PondNetworkService"))
local LanternService = safeRequire(game.ServerScriptService:WaitForChild("Server"):WaitForChild("LanternService"))

-- Fallback terrain restoration
local function restoreTerrain(center, radius)
    local region = Region3.new(
        center - Vector3.new(radius + 10, 20, radius + 10),
        center + Vector3.new(radius + 10, 20, radius + 10)
    )
    
    -- Expand to align with voxel grid
    region = Workspace.Terrain:ExpandToGrid(region)
    
    -- Simple terrain restoration - fill with grass
    Workspace.Terrain:FillRegion(region, 1, Enum.Material.Grass)
    
    print(string.format("[EnhancedRemovalSystem] Restored terrain at (%.1f, %.1f, %.1f) radius %.1f", 
        center.X, center.Y, center.Z, radius))
end

-- Check if any lanterns are within pond boundary
local function hasLanternsInPond(plotKey, pondPos, pondRadius)
    if not LanternService or not LanternService.GetLanternsForPlot then
        -- Fallback: check workspace for lantern models
        local lanternFolder = Workspace:FindFirstChild("Lanterns")
        if lanternFolder then
            for _, lantern in pairs(lanternFolder:GetChildren()) do
                if lantern:IsA("Model") and lantern.PrimaryPart then
                    local distance = (lantern.PrimaryPart.Position - pondPos).Magnitude
                    if distance <= pondRadius + 5 then -- 5 stud buffer
                        return true, {id = lantern.Name, position = lantern.PrimaryPart.Position}
                    end
                end
            end
        end
        return false, nil
    end
    
    -- Get all lanterns for this plot
    local lanterns = LanternService:GetLanternsForPlot(plotKey)
    
    for _, lanternData in pairs(lanterns) do
        local distance = (lanternData.position - pondPos).Magnitude
        if distance <= pondRadius + 5 then -- 5 stud buffer
            return true, lanternData
        end
    end
    
    return false, nil
end

-- Check if pond has any connected canals
local function hasConnectedCanals(plotKey, pondId)
    if not PondNetworkService or not PondNetworkService.GetNetworkSnapshot then
        -- Fallback: check for canal parts in workspace
        local canalFolder = Workspace:FindFirstChild("CanalSegments")
        if canalFolder then
            for _, child in pairs(canalFolder:GetChildren()) do
                if child.Name:find(pondId) then
                    return true, {id = child.Name}
                end
            end
        end
        return false, nil
    end
    
    local network = PondNetworkService:GetNetworkSnapshot(plotKey)
    
    -- Check both canals and lakes (different services may use different names)
    local canals = network.canals or network.lakes or {}
    
    for _, canal in pairs(canals) do
        if canal.pondA == pondId or canal.pondB == pondId or canal.a == pondId or canal.b == pondId then
            return true, canal
        end
    end
    
    return false, nil
end

-- Enhanced pond removal with validation
function EnhancedRemovalSystem:RemovePond(player, pondId)
    local plotKey = player.Name -- Assuming plot key is player name
    
    -- Get pond data - try multiple methods to find pond info
    local pond = nil
    local pondPos = nil
    local pondRadius = 10 -- default fallback
    
    if PondNetworkService and PondNetworkService.GetNetworkSnapshot then
        local network = PondNetworkService:GetNetworkSnapshot(plotKey)
        pond = network.ponds and network.ponds[pondId]
        if pond then
            pondPos = pond.pos and Vector3.new(pond.pos.X, 0, pond.pos.Y) or pond.position
            pondRadius = pond.radius or 10
        end
    end
    
    -- Fallback: look for pond in workspace
    if not pond then
        local pondFolder = Workspace:FindFirstChild("PondRims")
        if pondFolder then
            local thisPondFolder = pondFolder:FindFirstChild("Pond_" .. pondId)
            if thisPondFolder then
                -- Estimate pond center from rim stones
                local stones = thisPondFolder:GetChildren()
                if #stones > 0 then
                    local centerX, centerZ = 0, 0
                    for _, stone in pairs(stones) do
                        if stone:IsA("Part") then
                            centerX = centerX + stone.Position.X
                            centerZ = centerZ + stone.Position.Z
                        end
                    end
                    centerX = centerX / #stones
                    centerZ = centerZ / #stones
                    pondPos = Vector3.new(centerX, 0, centerZ)
                    
                    -- Estimate radius from farthest stone
                    for _, stone in pairs(stones) do
                        if stone:IsA("Part") then
                            local distance = (Vector3.new(stone.Position.X, 0, stone.Position.Z) - pondPos).Magnitude
                            pondRadius = math.max(pondRadius, distance)
                        end
                    end
                end
            end
        end
    end
    
    if not pondPos then
        return false, "Pond not found"
    end
    
    -- Check for lanterns in pond boundary
    local hasLanterns, lanternData = hasLanternsInPond(plotKey, pondPos, pondRadius)
    if hasLanterns then
        return false, "Cannot remove pond: Lantern '" .. tostring(lanternData.id) .. "' is within pond boundary. Remove lanterns first."
    end
    
    -- Check for connected canals
    local hasCanals, canalData = hasConnectedCanals(plotKey, pondId)
    if hasCanals then
        return false, "Cannot remove pond: Canal '" .. tostring(canalData.id) .. "' is connected. Remove canals first."
    end
    
    -- Proceed with removal
    local success = true
    if PondNetworkService and PondNetworkService.RemovePond then
        success = PondNetworkService:RemovePond(plotKey, pondId)
    end
    
    if not success then
        return false, "Failed to remove pond from network"
    end
    
    -- Remove rim stones
    local rimFolder = Workspace:FindFirstChild("PondRims")
    if rimFolder then
        local thisPondFolder = rimFolder:FindFirstChild("Pond_" .. pondId)
        if thisPondFolder then
            thisPondFolder:Destroy()
        end
    end
    
    -- Restore terrain
    restoreTerrain(pondPos, pondRadius)
    
    return true, "Pond removed successfully"
end

-- Enhanced canal removal
function EnhancedRemovalSystem:RemoveCanal(player, canalId)
    local plotKey = player.Name
    
    local success = true
    if PondNetworkService and PondNetworkService.RemoveCanal then
        success = PondNetworkService:RemoveCanal(plotKey, canalId)
    end
    
    if not success then
        return false, "Failed to remove canal from network"
    end
    
    -- Remove canal stones
    local canalFolder = Workspace:FindFirstChild("CanalSegments")
    if canalFolder then
        local thisCanalFolder = canalFolder:FindFirstChild(canalId)
        if thisCanalFolder then
            thisCanalFolder:Destroy()
        end
    end
    
    -- Also check old canal stone folder structure
    local canalStoneFolder = Workspace:FindFirstChild("CanalStones")
    if canalStoneFolder then
        local thisCanalFolder = canalStoneFolder:FindFirstChild("Canal_" .. canalId)
        if thisCanalFolder then
            thisCanalFolder:Destroy()
        end
    end
    
    return true, "Canal removed successfully"
end

-- Lantern removal with pond validation
function EnhancedRemovalSystem:RemoveLantern(player, lanternId)
    local plotKey = player.Name
    
    local success = true
    if LanternService and LanternService.RemoveLantern then
        success = LanternService:RemoveLantern(plotKey, lanternId)
    else
        -- Fallback: find and remove lantern from workspace
        local lanternFolder = Workspace:FindFirstChild("Lanterns")
        if lanternFolder then
            local lantern = lanternFolder:FindFirstChild(lanternId)
            if lantern then
                lantern:Destroy()
            end
        end
    end
    
    if not success then
        return false, "Failed to remove lantern"
    end
    
    return true, "Lantern removed successfully"
end

-- Bulk removal with proper ordering
function EnhancedRemovalSystem:WipePlot(player)
    local plotKey = player.Name
    
    print("Wiping plot for player:", player.Name)
    
    -- 1. Remove all lanterns first
    local lanterns = {}
    if LanternService and LanternService.GetLanternsForPlot then
        lanterns = LanternService:GetLanternsForPlot(plotKey)
    else
        -- Fallback: find lanterns in workspace
        local lanternFolder = Workspace:FindFirstChild("Lanterns")
        if lanternFolder then
            for _, child in pairs(lanternFolder:GetChildren()) do
                lanterns[child.Name] = true
            end
        end
    end
    
    for lanternId, _ in pairs(lanterns) do
        self:RemoveLantern(player, lanternId)
    end
    
    -- 2. Remove all canals
    local canals = {}
    if PondNetworkService and PondNetworkService.GetNetworkSnapshot then
        local network = PondNetworkService:GetNetworkSnapshot(plotKey)
        canals = network.canals or network.lakes or {}
    else
        -- Fallback: find canals in workspace
        local canalFolder = Workspace:FindFirstChild("CanalSegments")
        if canalFolder then
            for _, child in pairs(canalFolder:GetChildren()) do
                canals[child.Name] = true
            end
        end
    end
    
    for canalId, _ in pairs(canals) do
        self:RemoveCanal(player, canalId)
    end
    
    -- 3. Remove all ponds
    local ponds = {}
    if PondNetworkService and PondNetworkService.GetNetworkSnapshot then
        local network = PondNetworkService:GetNetworkSnapshot(plotKey)
        ponds = network.ponds or {}
    else
        -- Fallback: find ponds in workspace
        local pondFolder = Workspace:FindFirstChild("PondRims")
        if pondFolder then
            for _, child in pairs(pondFolder:GetChildren()) do
                if child.Name:match("Pond_(.+)") then
                    local pondId = child.Name:match("Pond_(.+)")
                    ponds[pondId] = true
                end
            end
        end
    end
    
    for pondId, _ in pairs(ponds) do
        self:RemovePond(player, pondId)
    end
    
    -- 4. Clear any remaining visual elements
    local folders = {"PondRims", "CanalStones", "CanalSegments", "Lanterns"}
    for _, folderName in pairs(folders) do
        local folder = Workspace:FindFirstChild(folderName)
        if folder then
            for _, child in pairs(folder:GetChildren()) do
                if child.Name:find(plotKey) then
                    child:Destroy()
                end
            end
        end
    end
    
    return true, "Plot wiped successfully"
end

return EnhancedRemovalSystem