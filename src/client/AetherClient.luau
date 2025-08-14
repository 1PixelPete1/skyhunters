local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Wait for RemoteEvents
local aetherSnapshot = ReplicatedStorage:WaitForChild("Aether_Snapshot")
local aetherRequestSell = ReplicatedStorage:WaitForChild("Aether_RequestSell")

local AetherClient = {}

-- Local state management
local aetherState = {
	current = 0,
	target = 20,
        totalRate = 0,
        decayRate = 0.08,
        purityBase = 0.55,
        lastUpdateTime = time(),
        serverSynced = false
}

local function clamp(value, min, max)
	if value < min then
		return min
	end
	if value > max then
		return max
	end
	return value
end

-- Client-side settle math (mirrors server logic)
local function settleAether(dt)
	if dt <= 0 then
		return
	end
	
	local current = aetherState.current
	
	if current >= aetherState.target then
		local excess = current - aetherState.target
		local decayed = excess * math.exp(-aetherState.decayRate * dt)
		current = aetherState.target + decayed
	else
		current = math.min(aetherState.target, current + aetherState.totalRate * dt)
	end
	
        aetherState.current = current
        aetherState.lastUpdateTime = time()
end

-- Calculate projected crumbs
local function getProjectedCrumbs()
	local purity = clamp(aetherState.purityBase, 0.10, 1.00)
	return math.floor(aetherState.current * purity * 8)
end

-- UI Creation
local function createAetherGauge()
	-- Wait for the canister to be created by server
	local workspace = game:GetService("Workspace")
	local canister = workspace:WaitForChild("AetherCanister")
	local surfaceGui = canister:WaitForChild("AetherGauge")
	
	-- Main frame
	local frame = Instance.new("Frame")
	frame.Name = "GaugeFrame"
	frame.Size = UDim2.new(1, 0, 1, 0)
	frame.Position = UDim2.new(0, 0, 0, 0)
	frame.BackgroundColor3 = Color3.new(0.1, 0.1, 0.1)
	frame.BorderSizePixel = 2
	frame.BorderColor3 = Color3.new(0.3, 0.3, 0.3)
	frame.Parent = surfaceGui
	
	-- Title
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 20)
	title.BackgroundTransparency = 1
	title.Text = "AETHER GAUGE"
	title.TextColor3 = Color3.new(0.8, 0.9, 1)
	title.Font = Enum.Font.SourceSansBold
	title.TextSize = 12
	title.Parent = frame
	
	-- Gauge background
	local gaugeBack = Instance.new("Frame")
	gaugeBack.Name = "GaugeBackground"
	gaugeBack.Size = UDim2.new(1, -20, 0, 20)
	gaugeBack.Position = UDim2.new(0, 10, 0, 25)
	gaugeBack.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
	gaugeBack.BorderSizePixel = 1
	gaugeBack.BorderColor3 = Color3.new(0.4, 0.4, 0.4)
	gaugeBack.Parent = frame
	
	-- Current aether fill bar
	local fillBar = Instance.new("Frame")
	fillBar.Name = "FillBar"
	fillBar.Size = UDim2.new(0, 0, 1, -2)
	fillBar.Position = UDim2.new(0, 1, 0, 1)
	fillBar.BackgroundColor3 = Color3.new(0.3, 0.7, 1)
	fillBar.BorderSizePixel = 0
	fillBar.Parent = gaugeBack
	
	-- Overfill indicator
	local overfillBar = Instance.new("Frame")
	overfillBar.Name = "OverfillBar"
	overfillBar.Size = UDim2.new(0, 0, 1, -2)
	overfillBar.Position = UDim2.new(1, 0, 0, 1)
	overfillBar.BackgroundColor3 = Color3.new(1, 0.5, 0)
	overfillBar.BorderSizePixel = 0
	overfillBar.Parent = gaugeBack
	
	-- Target line indicator
	local targetLine = Instance.new("Frame")
	targetLine.Name = "TargetLine"
	targetLine.Size = UDim2.new(0, 2, 1, 0)
	targetLine.Position = UDim2.new(1, 0, 0, 0)
	targetLine.BackgroundColor3 = Color3.new(1, 1, 0)
	targetLine.BorderSizePixel = 0
	targetLine.Parent = gaugeBack
	
	-- Current/Target text
	local currentText = Instance.new("TextLabel")
	currentText.Name = "CurrentText"
	currentText.Size = UDim2.new(1, 0, 0, 15)
	currentText.Position = UDim2.new(0, 10, 0, 50)
	currentText.BackgroundTransparency = 1
	currentText.Text = "Current: 0.0"
	currentText.TextColor3 = Color3.new(1, 1, 1)
	currentText.Font = Enum.Font.SourceSans
	currentText.TextSize = 11
	currentText.TextXAlignment = Enum.TextXAlignment.Left
	currentText.Parent = frame
	
	local targetText = Instance.new("TextLabel")
	targetText.Name = "TargetText"
	targetText.Size = UDim2.new(1, 0, 0, 15)
	targetText.Position = UDim2.new(0, 10, 0, 65)
	targetText.BackgroundTransparency = 1
	targetText.Text = "Target: 20.0"
	targetText.TextColor3 = Color3.new(1, 1, 1)
	targetText.Font = Enum.Font.SourceSans
	targetText.TextSize = 11
	targetText.TextXAlignment = Enum.TextXAlignment.Left
	targetText.Parent = frame
	
	-- Rate display
	local rateText = Instance.new("TextLabel")
	rateText.Name = "RateText"
	rateText.Size = UDim2.new(1, 0, 0, 15)
	rateText.Position = UDim2.new(0, 10, 0, 80)
	rateText.BackgroundTransparency = 1
	rateText.Text = "Rate: 0.0/s"
	rateText.TextColor3 = Color3.new(0.8, 0.8, 0.8)
	rateText.Font = Enum.Font.SourceSans
	rateText.TextSize = 10
	rateText.TextXAlignment = Enum.TextXAlignment.Left
	rateText.Parent = frame
	
	-- Sell button
	local sellButton = Instance.new("TextButton")
	sellButton.Name = "SellButton"
	sellButton.Size = UDim2.new(0, 60, 0, 20)
	sellButton.Position = UDim2.new(1, -70, 0, 95)
	sellButton.BackgroundColor3 = Color3.new(0.2, 0.6, 0.2)
	sellButton.Text = "SELL"
	sellButton.TextColor3 = Color3.new(1, 1, 1)
	sellButton.Font = Enum.Font.SourceSansBold
	sellButton.TextSize = 10
	sellButton.Parent = frame
	
	-- Tooltip frame (initially hidden)
	local tooltip = Instance.new("Frame")
	tooltip.Name = "Tooltip"
	tooltip.Size = UDim2.new(0, 100, 0, 25)
	tooltip.Position = UDim2.new(0, -105, 0, 95)
	tooltip.BackgroundColor3 = Color3.new(0, 0, 0)
	tooltip.BackgroundTransparency = 0.2
	tooltip.BorderSizePixel = 1
	tooltip.BorderColor3 = Color3.new(0.5, 0.5, 0.5)
	tooltip.Visible = false
	tooltip.Parent = sellButton
	
	local tooltipText = Instance.new("TextLabel")
	tooltipText.Name = "Text"
	tooltipText.Size = UDim2.new(1, 0, 1, 0)
	tooltipText.BackgroundTransparency = 1
	tooltipText.Text = "₡0"
	tooltipText.TextColor3 = Color3.new(1, 1, 1)
	tooltipText.Font = Enum.Font.SourceSans
	tooltipText.TextSize = 10
	tooltipText.Parent = tooltip
	
	return {
		frame = frame,
		fillBar = fillBar,
		overfillBar = overfillBar,
		targetLine = targetLine,
		currentText = currentText,
		targetText = targetText,
		rateText = rateText,
		sellButton = sellButton,
		tooltip = tooltip,
		tooltipText = tooltipText
	}
end

local ui = createAetherGauge()

-- Update UI display
local function updateUI()
	local current = aetherState.current
	local target = aetherState.target
	local rate = aetherState.totalRate
	
	-- Update text displays
	ui.currentText.Text = string.format("Current: %.1f", current)
	ui.targetText.Text = string.format("Target: %.1f", target)
	ui.rateText.Text = string.format("Rate: %.1f/s", rate)
	
	-- Update fill bars
	local fillRatio = math.min(current / target, 1)
	ui.fillBar.Size = UDim2.new(fillRatio, 0, 1, -2)
	
	-- Handle overfill
	if current > target then
		local overfillRatio = math.min((current - target) / target, 1)
		ui.overfillBar.Size = UDim2.new(overfillRatio, 0, 1, -2)
		ui.overfillBar.Visible = true
		ui.fillBar.BackgroundColor3 = Color3.new(0.5, 0.8, 1) -- Lighter blue when overfilled
	else
		ui.overfillBar.Visible = false
		ui.fillBar.BackgroundColor3 = Color3.new(0.3, 0.7, 1) -- Normal blue
	end
	
	-- Update tooltip with projected crumbs
	local projectedCrumbs = getProjectedCrumbs()
	ui.tooltipText.Text = "₡" .. projectedCrumbs
end

-- Tooltip hover events
ui.sellButton.MouseEnter:Connect(function()
	ui.tooltip.Visible = true
end)

ui.sellButton.MouseLeave:Connect(function()
	ui.tooltip.Visible = false
end)

-- Sell button functionality
ui.sellButton.MouseButton1Click:Connect(function()
	local success, gain = pcall(function()
		return aetherRequestSell:InvokeServer()
	end)
	
	if success and gain > 0 then
		print("Sold aether for", gain, "crumbs")
		aetherState.current = 0 -- Immediately update local state
		updateUI()
	else
		print("Failed to sell aether")
	end
end)

-- Handle server snapshots
aetherSnapshot.OnClientEvent:Connect(function(payload)
        local serverData = payload.aether or payload
        print("Received aether snapshot:", serverData.current, "/", serverData.target, "rate:", serverData.totalRate)
        aetherState.current = serverData.current
        aetherState.target = serverData.target
        aetherState.totalRate = serverData.totalRate
        aetherState.decayRate = serverData.decayRate
        aetherState.purityBase = serverData.purityBase
        aetherState.lastUpdateTime = serverData.serverNow
        aetherState.serverSynced = true

        updateUI()
end)

-- Main update loop for client-side prediction
local function onHeartbeat()
	if not aetherState.serverSynced then
		return
	end
	
        local now = time()
	local dt = now - aetherState.lastUpdateTime
	
	if dt > 0.01 then -- Update at most 100 times per second
		settleAether(dt)
		updateUI()
	end
end

RunService.Heartbeat:Connect(onHeartbeat)

AetherClient.GetCurrentAether = function()
	return aetherState.current
end

AetherClient.GetProjectedCrumbs = function()
	return getProjectedCrumbs()
end

return AetherClient
