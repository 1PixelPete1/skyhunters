local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Wait for RemoteEvents
local aetherSnapshot = ReplicatedStorage:WaitForChild("Aether_Snapshot")

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
	
        return {
                frame = frame,
                fillBar = fillBar,
                overfillBar = overfillBar,
                targetLine = targetLine,
                currentText = currentText,
                targetText = targetText,
                rateText = rateText,
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
	
end

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

return AetherClient
