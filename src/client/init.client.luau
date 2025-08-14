local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

ReplicatedStorage:WaitForChild("GetPlayerData")
local aetherSnapshot = ReplicatedStorage:WaitForChild("Aether_Snapshot")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "EconomyDebug"
screenGui.Parent = playerGui

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 300, 0, 400)
frame.Position = UDim2.new(0, 10, 0, 10)
frame.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
frame.BorderSizePixel = 2
frame.Parent = screenGui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 30)
title.BackgroundColor3 = Color3.new(0.1, 0.1, 0.1)
title.Text = "Economy Debug"
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.SourceSansBold
title.TextSize = 16
title.Parent = frame

local crumbsLabel = Instance.new("TextLabel")
crumbsLabel.Size = UDim2.new(1, 0, 0, 30)
crumbsLabel.Position = UDim2.new(0, 0, 0, 40)
crumbsLabel.BackgroundTransparency = 1
crumbsLabel.Text = "Crumbs: 0"
crumbsLabel.TextColor3 = Color3.new(1, 1, 1)
crumbsLabel.Font = Enum.Font.SourceSans
crumbsLabel.TextSize = 14
crumbsLabel.Parent = frame

aetherSnapshot.OnClientEvent:Connect(function(payload)
    if payload.crumbs ~= nil then
        crumbsLabel.Text = "₡" .. payload.crumbs
    end
end)

local function createButton(text, position, callback)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, -20, 0, 30)
    button.Position = position
    button.BackgroundColor3 = Color3.new(0.3, 0.3, 0.3)
    button.Text = text
    button.TextColor3 = Color3.new(1, 1, 1)
    button.Font = Enum.Font.SourceSans
    button.TextSize = 12
    button.Parent = frame
    button.MouseButton1Click:Connect(callback)
    return button
end

local function updateDisplay()
    local success, data = pcall(function()
        return ReplicatedStorage.GetPlayerData:InvokeServer()
    end)
    if success then
        crumbsLabel.Text = "₡" .. (data.crumbs or 0)
    else
        crumbsLabel.Text = "Error getting data"
    end
end

createButton("Refresh Data", UDim2.new(0, 10, 0, 80), updateDisplay)

createButton("Add 100 Crumbs", UDim2.new(0, 10, 0, 120), function()
    local success, result, newCrumbs = pcall(function()
        return ReplicatedStorage.DebugAddCrumbs:InvokeServer(100)
    end)
    if success and result then
        crumbsLabel.Text = "₡" .. newCrumbs
        print("Added 100 crumbs successfully")
    else
        print("Failed to add crumbs")
    end
end)

createButton("Set Aether to 50", UDim2.new(0, 10, 0, 160), function()
    local success, data = pcall(function()
        return ReplicatedStorage.GetPlayerData:InvokeServer()
    end)
    if success then
        data.aether.current = 50
        print("Set aether to 50 (client-side only for testing)")
    end
end)

createButton("Sell All Aether", UDim2.new(0, 10, 0, 200), function()
    local success, gain, newCrumbs = pcall(function()
        return ReplicatedStorage.SellAether:InvokeServer()
    end)
    if success then
        crumbsLabel.Text = "₡" .. newCrumbs
        print("Sold aether for", gain, "crumbs")
    else
        print("Failed to sell aether")
    end
end)

createButton("Buy Purity Upgrade", UDim2.new(0, 10, 0, 240), function()
    local success, result, newCrumbs = pcall(function()
        return ReplicatedStorage.PurchaseUpgrade:InvokeServer("purity_plus005")
    end)
    if success and result then
        crumbsLabel.Text = "₡" .. newCrumbs
        print("Purchased purity upgrade")
    else
        print("Failed to purchase upgrade")
    end
end)

createButton("Spawn Producer", UDim2.new(0, 10, 0, 280), function()
    local success, result = pcall(function()
        return ReplicatedStorage.SpawnProducer:InvokeServer()
    end)
    if success then
        print("Spawned producer object")
    else
        print("Failed to spawn producer")
    end
end)

createButton("Give Seed", UDim2.new(0, 10, 0, 320), function()
    local success = pcall(function()
        return ReplicatedStorage.DebugGiveSeed:InvokeServer()
    end)
    if success then
        print("Gave seed item")
    else
        print("Failed to give seed item")
    end
end)

-- Load AetherClient
print("Loading AetherClient...")
local success, AetherClient = pcall(function()
    return require(script:WaitForChild("AetherClient"))
end)
if success then
    print("AetherClient loaded successfully!")
else
    print("Failed to load AetherClient:", AetherClient)
end

updateDisplay()
print("Economy debug UI loaded!")

local okInv, InventoryUI = pcall(function()
    return require(script:WaitForChild("InventoryUI"))
end)
if okInv then
    InventoryUI.Init()
end

