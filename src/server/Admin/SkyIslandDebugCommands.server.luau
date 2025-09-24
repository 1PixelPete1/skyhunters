-- SkyIslandDebugCommands.server.luau
-- Debug commands for testing sky island generation and rendering

local Players = game:GetService("Players")
local SSS = game:GetService("ServerScriptService")

-- Robust resolver for the Worldgen folder (copied from WorldBootstrap)
local function resolveWorldgenFolder()
    -- Most repos put it here:
    local underServer = SSS:FindFirstChild("Server") and SSS.Server:FindFirstChild("Worldgen")
    if underServer then return underServer end

    -- Some Rojo maps as a sibling of 'Server' directly under SSS:
    local topLevel = SSS:FindFirstChild("Worldgen")
    if topLevel then return topLevel end

    return nil
end

local worldgenFolder = resolveWorldgenFolder()
if not worldgenFolder then
    warn("[SkyIslandDebugCommands] Worldgen folder not found - debug commands disabled")
    return
end

local ScatteredSkyIslands = require(worldgenFolder:WaitForChild("ScatteredSkyIslands"))
local SkyIslandRenderingService = require(SSS:WaitForChild("Systems"):WaitForChild("SkyIslandRenderingService"))
local SkyIslandCycleService = require(SSS:WaitForChild("Systems"):WaitForChild("SkyIslandCycleService"))

-- Simple notification function
local function notifyPlayer(player, title, text)
    -- Create a simple GUI notification since SendNotification might not exist
    local gui = Instance.new("ScreenGui")
    gui.Name = "DebugNotification"
    gui.Parent = player:WaitForChild("PlayerGui")
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 300, 0, 100)
    frame.Position = UDim2.new(1, -320, 0, 20)
    frame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    frame.BorderSizePixel = 0
    frame.Parent = gui
    
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -10, 0, 30)
    titleLabel.Position = UDim2.new(0, 5, 0, 5)
    titleLabel.Text = title
    titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleLabel.TextScaled = true
    titleLabel.BackgroundTransparency = 1
    titleLabel.Font = Enum.Font.SourceSansBold
    titleLabel.Parent = frame
    
    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, -10, 1, -40)
    textLabel.Position = UDim2.new(0, 5, 0, 35)
    textLabel.Text = text
    textLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    textLabel.TextScaled = true
    textLabel.BackgroundTransparency = 1
    textLabel.Font = Enum.Font.SourceSans
    textLabel.TextWrapped = true
    textLabel.Parent = frame
    
    -- Auto-remove after 5 seconds
    game:GetService("Debris"):AddItem(gui, 5)
end

-- Command processing
local function processCommand(player: Player, message: string)
    if not message:lower():find("^/sky") then
        return
    end
    
    local args = message:split(" ")
    local command = args[2]
    
    if command == "debug" then
        -- Show debug visualization
        ScatteredSkyIslands.debugVisualize()
        notifyPlayer(player, "Sky Island Debug", "Debug visualization enabled. Look for colored cubes representing islands.")
        
    elseif command == "stats" then
        -- Show rendering statistics
        local stats = SkyIslandRenderingService.getStats()
        local message = string.format(
            "Players: %d | Visible Islands: %d | Avg per Player: %.1f | Render Distance: %d",
            stats.playersTracked,
            stats.totalVisibleIslands,
            stats.averagePerPlayer,
            stats.renderDistance
        )
        notifyPlayer(player, "Sky Island Stats", message)
        
    elseif command == "tp" and args[3] then
        -- Teleport to island type
        local targetType = args[3]:lower()
        local islands = ScatteredSkyIslands.getIslands()
        
        for _, island in ipairs(islands) do
            if island.type:lower() == targetType then
                if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                    player.Character.HumanoidRootPart.CFrame = CFrame.new(island.position + Vector3.new(0, 10, 0))
                    notifyPlayer(player, "Teleported", string.format("Teleported to %s island", island.type))
                    return
                end
            end
        end
        notifyPlayer(player, "Error", string.format("No %s island found", targetType))
        
    elseif command == "clear" then
        -- Clear debug visualization
        for _, part in ipairs(workspace:GetChildren()) do
            if part.Name:find("^Debug_") then
                part:Destroy()
            end
        end
        notifyPlayer(player, "Debug Cleared", "All debug visualization removed")
        
    elseif command == "regen" then
        SkyIslandCycleService.regenNow("chat")
        notifyPlayer(player, "Sky Islands", "Regeneration triggered.")
        
    elseif command == "cleanall" then
        -- Comprehensive cleanup of all sky island content
        notifyPlayer(player, "Sky Islands", "Starting comprehensive cleanup...")
        
        -- Stop rendering service
        local ok, svc = pcall(function()
            return require(SSS:WaitForChild("Systems"):WaitForChild("SkyIslandRenderingService"))
        end)
        if ok and svc.stopRendering then 
            svc.stopRendering() 
        end
        
        -- Clear all sky-related folders
        local foldersToClean = {
            "SkyIslands",
            "SkyElements", 
            "FloatingPaths",
            "FloatingBridges",
            "SkyConstellations",
            "SkyConstellationMarkers",
            "Islands" -- Check the root islands folder too
        }
        
        local itemsRemoved = 0
        for _, folderName in ipairs(foldersToClean) do
            local folder = workspace:FindFirstChild(folderName)
            if folder then
                -- Special handling for Islands folder - only clear sky islands
                if folderName == "Islands" then
                    local skyFolder = folder:FindFirstChild("SkyIslands")
                    if skyFolder then
                        skyFolder:Destroy()
                        itemsRemoved = itemsRemoved + 1
                    end
                    local skyElements = folder:FindFirstChild("SkyElements")
                    if skyElements then
                        skyElements:Destroy()
                        itemsRemoved = itemsRemoved + 1
                    end
                else
                    folder:Destroy()
                    itemsRemoved = itemsRemoved + 1
                end
            end
        end
        
        -- Clear all POI buildings
        for _, child in ipairs(workspace:GetChildren()) do
            if child.Name:match("_POI_") or child.Name:match("_Buildings") then
                child:Destroy()
                itemsRemoved = itemsRemoved + 1
            end
        end
        
        -- Clear all path segments  
        for _, child in ipairs(workspace:GetChildren()) do
            if child.Name:match("^PathSegment_") or child.Name:match("^FloatingBridge_") then
                child:Destroy()
                itemsRemoved = itemsRemoved + 1
            end
        end
        
        -- Clear all street lights
        for _, child in ipairs(workspace:GetChildren()) do
            if child.Name:match("^StreetLight_") then
                child:Destroy()
                itemsRemoved = itemsRemoved + 1
            end
        end
        
        -- Clear anything with IsConstellation attribute
        for _, descendant in ipairs(workspace:GetDescendants()) do
            if descendant:GetAttribute("IsConstellation") then
                if descendant.Parent then
                    descendant:Destroy()
                    itemsRemoved = itemsRemoved + 1
                end
            end
        end
        
        -- Clear debug visualization
        for _, part in ipairs(workspace:GetChildren()) do
            if part.Name:find("^Debug_") then
                part:Destroy()
                itemsRemoved = itemsRemoved + 1
            end
        end
        local debugFolder = workspace:FindFirstChild("SkyIslandDebug")
        if debugFolder then
            debugFolder:Destroy()
            itemsRemoved = itemsRemoved + 1
        end
        
        notifyPlayer(player, "Cleanup Complete", string.format("Removed %d sky island items", itemsRemoved))

    elseif command == "help" then
        -- Show available commands
        local helpText = "/sky debug - Show island positions\n" ..
                        "/sky stats - Show rendering stats\n" ..
                        "/sky tp [type] - Teleport to island type\n" ..
                        "/sky clear - Clear debug visualization\n" ..
                        "/sky cleanall - Remove ALL sky islands\n" ..
                        "/sky regen - Force regeneration of islands"
        notifyPlayer(player, "Sky Island Commands", helpText)
        
    else
        notifyPlayer(player, "Unknown Command", "Use /sky help for available commands")
    end
end

-- Connect to all players
Players.PlayerAdded:Connect(function(player)
    player.Chatted:Connect(function(message)
        processCommand(player, message)
    end)
end)

-- Connect to existing players
for _, player in ipairs(Players:GetPlayers()) do
    player.Chatted:Connect(function(message)
        processCommand(player, message)
    end)
end

print("[SkyIslandDebugCommands] Debug commands loaded. Use /sky help in chat.")
