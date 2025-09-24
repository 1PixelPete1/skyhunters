--!strict
-- PlacementTransaction: Ensures placement is fully validated before any visual creation
-- Client-safe validation without server dependencies

local PlacementTransaction = {}

local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Only require client-safe modules
local PlacementPolicy = require(RS.Shared.PlacementPolicy)
local BoundaryConfig = require(RS.Shared.Boundary.BoundaryConfig)

export type PlacementRequest = {
    pondId: string?,
    posXZ: Vector2,
    radius: number,
    depth: number?,
    placementType: "pond" | "lantern",
    presetKey: string?,
    playerUserId: number?,
}

export type ValidationResult = {
    success: boolean,
    reason: string?,
    canProceed: boolean,
}

-- Comprehensive validation before any operations
function PlacementTransaction.validatePlacement(request: PlacementRequest): ValidationResult
    -- Basic parameter validation
    if not request or typeof(request.posXZ) ~= "Vector2" then
        return { success = false, reason = "BAD_PARAMS", canProceed = false }
    end
    
    if request.placementType == "pond" then
        return PlacementTransaction.validatePondPlacement(request)
    elseif request.placementType == "lantern" then
        return PlacementTransaction.validateLanternPlacement(request)
    else
        return { success = false, reason = "UNKNOWN_TYPE", canProceed = false }
    end
end

function PlacementTransaction.validatePondPlacement(request: PlacementRequest): ValidationResult
    local radius = request.radius or 10
    local posXZ = request.posXZ
    
    -- Radius bounds check
    if radius < 6 or radius > 20 then
        return { success = false, reason = "INVALID_RADIUS", canProceed = false }
    end
    
    -- Terrain validation
    local terrainCheck = PlacementTransaction.validateTerrainAtPosition(Vector3.new(posXZ.X, 0, posXZ.Y))
    if not terrainCheck.success then
        return terrainCheck
    end
    
    -- Client-side overlap check (basic distance check)
    local overlapCheck = PlacementTransaction.checkPondOverlapClient(posXZ, radius)
    if not overlapCheck.success then
        return overlapCheck
    end
    
    return { success = true, reason = nil, canProceed = true }
end

function PlacementTransaction.validateLanternPlacement(request: PlacementRequest): ValidationResult
    local posXZ = request.posXZ
    local position = Vector3.new(posXZ.X, 0, posXZ.Y)  -- Y will be determined by terrain raycast
    
    -- Always use PlacementPolicy for consistent validation between client and server
    local okPolicy, success, reason = pcall(function()
        local lanternRequest = {
            position = position,
            islandPresetKey = request.presetKey or "lantern_basic",  -- This will be ignored for bounds anyway
            islandCFrame = CFrame.new(),  -- Single island for now
        }
        
        return PlacementPolicy.validateLantern(lanternRequest)
    end)
    
    if okPolicy then
        return { 
            success = success, 
            reason = reason or "VALIDATION_FAILED", 
            canProceed = success 
        }
    else
        -- Fallback if PlacementPolicy fails
        warn("[PlacementTransaction] PlacementPolicy validation failed:", success)
        return { success = false, reason = "POLICY_ERROR", canProceed = false }
    end
end

-- Client-safe pond overlap check using workspace scanning
function PlacementTransaction.checkPondOverlapClient(posXZ: Vector2, radius: number): ValidationResult
    local POND_SCALE = BoundaryConfig.pond_scale or 0.5
    local PAD = BoundaryConfig.pad or 1.25
    local function ringR(r: number): number 
        return r * (1 + POND_SCALE) + PAD 
    end
    
    local newRing = ringR(radius)
    local overlapMargin = 0.5
    
    -- Look for existing pond rims in workspace
    local pondRims = workspace:FindFirstChild("PondRims")
    if pondRims then
        for _, rimFolder in ipairs(pondRims:GetChildren()) do
            if rimFolder:IsA("Folder") then
                -- Try to find a pond rim part to estimate position and radius
                for _, part in ipairs(rimFolder:GetChildren()) do
                    if part:IsA("BasePart") then
                        local pondPos = Vector2.new(part.Position.X, part.Position.Z)
                        local estimatedRadius = part.Size.X / 2  -- Rough estimate
                        
                        local dist = (posXZ - pondPos).Magnitude
                        local minDist = newRing + ringR(estimatedRadius) + overlapMargin
                        
                        if dist < minDist then
                            return { 
                                success = false, 
                                reason = "POND_OVERLAP", 
                                canProceed = false 
                            }
                        end
                        break  -- Only check first part per pond
                    end
                end
            end
        end
    end
    
    return { success = true, reason = nil, canProceed = true }
end

function PlacementTransaction.validateTerrainAtPosition(position: Vector3): ValidationResult
    -- Check if we're in the boundary ring area (between rim and carved pond)
    local posXZ = Vector2.new(position.X, position.Z)
    
    -- Check if position is within boundary ring but NOT in carved pond
    local isInBoundaryRing = false
    pcall(function()
        -- Access both client and server pond data
        local snapshot = nil
        
        -- Try server-side first
        if RunService:IsServer() then
            local PNS = require(game:GetService("ServerScriptService"):FindFirstChild("Systems"):FindFirstChild("PondNetworkService"))
            if PNS and PNS.getSnapshot then
                snapshot = PNS.getSnapshot()
            end
        else
            -- Client-side: try to get from network client
            local NetClient = _G.PondNetworkClient or {}
            snapshot = NetClient.snapshot
        end
        
        if snapshot and snapshot.ponds then
            local BoundaryConfig = require(RS.Shared.Boundary.BoundaryConfig)
            local POND_SCALE = BoundaryConfig.pond_scale or 0.5
            local PAD = BoundaryConfig.pad or 1.25
            
            for _, pond in pairs(snapshot.ponds) do
                local dist = (posXZ - pond.pos).Magnitude
                local pondRadius = pond.radius
                local boundaryRadius = pondRadius * (1 + POND_SCALE) + PAD
                
                -- Check if we're in the ring area: outside pond but inside boundary
                if dist > pondRadius and dist <= boundaryRadius then
                    isInBoundaryRing = true
                    break
                end
            end
        end
    end)
    
    -- Raycast to check surface
    local origin = position + Vector3.new(0, 200, 0)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Whitelist
    params.FilterDescendantsInstances = { workspace.Terrain }
    params.IgnoreWater = false  -- Don't ignore water, we need to detect it
    
    local hit = workspace:Raycast(origin, Vector3.new(0, -500, 0), params)
    
    if not hit or hit.Instance ~= workspace.Terrain then
        -- Check for rim stones as valid surface
        params.FilterType = Enum.RaycastFilterType.Blacklist
        params.FilterDescendantsInstances = {}
        hit = workspace:Raycast(origin, Vector3.new(0, -500, 0), params)
        
        if hit and hit.Instance and hit.Instance.Name == "RimStone" then
            -- On a rim stone - this is valid!
            return { success = true, reason = nil, canProceed = true }
        end
        
        return { success = false, reason = "BAD_SURFACE", canProceed = false }
    end
    
    -- If we're in the boundary ring area, allow placement even on slopes/water
    if isInBoundaryRing then
        return { success = true, reason = nil, canProceed = true }
    end
    
    -- Otherwise apply normal validation
    if hit.Material == Enum.Material.Water then
        return { success = false, reason = "ON_WATER", canProceed = false }
    end
    
    -- Check slope
    local upDot = hit.Normal:Dot(Vector3.yAxis)
    if upDot < 0.85 then  -- About 32 degrees max slope
        return { success = false, reason = "TOO_STEEP", canProceed = false }
    end
    
    return { success = true, reason = nil, canProceed = true }
end

-- Execute a transactional placement (validate first, then execute all or nothing)
function PlacementTransaction.executePlacement(request: PlacementRequest, executeCallback: (PlacementRequest) -> (boolean, any)): (boolean, string?, any?)
    -- Step 1: Comprehensive validation
    local validation = PlacementTransaction.validatePlacement(request)
    
    if not validation.success then
        print(string.format("[PlacementTransaction] Validation failed: %s", validation.reason or "unknown"))
        return false, validation.reason, nil
    end
    
    -- Step 2: Execute the placement operation
    local success, result = executeCallback(request)
    
    if success then
        print(string.format("[PlacementTransaction] Placement successful: %s", request.placementType))
        return true, nil, result
    else
        print(string.format("[PlacementTransaction] Execution failed: %s", tostring(result)))
        return false, "CREATE_FAILED", nil
    end
end

-- Utility to create fail-fast validation for client ghosts
function PlacementTransaction.quickValidateForGhost(placementType: string, posXZ: Vector2, radius: number?): (boolean, string?)
    local request: PlacementRequest = {
        posXZ = posXZ,
        radius = radius or 10,
        placementType = placementType :: any,
        presetKey = "lantern_basic",  -- Add preset key so both client and server use same validation path
    }
    
    local result = PlacementTransaction.validatePlacement(request)
    return result.success, result.reason
end

return PlacementTransaction