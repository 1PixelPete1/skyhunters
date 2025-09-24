-- OilHUD.client.luau  
-- Professional loading bar style oil level display

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local OilHUD = {}

-- UI Configuration
local UI_CONFIG = {
    position = UDim2.new(0, 20, 0, 100), -- Top-left positioning
    size = UDim2.new(0, 300, 0, 80),
    backgroundColor = Color3.fromRGB(25, 25, 30),
    barColor = Color3.fromRGB(139, 69, 19), -- Oil brown color
    lowOilColor = Color3.fromRGB(200, 50, 50), -- Red for low oil
    textColor = Color3.new(1, 1, 1),
    cornerRadius = UDim.new(0, 8),
}

-- State tracking
local oilData = {
    current = 0,
    maximum = 100,
    percentage = 0
}

-- Create the oil HUD
local function createOilHUD()
    -- Main screen GUI
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "OilHUD"
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = playerGui
    
    -- Main container
    local container = Instance.new("Frame")
    container.Name = "Container"
    container.Size = UI_CONFIG.size
    container.Position = UI_CONFIG.position
    container.BackgroundColor3 = UI_CONFIG.backgroundColor
    container.BorderSizePixel = 0
    container.Parent = screenGui
    
    -- Container corner rounding
    local containerCorner = Instance.new("UICorner")
    containerCorner.CornerRadius = UI_CONFIG.cornerRadius
    containerCorner.Parent = container
    
    -- Oil icon/title
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "TitleLabel"
    titleLabel.Size = UDim2.new(1, 0, 0, 25)
    titleLabel.Position = UDim2.new(0, 0, 0, 5)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "🛢️ Oil Storage"
    titleLabel.TextColor3 = UI_CONFIG.textColor
    titleLabel.TextScaled = true
    titleLabel.Font = Enum.Font.SourceSansBold
    titleLabel.Parent = container
    
    -- Progress bar background
    local progressBg = Instance.new("Frame")
    progressBg.Name = "ProgressBackground"
    progressBg.Size = UDim2.new(1, -20, 0, 20)
    progressBg.Position = UDim2.new(0, 10, 0, 35)
    progressBg.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
    progressBg.BorderSizePixel = 0
    progressBg.Parent = container
    
    -- Progress background corner
    local progressBgCorner = Instance.new("UICorner")
    progressBgCorner.CornerRadius = UDim.new(0, 10)
    progressBgCorner.Parent = progressBg
    
    -- Progress bar fill
    local progressFill = Instance.new("Frame")
    progressFill.Name = "ProgressFill"
    progressFill.Size = UDim2.new(0, 0, 1, 0) -- Start empty
    progressFill.BackgroundColor3 = UI_CONFIG.barColor
    progressFill.BorderSizePixel = 0
    progressFill.Parent = progressBg
    
    -- Progress fill corner
    local progressFillCorner = Instance.new("UICorner")
    progressFillCorner.CornerRadius = UDim.new(0, 10)
    progressFillCorner.Parent = progressFill
    
    -- Progress text (current/max)
    local progressText = Instance.new("TextLabel")
    progressText.Name = "ProgressText"
    progressText.Size = UDim2.new(1, 0, 0, 15)
    progressText.Position = UDim2.new(0, 0, 0, 60)
    progressText.BackgroundTransparency = 1
    progressText.Text = "0 / 100 units"
    progressText.TextColor3 = UI_CONFIG.textColor
    progressText.TextScaled = true
    progressText.Font = Enum.Font.SourceSans
    progressText.Parent = container
    
    return screenGui
end

-- Update the oil display with animation
local function updateOilDisplay(gui, current, maximum)
    local container = gui.Container
    local progressFill = container.ProgressBackground.ProgressFill
    local progressText = container.ProgressText
    local titleLabel = container.TitleLabel
    
    -- Calculate percentage
    local percentage = maximum > 0 and (current / maximum) or 0
    percentage = math.clamp(percentage, 0, 1)
    
    -- Update progress bar with smooth animation
    local targetSize = UDim2.new(percentage, 0, 1, 0)
    local fillTween = TweenService:Create(
        progressFill,
        TweenInfo.new(0.8, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
        {Size = targetSize}
    )
    fillTween:Play()
    
    -- Update color based on oil level
    local targetColor
    if percentage < 0.2 then
        targetColor = UI_CONFIG.lowOilColor -- Red for low oil
        titleLabel.Text = "⚠️ Oil Storage (LOW!)"
    elseif percentage < 0.5 then
        targetColor = Color3.fromRGB(200, 120, 30) -- Orange for medium
        titleLabel.Text = "🛢️ Oil Storage"
    else
        targetColor = UI_CONFIG.barColor -- Normal brown for good level
        titleLabel.Text = "🛢️ Oil Storage"
    end
    
    local colorTween = TweenService:Create(
        progressFill,
        TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
        {BackgroundColor3 = targetColor}
    )
    colorTween:Play()
    
    -- Update text
    progressText.Text = string.format("%.0f / %.0f units (%.0f%%)", 
        current, maximum, percentage * 100)
    
    -- Store current values
    oilData.current = current
    oilData.maximum = maximum
    oilData.percentage = percentage
end

-- Module state
local oilHUD = nil
local initialized = false

-- Public functions for integration with oil service
function OilHUD:UpdateOilLevel(current, maximum)
    if oilHUD then
        updateOilDisplay(oilHUD, current, maximum)
    end
end

function OilHUD:Show()
    if oilHUD then
        oilHUD.Enabled = true
    end
end

function OilHUD:Hide()
    if oilHUD then
        oilHUD.Enabled = false
    end
end

function OilHUD:GetCurrentData()
    return {
        current = oilData.current,
        maximum = oilData.maximum,
        percentage = oilData.percentage
    }
end

-- Initialize
function OilHUD.Init()
    if initialized then return OilHUD end
    initialized = true
    
    -- Create the HUD
    oilHUD = createOilHUD()
    
    -- Initialize with default values
    updateOilDisplay(oilHUD, 0, 100)
    
    -- Connect to oil level updates from server
    local Net = ReplicatedStorage:FindFirstChild("Net")
    if Net then
        local remotes = Net:FindFirstChild("Remotes")
        if remotes then
            local oilUpdateRemote = remotes:FindFirstChild("RE_OilLevelUpdate")
            if not oilUpdateRemote then
                oilUpdateRemote = Instance.new("RemoteEvent")
                oilUpdateRemote.Name = "RE_OilLevelUpdate"
                oilUpdateRemote.Parent = remotes
            end
            
            oilUpdateRemote.OnClientEvent:Connect(function(current, maximum)
                if oilHUD then
                    updateOilDisplay(oilHUD, current, maximum)
                end
            end)
        end
    end
    
    print("[OilHUD] Oil loading bar HUD initialized")
    return OilHUD
end

return OilHUD