local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer

local RF_FetchCatalog = ReplicatedStorage:WaitForChild("ShopRemotes"):WaitForChild("RF_FetchCatalog")
local RF_Purchase = ReplicatedStorage.ShopRemotes:WaitForChild("RF_Purchase")

local function createGui()
    local playerGui = localPlayer:WaitForChild("PlayerGui")

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "ShopGUI"
    screenGui.Enabled = false
    screenGui.Parent = playerGui

    local frame = Instance.new("Frame")
    frame.Size = UDim2.fromOffset(200, 100)
    frame.Position = UDim2.fromScale(0.5, 0.5)
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    frame.BorderSizePixel = 0
    frame.Parent = screenGui

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 30)
    title.BackgroundTransparency = 1
    title.Text = "Shop"
    title.TextColor3 = Color3.new(1, 1, 1)
    title.Font = Enum.Font.SourceSansBold
    title.TextSize = 16
    title.Parent = frame

    local close = Instance.new("TextButton")
    close.Size = UDim2.new(0, 80, 0, 24)
    close.Position = UDim2.new(1, -85, 1, -29)
    close.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    close.TextColor3 = Color3.new(1, 1, 1)
    close.Text = "Close"
    close.Parent = frame

    close.MouseButton1Click:Connect(function()
        screenGui.Enabled = false
    end)

    local buy = Instance.new("TextButton")
    buy.Size = UDim2.new(0, 80, 0, 24)
    buy.Position = UDim2.new(0, 5, 1, -29)
    buy.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    buy.TextColor3 = Color3.new(1, 1, 1)
    buy.Text = "Buy Test"
    buy.Parent = frame

    buy.MouseButton1Click:Connect(function()
        pcall(function()
            RF_Purchase:InvokeServer({ itemId = "debug_item" })
        end)
    end)

    return screenGui
end

local ShopUI = {}

function ShopUI.Init()
    local prompt = workspace:WaitForChild("ShopNPC"):WaitForChild("ProximityPrompt")
    local gui = createGui()

    prompt.Triggered:Connect(function()
        gui.Enabled = true
        pcall(function()
            RF_FetchCatalog:InvokeServer()
        end)
    end)
end

return ShopUI

