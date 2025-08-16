local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer

local RF_FetchCatalog = ReplicatedStorage:WaitForChild("ShopRemotes"):WaitForChild("RF_FetchCatalog")
local RF_Purchase = ReplicatedStorage.ShopRemotes:WaitForChild("RF_Purchase")

local rarityColors = {
    Common = Color3.fromRGB(200, 200, 200),
    Uncommon = Color3.fromRGB(120, 255, 120),
    Rare = Color3.fromRGB(120, 120, 255),
    Legendary = Color3.fromRGB(255, 170, 0),
    Mythic = Color3.fromRGB(255, 0, 255),
}

local inventoryCount = {}

local function createGui()
    local playerGui = localPlayer:WaitForChild("PlayerGui")

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "ShopGUI"
    screenGui.Enabled = false
    screenGui.Parent = playerGui

    local plate = Instance.new("ImageLabel")
    plate.Name = "Plate"
    plate.Size = UDim2.fromOffset(300, 260)
    plate.Position = UDim2.fromScale(0.5, 0.5)
    plate.AnchorPoint = Vector2.new(0.5, 0.5)
    plate.BackgroundTransparency = 1
    plate.Image = "rbxassetid://0"
    plate.Parent = screenGui

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -20, 1, -20)
    frame.Position = UDim2.new(0, 10, 0, 10)
    frame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    frame.BorderSizePixel = 0
    frame.Parent = plate

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 30)
    title.BackgroundTransparency = 1
    title.Text = "Shop"
    title.TextColor3 = Color3.new(1, 1, 1)
    title.Font = Enum.Font.SourceSansBold
    title.TextSize = 16
    title.Parent = frame

    local crumbsLabel = Instance.new("TextLabel")
    crumbsLabel.Size = UDim2.new(0, 80, 0, 24)
    crumbsLabel.Position = UDim2.new(0, 5, 0, 5)
    crumbsLabel.BackgroundTransparency = 1
    crumbsLabel.TextColor3 = Color3.new(1, 1, 1)
    crumbsLabel.Text = "0"
    crumbsLabel.Parent = frame

    local close = Instance.new("TextButton")
    close.Size = UDim2.new(0, 80, 0, 24)
    close.Position = UDim2.new(1, -85, 0, 5)
    close.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    close.TextColor3 = Color3.new(1, 1, 1)
    close.Text = "Close"
    close.Parent = frame
    close.MouseButton1Click:Connect(function()
        screenGui.Enabled = false
    end)

    local errorLabel = Instance.new("TextLabel")
    errorLabel.Size = UDim2.new(1, -10, 0, 20)
    errorLabel.Position = UDim2.new(0, 5, 1, -25)
    errorLabel.BackgroundTransparency = 1
    errorLabel.TextColor3 = Color3.new(1, 0.3, 0.3)
    errorLabel.Text = ""
    errorLabel.TextSize = 14
    errorLabel.Parent = frame

    local list = Instance.new("ScrollingFrame")
    list.Name = "List"
    list.Size = UDim2.new(1, -10, 1, -60)
    list.Position = UDim2.new(0, 5, 0, 35)
    list.CanvasSize = UDim2.new(0, 0, 0, 0)
    list.ScrollBarThickness = 6
    list.BackgroundTransparency = 1
    list.Parent = frame

    return screenGui, list, errorLabel, crumbsLabel
end

local function populateList(list, errorLabel, crumbsLabel)
    for _, child in ipairs(list:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
    errorLabel.Text = ""

    local catalog = RF_FetchCatalog:InvokeServer()
    if typeof(catalog) ~= "table" or typeof(catalog.items) ~= "table" then
        errorLabel.Text = "Failed to load catalog"
        return
    end

    local y = 0
    local order = catalog.rarityOrder or {}
    for _, rarity in ipairs(order) do
        for id, item in pairs(catalog.items) do
            if item.rarity == rarity then
                local entry = Instance.new("Frame")
                entry.Size = UDim2.new(1, -10, 0, 40)
                entry.Position = UDim2.new(0, 0, 0, y)
                entry.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
                entry.BorderSizePixel = 1
                entry.Parent = list

                local nameLabel = Instance.new("TextLabel")
                nameLabel.Size = UDim2.new(0.5, 0, 1, 0)
                nameLabel.Position = UDim2.new(0, 5, 0, 0)
                nameLabel.BackgroundTransparency = 1
                nameLabel.TextXAlignment = Enum.TextXAlignment.Left
                nameLabel.Text = item.name
                nameLabel.TextColor3 = rarityColors[item.rarity] or Color3.new(1, 1, 1)
                nameLabel.Parent = entry

                local priceLabel = Instance.new("TextLabel")
                priceLabel.Size = UDim2.new(0, 80, 1, 0)
                priceLabel.Position = UDim2.new(0.5, 0, 0, 0)
                priceLabel.BackgroundTransparency = 1
                priceLabel.Text = tostring(item.displayPrice)
                priceLabel.TextColor3 = Color3.new(1, 1, 1)
                priceLabel.Parent = entry

                local buyButton = Instance.new("TextButton")
                buyButton.Size = UDim2.new(0, 60, 0, 24)
                buyButton.Position = UDim2.new(1, -65, 0.5, -12)
                buyButton.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
                buyButton.TextColor3 = Color3.new(1, 1, 1)
                buyButton.Text = "Buy"
                buyButton.Parent = entry

                buyButton.MouseButton1Click:Connect(function()
                    local result = RF_Purchase:InvokeServer({ itemId = id })
                    if result and result.ok then
                        crumbsLabel.Text = tostring(result.newBalance)
                        inventoryCount[id] = result.newCount
                        errorLabel.Text = "Purchased " .. (item.name or id)
                    else
                        errorLabel.Text = result and result.code or "Purchase failed"
                    end
                end)

                y += 45
            end
        end
    end
    list.CanvasSize = UDim2.new(0, 0, 0, y)
end

local ShopUI = {}

function ShopUI.Init()
    local prompt = workspace:WaitForChild("ShopNPC"):WaitForChild("ProximityPrompt")
    local gui, list, errorLabel, crumbsLabel = createGui()

    prompt.Triggered:Connect(function()
        gui.Enabled = true
        populateList(list, errorLabel, crumbsLabel)
    end)
end

return ShopUI

