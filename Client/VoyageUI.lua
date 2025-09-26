-- VoyageUI.lua  
-- UI for voyage initiation and rewards

local VoyageUI = {}
local TweenService = game:GetService("TweenService")

local player = game:GetService("Players").LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local voyageFrame = nil
local isVoyageActive = false

function VoyageUI:Initialize()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "VoyageUI"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = playerGui
    
    -- Voyage popup frame
    voyageFrame = Instance.new("Frame")
    voyageFrame.Size = UDim2.new(0, 400, 0, 300)
    voyageFrame.Position = UDim2.new(0.5, -200, 0.5, -150)
    voyageFrame.BackgroundColor3 = Color3.new(0.08, 0.08, 0.12)
    voyageFrame.BorderSizePixel = 0
    voyageFrame.Visible = false
    voyageFrame.Parent = screenGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 16)
    corner.Parent = voyageFrame
    
    -- Title
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 50)
    title.BackgroundTransparency = 1
    title.Text = "⛵ UNDERGROUND VOYAGE"
    title.TextColor3 = Color3.fromRGB(220, 200, 255)
    title.TextScaled = true
    title.Font = Enum.Font.Fantasy
    title.Parent = voyageFrame
    
    -- Resource display
    self.resourceDisplay = Instance.new("TextLabel")
    self.resourceDisplay.Size = UDim2.new(1, -40, 0, 40)
    self.resourceDisplay.Position = UDim2.new(0, 20, 0, 60)
    self.resourceDisplay.BackgroundTransparency = 1
    self.resourceDisplay.Text = "Resources Available: 0"
    self.resourceDisplay.TextColor3 = Color3.fromRGB(180, 220, 255)
    self.resourceDisplay.TextScaled = true
    self.resourceDisplay.Font = Enum.Font.SourceSans
    self.resourceDisplay.Parent = voyageFrame
    
    -- Option buttons container
    local buttonContainer = Instance.new("Frame")
    buttonContainer.Size = UDim2.new(1, -40, 0, 150)
    buttonContainer.Position = UDim2.new(0, 20, 0, 110)
    buttonContainer.BackgroundTransparency = 1
    buttonContainer.Parent = voyageFrame
    
    -- Three options: Cancel, Sell for Gold, Start Voyage
    local options = {
        {Text = "❌ Cancel", Color = Color3.new(0.3, 0.3, 0.3), Action = "Cancel"},
        {Text = "💰 Sell for Gold", Color = Color3.new(0.6, 0.5, 0.2), Action = "Sell"},
        {Text = "🚀 Start Voyage", Color = Color3.new(0.2, 0.4, 0.6), Action = "Voyage"}
    }
    
    for i, option in ipairs(options) do
        local button = Instance.new("TextButton")
        button.Size = UDim2.new(1, 0, 0, 40)
        button.Position = UDim2.new(0, 0, 0, (i-1) * 50)
        button.BackgroundColor3 = option.Color
        button.Text = option.Text
        button.TextColor3 = Color3.new(1, 1, 1)
        button.TextScaled = true
        button.Font = Enum.Font.SourceSansBold
        button.Parent = buttonContainer
        
        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 8)
        btnCorner.Parent = button
        
        -- Button interactions
        button.MouseEnter:Connect(function()
            TweenService:Create(button, TweenInfo.new(0.2), {
                BackgroundColor3 = option.Color * 1.3
            }):Play()
        end)
        
        button.MouseLeave:Connect(function()
            TweenService:Create(button, TweenInfo.new(0.2), {
                BackgroundColor3 = option.Color
            }):Play()
        end)
        
        button.MouseButton1Click:Connect(function()
            self:HandleOption(option.Action)
        end)
    end
    
    -- Progress bar (hidden initially)
    self.progressBar = Instance.new("Frame")
    self.progressBar.Size = UDim2.new(1, -40, 0, 20)
    self.progressBar.Position = UDim2.new(0, 20, 1, -40)
    self.progressBar.BackgroundColor3 = Color3.new(0.1, 0.1, 0.15)
    self.progressBar.BorderSizePixel = 0
    self.progressBar.Visible = false
    self.progressBar.Parent = voyageFrame
    
    local barCorner = Instance.new("UICorner")
    barCorner.CornerRadius = UDim.new(0, 10)
    barCorner.Parent = self.progressBar
    
    self.progressFill = Instance.new("Frame")
    self.progressFill.Size = UDim2.new(0, 0, 1, 0)
    self.progressFill.BackgroundColor3 = Color3.fromRGB(100, 200, 255)
    self.progressFill.BorderSizePixel = 0
    self.progressFill.Parent = self.progressBar
    
    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(0, 10)
    fillCorner.Parent = self.progressFill
end

function VoyageUI:ShowVoyagePrompt(resourceAmount)
    self.resourceDisplay.Text = string.format("Resources Available: %.1f", resourceAmount)
    voyageFrame.Visible = true
    
    -- Animate in
    voyageFrame.Position = UDim2.new(0.5, -200, 0.6, -150)
    TweenService:Create(voyageFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
        Position = UDim2.new(0.5, -200, 0.5, -150)
    }):Play()
end

function VoyageUI:HandleOption(action)
    if action == "Cancel" then
        self:Hide()
    elseif action == "Sell" then
        -- Fire sell event
        local remote = game.ReplicatedStorage:FindFirstChild("SellReservoir")
        if remote then
            remote:FireServer()
        end
        self:Hide()
    elseif action == "Voyage" then
        self:StartVoyageAnimation()
        -- Fire voyage event
        local remote = game.ReplicatedStorage:FindFirstChild("StartVoyage")
        if remote then
            remote:FireServer()
        end
    end
end

function VoyageUI:StartVoyageAnimation()
    isVoyageActive = true
    
    -- Hide options, show progress
    for _, child in pairs(voyageFrame:GetChildren()) do
        if child:IsA("Frame") and child ~= self.progressBar then
            child.Visible = false
        end
    end
    
    self.progressBar.Visible = true
    
    -- Animate progress over 30 seconds
    TweenService:Create(self.progressFill, TweenInfo.new(30, Enum.EasingStyle.Linear), {
        Size = UDim2.new(1, 0, 1, 0)
    }):Play()
end

function VoyageUI:ShowRewards(rewards)
    -- Create reward display
    voyageFrame.Visible = true
    
    -- Clear contents
    for _, child in pairs(voyageFrame:GetChildren()) do
        if child:IsA("TextLabel") or child:IsA("Frame") then
            child:Destroy()
        end
    end
    
    local rewardTitle = Instance.new("TextLabel")
    rewardTitle.Size = UDim2.new(1, 0, 0, 60)
    rewardTitle.BackgroundTransparency = 1
    rewardTitle.Text = "🎉 VOYAGE COMPLETE!"
    rewardTitle.TextColor3 = Color3.fromRGB(255, 215, 0)
    rewardTitle.TextScaled = true
    rewardTitle.Font = Enum.Font.Fantasy
    rewardTitle.Parent = voyageFrame
    
    -- Display rewards
    local rewardText = Instance.new("TextLabel")
    rewardText.Size = UDim2.new(1, -40, 0, 100)
    rewardText.Position = UDim2.new(0, 20, 0, 80)
    rewardText.BackgroundTransparency = 1
    rewardText.Text = self:FormatRewards(rewards)
    rewardText.TextColor3 = Color3.new(1, 1, 1)
    rewardText.TextScaled = true
    rewardText.Font = Enum.Font.SourceSans
    rewardText.Parent = voyageFrame
    
    -- Auto-hide after 5 seconds
    task.wait(5)
    self:Hide()
end

function VoyageUI:FormatRewards(rewards)
    if rewards.Type == "Gold" then
        return "💰 " .. rewards.Amount .. " Gold"
    elseif rewards.Type == "Machine" then
        return "⚙️ " .. rewards.Machine .. " (Rarity " .. rewards.Rarity .. ")"
    elseif rewards.Type == "LanternUpgrade" then
        return "✨ Lantern Upgrade!"
    elseif rewards.Type == "RareLantern" then
        return "🏮 Rare Lantern (Rarity " .. rewards.LanternRarity .. ")"
    else
        return "Better luck next time!"
    end
end

function VoyageUI:Hide()
    TweenService:Create(voyageFrame, TweenInfo.new(0.3), {
        Position = UDim2.new(0.5, -200, 0.6, -150),
        Transparency = 1
    }):Play()
    
    task.wait(0.3)
    voyageFrame.Visible = false
    voyageFrame.Transparency = 0
    isVoyageActive = false
end

return VoyageUI