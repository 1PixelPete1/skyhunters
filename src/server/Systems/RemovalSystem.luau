--!strict
-- RemovalSystem.luau: Server-side removal logic with validation and terrain restoration
-- Handles safe removal of ponds and lanterns with ownership checks

local RemovalSystem = {}

local CS = game:GetService("CollectionService")
local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local WorldConfig = require(RS.Config.WorldConfig)
local UnifiedCarvingUtil = require(RS.Shared.UnifiedCarvingUtil)

-- Ensure remotes exist
local Net = RS:FindFirstChild("Net") or Instance.new("Folder")
Net.Name = "Net"; Net.Parent = RS
local Remotes = Net:FindFirstChild("Remotes") or Instance.new("Folder")
Remotes.Name = "Remotes"; Remotes.Parent = Net

local RF_RemovePond = Remotes:FindFirstChild("RF_RemovePond") or Instance.new("RemoteFunction")
RF_RemovePond.Name = "RF_RemovePond"; RF_RemovePond.Parent = Remotes

local RF_RemoveLantern = Remotes:FindFirstChild("RF_RemoveLantern") or Instance.new("RemoteFunction")
RF_RemoveLantern.Name = "RF_RemoveLantern"; RF_RemoveLantern.Parent = Remotes

local RF_RemoveOilReservoir = Remotes:FindFirstChild("RF_RemoveOilReservoir") or Instance.new("RemoteFunction")
RF_RemoveOilReservoir.Name = "RF_RemoveOilReservoir"; RF_RemoveOilReservoir.Parent = Remotes

-- Preflight remote to check whether a pond can be removed (no side effects)
local RF_CanRemovePond = Remotes:FindFirstChild("RF_CanRemovePond") or Instance.new("RemoteFunction")
RF_CanRemovePond.Name = "RF_CanRemovePond"; RF_CanRemovePond.Parent = Remotes

-- Get pond network service
local function getPondNetworkService()
    local ok, PNS = pcall(function()
        return require(SSS:WaitForChild("Systems"):WaitForChild("PondNetworkService"))
    end)
    return ok and PNS or nil
end

-- Validate pond ownership/permissions
local function canRemovePond(player: Player, pondId: string): (boolean, string?)
    local PNS = getPondNetworkService()
    if not PNS then
        return false, "SERVICE_UNAVAILABLE"
    end
    
    -- Access snapshot through function if available
    local snapshot = PNS.getSnapshot and PNS.getSnapshot() or PNS.snapshot
    if not snapshot then
        return false, "SNAPSHOT_UNAVAILABLE"
    end
    
    local pond = snapshot.ponds[pondId]
    if not pond then
        return false, "POND_NOT_FOUND"
    end
    
    -- For now, allow any player to remove any pond (can add ownership later)
    return true, nil
end

-- Comprehensive lantern search function that finds and returns the actual lantern object
local function findLanternObject(lanternId: string): Instance?
    local lantern = nil
    
    -- Search by CollectionService tag first
    for _, item in ipairs(CS:GetTagged("Lantern")) do
        local itemId = item:GetAttribute("lanternId") or item:GetAttribute("LanternId") or item.Name
        if itemId == lanternId then
            return item
        end
    end
    
    -- Search in workspace hierarchically if not found by tag
    local function searchDescendants(parent)
        for _, child in ipairs(parent:GetChildren()) do
            if child:IsA("Model") or child:IsA("BasePart") then
                local itemId = child:GetAttribute("lanternId") or child:GetAttribute("LanternId") or child.Name
                if itemId == lanternId then
                    return child
                end
                
                -- Check if this is a model containing lantern parts
                if CS:HasTag(child, "Lantern") then
                    local taggedId = child:GetAttribute("lanternId") or child:GetAttribute("LanternId") or child.Name
                    if taggedId == lanternId then
                        return child
                    end
                end
            end
            local found = searchDescendants(child)
            if found then return found end
        end
        return nil
    end
    
    return searchDescendants(workspace)
end

-- Validate lantern ownership/permissions
local function canRemoveLantern(player: Player, lanternId: string): (boolean, string?)
    local lantern = findLanternObject(lanternId)
    
    if not lantern then
        -- Debug: List all available lanterns for troubleshooting
        print("[RemovalSystem] Available lanterns:")
        for _, item in ipairs(CS:GetTagged("Lantern")) do
            local itemId = item:GetAttribute("lanternId") or item:GetAttribute("LanternId") or item.Name
            print(string.format("  - %s (type: %s, parent: %s)", itemId, item.ClassName, item.Parent and item.Parent.Name or "nil"))
        end
        return false, "LANTERN_NOT_FOUND"
    end
    
    -- Check ownership (for now, allow any player to remove any lantern)
    print(string.format("[RemovalSystem] Found lantern %s for removal", lanternId))
    return true, nil
end

-- Enhanced terrain restoration to properly fill the pond bowl
local function restorePondTerrain(pond: any)
    local yTop = WorldConfig.ISLANDS.DefaultHeightY
    local radius = pond.radius
    local posXZ = pond.pos
    
    local ok, err = pcall(function()
        -- Use UnifiedCarvingUtil to properly restore the terrain
        -- Create a filled bowl at surface level
        local fillCenter = Vector3.new(posXZ.X, yTop, posXZ.Y)
        local material = Enum.Material.Ground  -- Use ground material for restoration
        
        -- Create a region that covers the pond area
        local region = Region3.new(
            Vector3.new(posXZ.X - radius - 2, yTop - 3, posXZ.Y - radius - 2),
            Vector3.new(posXZ.X + radius + 2, yTop + 1, posXZ.Y + radius + 2)
        )
        
        -- Fill the region to restore flat terrain
        workspace.Terrain:FillRegion(region, 4, material)
        
        print(string.format("[RemovalSystem] Restored terrain at (%.1f,%.1f) r=%.1f to height %.1f", posXZ.X, posXZ.Y, radius, yTop))
    end)
    
    if not ok then
        warn("[RemovalSystem] Failed to restore terrain:", err)
    end
end

-- Check if any lanterns are within pond boundary (prevent removal if they exist)
local function checkLanternsInPondBoundary(pondId: string, pond: any): (boolean, string?)
    local POND_SCALE = require(RS.Shared.Boundary.BoundaryConfig).pond_scale or 0.5
    local PAD = require(RS.Shared.Boundary.BoundaryConfig).pad or 1.25
    local boundaryRadius = pond.radius * (1 + POND_SCALE) + PAD
    
    local lanternsInBoundary = {}
    
    for _, lantern in ipairs(CS:GetTagged("Lantern")) do
        local lanternPos: Vector3?
        if lantern:IsA("Model") and lantern.PrimaryPart then
            lanternPos = lantern.PrimaryPart.Position
        elseif lantern:IsA("BasePart") then
            lanternPos = lantern.Position
        end
        
        if lanternPos then
            local distance = (Vector2.new(lanternPos.X, lanternPos.Z) - pond.pos).Magnitude
            if distance <= boundaryRadius then
                local lanternId = lantern:GetAttribute("LanternId") or lantern:GetAttribute("lanternId") or lantern.Name
                table.insert(lanternsInBoundary, lanternId)
            end
        end
    end
    
    if #lanternsInBoundary > 0 then
        local lanternList = table.concat(lanternsInBoundary, ", ")
        return false, string.format("LANTERNS_IN_BOUNDARY: %s", lanternList)
    end
    
    return true, nil
end

-- Check if any lanterns intersect any of the given canal paths (within half-width + pad)
local function checkLanternsInConnectedCanals(snapshot: any, connectedLakeIds: { string }): (boolean, string?)
    if not snapshot or not snapshot.lakes then return true, nil end
    local PAD = (require(RS.Shared.Boundary.BoundaryConfig).pad or 1.25)

    local function pointSegDist(p: Vector2, a: Vector2, b: Vector2): number
        local ab = b - a
        local t = 0
        local denom = ab:Dot(ab)
        if denom > 1e-6 then
            t = math.clamp((p - a):Dot(ab) / denom, 0, 1)
        end
        local proj = a + ab * t
        return (p - proj).Magnitude
    end

    local offenders = {}
    -- Collect lantern positions once
    local lanPos: { Vector2 } = {}
    local lanIds: { string } = {}
    for _, lantern in ipairs(CS:GetTagged("Lantern")) do
        local pos: Vector3? = nil
        if lantern:IsA("Model") and lantern.PrimaryPart then pos = lantern.PrimaryPart.Position
        elseif lantern:IsA("BasePart") then pos = lantern.Position end
        if pos then
            table.insert(lanPos, Vector2.new(pos.X, pos.Z))
            table.insert(lanIds, (lantern:GetAttribute("LanternId") or lantern:GetAttribute("lanternId") or lantern.Name))
        end
    end

    for _, lakeId in ipairs(connectedLakeIds) do
        local lake = snapshot.lakes[lakeId]
        if lake and type(lake.path) == "table" and #lake.path >= 2 then
            local halfW = (lake.width or 4) * 0.5
            local thresh = halfW + PAD
            for li, lp in ipairs(lanPos) do
                -- scan polyline segments
                local within = false
                for i = 1, #lake.path - 1 do
                    local a = lake.path[i]
                    local b = lake.path[i+1]
                    local d = pointSegDist(lp, a, b)
                    if d <= thresh then within = true; break end
                end
                if within then
                    table.insert(offenders, lanIds[li])
                end
            end
        end
    end
    if #offenders > 0 then
        return false, string.format("LANTERNS_IN_CANAL: %s", table.concat(offenders, ", "))
    end
    return true, nil
end

-- Remove pond and all associated elements
function RemovalSystem.removePond(player: Player, pondId: string): (boolean, string?)
    -- Validate permissions
    local canRemove, reason = canRemovePond(player, pondId)
    if not canRemove then
        return false, reason
    end
    
    local PNS = getPondNetworkService()
    if not PNS then
        return false, "SERVICE_UNAVAILABLE"
    end
    
    -- Access snapshot through function if available
    local snapshot = PNS.getSnapshot and PNS.getSnapshot() or PNS.snapshot
    if not snapshot then
        return false, "SNAPSHOT_UNAVAILABLE"
    end
    
    local pond = snapshot.ponds[pondId]
    if not pond then
        return false, "POND_NOT_FOUND"
    end
    
    -- NEW: Check for lanterns within pond boundary before removal
    local pondCenter = pond.pos
    local pondRadius = pond.radius
    
    for _, lantern in ipairs(CS:GetTagged("Lantern")) do
        if lantern:IsA("Model") and lantern.PrimaryPart then
            local lanternPos = Vector2.new(lantern.PrimaryPart.Position.X, lantern.PrimaryPart.Position.Z)
            local distanceFromPond = (lanternPos - pondCenter).Magnitude
            if distanceFromPond <= pondRadius + 2 then -- 2 stud buffer
                return false, "LANTERNS_IN_BOUNDARY"
            end
        elseif lantern:IsA("BasePart") then
            local lanternPos = Vector2.new(lantern.Position.X, lantern.Position.Z)
            local distanceFromPond = (lanternPos - pondCenter).Magnitude
            if distanceFromPond <= pondRadius + 2 then
                return false, "LANTERNS_IN_BOUNDARY"
            end
        end
    end
    
    -- Check for connected canals and ensure no dependent lanterns are inside them
    local connectedCanals = {}
    for lakeId, lake in pairs(snapshot.lakes) do
        if lake.a == pondId or lake.b == pondId then
            table.insert(connectedCanals, lakeId)
        end
    end
    if #connectedCanals > 0 then
        local okCanals, canalReason = checkLanternsInConnectedCanals(snapshot, connectedCanals)
        if not okCanals then
            return false, canalReason or "LANTERNS_IN_CANAL"
        end
        -- No dependent lanterns in canals; allow removal and we will also delete those canals below
    end
    
    -- Remove visual elements
    local success = true
    local errorReason = nil
    
    -- Remove pond rim parts
    local pondRims = workspace:FindFirstChild("PondRims")
    if pondRims then
        local rimFolder = pondRims:FindFirstChild(pondId)
        if rimFolder then
            rimFolder:Destroy()
        end
    end
    
    -- Remove canal segments (none should exist due to check above, but cleanup anyway)
    local canalSegments = workspace:FindFirstChild("CanalSegments")
    if canalSegments then
        for _, lakeId in ipairs(connectedCanals) do
            local canalFolder = canalSegments:FindFirstChild(lakeId)
            if canalFolder then
                canalFolder:Destroy()
            end
        end
    end
    
    -- Update pond network service data and trigger persistence save
    pcall(function()
        -- Get current snapshot
        local currentSnapshot = PNS.getSnapshot and PNS.getSnapshot() or PNS.snapshot
        if currentSnapshot then
            -- Remove from snapshot
            currentSnapshot.ponds[pondId] = nil
            
            -- Remove connected lakes
            for _, lakeId in ipairs(connectedCanals) do
                currentSnapshot.lakes[lakeId] = nil
            end
            
            -- Bump version and notify clients if bump function exists
            if PNS.bump then
                PNS.bump({ 
                    ponds = { removed = { pondId } },
                    lakes = { removed = connectedCanals }
                })
            end
            
            -- Trigger immediate save to persist pond removal
            task.spawn(function()
                task.wait(0.5)  -- Small delay to let cleanup complete
                local PondPersistence = require(SSS:FindFirstChild("Systems"):FindFirstChild("PondPersistence"))
                if PondPersistence and PondPersistence.save then
                    PondPersistence.save()
                    print(string.format("[RemovalSystem] Triggered pond persistence save after removing %s", pondId))
                end
            end)
        end
    end)
    
    -- NEW: Properly restore terrain using Region3 fill
    pcall(function()
        local yTop = (WorldConfig.ISLANDS and WorldConfig.ISLANDS.DefaultHeightY) or 1
        local radius = pond.radius
        local posXZ = pond.pos
        
        -- Create a region that covers the pond area
        local regionMin = Vector3.new(posXZ.X - radius - 2, yTop - 3, posXZ.Y - radius - 2)
        local regionMax = Vector3.new(posXZ.X + radius + 2, yTop + 1, posXZ.Y + radius + 2)
        local region = Region3.new(regionMin, regionMax)
        
        -- Fill the region with the appropriate terrain material
        local material = Enum.Material.Grass
        if WorldConfig.ISLANDS and WorldConfig.ISLANDS.TopMaterial then
            local topMaterial = WorldConfig.ISLANDS.TopMaterial
            if topMaterial == "Ground" then
                material = Enum.Material.Ground
            elseif topMaterial == "Mud" then
                material = Enum.Material.Mud
            elseif topMaterial == "Sand" then
                material = Enum.Material.Sand
            end
        end
        
        workspace.Terrain:FillRegion(region, 4, material)
        
        print(string.format("[RemovalSystem] Restored terrain at (%.1f,%.1f) r=%.1f to height %.1f with %s", 
            posXZ.X, posXZ.Y, radius, yTop, tostring(material)))
    end)
    
    -- Update boundary system
    pcall(function()
        local BoundaryGraph = require(SSS:WaitForChild("Server"):WaitForChild("Boundary"):WaitForChild("BoundaryGraph"))
        BoundaryGraph.removeNode(pondId)
    end)
    
    print(string.format("[RemovalSystem] Removed pond %s (player: %s)", pondId, player.Name))
    return true, nil
end

-- Preflight without mutating state: can we remove this pond?
function RemovalSystem.preflightPondRemoval(player: Player, pondId: string): (boolean, string?)
    local okPerm, reason = canRemovePond(player, pondId)
    if not okPerm then return false, reason end
    local PNS = getPondNetworkService(); if not PNS then return false, "SERVICE_UNAVAILABLE" end
    local snapshot = PNS.getSnapshot and PNS.getSnapshot() or PNS.snapshot
    if not snapshot then return false, "SNAPSHOT_UNAVAILABLE" end
    local pond = snapshot.ponds[pondId]
    if not pond then return false, "POND_NOT_FOUND" end
    -- Disallow removing default pond (closest to origin with expected radius)
    do
        local cfg = require(RS.Config.WorldConfig)
        local expectedR = (cfg.ISLANDS and cfg.ISLANDS.Pond and cfg.ISLANDS.Pond.Radius) or 15
        local bestId: string? = nil
        local bestDist = math.huge
        for id, p in pairs(snapshot.ponds) do
            local d = (p.pos - Vector2.new(0,0)).Magnitude
            if math.abs((p.radius or 0) - expectedR) <= (expectedR * 0.2) and d < bestDist then
                bestDist = d; bestId = id
            end
        end
        if bestId and pondId == bestId then
            return false, "DEFAULT_POND"
        end
    end
    -- Check lanterns within pond boundary
    do
        local pondCenter = pond.pos
        local pondRadius = pond.radius
        for _, lantern in ipairs(CS:GetTagged("Lantern")) do
            if lantern:IsA("Model") and lantern.PrimaryPart then
                local lp = Vector2.new(lantern.PrimaryPart.Position.X, lantern.PrimaryPart.Position.Z)
                if (lp - pondCenter).Magnitude <= pondRadius + 2 then return false, "LANTERNS_IN_BOUNDARY" end
            elseif lantern:IsA("BasePart") then
                local lp = Vector2.new(lantern.Position.X, lantern.Position.Z)
                if (lp - pondCenter).Magnitude <= pondRadius + 2 then return false, "LANTERNS_IN_BOUNDARY" end
            end
        end
    end
    -- Check canals for dependent lanterns
    local connected = {}
    for lid, lake in pairs(snapshot.lakes) do
        if lake.a == pondId or lake.b == pondId then table.insert(connected, lid) end
    end
    if #connected > 0 then
        local okCanals, canalReason = checkLanternsInConnectedCanals(snapshot, connected)
        if not okCanals then return false, canalReason or "LANTERNS_IN_CANAL" end
    end
    return true, nil
end

-- Remove lantern with save data cleanup (UNIFIED search to avoid race conditions)
function RemovalSystem.removeLantern(player: Player, lanternId: string): (boolean, string?)
    -- Find the lantern object using the unified search function
    local lanternObject = findLanternObject(lanternId)
    
    if not lanternObject then
        -- Debug: List all available lanterns for troubleshooting
        print("[RemovalSystem] Available lanterns:")
        for _, item in ipairs(CS:GetTagged("Lantern")) do
            local itemId = item:GetAttribute("lanternId") or item:GetAttribute("LanternId") or item.Name
            print(string.format("  - %s (type: %s, parent: %s)", itemId, item.ClassName, item.Parent and item.Parent.Name or "nil"))
        end
        return false, "LANTERN_NOT_FOUND"
    end
    
    -- Check permissions (for now, allow any player to remove any lantern)
    print(string.format("[RemovalSystem] Found lantern %s for removal and destruction", lanternId))
    
    -- Destroy the lantern object
    lanternObject:Destroy()
    print(string.format("[RemovalSystem] Destroyed lantern object %s", lanternId))
    
    -- Update save data to remove the lantern from persistent storage
    pcall(function()
        -- Access the correct lantern save service (LanternSaveStore, not SaveService)
        local LanternSaveStore = require(SSS:WaitForChild("Server"):WaitForChild("LanternSaveStore"))
        if LanternSaveStore and LanternSaveStore.removeLantern then
            local success = LanternSaveStore.removeLantern(lanternId)
            if success then
                print(string.format("[RemovalSystem] Successfully removed lantern %s from save data", lanternId))
            else
                warn(string.format("[RemovalSystem] Failed to find lantern %s in save data", lanternId))
            end
        else
            warn("[RemovalSystem] LanternSaveStore.removeLantern not found")
        end
    end)
    
    print(string.format("[RemovalSystem] Removed lantern %s (player: %s)", lanternId, player.Name))
    return true, nil
end

-- Remove oil reservoir with capacity updates
function RemovalSystem.removeOilReservoir(player: Player, reservoirId: string): (boolean, string?)
    if type(reservoirId) ~= "string" then
        return false, "INVALID_RESERVOIR_ID"
    end
    
    -- Delegate to OilReservoirService
    local ok, OilReservoirService = pcall(function()
        return require(SSS:WaitForChild("Server"):WaitForChild("OilReservoirService"))
    end)
    
    if not ok or not OilReservoirService then
        return false, "SERVICE_UNAVAILABLE"
    end
    
    local success, reason = OilReservoirService.RemoveReservoir(player, reservoirId)
    if success then
        print(string.format("[RemovalSystem] Removed oil reservoir %s (player: %s)", reservoirId, player.Name))
    end
    return success, reason
end

-- Wire up remote functions
RF_RemovePond.OnServerInvoke = function(player: Player, pondId: string)
    if type(pondId) ~= "string" then
        return false, "INVALID_POND_ID"
    end
    
    return RemovalSystem.removePond(player, pondId)
end

RF_CanRemovePond.OnServerInvoke = function(player: Player, pondId: string)
    if type(pondId) ~= "string" then
        return false, "INVALID_POND_ID"
    end
    return RemovalSystem.preflightPondRemoval(player, pondId)
end

RF_RemoveLantern.OnServerInvoke = function(player: Player, lanternId: string)
    if type(lanternId) ~= "string" then
        return false, "INVALID_LANTERN_ID"
    end
    
    return RemovalSystem.removeLantern(player, lanternId)
end

RF_RemoveOilReservoir.OnServerInvoke = function(player: Player, reservoirId: string)
    if type(reservoirId) ~= "string" then
        return false, "INVALID_RESERVOIR_ID"
    end
    
    return RemovalSystem.removeOilReservoir(player, reservoirId)
end

print("[RemovalSystem] Initialized - RF_RemovePond, RF_RemoveLantern, and RF_RemoveOilReservoir ready")

return RemovalSystem
