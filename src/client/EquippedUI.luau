local Players = game:GetService("Players")

local player = Players.LocalPlayer

local EquippedUI = {}

local screenGui: ScreenGui? = nil
local frame: Frame? = nil
local iconImage: ImageLabel? = nil
local nameLabel: TextLabel? = nil
local countLabel: TextLabel? = nil

local function ensureGui()
    if frame then
        return
    end
    local playerGui = player:WaitForChild("PlayerGui")
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "EquippedUI"
    screenGui.Parent = playerGui

    frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 160, 0, 50)
    frame.Position = UDim2.new(0.5, -80, 1, -60)
    frame.AnchorPoint = Vector2.new(0.5, 1)
    frame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    frame.BackgroundTransparency = 0.3
    frame.Visible = false
    frame.Parent = screenGui

    iconImage = Instance.new("ImageLabel")
    iconImage.Size = UDim2.new(0, 50, 0, 50)
    iconImage.BackgroundTransparency = 1
    iconImage.Parent = frame

    nameLabel = Instance.new("TextLabel")
    nameLabel.Position = UDim2.new(0, 55, 0, 0)
    nameLabel.Size = UDim2.new(1, -55, 0.5, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.TextColor3 = Color3.new(1, 1, 1)
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Font = Enum.Font.SourceSans
    nameLabel.TextSize = 18
    nameLabel.Parent = frame

    countLabel = Instance.new("TextLabel")
    countLabel.Position = UDim2.new(0, 55, 0.5, 0)
    countLabel.Size = UDim2.new(1, -55, 0.5, 0)
    countLabel.BackgroundTransparency = 1
    countLabel.TextColor3 = Color3.new(1, 1, 1)
    countLabel.TextXAlignment = Enum.TextXAlignment.Left
    countLabel.Font = Enum.Font.SourceSans
    countLabel.TextSize = 18
    countLabel.Parent = frame
end

function EquippedUI.Show(icon: string, name: string, count: number)
    ensureGui()
    if iconImage then
        iconImage.Image = icon
    end
    if nameLabel then
        nameLabel.Text = name
    end
    if countLabel then
        countLabel.Text = tostring(count)
    end
    if frame then
        frame.Visible = true
    end
end

function EquippedUI.Update(count: number)
    if countLabel then
        countLabel.Text = tostring(count)
    end
end

function EquippedUI.Hide()
    if frame then
        frame.Visible = false
    end
end

return EquippedUI
