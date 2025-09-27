--!strict
-- LanternDesigner.client.luau (FIXED - Remote spawn, no per-param dice)
-- Studio-only designer UI for authoring lantern presets

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Only run in Studio
if not RunService:IsStudio() then
	return
end

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FeatureFlags = require(Shared:WaitForChild("FeatureFlags"))
local Types = require(Shared:WaitForChild("LanternTypes"))
local Archetypes = require(Shared:WaitForChild("LanternArchetypes"))

-- Check if designer is enabled
if not FeatureFlags.get("Lanterns.DesignerEnabled") then
	return
end

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Create RemoteEvent for spawning (if not exists)
local spawnRemote = ReplicatedStorage:FindFirstChild("SpawnDesignerLantern")
if not spawnRemote then
	spawnRemote = Instance.new("RemoteEvent")
	spawnRemote.Name = "SpawnDesignerLantern"
	spawnRemote.Parent = ReplicatedStorage
end

-- FIXED: Designer state (removed per-param RNG, using seed-based only)
local designerState = {
	mode = "lamp",
	visible = false,
	currentArchetype = nil :: Types.DesignerArchetype?,
	sessionBranches = {},
	sessionLamps = {},
	selectedStyle = "straight",
	selectedArchetype = "CommonA",
	currentSeed = math.random(1, 1000000),  -- Global seed for entire lantern
	paramValues = {} :: {[string]: number},  -- Current param values
	paramLocked = {} :: {[string]: boolean}, -- Lock state
	previewModel = nil,
	activeDropdown = nil,
}

-- FIXED: Style-specific param visibility rules
local STYLE_PARAM_VISIBILITY = {
	straight = {},
	scurve = {"bend_deg"},
	planar_spiral = {"twist_deg", "bend_deg"},
	helix = {"twist_deg"}
}

-- Create session storage folder
local function ensureSessionFolder()
	local folder = workspace:FindFirstChild("__LanternDesignerSession")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "__LanternDesignerSession"
		folder.Parent = workspace
		
		local branches = Instance.new("Folder")
		branches.Name = "Branches"
		branches.Parent = folder
		
		local lamps = Instance.new("Folder")
		lamps.Name = "Lamps"
		lamps.Parent = folder
	end
	return folder
end

-- Save lamp to session
local function saveLampToSession(archetype: Types.DesignerArchetype)
	local sessionFolder = ensureSessionFolder()
	local lampsFolder = sessionFolder:FindFirstChild("Lamps")
	
	local count = #lampsFolder:GetChildren() + 1
	local stringValue = Instance.new("StringValue")
	stringValue.Name = "Lamp_" .. count
	stringValue.Value = HttpService:JSONEncode(archetype)
	stringValue.Parent = lampsFolder
	
	table.insert(designerState.sessionLamps, archetype)
	print("✅ Saved lamp archetype (Designer format)")
end

-- Load session data
local function loadSession()
	local sessionFolder = workspace:FindFirstChild("__LanternDesignerSession")
	if not sessionFolder then
		return
	end
	
	local branchesFolder = sessionFolder:FindFirstChild("Branches")
	if branchesFolder then
		for _, stringValue in ipairs(branchesFolder:GetChildren()) do
			if stringValue:IsA("StringValue") then
				local success, branch = pcall(function()
					return HttpService:JSONDecode(stringValue.Value)
				end)
				if success then
					table.insert(designerState.sessionBranches, branch)
				end
			end
		end
	end
	
	local lampsFolder = sessionFolder:FindFirstChild("Lamps")
	if lampsFolder then
		for _, stringValue in ipairs(lampsFolder:GetChildren()) do
			if stringValue:IsA("StringValue") then
				local success, lamp = pcall(function()
					return HttpService:JSONDecode(stringValue.Value)
				end)
				if success then
					table.insert(designerState.sessionLamps, lamp)
				end
			end
		end
	end
	
	print("Loaded session:", #designerState.sessionBranches, "branches,", #designerState.sessionLamps, "lamps")
end

-- FIXED: Check if param should be visible for current style
local function isParamVisible(paramName: string): boolean
	local visibleParams = STYLE_PARAM_VISIBILITY[designerState.selectedStyle]
	if not visibleParams then
		return true
	end
	
	if #visibleParams == 0 then
		return true
	end
	
	for _, visibleParam in ipairs(visibleParams) do
		if visibleParam == paramName then
			return true
		end
	end
	
	local alwaysVisible = {"height", "arm_len", "head_scale", "base_scale", "paint_wear", "lantern_tilt", "lantern_yaw"}
	for _, name in ipairs(alwaysVisible) do
		if name == paramName then
			return true
		end
	end
	
	return false
end

-- Create the main UI
local function createDesignerUI()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "LanternDesigner"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 10
	
	-- Main frame
	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainFrame"
	mainFrame.Size = UDim2.new(0, 450, 0, 700)
	mainFrame.Position = UDim2.new(1, -470, 0.5, -350)
	mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	mainFrame.BorderSizePixel = 0
	mainFrame.Parent = screenGui
	
	-- Title bar
	local titleBar = Instance.new("Frame")
	titleBar.Name = "TitleBar"
	titleBar.Size = UDim2.new(1, 0, 0, 35)
	titleBar.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	titleBar.BorderSizePixel = 0
	titleBar.Parent = mainFrame
	
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, -35, 1, 0)
	titleLabel.Position = UDim2.new(0, 5, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "🏮 Lantern Designer"
	titleLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	titleLabel.TextSize = 18
	titleLabel.Font = Enum.Font.SourceSansBold
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = titleBar
	
	-- Close button
	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseButton"
	closeButton.Size = UDim2.new(0, 35, 1, 0)
	closeButton.Position = UDim2.new(1, -35, 0, 0)
	closeButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
	closeButton.Text = "✕"
	closeButton.TextColor3 = Color3.new(1, 1, 1)
	closeButton.TextSize = 20
	closeButton.Font = Enum.Font.SourceSansBold
	closeButton.Parent = titleBar
	
	-- Content area with scroll
	local contentFrame = Instance.new("ScrollingFrame")
	contentFrame.Name = "Content"
	contentFrame.Size = UDim2.new(1, -10, 1, -85)
	contentFrame.Position = UDim2.new(0, 5, 0, 40)
	contentFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
	contentFrame.BorderSizePixel = 0
	contentFrame.ScrollBarThickness = 8
	contentFrame.CanvasSize = UDim2.new(0, 0, 3, 0)
	contentFrame.Parent = mainFrame
	
	-- Add list layout
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 8)
	layout.Parent = contentFrame
	
	-- Bottom buttons
	local buttonFrame = Instance.new("Frame")
	buttonFrame.Name = "Buttons"
	buttonFrame.Size = UDim2.new(1, -10, 0, 40)
	buttonFrame.Position = UDim2.new(0, 5, 1, -45)
	buttonFrame.BackgroundTransparency = 1
	buttonFrame.Parent = mainFrame
	
	-- FIXED: Reroll All button (generates new seed)
	local rerollButton = Instance.new("TextButton")
	rerollButton.Name = "RerollButton"
	rerollButton.Size = UDim2.new(0.25, -3, 1, 0)
	rerollButton.Position = UDim2.new(0, 0, 0, 0)
	rerollButton.BackgroundColor3 = Color3.fromRGB(100, 150, 200)
	rerollButton.Text = "🎲 Reroll"
	rerollButton.TextColor3 = Color3.new(1, 1, 1)
	rerollButton.TextSize = 16
	rerollButton.Font = Enum.Font.SourceSansBold
	rerollButton.Parent = buttonFrame
	
	local previewButton = Instance.new("TextButton")
	previewButton.Name = "PreviewButton"
	previewButton.Size = UDim2.new(0.25, -3, 1, 0)
	previewButton.Position = UDim2.new(0.25, 0, 0, 0)
	previewButton.BackgroundColor3 = Color3.fromRGB(50, 100, 200)
	previewButton.Text = "👁 Preview"
	previewButton.TextColor3 = Color3.new(1, 1, 1)
	previewButton.TextSize = 16
	previewButton.Font = Enum.Font.SourceSansBold
	previewButton.Parent = buttonFrame
	
	local spawnButton = Instance.new("TextButton")
	spawnButton.Name = "SpawnButton"
	spawnButton.Size = UDim2.new(0.25, -3, 1, 0)
	spawnButton.Position = UDim2.new(0.5, 0, 0, 0)
	spawnButton.BackgroundColor3 = Color3.fromRGB(200, 80, 50)
	spawnButton.Text = "🚀 Spawn"
	spawnButton.TextColor3 = Color3.new(1, 1, 1)
	spawnButton.TextSize = 16
	spawnButton.Font = Enum.Font.SourceSansBold
	spawnButton.Parent = buttonFrame
	
	local saveButton = Instance.new("TextButton")
	saveButton.Name = "SaveButton"
	saveButton.Size = UDim2.new(0.25, -3, 1, 0)
	saveButton.Position = UDim2.new(0.75, 0, 0, 0)
	saveButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
	saveButton.Text = "💾 Save"
	saveButton.TextColor3 = Color3.new(1, 1, 1)
	saveButton.TextSize = 16
	saveButton.Font = Enum.Font.SourceSansBold
	saveButton.Parent = buttonFrame
	
	-- FIXED: Reroll button - generates new seed
	rerollButton.MouseButton1Click:Connect(function()
		designerState.currentSeed = math.random(1, 1000000)
		print("🎲 New seed:", designerState.currentSeed)
		-- Update UI to show new seed
		local seedLabel = contentFrame:FindFirstChild("SeedDisplay", true)
		if seedLabel and seedLabel:IsA("TextLabel") then
			seedLabel.Text = "Seed: " .. designerState.currentSeed
		end
	end)
	
	-- FIXED: Preview button - use RemoteEvent
	previewButton.MouseButton1Click:Connect(function()
		if designerState.previewModel then
			designerState.previewModel:Destroy()
			designerState.previewModel = nil
			previewButton.Text = "👁 Preview"
		else
			local character = player.Character
			if character and character:FindFirstChild("HumanoidRootPart") then
				local previewPos = character.HumanoidRootPart.Position + character.HumanoidRootPart.CFrame.LookVector * 8
				
				-- Fire remote to server
				spawnRemote:FireServer("preview", previewPos, designerState.selectedArchetype, designerState.currentSeed)
				previewButton.Text = "⏳ Loading..."
				
				-- Wait for lantern to appear
				task.wait(0.5)
				local lantern = workspace:FindFirstChild("DynamicLantern")
				if lantern and lantern:GetAttribute("IsPreview") then
					designerState.previewModel = lantern
					previewButton.Text = "❌ Clear"
				else
					previewButton.Text = "👁 Preview"
				end
			end
		end
	end)
	
	-- FIXED: Spawn button - use RemoteEvent
	spawnButton.MouseButton1Click:Connect(function()
		local character = player.Character
		if character and character:FindFirstChild("HumanoidRootPart") then
			local spawnPos = character.HumanoidRootPart.Position + Vector3.new(5, 0, 5)
			
			-- Fire remote to server
			spawnRemote:FireServer("spawn", spawnPos, designerState.selectedArchetype, designerState.currentSeed)
			print("✅ Spawn requested at", spawnPos, "with seed", designerState.currentSeed)
		end
	end)
	
	-- Save button
	saveButton.MouseButton1Click:Connect(function()
		if designerState.currentArchetype then
			saveLampToSession(designerState.currentArchetype)
		else
			warn("No archetype to save!")
		end
	end)
	
	-- Close button
	closeButton.MouseButton1Click:Connect(function()
		designerState.visible = false
		screenGui.Enabled = false
	end)
	
	-- Initial content
	updateContent(contentFrame)
	
	screenGui.Parent = playerGui
	return screenGui
end

-- FIXED: Create real dropdown
function createRealDropdown(parent: Instance, label: string, options: {string}, defaultValue: string, order: number, callback: (string) -> ()): Frame
	local frame = Instance.new("Frame")
	frame.Name = "Dropdown_" .. label
	frame.Size = UDim2.new(1, -10, 0, 35)
	frame.BackgroundTransparency = 1
	frame.LayoutOrder = order
	frame.Parent = parent
	
	local labelObj = Instance.new("TextLabel")
	labelObj.Size = UDim2.new(0.35, 0, 1, 0)
	labelObj.BackgroundTransparency = 1
	labelObj.Text = label
	labelObj.TextColor3 = Color3.fromRGB(200, 200, 200)
	labelObj.TextSize = 14
	labelObj.TextXAlignment = Enum.TextXAlignment.Left
	labelObj.Font = Enum.Font.SourceSans
	labelObj.Parent = frame
	
	local dropdown = Instance.new("TextButton")
	dropdown.Name = "Button"
	dropdown.Size = UDim2.new(0.65, -10, 1, -4)
	dropdown.Position = UDim2.new(0.35, 5, 0, 2)
	dropdown.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
	dropdown.BorderSizePixel = 0
	dropdown.Text = defaultValue .. " ▼"
	dropdown.TextColor3 = Color3.new(1, 1, 1)
	dropdown.TextSize = 14
	dropdown.Font = Enum.Font.SourceSans
	dropdown.Parent = frame
	
	local menu = Instance.new("Frame")
	menu.Name = "Menu"
	menu.Size = UDim2.new(0.65, -10, 0, #options * 30)
	menu.Position = UDim2.new(0.35, 5, 1, 2)
	menu.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
	menu.BorderSizePixel = 1
	menu.BorderColor3 = Color3.fromRGB(80, 80, 80)
	menu.Visible = false
	menu.ZIndex = 10
	menu.Parent = frame
	
	local menuLayout = Instance.new("UIListLayout")
	menuLayout.SortOrder = Enum.SortOrder.LayoutOrder
	menuLayout.Parent = menu
	
	for i, option in ipairs(options) do
		local optionButton = Instance.new("TextButton")
		optionButton.Name = "Option_" .. option
		optionButton.Size = UDim2.new(1, 0, 0, 30)
		optionButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
		optionButton.BorderSizePixel = 0
		optionButton.Text = option
		optionButton.TextColor3 = Color3.new(1, 1, 1)
		optionButton.TextSize = 13
		optionButton.Font = Enum.Font.SourceSans
		optionButton.LayoutOrder = i
		optionButton.ZIndex = 11
		optionButton.Parent = menu
		
		optionButton.MouseEnter:Connect(function()
			optionButton.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
		end)
		
		optionButton.MouseLeave:Connect(function()
			optionButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
		end)
		
		optionButton.MouseButton1Click:Connect(function()
			dropdown.Text = option .. " ▼"
			menu.Visible = false
			callback(option)
		end)
	end
	
	dropdown.MouseButton1Click:Connect(function()
		menu.Visible = not menu.Visible
		if menu.Visible and designerState.activeDropdown and designerState.activeDropdown ~= menu then
			designerState.activeDropdown.Visible = false
		end
		designerState.activeDropdown = menu.Visible and menu or nil
	end)
	
	return frame
end

-- FIXED: Create param control (no per-param dice, just lock and slider)
function createParamControl(parent: Instance, paramName: string, label: string, min: number, max: number, default: number, order: number): Frame
	local frame = Instance.new("Frame")
	frame.Name = "Param_" .. paramName
	frame.Size = UDim2.new(1, -10, 0, 50)
	frame.BackgroundTransparency = 1
	frame.LayoutOrder = order
	frame.Parent = parent
	
	if not isParamVisible(paramName) then
		frame.Visible = false
	end
	
	-- Initialize value
	designerState.paramValues[paramName] = default
	
	-- Top row: label, value, lock
	local topRow = Instance.new("Frame")
	topRow.Size = UDim2.new(1, 0, 0, 25)
	topRow.BackgroundTransparency = 1
	topRow.Parent = frame
	
	local labelObj = Instance.new("TextLabel")
	labelObj.Size = UDim2.new(0.6, 0, 1, 0)
	labelObj.BackgroundTransparency = 1
	labelObj.Text = label
	labelObj.TextColor3 = Color3.fromRGB(200, 200, 200)
	labelObj.TextSize = 14
	labelObj.TextXAlignment = Enum.TextXAlignment.Left
	labelObj.Font = Enum.Font.SourceSans
	labelObj.Parent = topRow
	
	local valueLabel = Instance.new("TextLabel")
	valueLabel.Name = "Value"
	valueLabel.Size = UDim2.new(0.25, 0, 1, 0)
	valueLabel.Position = UDim2.new(0.6, 0, 0, 0)
	valueLabel.BackgroundTransparency = 1
	valueLabel.Text = string.format("%.2f", default)
	valueLabel.TextColor3 = Color3.new(1, 1, 1)
	valueLabel.TextSize = 14
	valueLabel.Font = Enum.Font.SourceSansBold
	valueLabel.Parent = topRow
	
	-- Lock button
	local lockButton = Instance.new("TextButton")
	lockButton.Name = "Lock"
	lockButton.Size = UDim2.new(0, 25, 0, 25)
	lockButton.Position = UDim2.new(0.88, 0, 0, 0)
	lockButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	lockButton.BorderSizePixel = 0
	lockButton.Text = "🔓"
	lockButton.TextSize = 16
	lockButton.Parent = topRow
	
	-- Slider
	local sliderRow = Instance.new("Frame")
	sliderRow.Size = UDim2.new(1, 0, 0, 20)
	sliderRow.Position = UDim2.new(0, 0, 0, 28)
	sliderRow.BackgroundTransparency = 1
	sliderRow.Parent = frame
	
	local sliderBack = Instance.new("Frame")
	sliderBack.Size = UDim2.new(1, -5, 0, 6)
	sliderBack.Position = UDim2.new(0, 0, 0.5, -3)
	sliderBack.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	sliderBack.BorderSizePixel = 0
	sliderBack.Parent = sliderRow
	
	local sliderButton = Instance.new("TextButton")
	sliderButton.Size = UDim2.new(0, 18, 0, 18)
	sliderButton.Position = UDim2.new((default - min) / (max - min), -9, 0.5, -9)
	sliderButton.BackgroundColor3 = Color3.fromRGB(100, 150, 200)
	sliderButton.BorderSizePixel = 0
	sliderButton.Text = ""
	sliderButton.Parent = sliderBack
	
	-- Slider dragging
	local dragging = false
	sliderButton.MouseButton1Down:Connect(function()
		dragging = true
	end)
	
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end)
	
	UserInputService.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			local mouse = UserInputService:GetMouseLocation()
			local relativeX = mouse.X - sliderBack.AbsolutePosition.X
			local percent = math.clamp(relativeX / sliderBack.AbsoluteSize.X, 0, 1)
			
			sliderButton.Position = UDim2.new(percent, -9, 0.5, -9)
			
			local value = min + (max - min) * percent
			valueLabel.Text = string.format("%.2f", value)
			designerState.paramValues[paramName] = value
		end
	end)
	
	-- Lock button
	lockButton.MouseButton1Click:Connect(function()
		designerState.paramLocked[paramName] = not designerState.paramLocked[paramName]
		lockButton.Text = designerState.paramLocked[paramName] and "🔒" or "🔓"
		lockButton.BackgroundColor3 = designerState.paramLocked[paramName] and Color3.fromRGB(100, 60, 60) or Color3.fromRGB(60, 60, 60)
	end)
	
	return frame
end

-- Update content based on mode
function updateContent(contentFrame: ScrollingFrame)
	for _, child in ipairs(contentFrame:GetChildren()) do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
	
	createLampControls(contentFrame)
end

-- Create lamp mode controls (FIXED)
function createLampControls(parent: ScrollingFrame)
	-- Seed display
	local seedFrame = Instance.new("Frame")
	seedFrame.Size = UDim2.new(1, -10, 0, 30)
	seedFrame.BackgroundTransparency = 1
	seedFrame.LayoutOrder = 0
	seedFrame.Parent = parent
	
	local seedLabel = Instance.new("TextLabel")
	seedLabel.Name = "SeedDisplay"
	seedLabel.Size = UDim2.new(1, 0, 1, 0)
	seedLabel.BackgroundTransparency = 1
	seedLabel.Text = "Seed: " .. designerState.currentSeed
	seedLabel.TextColor3 = Color3.fromRGB(150, 150, 255)
	seedLabel.TextSize = 14
	seedLabel.Font = Enum.Font.SourceSansBold
	seedLabel.TextXAlignment = Enum.TextXAlignment.Left
	seedLabel.Parent = seedFrame
	
	-- Archetype selector
	createRealDropdown(parent, "Archetype:", 
		{"CommonA", "OrnateB", "TestSpiral"}, 
		designerState.selectedArchetype, 
		1,
		function(archetype)
			designerState.selectedArchetype = archetype
			print("Archetype:", archetype)
		end
	)
	
	-- Style selector
	createRealDropdown(parent, "Style:", 
		{"straight", "scurve", "planar_spiral", "helix"}, 
		designerState.selectedStyle, 
		2,
		function(newStyle)
			designerState.selectedStyle = newStyle
			print("Style changed to:", newStyle)
			updateContent(parent)
		end
	)
	
	-- Params
	createParamControl(parent, "height", "Height:", 8, 20, 12, 3)
	createParamControl(parent, "bend_deg", "Bend (deg):", 0, 60, 15, 4)
	createParamControl(parent, "twist_deg", "Twist (deg):", 0, 360, 0, 5)
	createParamControl(parent, "tip_drop", "Tip Drop:", 0, 0.5, 0.2, 6)
	createParamControl(parent, "arm_len", "Arm Length:", 1, 4, 1.8, 7)
	createParamControl(parent, "lantern_tilt", "Lantern Tilt:", -45, 45, 5, 8)
	createParamControl(parent, "lantern_yaw", "Lantern Yaw:", -90, 90, 0, 9)
	createParamControl(parent, "head_scale", "Head Scale:", 0.5, 2, 1.0, 10)
	createParamControl(parent, "base_scale", "Base Scale:", 0.5, 2, 1.0, 11)
	createParamControl(parent, "paint_wear", "Paint Wear:", 0, 1, 0.3, 12)
end

-- Hotkey handling
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	
	local isAltDown = UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt) or UserInputService:IsKeyDown(Enum.KeyCode.RightAlt)
	
	if isAltDown and input.KeyCode == Enum.KeyCode.D then
		designerState.visible = not designerState.visible
		if designerUI then
			designerUI.Enabled = designerState.visible
		end
	end
end)

-- Initialize
local designerUI = createDesignerUI()
loadSession()

print("✅ Lantern Designer initialized (Studio only)")
print("📋 Hotkey: Alt+D (Toggle UI)")
print("🎲 Use 'Reroll' button to generate new seed for entire lantern")
