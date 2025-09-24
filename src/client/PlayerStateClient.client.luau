--!strict
-- PlayerStateClient.client.luau
-- Client-side player state management and UI

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Wait for remotes
local stateRemote = ReplicatedStorage:WaitForChild("PlayerStateRemote")
local resourceRemote = ReplicatedStorage:WaitForChild("ResourceNodeRemote", 5)

-- State variables
local currentState = "Neutral"
local hearts = 3
local maxHearts = 3
local temporaryBag = nil
local isRecalling = false
local recallStartTime = 0
local RECALL_DURATION = 4

-- UI elements
local screenGui: ScreenGui
local heartsContainer: Frame
local bagContainer: Frame
local stateLabel: TextLabel
local recallBar: Frame
local defeatScreen: Frame
local lootNotification: Frame

-- Initialize UI
local function createUI()
	-- Create ScreenGui
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "PlayerStateUI"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = playerGui
	
	-- State indicator
	stateLabel = Instance.new("TextLabel")
	stateLabel.Name = "StateLabel"
	stateLabel.Size = UDim2.new(0.2, 0, 0.05, 0)
	stateLabel.Position = UDim2.new(0.4, 0, 0, 10)
	stateLabel.BackgroundTransparency = 0.3
	stateLabel.BackgroundColor3 = Color3.new(0, 0, 0)
	stateLabel.BorderSizePixel = 0
	stateLabel.Font = Enum.Font.SourceSansBold
	stateLabel.Text = "State: Neutral"
	stateLabel.TextColor3 = Color3.new(1, 1, 1)
	stateLabel.TextScaled = true
	stateLabel.Parent = screenGui
	
    -- Hearts container (auto-sized, fully transparent)
    heartsContainer = Instance.new("Frame")
    heartsContainer.Name = "Hearts"
    heartsContainer.Size = UDim2.new(0, 0, 0, 0)
    heartsContainer.AutomaticSize = Enum.AutomaticSize.XY
    heartsContainer.Position = UDim2.new(0.02, 0, 0.02, 0)
    heartsContainer.BackgroundTransparency = 1
    heartsContainer.BorderSizePixel = 0
    heartsContainer.Parent = screenGui
	
    local heartsLayout = Instance.new("UIListLayout")
    heartsLayout.FillDirection = Enum.FillDirection.Horizontal
    heartsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    heartsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    heartsLayout.Padding = UDim.new(0, 5)
    heartsLayout.Parent = heartsContainer
	
	local heartsPadding = Instance.new("UIPadding")
	heartsPadding.PaddingLeft = UDim.new(0, 10)
	heartsPadding.PaddingTop = UDim.new(0, 10)
	heartsPadding.Parent = heartsContainer
	
	-- Bag container
	bagContainer = Instance.new("Frame")
	bagContainer.Name = "TemporaryBag"
	bagContainer.Size = UDim2.new(0.25, 0, 0.3, 0)
	bagContainer.Position = UDim2.new(0.73, 0, 0.35, 0)
	bagContainer.BackgroundTransparency = 0.3
	bagContainer.BackgroundColor3 = Color3.new(0, 0, 0)
	bagContainer.BorderSizePixel = 2
	bagContainer.BorderColor3 = Color3.new(0.7, 0.5, 0.2)
	bagContainer.Visible = false
	bagContainer.Parent = screenGui
	
	local bagTitle = Instance.new("TextLabel")
	bagTitle.Name = "Title"
	bagTitle.Size = UDim2.new(1, 0, 0.15, 0)
	bagTitle.BackgroundTransparency = 0.5
	bagTitle.BackgroundColor3 = Color3.new(0, 0, 0)
	bagTitle.Font = Enum.Font.SourceSansBold
	bagTitle.Text = "Temporary Bag"
	bagTitle.TextColor3 = Color3.new(1, 0.8, 0.4)
	bagTitle.TextScaled = true
	bagTitle.Parent = bagContainer
	
	local bagContent = Instance.new("ScrollingFrame")
	bagContent.Name = "Content"
	bagContent.Size = UDim2.new(1, 0, 0.85, 0)
	bagContent.Position = UDim2.new(0, 0, 0.15, 0)
	bagContent.BackgroundTransparency = 1
	bagContent.BorderSizePixel = 0
	bagContent.ScrollBarThickness = 4
	bagContent.Parent = bagContainer
	
	local bagLayout = Instance.new("UIListLayout")
	bagLayout.Parent = bagContent
	
	-- Recall bar
	recallBar = Instance.new("Frame")
	recallBar.Name = "RecallBar"
	recallBar.Size = UDim2.new(0.3, 0, 0.05, 0)
	recallBar.Position = UDim2.new(0.35, 0, 0.4, 0)
	recallBar.BackgroundTransparency = 0.3
	recallBar.BackgroundColor3 = Color3.new(0, 0, 0)
	recallBar.BorderSizePixel = 2
	recallBar.BorderColor3 = Color3.new(0, 0.5, 1)
	recallBar.Visible = false
	recallBar.Parent = screenGui
	
	local recallProgress = Instance.new("Frame")
	recallProgress.Name = "Progress"
	recallProgress.Size = UDim2.new(0, 0, 1, 0)
	recallProgress.BackgroundColor3 = Color3.new(0, 0.7, 1)
	recallProgress.BorderSizePixel = 0
	recallProgress.Parent = recallBar
	
	local recallText = Instance.new("TextLabel")
	recallText.Name = "Text"
	recallText.Size = UDim2.new(1, 0, 1, 0)
	recallText.BackgroundTransparency = 1
	recallText.Font = Enum.Font.SourceSansBold
	recallText.Text = "Recalling..."
	recallText.TextColor3 = Color3.new(1, 1, 1)
	recallText.TextScaled = true
	recallText.Parent = recallBar
	
	-- Defeat screen
	defeatScreen = Instance.new("Frame")
	defeatScreen.Name = "DefeatScreen"
	defeatScreen.Size = UDim2.new(1, 0, 1, 0)
	defeatScreen.BackgroundTransparency = 1
	defeatScreen.BackgroundColor3 = Color3.new(0, 0, 0)
	defeatScreen.Visible = false
	defeatScreen.Parent = screenGui
	
	local defeatText = Instance.new("TextLabel")
	defeatText.Name = "Message"
	defeatText.Size = UDim2.new(0.5, 0, 0.2, 0)
	defeatText.Position = UDim2.new(0.25, 0, 0.4, 0)
	defeatText.BackgroundTransparency = 1
	defeatText.Font = Enum.Font.SourceSansBold
	defeatText.Text = "You fell into the void..."
	defeatText.TextColor3 = Color3.new(1, 0, 0)
	defeatText.TextScaled = true
	defeatText.Parent = defeatScreen
	
	-- Loot notification
	lootNotification = Instance.new("Frame")
	lootNotification.Name = "LootNotification"
	lootNotification.Size = UDim2.new(0.3, 0, 0.15, 0)
	lootNotification.Position = UDim2.new(0.35, 0, 1.1, 0)
	lootNotification.BackgroundTransparency = 0.3
	lootNotification.BackgroundColor3 = Color3.new(0, 0, 0)
	lootNotification.BorderSizePixel = 2
	lootNotification.Parent = screenGui
	
	local lootLayout = Instance.new("UIListLayout")
	lootLayout.Parent = lootNotification
end

-- Update hearts display
local heartViews: { [number]: { frame: TextLabel, fill: TextLabel, scale: UIScale } } = {}
local heartStatus: { [number]: string } = {}

local function ensureHeartsUI(maxHeartCount: number)
    -- Build once or rebuild if max changed
    local existing = #heartViews
    if existing == maxHeartCount and heartsContainer:FindFirstChild("Heart1") then return end
    -- Clear old
    for _, child in ipairs(heartsContainer:GetChildren()) do
        if child:IsA("GuiObject") then child:Destroy() end
    end
    heartViews = {}
    heartStatus = {}
    print(string.format("[HeartsUI] ensureHeartsUI max=%d", maxHeartCount))
    -- Create slots
    for i = 1, maxHeartCount do
        local frameImg = Instance.new("TextLabel")
        frameImg.Name = "Heart" .. i
        frameImg.Size = UDim2.new(0, 30, 0, 30)
        frameImg.BackgroundTransparency = 1
        frameImg.Text = "\226\153\165" -- Unicode heart (♥)
        frameImg.TextScaled = true
        frameImg.TextColor3 = Color3.fromRGB(70, 70, 70) -- dark frame
        frameImg.Font = Enum.Font.SourceSansBold
        frameImg.Parent = heartsContainer

        local fillImg = Instance.new("TextLabel")
        fillImg.Name = "Fill"
        fillImg.AnchorPoint = Vector2.new(0.5, 0.5)
        fillImg.Position = UDim2.new(0.5, 0, 0.5, 0)
        fillImg.Size = UDim2.new(0, 24, 0, 24) -- slightly smaller to sit inside frame
        fillImg.BackgroundTransparency = 1
        fillImg.Text = "\226\153\165"
        fillImg.TextScaled = true
        fillImg.TextColor3 = Color3.new(1, 0, 0)
        fillImg.Font = Enum.Font.SourceSansBold
        fillImg.Parent = frameImg

        local scale = Instance.new("UIScale")
        scale.Scale = 1
        scale.Parent = fillImg

        heartViews[i] = { frame = frameImg, fill = fillImg, scale = scale }
        heartStatus[i] = (i <= hearts) and "alive" or "dead"
    end
end

local function setHeartsUI(currentHeartsCount: number, maxHeartCount: number)
    ensureHeartsUI(maxHeartCount)
    for i = 1, maxHeartCount do
        local v = heartViews[i]
        if v then
            if heartStatus[i] == "dying" or heartStatus[i] == "gaining" then
                v.fill.Visible = true
            elseif i <= currentHeartsCount then
                heartStatus[i] = "alive"
                v.fill.Visible = true
            else
                heartStatus[i] = "dead"
                v.fill.Visible = false
            end
        end
    end
    print(string.format("[HeartsUI] setHeartsUI hearts=%d/%d", currentHeartsCount, maxHeartCount))
end

local function animateLoseHeart(index: number, onDone: (() -> ())?)
    local v = heartViews[index]
    if not v then if onDone then onDone() end return end
    local fill = v.fill
    -- Shake + fade to white, then hide
    fill.TextColor3 = Color3.new(1, 0, 0)
    fill.TextTransparency = 0
    heartStatus[index] = "dying"
    task.spawn(function()
        local originalRotation = fill.Rotation
        local tw1 = TweenService:Create(fill, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextColor3 = Color3.new(1,1,1) })
        tw1:Play(); tw1.Completed:Wait()
        for _ = 1, 4 do
            fill.Rotation = 10; task.wait(0.04)
            fill.Rotation = -10; task.wait(0.04)
        end
        fill.Rotation = originalRotation
        local tw2 = TweenService:Create(fill, TweenInfo.new(0.15, Enum.EasingStyle.Linear), { TextTransparency = 1 })
        tw2:Play(); tw2.Completed:Wait()
        fill.Visible = false
        fill.TextTransparency = 0
        fill.TextColor3 = Color3.new(1,0,0)
        heartStatus[index] = "dead"
        if onDone then onDone() end
    end)
end

local function animateGainHeart(index: number, onDone: (() -> ())?)
    local v = heartViews[index]
    if not v then if onDone then onDone() end return end
    local fill = v.fill
    local scale = v.scale
    fill.Visible = true
    fill.TextTransparency = 1
    fill.TextColor3 = Color3.new(1,1,1)
    scale.Scale = 0.6
    heartStatus[index] = "gaining"
    task.spawn(function()
        local twA = TweenService:Create(fill, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextTransparency = 0, TextColor3 = Color3.new(1,0,0) })
        local twB = TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
        twA:Play(); twB:Play(); twA.Completed:Wait()
        heartStatus[index] = "alive"
        if onDone then onDone() end
    end)
end

local function updateHearts(currentHearts: number, maxHeartCount: number)
    setHeartsUI(currentHearts, maxHeartCount)
end

-- Update bag display
local function updateBag(bag)
	if not bag then
		bagContainer.Visible = false
		return
	end
	
	bagContainer.Visible = true
	local content = bagContainer:FindFirstChild("Content")
	if not content then return end
	
	-- Clear existing items
	for _, child in ipairs(content:GetChildren()) do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	
	-- Add crude oil
	if bag.crudeOil and bag.crudeOil > 0 then
		local oilLabel = Instance.new("TextLabel")
		oilLabel.Size = UDim2.new(1, -10, 0, 30)
		oilLabel.BackgroundTransparency = 0.5
		oilLabel.BackgroundColor3 = Color3.new(0.1, 0.1, 0.1)
		oilLabel.Font = Enum.Font.SourceSans
		oilLabel.Text = string.format("Crude Oil: %d", bag.crudeOil)
		oilLabel.TextColor3 = Color3.new(1, 1, 1)
		oilLabel.TextScaled = true
		oilLabel.Parent = content
	end
	
	-- Add items
	if bag.items then
		for itemId, count in pairs(bag.items) do
			local itemLabel = Instance.new("TextLabel")
			itemLabel.Size = UDim2.new(1, -10, 0, 30)
			itemLabel.BackgroundTransparency = 0.5
			itemLabel.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
			itemLabel.Font = Enum.Font.SourceSans
			itemLabel.Text = string.format("%s: %d", itemId, count)
			itemLabel.TextColor3 = Color3.new(1, 1, 1)
			itemLabel.TextScaled = true
			itemLabel.Parent = content
		end
	end
	
	-- Show slot usage
	local slotsLabel = Instance.new("TextLabel")
	slotsLabel.Size = UDim2.new(1, -10, 0, 30)
	slotsLabel.BackgroundTransparency = 0.3
	slotsLabel.BackgroundColor3 = Color3.new(0, 0, 0)
	slotsLabel.Font = Enum.Font.SourceSansBold
	slotsLabel.Text = string.format("Slots: %d/%d", bag.usedSlots or 0, bag.maxSlots or 8)
	slotsLabel.TextColor3 = Color3.new(1, 0.8, 0.4)
	slotsLabel.TextScaled = true
	slotsLabel.Parent = content
end

-- Show loot notification
local function showLootNotification(lootData)
	-- Clear existing
	for _, child in ipairs(lootNotification:GetChildren()) do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	
	-- Add title
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0.3, 0)
	title.BackgroundTransparency = 0.5
	title.BackgroundColor3 = Color3.new(0, 0, 0)
	title.Font = Enum.Font.SourceSansBold
	title.Text = lootData.bagFull and "Bag Full! Some items lost!" or "Items Collected!"
	title.TextColor3 = lootData.bagFull and Color3.new(1, 0.5, 0) or Color3.new(0, 1, 0)
	title.TextScaled = true
	title.Parent = lootNotification
	
	-- Add loot items
	for _, item in ipairs(lootData.loot) do
		local itemLabel = Instance.new("TextLabel")
		itemLabel.Size = UDim2.new(1, 0, 0.2, 0)
		itemLabel.BackgroundTransparency = 1
		itemLabel.Font = Enum.Font.SourceSans
		itemLabel.Text = string.format("+%d %s", item.count, item.name)
		
		-- Color by rarity
		local rarityColors = {
			Common = Color3.new(0.7, 0.7, 0.7),
			Uncommon = Color3.new(0, 1, 0),
			Rare = Color3.new(0, 0.5, 1),
			Epic = Color3.new(0.5, 0, 1),
			Legendary = Color3.new(1, 0.5, 0),
		}
		itemLabel.TextColor3 = rarityColors[item.rarity] or Color3.new(1, 1, 1)
		itemLabel.TextScaled = true
		itemLabel.Parent = lootNotification
	end
	
	-- Animate in
	lootNotification:TweenPosition(
		UDim2.new(0.35, 0, 0.8, 0),
		Enum.EasingDirection.Out,
		Enum.EasingStyle.Back,
		0.5
	)
	
	-- Fade out after delay
	task.wait(3)
	lootNotification:TweenPosition(
		UDim2.new(0.35, 0, 1.1, 0),
		Enum.EasingDirection.In,
		Enum.EasingStyle.Quad,
		0.5
	)
end

-- Show defeat screen
local function showDefeatScreen(message: string, fadeTime: number)
	defeatScreen.BackgroundTransparency = 1
	defeatScreen.Visible = true
	
	local messageLabel = defeatScreen:FindFirstChild("Message")
	if messageLabel then
		messageLabel.Text = message
	end
	
	-- Fade in
	TweenService:Create(defeatScreen, TweenInfo.new(fadeTime / 2), {
		BackgroundTransparency = 0
	}):Play()
	
	task.wait(fadeTime)
	
	-- Fade out
	TweenService:Create(defeatScreen, TweenInfo.new(fadeTime / 2), {
		BackgroundTransparency = 1
	}):Play()
	
	task.wait(fadeTime / 2)
	defeatScreen.Visible = false
end

-- Update state display
local function updateStateDisplay(state: string, metadata)
	currentState = state
	
	-- Update label
	stateLabel.Text = "State: " .. state
	
	-- Update label color based on state
	if state == "Build" then
		stateLabel.BackgroundColor3 = Color3.new(0, 0.5, 0) -- Green
		bagContainer.Visible = false
	elseif state == "Neutral" then
		stateLabel.BackgroundColor3 = Color3.new(0, 0, 0.5) -- Blue
		bagContainer.Visible = false
	elseif state == "Run" then
		stateLabel.BackgroundColor3 = Color3.new(0.5, 0, 0) -- Red
		bagContainer.Visible = true
	elseif state == "Recalling" then
		stateLabel.BackgroundColor3 = Color3.new(0, 0.5, 0.5) -- Cyan
		isRecalling = true
		recallStartTime = tick()
		recallBar.Visible = true
	end
	
	-- Hide recall bar if not recalling
	if state ~= "Recalling" then
		isRecalling = false
		recallBar.Visible = false
	end
end

-- Handle remote events
stateRemote.OnClientEvent:Connect(function(eventType, data)
    if eventType == "StateChanged" then
        updateStateDisplay(data.state, data.metadata)
        
    elseif eventType == "HeartsChanged" then
        print("[HeartsUI] HeartsChanged", data.hearts, data.maxHearts)
        local newHearts = data.hearts
        local newMax = data.maxHearts
        ensureHeartsUI(newMax)
        if newHearts < hearts then
            local delta = hearts - newHearts
            hearts = newHearts; maxHearts = newMax -- apply logical state immediately
            for _ = 1, delta do
                local idx = -1
                for i = maxHearts, 1, -1 do
                    if heartStatus[i] == "alive" then idx = i; break end
                end
                if idx ~= -1 then
                    print("[HeartsUI] animating lose at index", idx)
                    animateLoseHeart(idx, function()
                        setHeartsUI(hearts, maxHearts)
                    end)
                end
            end
            setHeartsUI(hearts, maxHearts)
        elseif newHearts > hearts then
            local delta = newHearts - hearts
            hearts = newHearts; maxHearts = newMax -- apply logical state immediately
            for _ = 1, delta do
                local idx = -1
                for i = 1, maxHearts do
                    if heartStatus[i] == "dead" then idx = i; break end
                end
                if idx ~= -1 then
                    animateGainHeart(idx, function()
                        setHeartsUI(hearts, maxHearts)
                    end)
                end
            end
            setHeartsUI(hearts, maxHearts)
        else
            hearts = newHearts; maxHearts = newMax
            setHeartsUI(hearts, maxHearts)
        end
        
    elseif eventType == "BagUpdated" then
        temporaryBag = data
        updateBag(temporaryBag)
        
    elseif eventType == "ShowDefeat" then
        task.spawn(function()
            showDefeatScreen(data.message, data.fadeTime)
        end)
    end
end)

-- Handle resource events
if resourceRemote then
	resourceRemote.OnClientEvent:Connect(function(eventType, data)
		if eventType == "HarvestComplete" then
			showLootNotification(data)
		end
	end)
end

-- Handle recall input
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	
  if input.KeyCode == Enum.KeyCode.B then
    -- Request recall (server decides instant vs channel)
    stateRemote:FireServer("StartRecall")
  end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	
	if input.KeyCode == Enum.KeyCode.B and isRecalling then
		-- Cancel recall
		stateRemote:FireServer("CancelRecall")
	end
end)

-- Update recall bar
RunService.RenderStepped:Connect(function()
	if isRecalling and recallBar.Visible then
		local elapsed = tick() - recallStartTime
		local progress = math.clamp(elapsed / RECALL_DURATION, 0, 1)
		
		local progressBar = recallBar:FindFirstChild("Progress")
		if progressBar then
			progressBar.Size = UDim2.new(progress, 0, 1, 0)
		end
	end
end)

-- Initialize
createUI()
print("[HeartsUI] init hearts=", hearts, "max=", maxHearts)
ensureHeartsUI(maxHearts)
setHeartsUI(hearts, maxHearts)
updateStateDisplay(currentState, nil)

print("[PlayerStateClient] Initialized")
