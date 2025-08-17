local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer

local RF_FetchShopSnapshot = ReplicatedStorage:WaitForChild("ShopRemotes"):WaitForChild("RF_FetchShopSnapshot")
local RF_Purchase = ReplicatedStorage.ShopRemotes:WaitForChild("RF_Purchase")

local rarityColors = {
    Common = Color3.fromRGB(200, 200, 200),
    Uncommon = Color3.fromRGB(120, 255, 120),
    Rare = Color3.fromRGB(120, 120, 255),
    Legendary = Color3.fromRGB(255, 170, 0),
    Mythic = Color3.fromRGB(255, 0, 255),
}

local inventoryCount = {}

local screenGui
local list
local errorLabel
local crumbsLabel

local function createGui()
    local playerGui = localPlayer:WaitForChild("PlayerGui")

    local gui = Instance.new("ScreenGui")
    gui.Name = "ShopGUI"
    gui.Enabled = false
    gui.Parent = playerGui

    local plate = Instance.new("ImageLabel")
    plate.Name = "Plate"
    plate.Size = UDim2.fromOffset(300, 260)
    plate.Position = UDim2.fromScale(0.5, 0.5)
    plate.AnchorPoint = Vector2.new(0.5, 0.5)
    plate.BackgroundTransparency = 1
    plate.Image = "rbxassetid://0"
    plate.Parent = gui

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

    local crumb = Instance.new("TextLabel")
    crumb.Size = UDim2.new(0, 80, 0, 24)
    crumb.Position = UDim2.new(0, 5, 0, 5)
    crumb.BackgroundTransparency = 1
    crumb.TextColor3 = Color3.new(1, 1, 1)
    crumb.Text = "0"
    crumb.Parent = frame

    local close = Instance.new("TextButton")
    close.Size = UDim2.new(0, 80, 0, 24)
    close.Position = UDim2.new(1, -85, 0, 5)
    close.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    close.TextColor3 = Color3.new(1, 1, 1)
    close.Text = "Close"
    close.Parent = frame
    close.MouseButton1Click:Connect(function()
        gui.Enabled = false
    end)

    local err = Instance.new("TextLabel")
    err.Size = UDim2.new(1, -10, 0, 20)
    err.Position = UDim2.new(0, 5, 1, -25)
    err.BackgroundTransparency = 1
    err.TextColor3 = Color3.new(1, 0.3, 0.3)
    err.Text = ""
    err.TextSize = 14
    err.Parent = frame

    local listFrame = Instance.new("ScrollingFrame")
    listFrame.Name = "List"
    listFrame.Size = UDim2.new(1, -10, 1, -60)
    listFrame.Position = UDim2.new(0, 5, 0, 35)
    listFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    listFrame.ScrollBarThickness = 6
    listFrame.BackgroundTransparency = 1
    listFrame.Parent = frame

    screenGui = gui
    list = listFrame
    errorLabel = err
    crumbsLabel = crumb
    return gui
end

local function populateList(catalog)
    for _, child in ipairs(list:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
    errorLabel.Text = ""

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

local function open()
    if not screenGui then
        createGui()
    end
    screenGui.Enabled = true
    local snapshot = RF_FetchShopSnapshot:InvokeServer()
    if typeof(snapshot) ~= "table" then
        errorLabel.Text = "Failed to load catalog"
        return
    end
    crumbsLabel.Text = tostring(snapshot.balance or 0)
    populateList(snapshot.catalog)
end

function ShopUI.Init()
    createGui()
    local prompt = workspace:WaitForChild("ShopNPC"):WaitForChild("ProximityPrompt")
    prompt.Triggered:Connect(open)
end

ShopUI.Open = open

return ShopUI

