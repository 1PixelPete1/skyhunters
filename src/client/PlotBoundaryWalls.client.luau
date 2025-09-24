--!strict
-- PlotBoundaryWalls: Shows red translucent walls at plot edges
-- Appears when player approaches the boundary, disappears when they move away

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")

local WorldConfig = require(RS.Config.WorldConfig)
local PresetUtil = require(RS.Shared.PresetUtil)
local Net = require(RS.Shared.Net)

local Player = Players.LocalPlayer

-- Configuration
local WALL_HEIGHT = 20  -- Height of the boundary walls
local TRIGGER_DISTANCE = 10  -- Distance from edge when walls appear
local WALL_THICKNESS = 0.2
local WALL_COLOR = Color3.fromRGB(255, 0, 0)
local WALL_TRANSPARENCY = 0.7

-- Wall storage
local walls: { Part } = {}
local wallsVisible = false

-- Get plot bounds from config
local plotCenter: Vector3? = nil
local halfSize: Vector3 = PresetUtil.getPresetHalfSizeVector(WorldConfig.ISLANDS.MainPresetKey or "plane_64m")

local function getPlotBounds(): (Vector3, number, number, number, number)
    local center = plotCenter or Vector3.new(0, 0, 0)
    return center, center.X - halfSize.X, center.X + halfSize.X, center.Z - halfSize.Z, center.Z + halfSize.Z
end

-- Create boundary wall parts
local function createWalls()
    if #walls > 0 then return end  -- Already created
    
    local center, minX, maxX, minZ, maxZ = getPlotBounds()
    
    -- Create 4 walls (North, South, East, West)
    local wallConfigs = {
        { pos = Vector3.new(center.X, WALL_HEIGHT/2, maxZ), size = Vector3.new(maxX - minX, WALL_HEIGHT, WALL_THICKNESS), name = "NorthWall" },
        { pos = Vector3.new(center.X, WALL_HEIGHT/2, minZ), size = Vector3.new(maxX - minX, WALL_HEIGHT, WALL_THICKNESS), name = "SouthWall" },
        { pos = Vector3.new(maxX, WALL_HEIGHT/2, center.Z), size = Vector3.new(WALL_THICKNESS, WALL_HEIGHT, maxZ - minZ), name = "EastWall" },
        { pos = Vector3.new(minX, WALL_HEIGHT/2, center.Z), size = Vector3.new(WALL_THICKNESS, WALL_HEIGHT, maxZ - minZ), name = "WestWall" },
    }
    
    for _, config in ipairs(wallConfigs) do
        local wall = Instance.new("Part")
        wall.Name = config.name
        wall.Anchored = true
        wall.CanCollide = false
        wall.CanQuery = false
        wall.CanTouch = false
        wall.Material = Enum.Material.ForceField
        wall.Color = WALL_COLOR
        wall.Transparency = 1  -- Start invisible
        wall.Size = config.size
        wall.Position = config.pos
        wall.Parent = workspace
        
        table.insert(walls, wall)
    end
    
    print("[PlotBoundaryWalls] Created boundary walls")
end

-- Show/hide walls
local function setWallsVisible(visible: boolean)
    if visible == wallsVisible then return end
    wallsVisible = visible
    
    for _, wall in ipairs(walls) do
        wall.Transparency = visible and WALL_TRANSPARENCY or 1
    end
    
    if visible then
        print("[PlotBoundaryWalls] Boundary walls visible - approaching plot edge")
    else
        print("[PlotBoundaryWalls] Boundary walls hidden")
    end
end

-- Check if player is near plot boundary
local function checkPlayerPosition()
    local character = Player.Character
    local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return end
    
    local pos = humanoidRootPart.Position
    local _, minX, maxX, minZ, maxZ = getPlotBounds()
    
    -- Calculate distance to each edge
    local distToEastEdge = math.abs(pos.X - maxX)
    local distToWestEdge = math.abs(pos.X - minX)
    local distToNorthEdge = math.abs(pos.Z - maxZ)
    local distToSouthEdge = math.abs(pos.Z - minZ)
    
    -- Find minimum distance to any edge
    local minDistToEdge = math.min(distToEastEdge, distToWestEdge, distToNorthEdge, distToSouthEdge)
    
    -- Show walls if close to edge
    setWallsVisible(minDistToEdge <= TRIGGER_DISTANCE)
end

-- Initialize
createWalls()

-- Update loop
local connection: RBXScriptConnection?
connection = RunService.Heartbeat:Connect(checkPlayerPosition)

-- Cleanup on character respawn
Player.CharacterAdded:Connect(function()
    -- Restart the check when character respawns
    if connection then
        connection:Disconnect()
    end
    connection = RunService.Heartbeat:Connect(checkPlayerPosition)
end)

print("[PlotBoundaryWalls] Loaded - red walls will appear when approaching plot edges")

-- Track plot assignment and update wall positions when assigned
task.spawn(function()
    local ok, ev = pcall(function() return Net:GetEvent("RE_BaseAssigned") end)
    if ok and ev then
        ev.OnClientEvent:Connect(function(assignment)
            if assignment and typeof(assignment) == "table" and typeof(assignment.origin) == "CFrame" then
                plotCenter = assignment.origin.Position
                -- Recreate walls at new center
                for _, w in ipairs(walls) do w:Destroy() end
                table.clear(walls)
                createWalls()
            end
        end)
    end
end)
