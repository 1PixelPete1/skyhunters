--!strict
-- UpgradeShop.client.luau
-- Client-side upgrade shop UI

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Wait for remotes
local upgradeRemote = ReplicatedStorage:WaitForChild("UpgradeRemote")

-- UI State
local shopOpen = false
local currentUpgrades = {}
local availableUpgrades = {}
local playerStats = {}

-- Colors by rarity/type
local TYPE_COLORS = {
	maxHearts = Color3.fromRGB(255, 100, 100),    -- Red
	bagCapacity = Color3.fromRGB(139, 90, 43),    -- Brown
	moveSpeed = Color3.fromRGB(100, 200, 255),    -- Light Blue
	recallSpeed = Color3.fromRGB(200, 100, 255),  -- Purple
	luck = Color3.fromRGB(255, 215, 0),           -- Gold
}

-- UI Elements
local screenGui: ScreenGui
local mainFrame: Frame
local upgradeList: ScrollingFrame
local statsFrame: Frame
local toggleButton: TextButton

-- Create UI
local function createShopUI()
	-- Main ScreenGui
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "UpgradeShop"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = playerGui
	
	-- Toggle Button
	toggleButton = Instance.new("TextButton")
	toggleButton.Name = "ToggleButton"
	toggleButton.Size = UDim2.new(0, 50, 0, 50)
	toggleButton.Position = UDim2.new(0, 10, 0.5, -25)
	toggleButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	toggleButton.BorderSizePixel = 2
	toggleButton.BorderColor3 = Color3.fromRGB(255, 215, 0)
	toggleButton.Text = "⚙️"
	toggleButton.TextScaled = true
	toggleButton.Parent = screenGui
	
	-- Main Shop Frame
	mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainFrame"
	mainFrame.Size = UDim2.new(0.6, 0, 0.7, 0)
	mainFrame.Position = UDim2.new(1.2, 0, 0.15, 0) -- Off-screen initially
	mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	mainFrame.BorderSizePixel = 3
	mainFrame.BorderColor3 = Color3.fromRGB(100, 100, 100)
	mainFrame.Parent = screenGui
	
	-- Title
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, 0, 0.08, 0)
	titleLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	titleLabel.BorderSizePixel = 0
	titleLabel.Font = Enum.Font.SourceSansBold
	titleLabel.Text = "UPGRADE SHOP"
	titleLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	titleLabel.TextScaled = true
	titleLabel.Parent = mainFrame
	
	-- Close Button
	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseButton"
	closeButton.Size = UDim2.new(0, 30, 0, 30)
	closeButton.Position = UDim2.new(1, -35, 0, 5)
	closeButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
	closeButton.BorderSizePixel = 0
	closeButton.Text = "X"
	closeButton.TextColor3 = Color3.new(1, 1, 1)
	closeButton.TextScaled = true
	closeButton.Parent = mainFrame
	
	-- Stats Frame
	statsFrame = Instance.new("Frame")
	statsFrame.Name = "Stats"
	statsFrame.Size = UDim2.new(0.25, 0, 0.3, 0)
	statsFrame.Position = UDim2.new(0.02, 0, 0.1, 0)
	statsFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	statsFrame.BorderSizePixel = 1
	statsFrame.BorderColor3 = Color3.fromRGB(80, 80, 80)
	statsFrame.Parent = mainFrame
	
	local statsTitle = Instance.new("TextLabel")
	statsTitle.Size = UDim2.new(1, 0, 0.2, 0)
	statsTitle.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	statsTitle.BorderSizePixel = 0
	statsTitle.Font = Enum.Font.SourceSansBold
	statsTitle.Text = "Your Stats"
	statsTitle.TextColor3 = Color3.new(1, 1, 1)
	statsTitle.TextScaled = true
	statsTitle.Parent = statsFrame
	
	local statsContent = Instance.new("Frame")
	statsContent.Name = "Content"
	statsContent.Size = UDim2.new(1, 0, 0.8, 0)
	statsContent.Position = UDim2.new(0, 0, 0.2, 0)
	statsContent.BackgroundTransparency = 1
	statsContent.Parent = statsFrame
	
	local statsLayout = Instance.new("UIListLayout")
	statsLayout.Parent = statsContent
	
	-- Currency Frame
	local currencyFrame = Instance.new("Frame")
	currencyFrame.Name = "Currency"
	currencyFrame.Size = UDim2.new(0.25, 0, 0.15, 0)
	currencyFrame.Position = UDim2.new(0.02, 0, 0.42, 0)
	currencyFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	currencyFrame.BorderSizePixel = 1
	currencyFrame.BorderColor3 = Color3.fromRGB(80, 80, 80)
	currencyFrame.Parent = mainFrame
	
	local currencyTitle = Instance.new("TextLabel")
	currencyTitle.Size = UDim2.new(1, 0, 0.3, 0)
	currencyTitle.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	currencyTitle.BorderSizePixel = 0
	currencyTitle.Font = Enum.Font.SourceSansBold
	currencyTitle.Text = "Resources"
	currencyTitle.TextColor3 = Color3.new(1, 1, 1)
	currencyTitle.TextScaled = true
	currencyTitle.Parent = currencyFrame
	
	local currencyContent = Instance.new("Frame")
	currencyContent.Name = "Content"
	currencyContent.Size = UDim2.new(1, 0, 0.7, 0)
	currencyContent.Position = UDim2.new(0, 0, 0.3, 0)
	currencyContent.BackgroundTransparency = 1
	currencyContent.Parent = currencyFrame
	
	local currencyLayout = Instance.new("UIListLayout")
	currencyLayout.Parent = currencyContent
	
	-- Upgrade List
	upgradeList = Instance.new("ScrollingFrame")
	upgradeList.Name = "UpgradeList"
	upgradeList.Size = UDim2.new(0.68, 0, 0.78, 0)
	upgradeList.Position = UDim2.new(0.3, 0, 0.1, 0)
	upgradeList.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
	upgradeList.BorderSizePixel = 2
	upgradeList.BorderColor3 = Color3.fromRGB(60, 60, 60)
	upgradeList.ScrollBarThickness = 8
	upgradeList.CanvasSize = UDim2.new(0, 0, 0, 0)
	upgradeList.Parent = mainFrame
	
	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 5)
	listLayout.Parent = upgradeList
	
	local listPadding = Instance.new("UIPadding")
	listPadding.PaddingLeft = UDim.new(0, 5)
	listPadding.PaddingRight = UDim.new(0, 5)
	listPadding.PaddingTop = UDim.new(0, 5)
	listPadding.Parent = upgradeList
	
	-- Connect events
	toggleButton.MouseButton1Click:Connect(toggleShop)
	closeButton.MouseButton1Click:Connect(function()
		if shopOpen then toggleShop() end
	end)
end

-- Create upgrade card
local function createUpgradeCard(upgrade: any): Frame
	local card = Instance.new("Frame")
	card.Name = upgrade.id
	card.Size = UDim2.new(1, -10, 0, 100)
	card.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	card.BorderSizePixel = 2
	card.BorderColor3 = TYPE_COLORS[upgrade.upgradeType] or Color3.fromRGB(100, 100, 100)
	
	-- Name
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(0.5, 0, 0.3, 0)
	nameLabel.Position = UDim2.new(0.02, 0, 0.05, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.SourceSansBold
	nameLabel.Text = upgrade.name
	nameLabel.TextColor3 = TYPE_COLORS[upgrade.upgradeType] or Color3.new(1, 1, 1)
	nameLabel.TextScaled = true
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = card
	
	-- Description
	local descLabel = Instance.new("TextLabel")
	descLabel.Size = UDim2.new(0.96, 0, 0.35, 0)
	descLabel.Position = UDim2.new(0.02, 0, 0.35, 0)
	descLabel.BackgroundTransparency = 1
	descLabel.Font = Enum.Font.SourceSans
	descLabel.Text = upgrade.description
	descLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	descLabel.TextScaled = true
	descLabel.TextWrapped = true
	descLabel.TextXAlignment = Enum.TextXAlignment.Left
	descLabel.Parent = card
	
	-- Cost
	local currentLevel = currentUpgrades[upgrade.id] or 0
	local nextLevel = currentLevel + 1
	local cost = upgrade.costPerLevel[nextLevel]
	
	if cost then
		local costLabel = Instance.new("TextLabel")
		costLabel.Size = UDim2.new(0.3, 0, 0.25, 0)
		costLabel.Position = UDim2.new(0.02, 0, 0.72, 0)
		costLabel.BackgroundTransparency = 1
		costLabel.Font = Enum.Font.SourceSansBold
		costLabel.Text = string.format("Cost: %d %s", cost, upgrade.currency == "crudeOil" and "Oil" or "Crumbs")
		costLabel.TextColor3 = upgrade.currency == "crudeOil" and Color3.fromRGB(20, 20, 20) or Color3.fromRGB(255, 215, 0)
		costLabel.TextScaled = true
		costLabel.TextXAlignment = Enum.TextXAlignment.Left
		costLabel.Parent = card
	end
	
	-- Purchase button
	local purchaseButton = Instance.new("TextButton")
	purchaseButton.Size = UDim2.new(0.25, 0, 0.35, 0)
	purchaseButton.Position = UDim2.new(0.72, 0, 0.6, 0)
	purchaseButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
	purchaseButton.BorderSizePixel = 0
	purchaseButton.Font = Enum.Font.SourceSansBold
	purchaseButton.Text = currentLevel >= upgrade.maxLevel and "MAX" or "BUY"
	purchaseButton.TextColor3 = Color3.new(1, 1, 1)
	purchaseButton.TextScaled = true
	
	-- Check affordability
	local canAfford = false
	if cost and currentLevel < upgrade.maxLevel then
		if upgrade.currency == "crudeOil" then
			canAfford = (playerStats.crudeOil or 0) >= cost
		else
			canAfford = (playerStats.crumbs or 0) >= cost
		end
	end
	
	if currentLevel >= upgrade.maxLevel then
		purchaseButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
		purchaseButton.Text = "MAX"
	elseif not canAfford then
		purchaseButton.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
		purchaseButton.Text = "LOCKED"
	end
	
	purchaseButton.Parent = card
	
	-- Connect purchase
	if canAfford and currentLevel < upgrade.maxLevel then
		purchaseButton.MouseButton1Click:Connect(function()
			local success, result = upgradeRemote:InvokeServer("Purchase", upgrade.id)
			if success then
				-- Refresh UI
				refreshShop()
				
				-- Visual feedback
				local flash = Instance.new("Frame")
				flash.Size = UDim2.new(1, 0, 1, 0)
				flash.BackgroundColor3 = Color3.fromRGB(100, 255, 100)
				flash.BackgroundTransparency = 0.5
				flash.BorderSizePixel = 0
				flash.Parent = card
				
				TweenService:Create(flash, TweenInfo.new(0.5), {
					BackgroundTransparency = 1
				}):Play()
				
				task.wait(0.5)
				flash:Destroy()
			end
		end)
	end
	
	return card
end

-- Update stats display
local function updateStats()
	local content = statsFrame:FindFirstChild("Content")
	if not content then return end
	
	-- Clear existing
	for _, child in ipairs(content:GetChildren()) do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	
	-- Add stats
	local stats = {
		{name = "Hearts", value = string.format("%d/%d", playerStats.hearts or 3, playerStats.maxHearts or 3), color = Color3.fromRGB(255, 100, 100)},
		{name = "Bag Slots", value = tostring(playerStats.bagSlots or 8), color = Color3.fromRGB(139, 90, 43)},
		{name = "Luck Bonus", value = string.format("+%.0f%%", (playerStats.luckBonus or 0) * 100), color = Color3.fromRGB(255, 215, 0)},
		{name = "Move Speed", value = string.format("x%.1f", playerStats.moveSpeedMultiplier or 1.0), color = Color3.fromRGB(100, 200, 255)},
	}
	
	for _, stat in ipairs(stats) do
		local statLabel = Instance.new("TextLabel")
		statLabel.Size = UDim2.new(1, -10, 0, 25)
		statLabel.BackgroundTransparency = 1
		statLabel.Font = Enum.Font.SourceSans
		statLabel.Text = string.format("%s: %s", stat.name, stat.value)
		statLabel.TextColor3 = stat.color
		statLabel.TextScaled = true
		statLabel.TextXAlignment = Enum.TextXAlignment.Left
		statLabel.Parent = content
	end
	
	-- Update currency
	local currencyContent = mainFrame:FindFirstChild("Currency"):FindFirstChild("Content")
	if currencyContent then
		-- Clear
		for _, child in ipairs(currencyContent:GetChildren()) do
			if child:IsA("TextLabel") then
				child:Destroy()
			end
		end
		
		-- Add currencies
		local crumbsLabel = Instance.new("TextLabel")
		crumbsLabel.Size = UDim2.new(1, -10, 0, 25)
		crumbsLabel.BackgroundTransparency = 1
		crumbsLabel.Font = Enum.Font.SourceSans
		crumbsLabel.Text = string.format("Crumbs: %d", playerStats.crumbs or 0)
		crumbsLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
		crumbsLabel.TextScaled = true
		crumbsLabel.TextXAlignment = Enum.TextXAlignment.Left
		crumbsLabel.Parent = currencyContent
		
		local oilLabel = Instance.new("TextLabel")
		oilLabel.Size = UDim2.new(1, -10, 0, 25)
		oilLabel.BackgroundTransparency = 1
		oilLabel.Font = Enum.Font.SourceSans
		oilLabel.Text = string.format("Crude Oil: %d", playerStats.crudeOil or 0)
		oilLabel.TextColor3 = Color3.fromRGB(20, 20, 20)
		oilLabel.TextScaled = true
		oilLabel.TextXAlignment = Enum.TextXAlignment.Left
		oilLabel.Parent = currencyContent
	end
end

-- Refresh shop
function refreshShop()
	-- Get current data
	currentUpgrades = upgradeRemote:InvokeServer("GetUpgrades") or {}
	availableUpgrades = upgradeRemote:InvokeServer("GetAvailable") or {}
	playerStats = upgradeRemote:InvokeServer("GetStats") or {}
	
	-- Clear upgrade list
	for _, child in ipairs(upgradeList:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	
	-- Add upgrade cards
	for _, upgrade in ipairs(availableUpgrades) do
		local card = createUpgradeCard(upgrade)
		card.Parent = upgradeList
	end
	
	-- Update canvas size
	upgradeList.CanvasSize = UDim2.new(0, 0, 0, #availableUpgrades * 105)
	
	-- Update stats
	updateStats()
end

-- Toggle shop
function toggleShop()
	shopOpen = not shopOpen
	
	if shopOpen then
		-- Refresh data
		refreshShop()
		
		-- Animate in
		mainFrame:TweenPosition(
			UDim2.new(0.2, 0, 0.15, 0),
			Enum.EasingDirection.Out,
			Enum.EasingStyle.Back,
			0.5
		)
	else
		-- Animate out
		mainFrame:TweenPosition(
			UDim2.new(1.2, 0, 0.15, 0),
			Enum.EasingDirection.In,
			Enum.EasingStyle.Back,
			0.5
		)
	end
end

-- Keyboard shortcut
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	
	if input.KeyCode == Enum.KeyCode.U then
		toggleShop()
	end
end)

-- Initialize
createShopUI()
print("[UpgradeShop] Initialized - Press U to open shop")