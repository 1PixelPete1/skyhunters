-- StudioDevUI.client.luau
-- Comprehensive Studio testing interface with top-right toggle button

local Players = Players or game:GetService("Players")
local RunService = RunService or game:GetService("RunService")
local ReplicatedStorage = ReplicatedStorage or game:GetService("ReplicatedStorage")

-- Only run in Studio
if not RunService:IsStudio() then
    return
end

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Create main UI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "StudioDevUI"
screenGui.Parent = playerGui

-- Create toggle button in top-right corner
local toggleButton = Instance.new("TextButton")
toggleButton.Name = "ToggleButton"
toggleButton.Size = UDim2.new(0, 120, 0, 30)
toggleButton.Position = UDim2.new(1, -130, 0, 10)
toggleButton.BackgroundColor3 = Color3.fromRGB(70, 130, 180)
toggleButton.BorderSizePixel = 0
toggleButton.Text = "Dev Tools"
toggleButton.TextColor3 = Color3.new(1, 1, 1)
toggleButton.TextScaled = true
toggleButton.Font = Enum.Font.SourceSansBold
toggleButton.Parent = screenGui

-- Add corner rounding to button
local buttonCorner = Instance.new("UICorner")
buttonCorner.CornerRadius = UDim.new(0, 6)
buttonCorner.Parent = toggleButton

-- Create main dev tools panel
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 300, 0, 400)
mainFrame.Position = UDim2.new(1, -310, 0, 50)
mainFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
mainFrame.BorderSizePixel = 0
mainFrame.Visible = false -- Start hidden
mainFrame.Parent = screenGui

-- Add corner rounding to main frame
local frameCorner = Instance.new("UICorner")
frameCorner.CornerRadius = UDim.new(0, 8)
frameCorner.Parent = mainFrame

-- Title
local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, 0, 0, 30)
title.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
title.BorderSizePixel = 0
title.Text = "QuietWinds Dev Tools"
title.TextColor3 = Color3.new(1, 1, 1)
title.TextScaled = true
title.Font = Enum.Font.SourceSansBold
title.Parent = mainFrame

-- Add corner rounding to title
local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 8)
titleCorner.Parent = title

-- Scroll frame for content
local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Name = "ScrollFrame"
scrollFrame.Size = UDim2.new(1, 0, 1, -30)
scrollFrame.Position = UDim2.new(0, 0, 0, 30)
scrollFrame.BackgroundTransparency = 1
scrollFrame.ScrollBarThickness = 8
scrollFrame.Parent = mainFrame

-- Layout
local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 5)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = scrollFrame

-- Helper function to create buttons
local function createButton(text, callback, layoutOrder)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, -10, 0, 30)
    button.BackgroundColor3 = Color3.fromRGB(70, 130, 180)
    button.BorderSizePixel = 0
    button.Text = text
    button.TextColor3 = Color3.new(1, 1, 1)
    button.TextScaled = true
    button.Font = Enum.Font.SourceSans
    button.LayoutOrder = layoutOrder
    button.Parent = scrollFrame
    
    -- Add corner rounding
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = button
    
    -- Hover effects
    button.MouseEnter:Connect(function()
        button.BackgroundColor3 = Color3.fromRGB(90, 150, 200)
    end)
    
    button.MouseLeave:Connect(function()
        button.BackgroundColor3 = Color3.fromRGB(70, 130, 180)
    end)
    
    button.Activated:Connect(callback)
    return button
end

-- Helper function to create sections
local function createSection(text, layoutOrder)
    local section = Instance.new("TextLabel")
    section.Size = UDim2.new(1, -10, 0, 25)
    section.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    section.BorderSizePixel = 0
    section.Text = text
    section.TextColor3 = Color3.fromRGB(200, 200, 200)
    section.TextScaled = true
    section.Font = Enum.Font.SourceSansBold
    section.LayoutOrder = layoutOrder
    section.Parent = scrollFrame
    
    -- Add corner rounding
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = section
    
    return section
end

-- Helper function for network calls (checks Net/Remotes path)
local function callServer(remoteName, ...)
    -- Try Net/Remotes path first (standard structure)
    local Net = ReplicatedStorage:FindFirstChild("Net")
    if Net then
        local remotes = Net:FindFirstChild("Remotes")
        if remotes then
            local remote = remotes:FindFirstChild(remoteName)
            if remote then
                remote:FireServer(...)
                return true
            end
        end
    end
    
    -- Fallback to direct Remotes folder
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if remotes then
        local remote = remotes:FindFirstChild(remoteName)
        if remote then
            remote:FireServer(...)
            return true
        end
    end
    
    warn("Remote not found:", remoteName)
    return false
end

-- Dev Tools Sections
local layoutOrder = 0

-- ITEM SPAWNING
createSection("🎒 ITEM SPAWNING", layoutOrder)
layoutOrder = layoutOrder + 1

createButton("Grant All Lantern Types", function()
    callServer("GrantItemRemote", "basic_lantern", 10)
    callServer("GrantItemRemote", "enhanced_lantern", 5)
    callServer("GrantItemRemote", "crystal_lantern", 3)
    print("Added lanterns to inventory")
end, layoutOrder)
layoutOrder = layoutOrder + 1

createButton("Grant Oil Canisters", function()
    callServer("GrantItemRemote", "oil_cannister", 20)
    print("Added oil canisters to inventory")
end, layoutOrder)
layoutOrder = layoutOrder + 1

createButton("Grant Plot Upgrades", function()
    callServer("GrantItemRemote", "pond_excavator", 5)
    callServer("GrantItemRemote", "oil_cannister", 10)
    print("Added plot upgrades to inventory")
end, layoutOrder)
layoutOrder = layoutOrder + 1

createButton("Grant Mobility Equipment", function()
    callServer("GrantItemRemote", "double_jump", 1)
    callServer("GrantItemRemote", "dash_boots", 1)
    callServer("GrantItemRemote", "grappling_hook", 1)
    print("Added mobility equipment to inventory")
end, layoutOrder)
layoutOrder = layoutOrder + 1

createButton("Grant Lantern Head", function()
    callServer("GrantItemRemote", "lantern_headlamp", 1)
    print("Added lantern headlamp to inventory")
end, layoutOrder)
layoutOrder = layoutOrder + 1

createButton("Grant Curse", function()
    callServer("GrantItemRemote", "curse_of_greed", 1)
    print("Added curse to inventory")
end, layoutOrder)
layoutOrder = layoutOrder + 1

createButton("Grant Weapon", function()
    callServer("GrantItemRemote", "iron_sword", 1)
    print("Added weapon to inventory")
end, layoutOrder)
layoutOrder = layoutOrder + 1

-- OIL TOOLS
createSection("Oil Tools", layoutOrder)
layoutOrder = layoutOrder + 1

createButton("Oil +50", function()
    callServer("OilAddAmountRemote", 50)
    print("Added 50 oil")
end, layoutOrder)
layoutOrder = layoutOrder + 1

createButton("Oil -50", function()
    callServer("OilAddAmountRemote", -50)
    print("Removed 50 oil")
end, layoutOrder)
layoutOrder = layoutOrder + 1

createButton("Oil Set 0", function()
    callServer("OilSetAmountRemote", 0)
    print("Oil set to 0")
end, layoutOrder)
layoutOrder = layoutOrder + 1

createButton("Oil Set Full", function()
    -- Use a large number; server clamps to capacity
    callServer("OilSetAmountRemote", 1e9)
    print("Oil set to full")
end, layoutOrder)
layoutOrder = layoutOrder + 1

createButton("Grant Currency (1000 each)", function()
    callServer("GrantCurrencyRemote", "aether", 1000)
    callServer("GrantCurrencyRemote", "crumbs", 1000)
    print("Granted currency")
end, layoutOrder)
layoutOrder = layoutOrder + 1

-- PLOT MANAGEMENT
createSection("🏝️ PLOT MANAGEMENT", layoutOrder)
layoutOrder = layoutOrder + 1

createButton("Wipe Current Plot", function()
    callServer("WipePlotRemote")
    print("Wiped current plot")
end, layoutOrder)
layoutOrder = layoutOrder + 1

createButton("Reset Plot Terrain", function()
    callServer("ResetTerrainRemote")
    print("Reset plot terrain")
end, layoutOrder)
layoutOrder = layoutOrder + 1

createButton("Teleport to Plot Center", function()
    callServer("TeleportToPlotRemote")
    print("Teleporting to plot center")
end, layoutOrder)
layoutOrder = layoutOrder + 1

createButton("Teleport to POI", function()
    callServer("TeleportToPOIRemote")
    print("Teleporting to POI")
end, layoutOrder)
layoutOrder = layoutOrder + 1

createButton("Clear My Ponds + Lanterns (Save)", function()
    callServer("ClearPondsLanternsRemote")
    print("Requested save clear for ponds+lanterns")
end, layoutOrder)
layoutOrder = layoutOrder + 1

createButton("Clear My Player Profile", function()
    callServer("ClearPlayerProfileRemote")
    print("Requested profile reset")
end, layoutOrder)
layoutOrder = layoutOrder + 1

-- PLAYER STATE DEBUG
createSection("Player State Debug", layoutOrder)
layoutOrder = layoutOrder + 1

createButton("Damage 1 Heart", function()
    local stateRemote = ReplicatedStorage:FindFirstChild("PlayerStateRemote")
    if stateRemote then stateRemote:FireServer("DebugDamage", 1) end
end, layoutOrder)
layoutOrder = layoutOrder + 1

createButton("Heal 1 Heart", function()
    local stateRemote = ReplicatedStorage:FindFirstChild("PlayerStateRemote")
    if stateRemote then stateRemote:FireServer("DebugHeal", 1) end
end, layoutOrder)
layoutOrder = layoutOrder + 1

-- TESTING TOOLS
createSection("🔧 TESTING TOOLS", layoutOrder)
layoutOrder = layoutOrder + 1

createButton("Force Save Profile", function()
    callServer("ForceSaveRemote")
    print("Forced profile save")
end, layoutOrder)
layoutOrder = layoutOrder + 1

createButton("Reload Ponds from Save", function()
    callServer("ReloadPondsRemote")
    print("Reloading ponds from save data")
end, layoutOrder)
layoutOrder = layoutOrder + 1

createButton("Debug Pond Network", function()
    callServer("DebugPondNetworkRemote")
    print("Debug info printed to server console")
end, layoutOrder)
layoutOrder = layoutOrder + 1

createButton("Validate All Placements", function()
    callServer("ValidateAllPlacementsRemote")
    print("Validating all current placements")
end, layoutOrder)
layoutOrder = layoutOrder + 1

-- PERFORMANCE TESTING
createSection("⚡ PERFORMANCE", layoutOrder)
layoutOrder = layoutOrder + 1

createButton("Spawn 50 Test Ponds", function()
    callServer("SpawnTestPondsRemote", 50)
    print("Spawning test ponds")
end, layoutOrder)
layoutOrder = layoutOrder + 1

createButton("Clear All Test Objects", function()
    callServer("ClearTestObjectsRemote")
    print("Cleared test objects")
end, layoutOrder)
layoutOrder = layoutOrder + 1

-- VISUAL DEBUGGING
createSection("👁️ VISUAL DEBUG", layoutOrder)
layoutOrder = layoutOrder + 1

createButton("Toggle Boundary Visualization", function()
    callServer("ToggleBoundaryVisRemote")
    print("Toggled boundary visualization")
end, layoutOrder)
layoutOrder = layoutOrder + 1

createButton("Show Pond Network Connections", function()
    callServer("ShowPondConnectionsRemote")
    print("Showing pond network connections")
end, layoutOrder)
layoutOrder = layoutOrder + 1

-- SKY ISLANDS
createSection("🪨 Sky Islands", layoutOrder)
layoutOrder = layoutOrder + 1

createButton("Regen Sky Islands", function()
    callServer("ResetSkyIslandsRemote")
    print("Sky island regeneration queued")
end, layoutOrder)
layoutOrder = layoutOrder + 1

-- Toggle functionality
local isVisible = false
local function toggleVisibility()
    isVisible = not isVisible
    mainFrame.Visible = isVisible
    
    -- Update button text
    if isVisible then
        toggleButton.Text = "Hide Tools"
        toggleButton.BackgroundColor3 = Color3.fromRGB(180, 70, 70) -- Red when open
    else
        toggleButton.Text = "Dev Tools"
        toggleButton.BackgroundColor3 = Color3.fromRGB(70, 130, 180) -- Blue when closed
    end
end

-- Connect toggle button
toggleButton.Activated:Connect(toggleVisibility)

-- Update canvas size
local function updateCanvasSize()
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 10)
end

listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvasSize)
updateCanvasSize()

print("Studio Dev UI loaded! Click the 'Dev Tools' button in the top-right corner.")
