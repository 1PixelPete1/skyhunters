-- ReservoirUI.lua
-- Basic UI for selling reservoir resources

local ReservoirUI = {}
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- UI State
local currentReservoir = 0
local sellFrame = nil

function ReservoirUI:Initialize()
    -- Create UI
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "ReservoirUI"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = playerGui
    
    -- Main container
    sellFrame = Instance.new("Frame")
    sellFrame.Size = UDim2.new(0, 300, 0, 150)
    sellFrame.Position = UDim2.new(1, -320, 1, -170)
    sellFrame.BackgroundColor3 = Color3.new(0.1, 0.1, 0.15)
    sellFrame.BorderSizePixel = 0
    sellFrame.Parent = screenGui
    
    -- Corner rounding
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = sellFrame
    
    -- Title
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 30)
    title.Position = UDim2.new(0, 0, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "Underground Reservoir"
    title.TextColor3 = Color3.new(0.9, 0.85, 0.7)
    title.TextScaled = true
    title.Font = Enum.Font.SourceSansBold
    title.Parent = sellFrame
    
    -- Resource amount
    self.resourceLabel = Instance.new("TextLabel")
    self.resourceLabel.Size = UDim2.new(1, -20, 0, 40)
    self.resourceLabel.Position = UDim2.new(0, 10, 0, 35)
    self.resourceLabel.BackgroundTransparency = 1
    self.resourceLabel.Text = "0 Units"
    self.resourceLabel.TextColor3 = Color3.new(0.7, 0.9, 1)
    self.resourceLabel.TextScaled = true
    self.resourceLabel.Font = Enum.Font.SourceSans
    self.resourceLabel.Parent = sellFrame
    
    -- Sell button
    local sellButton = Instance.new("TextButton")
    sellButton.Size = UDim2.new(0.8, 0, 0, 35)
    sellButton.Position = UDim2.new(0.1, 0, 0, 85)
    sellButton.BackgroundColor3 = Color3.new(0.2, 0.5, 0.3)
    sellButton.Text = "SELL ALL"
    sellButton.TextColor3 = Color3.new(1, 1, 1)
    sellButton.TextScaled = true
    sellButton.Font = Enum.Font.SourceSansBold
    sellButton.Parent = sellFrame
    
    local buttonCorner = Instance.new("UICorner")
    buttonCorner.CornerRadius = UDim.new(0, 8)
    buttonCorner.Parent = sellButton
    
    -- Depreciation warning
    self.depreciationLabel = Instance.new("TextLabel")
    self.depreciationLabel.Size = UDim2.new(1, -20, 0, 15)
    self.depreciationLabel.Position = UDim2.new(0, 10, 1, -20)
    self.depreciationLabel.BackgroundTransparency = 1
    self.depreciationLabel.Text = ""
    self.depreciationLabel.TextColor3 = Color3.new(1, 0.7, 0.3)
    self.depreciationLabel.TextScaled = true
    self.depreciationLabel.Font = Enum.Font.SourceSans
    self.depreciationLabel.Visible = false
    self.depreciationLabel.Parent = sellFrame
    
    -- Button hover effect
    sellButton.MouseEnter:Connect(function()
        TweenService:Create(sellButton, TweenInfo.new(0.2), {
            BackgroundColor3 = Color3.new(0.3, 0.6, 0.4)
        }):Play()
    end)
    
    sellButton.MouseLeave:Connect(function()
        TweenService:Create(sellButton, TweenInfo.new(0.2), {
            BackgroundColor3 = Color3.new(0.2, 0.5, 0.3)
        }):Play()
    end)
    
    -- Connect sell button
    sellButton.MouseButton1Click:Connect(function()
        self:OnSellClick()
    end)
end

function ReservoirUI:UpdateReservoir(amount)
    currentReservoir = amount
    self.resourceLabel.Text = string.format("%.1f Units", amount)
    
    -- Show depreciation warning if above threshold
    if amount > 100 then
        local effectiveAmount = 100 + ((amount - 100) * 0.95)
        local loss = amount - effectiveAmount
        self.depreciationLabel.Text = string.format("Depreciation: -%.1f units", loss)
        self.depreciationLabel.Visible = true
    else
        self.depreciationLabel.Visible = false
    end
end

function ReservoirUI:OnSellClick()
    if currentReservoir <= 0 then return end
    
    -- Fire remote event to server
    local remoteEvent = game.ReplicatedStorage:FindFirstChild("SellReservoir")
    if remoteEvent then
        remoteEvent:FireServer()
        
        -- Visual feedback
        self:ShowSellFeedback()
    end
end

function ReservoirUI:ShowSellFeedback()
    -- Create popup for gold gained
    local popup = Instance.new("Frame")
    popup.Size = UDim2.new(0, 200, 0, 60)
    popup.Position = UDim2.new(0.5, -100, 0.5, -30)
    popup.BackgroundColor3 = Color3.new(0.9, 0.8, 0.3)
    popup.Parent = playerGui.ReservoirUI
    
    local popupText = Instance.new("TextLabel")
    popupText.Size = UDim2.new(1, 0, 1, 0)
    popupText.BackgroundTransparency = 1
    popupText.Text = "+Gold"
    popupText.TextScaled = true
    popupText.Font = Enum.Font.SourceSansBold
    popupText.TextColor3 = Color3.new(0.2, 0.15, 0)
    popupText.Parent = popup
    
    -- Animate and remove
    local tween = TweenService:Create(popup, TweenInfo.new(1.5, Enum.EasingStyle.Quad), {
        Position = UDim2.new(0.5, -100, 0.3, 0),
        BackgroundTransparency = 1
    })
    
    TweenService:Create(popupText, TweenInfo.new(1.5), {
        TextTransparency = 1
    }):Play()
    
    tween:Play()
    tween.Completed:Connect(function()
        popup:Destroy()
    end)
end

return ReservoirUI