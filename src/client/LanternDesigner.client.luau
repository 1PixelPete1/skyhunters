--!strict
-- LanternDesigner.client.luau
-- Studio-only designer UI for authoring lantern presets

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

-- Only run in Studio
if not RunService:IsStudio() then
	return
end

local Shared = game.ReplicatedStorage:WaitForChild("Shared")
local FeatureFlags = require(Shared:WaitForChild("FeatureFlags"))
local Types = require(Shared:WaitForChild("LanternTypes"))
local Archetypes = require(Shared:WaitForChild("LanternArchetypes"))

-- Check if designer is enabled
if not FeatureFlags.get("Lanterns.DesignerEnabled") then
	return
end

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Designer state
local designerState = {
	mode = "lamp",  -- "branch" or "lamp"
	visible = false,
	currentBranch = nil,
	currentLamp = nil,
	sessionBranches = {},
	sessionLamps = {},
	selectedArchetype = "CommonA",
	paramLocks = {},
	previewModel = nil
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

-- Save branch to session
local function saveBranchToSession(branch: Types.BranchProfile & {decorations: {Types.DecorationRule}})
	local sessionFolder = ensureSessionFolder()
	local branchesFolder = sessionFolder:FindFirstChild("Branches")
	
	local count = #branchesFolder:GetChildren() + 1
	local stringValue = Instance.new("StringValue")
	stringValue.Name = "Branch_" .. count
	stringValue.Value = HttpService:JSONEncode(branch)
	stringValue.Parent = branchesFolder
	
	table.insert(designerState.sessionBranches, branch)
	print("Saved branch:", branch.id)
end

-- Save lamp to session
local function saveLampToSession(archetype: Types.Archetype)
	local sessionFolder = ensureSessionFolder()
	local lampsFolder = sessionFolder:FindFirstChild("Lamps")
	
	local count = #lampsFolder:GetChildren() + 1
	local stringValue = Instance.new("StringValue")
	stringValue.Name = "Lamp_" .. count
	stringValue.Value = HttpService:JSONEncode(archetype)
	stringValue.Parent = lampsFolder
	
	table.insert(designerState.sessionLamps, archetype)
	print("Saved lamp archetype")
end

-- Load session data
local function loadSession()
	local sessionFolder = workspace:FindFirstChild("__LanternDesignerSession")
	if not sessionFolder then
		return
	end
	
	-- Load branches
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
	
	-- Load lamps
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

-- Create the main UI
local function createDesignerUI()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "LanternDesigner"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 10
	
	-- Main frame
	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainFrame"
	mainFrame.Size = UDim2.new(0, 400, 0, 600)
	mainFrame.Position = UDim2.new(1, -420, 0.5, -300)
	mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	mainFrame.BorderSizePixel = 0
	mainFrame.Parent = screenGui
	
	-- Title bar
	local titleBar = Instance.new("Frame")
	titleBar.Name = "TitleBar"
	titleBar.Size = UDim2.new(1, 0, 0, 30)
	titleBar.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	titleBar.BorderSizePixel = 0
	titleBar.Parent = mainFrame
	
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, -30, 1, 0)
	titleLabel.Position = UDim2.new(0, 5, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "Lantern Designer"
	titleLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	titleLabel.TextScaled = true
	titleLabel.Font = Enum.Font.SourceSansBold
	titleLabel.Parent = titleBar
	
	-- Close button
	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseButton"
	closeButton.Size = UDim2.new(0, 30, 1, 0)
	closeButton.Position = UDim2.new(1, -30, 0, 0)
	closeButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
	closeButton.Text = "X"
	closeButton.TextColor3 = Color3.new(1, 1, 1)
	closeButton.TextScaled = true
	closeButton.Font = Enum.Font.SourceSansBold
	closeButton.Parent = titleBar
	
	-- Mode tabs
	local tabFrame = Instance.new("Frame")
	tabFrame.Name = "Tabs"
	tabFrame.Size = UDim2.new(1, 0, 0, 40)
	tabFrame.Position = UDim2.new(0, 0, 0, 30)
	tabFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	tabFrame.BorderSizePixel = 0
	tabFrame.Parent = mainFrame
	
	local branchTab = Instance.new("TextButton")
	branchTab.Name = "BranchTab"
	branchTab.Size = UDim2.new(0.5, -1, 1, 0)
	branchTab.Position = UDim2.new(0, 0, 0, 0)
	branchTab.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	branchTab.Text = "Branch Mode"
	branchTab.TextColor3 = Color3.fromRGB(180, 180, 180)
	branchTab.TextScaled = true
	branchTab.Font = Enum.Font.SourceSans
	branchTab.Parent = tabFrame
	
	local lampTab = Instance.new("TextButton")
	lampTab.Name = "LampTab"
	lampTab.Size = UDim2.new(0.5, -1, 1, 0)
	lampTab.Position = UDim2.new(0.5, 1, 0, 0)
	lampTab.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	lampTab.Text = "Lamp Mode"
	lampTab.TextColor3 = Color3.new(1, 1, 1)
	lampTab.TextScaled = true
	lampTab.Font = Enum.Font.SourceSans
	lampTab.Parent = tabFrame
	
	-- Content area
	local contentFrame = Instance.new("ScrollingFrame")
	contentFrame.Name = "Content"
	contentFrame.Size = UDim2.new(1, -10, 1, -120)
	contentFrame.Position = UDim2.new(0, 5, 0, 70)
	contentFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
	contentFrame.BorderSizePixel = 0
	contentFrame.ScrollBarThickness = 8
	contentFrame.CanvasSize = UDim2.new(0, 0, 2, 0)
	contentFrame.Parent = mainFrame
	
	-- Bottom buttons
	local buttonFrame = Instance.new("Frame")
	buttonFrame.Name = "Buttons"
	buttonFrame.Size = UDim2.new(1, -10, 0, 40)
	buttonFrame.Position = UDim2.new(0, 5, 1, -45)
	buttonFrame.BackgroundTransparency = 1
	buttonFrame.Parent = mainFrame
	
	local saveButton = Instance.new("TextButton")
	saveButton.Name = "SaveButton"
	saveButton.Size = UDim2.new(0.3, -2, 1, 0)
	saveButton.Position = UDim2.new(0, 0, 0, 0)
	saveButton.BackgroundColor3 = Color3.fromRGB(50, 120, 50)
	saveButton.Text = "Save"
	saveButton.TextColor3 = Color3.new(1, 1, 1)
	saveButton.TextScaled = true
	saveButton.Font = Enum.Font.SourceSansBold
	saveButton.Parent = buttonFrame
	
	local previewButton = Instance.new("TextButton")
	previewButton.Name = "PreviewButton"
	previewButton.Size = UDim2.new(0.3, -2, 1, 0)
	previewButton.Position = UDim2.new(0.35, 0, 0, 0)
	previewButton.BackgroundColor3 = Color3.fromRGB(50, 50, 120)
	previewButton.Text = "Preview"
	previewButton.TextColor3 = Color3.new(1, 1, 1)
	previewButton.TextScaled = true
	previewButton.Font = Enum.Font.SourceSansBold
	previewButton.Parent = buttonFrame
	
	local spawnButton = Instance.new("TextButton")
	spawnButton.Name = "SpawnButton"
	spawnButton.Size = UDim2.new(0.3, -2, 1, 0)
	spawnButton.Position = UDim2.new(0.7, 0, 0, 0)
	spawnButton.BackgroundColor3 = Color3.fromRGB(120, 50, 50)
	spawnButton.Text = "Spawn Test"
	spawnButton.TextColor3 = Color3.new(1, 1, 1)
	spawnButton.TextScaled = true
	spawnButton.Font = Enum.Font.SourceSansBold
	spawnButton.Parent = buttonFrame
	
	-- Wire up tab switching
	branchTab.MouseButton1Click:Connect(function()
		designerState.mode = "branch"
		branchTab.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
		branchTab.TextColor3 = Color3.new(1, 1, 1)
		lampTab.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
		lampTab.TextColor3 = Color3.fromRGB(180, 180, 180)
		-- Update content
		updateContent(contentFrame)
	end)
	
	lampTab.MouseButton1Click:Connect(function()
		designerState.mode = "lamp"
		lampTab.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
		lampTab.TextColor3 = Color3.new(1, 1, 1)
		branchTab.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
		branchTab.TextColor3 = Color3.fromRGB(180, 180, 180)
		-- Update content
		updateContent(contentFrame)
	end)
	
	-- Wire up buttons
	saveButton.MouseButton1Click:Connect(function()
		if designerState.mode == "branch" and designerState.currentBranch then
			saveBranchToSession(designerState.currentBranch)
		elseif designerState.mode == "lamp" and designerState.currentLamp then
			saveLampToSession(designerState.currentLamp)
		end
	end)
	
	previewButton.MouseButton1Click:Connect(function()
		-- Preview functionality - spawn a temporary ghost model
		if designerState.previewModel then
			designerState.previewModel:Destroy()
			designerState.previewModel = nil
			print("Preview cleared")
		else
			local character = player.Character
			if character and character:FindFirstChild("HumanoidRootPart") then
				local previewPos = character.HumanoidRootPart.Position + Vector3.new(8, 0, 0)
				
				-- Create a simple preview model
				local previewModel = Instance.new("Model")
				previewModel.Name = "LanternPreview"
				
				local part = Instance.new("Part")
				part.Name = "PreviewPart"
				part.Size = Vector3.new(2, 10, 2)
				part.Position = previewPos
				part.Anchored = true
				part.CanCollide = false
				part.Material = Enum.Material.ForceField
				part.BrickColor = BrickColor.new("Bright blue")
				part.Transparency = 0.5
				part.Parent = previewModel
				
				local selectionBox = Instance.new("SelectionBox")
				selectionBox.Adornee = part
				selectionBox.Color3 = Color3.fromRGB(100, 150, 255)
				selectionBox.LineThickness = 0.05
				selectionBox.Parent = part
				
				previewModel.Parent = workspace
				designerState.previewModel = previewModel
				
				print("✅ Preview created at", previewPos)
				print("   Archetype:", designerState.selectedArchetype)
			else
				warn("Character not found - unable to create preview")
			end
		end
	end)
	
	spawnButton.MouseButton1Click:Connect(function()
		-- Spawn test lantern
		local archetype = designerState.currentLamp or Archetypes[designerState.selectedArchetype]
		if archetype then
			-- Get player's position for spawn location
			local character = player.Character
			if character and character:FindFirstChild("HumanoidRootPart") then
				local spawnPos = character.HumanoidRootPart.Position + Vector3.new(5, 0, 5)
				
				-- Create RemoteEvent if it doesn't exist
				local remoteEvent = game.ReplicatedStorage:FindFirstChild("SpawnDynamicLantern")
				if not remoteEvent then
					-- Try to spawn directly if we have access (Studio)
					local success, err = pcall(function()
						local LanternSpawnService = require(game.ServerScriptService:WaitForChild("LanternSpawnService", 2))
						if LanternSpawnService then
							local lantern = LanternSpawnService.SpawnDynamicLantern(
								"designer_test",
								spawnPos,
								"designer",
								designerState.selectedArchetype
							)
							if lantern then
								lantern:SetAttribute("SpawnedByDesigner", true)
								print("✅ Spawned lantern at", spawnPos)
							end
						end
					end)
					
					if not success then
						warn("Failed to spawn lantern:", err)
						print("Tip: Make sure LanternSpawnService is loaded")
					end
				else
					-- Use RemoteEvent
					remoteEvent:FireServer(spawnPos, designerState.selectedArchetype)
					print("Requested lantern spawn at", spawnPos)
				end
			else
				warn("Character not found - unable to determine spawn position")
			end
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

-- Update content based on mode
function updateContent(contentFrame: ScrollingFrame)
	-- Clear existing content
	for _, child in ipairs(contentFrame:GetChildren()) do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
	
	-- Add list layout if missing
	local layout = contentFrame:FindFirstChild("UIListLayout")
	if not layout then
		layout = Instance.new("UIListLayout")
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Padding = UDim.new(0, 5)
		layout.Parent = contentFrame
	end
	
	if designerState.mode == "branch" then
		createBranchControls(contentFrame)
	else
		createLampControls(contentFrame)
	end
end

-- Create branch mode controls
function createBranchControls(parent: ScrollingFrame)
	-- Branch ID
	local idFrame = createLabeledInput(parent, "Branch ID:", "simple_arm", 1)
	
	-- Max children
	local maxChildrenFrame = createSlider(parent, "Max Children:", 0, 5, 1, 2)
	
	-- Length fraction
	local lenFracFrame = createCurveControl(parent, "Length Fraction:", 
		{mu = 0.4, sigma = 0.05, lo = 0.3, hi = 0.5}, 3)
	
	-- Pitch degrees
	local pitchFrame = createCurveControl(parent, "Pitch (deg):", 
		{mu = -20, sigma = 10, lo = -45, hi = 0}, 4)
	
	-- Yaw degrees
	local yawFrame = createCurveControl(parent, "Yaw (deg):", 
		{mu = 0, sigma = 30, lo = -60, hi = 60}, 5)
	
	-- Inherit rotation
	local inheritFrame = createCheckbox(parent, "Inherit Rotation", false, 6)
	
	-- Jitter
	local jitterFrame = createCurveControl(parent, "Jitter (deg):", 
		{mu = 0, sigma = 2, lo = -5, hi = 5}, 7)
	
	-- Decorations section
	local decorLabel = Instance.new("TextLabel")
	decorLabel.Size = UDim2.new(1, 0, 0, 30)
	decorLabel.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
	decorLabel.BorderSizePixel = 0
	decorLabel.Text = "Decorations"
	decorLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	decorLabel.TextScaled = true
	decorLabel.Font = Enum.Font.SourceSansBold
	decorLabel.LayoutOrder = 8
	decorLabel.Parent = parent
end

-- Create lamp mode controls
function createLampControls(parent: ScrollingFrame)
	-- Archetype selector
	local archetypeFrame = createDropdown(parent, "Archetype:", 
		{"CommonA", "OrnateB", "TestSpiral"}, designerState.selectedArchetype, 1)
	
	-- Core parameters
	local heightFrame = createSlider(parent, "Height:", 8, 20, 12, 2)
	local bendFrame = createSlider(parent, "Bend (deg):", 0, 45, 15, 3)
	local twistFrame = createSlider(parent, "Twist (deg):", 0, 360, 0, 4)
	local tipDropFrame = createSlider(parent, "Tip Drop:", 0, 0.5, 0.2, 5)
	local armLenFrame = createSlider(parent, "Arm Length:", 1, 3, 1.8, 6)
	local tiltFrame = createSlider(parent, "Lantern Tilt:", -30, 30, 5, 7)
	local yawFrame = createSlider(parent, "Lantern Yaw:", -45, 45, 0, 8)
	
	-- Scales
	local headScaleFrame = createSlider(parent, "Head Scale:", 0.5, 1.5, 1.0, 9)
	local baseScaleFrame = createSlider(parent, "Base Scale:", 0.5, 1.5, 1.0, 10)
	
	-- Style weights
	local styleLabel = Instance.new("TextLabel")
	styleLabel.Size = UDim2.new(1, 0, 0, 30)
	styleLabel.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
	styleLabel.BorderSizePixel = 0
	styleLabel.Text = "Style Weights"
	styleLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	styleLabel.TextScaled = true
	styleLabel.Font = Enum.Font.SourceSansBold
	styleLabel.LayoutOrder = 11
	styleLabel.Parent = parent
	
	local straightWeight = createSlider(parent, "Straight:", 0, 1, 0.5, 12)
	local scurveWeight = createSlider(parent, "S-Curve:", 0, 1, 0.4, 13)
	local spiralWeight = createSlider(parent, "Spiral:", 0, 1, 0.1, 14)
	local helixWeight = createSlider(parent, "Helix:", 0, 1, 0, 15)
end

-- UI Helper functions
function createLabeledInput(parent: Instance, label: string, defaultValue: string, order: number): Frame
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 0, 30)
	frame.BackgroundTransparency = 1
	frame.LayoutOrder = order
	frame.Parent = parent
	
	local labelObj = Instance.new("TextLabel")
	labelObj.Size = UDim2.new(0.4, 0, 1, 0)
	labelObj.BackgroundTransparency = 1
	labelObj.Text = label
	labelObj.TextColor3 = Color3.fromRGB(180, 180, 180)
	labelObj.TextScaled = true
	labelObj.TextXAlignment = Enum.TextXAlignment.Left
	labelObj.Font = Enum.Font.SourceSans
	labelObj.Parent = frame
	
	local input = Instance.new("TextBox")
	input.Size = UDim2.new(0.6, -5, 1, 0)
	input.Position = UDim2.new(0.4, 5, 0, 0)
	input.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	input.BorderSizePixel = 0
	input.Text = defaultValue
	input.TextColor3 = Color3.new(1, 1, 1)
	input.TextScaled = true
	input.Font = Enum.Font.SourceSans
	input.Parent = frame
	
	return frame
end

function createSlider(parent: Instance, label: string, min: number, max: number, default: number, order: number): Frame
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 0, 40)
	frame.BackgroundTransparency = 1
	frame.LayoutOrder = order
	frame.Parent = parent
	
	local labelObj = Instance.new("TextLabel")
	labelObj.Size = UDim2.new(0.4, 0, 0.5, 0)
	labelObj.BackgroundTransparency = 1
	labelObj.Text = label
	labelObj.TextColor3 = Color3.fromRGB(180, 180, 180)
	labelObj.TextScaled = true
	labelObj.TextXAlignment = Enum.TextXAlignment.Left
	labelObj.Font = Enum.Font.SourceSans
	labelObj.Parent = frame
	
	local valueLabel = Instance.new("TextLabel")
	valueLabel.Size = UDim2.new(0.2, 0, 0.5, 0)
	valueLabel.Position = UDim2.new(0.8, 0, 0, 0)
	valueLabel.BackgroundTransparency = 1
	valueLabel.Text = tostring(default)
	valueLabel.TextColor3 = Color3.new(1, 1, 1)
	valueLabel.TextScaled = true
	valueLabel.Font = Enum.Font.SourceSansBold
	valueLabel.Parent = frame
	
	local sliderBack = Instance.new("Frame")
	sliderBack.Size = UDim2.new(0.6, -10, 0, 4)
	sliderBack.Position = UDim2.new(0.4, 5, 0.75, -2)
	sliderBack.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	sliderBack.BorderSizePixel = 0
	sliderBack.Parent = frame
	
	local sliderButton = Instance.new("TextButton")
	sliderButton.Size = UDim2.new(0, 16, 0, 16)
	sliderButton.Position = UDim2.new((default - min) / (max - min), -8, 0.5, -8)
	sliderButton.BackgroundColor3 = Color3.fromRGB(100, 150, 200)
	sliderButton.Text = ""
	sliderButton.Parent = sliderBack
	
	-- Make it draggable
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
			
			sliderButton.Position = UDim2.new(percent, -8, 0.5, -8)
			
			local value = min + (max - min) * percent
			valueLabel.Text = string.format("%.2f", value)
		end
	end)
	
	return frame
end

function createCheckbox(parent: Instance, label: string, default: boolean, order: number): Frame
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 0, 30)
	frame.BackgroundTransparency = 1
	frame.LayoutOrder = order
	frame.Parent = parent
	
	local checkbox = Instance.new("TextButton")
	checkbox.Size = UDim2.new(0, 20, 0, 20)
	checkbox.Position = UDim2.new(0, 5, 0.5, -10)
	checkbox.BackgroundColor3 = default and Color3.fromRGB(100, 200, 100) or Color3.fromRGB(50, 50, 50)
	checkbox.Text = default and "✓" or ""
	checkbox.TextColor3 = Color3.new(1, 1, 1)
	checkbox.TextScaled = true
	checkbox.Font = Enum.Font.SourceSansBold
	checkbox.Parent = frame
	
	local labelObj = Instance.new("TextLabel")
	labelObj.Size = UDim2.new(1, -35, 1, 0)
	labelObj.Position = UDim2.new(0, 30, 0, 0)
	labelObj.BackgroundTransparency = 1
	labelObj.Text = label
	labelObj.TextColor3 = Color3.fromRGB(180, 180, 180)
	labelObj.TextScaled = true
	labelObj.TextXAlignment = Enum.TextXAlignment.Left
	labelObj.Font = Enum.Font.SourceSans
	labelObj.Parent = frame
	
	checkbox.MouseButton1Click:Connect(function()
		local checked = checkbox.Text == ""
		checkbox.Text = checked and "✓" or ""
		checkbox.BackgroundColor3 = checked and Color3.fromRGB(100, 200, 100) or Color3.fromRGB(50, 50, 50)
	end)
	
	return frame
end

function createDropdown(parent: Instance, label: string, options: {string}, default: string, order: number): Frame
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 0, 30)
	frame.BackgroundTransparency = 1
	frame.LayoutOrder = order
	frame.Parent = parent
	
	local labelObj = Instance.new("TextLabel")
	labelObj.Size = UDim2.new(0.4, 0, 1, 0)
	labelObj.BackgroundTransparency = 1
	labelObj.Text = label
	labelObj.TextColor3 = Color3.fromRGB(180, 180, 180)
	labelObj.TextScaled = true
	labelObj.TextXAlignment = Enum.TextXAlignment.Left
	labelObj.Font = Enum.Font.SourceSans
	labelObj.Parent = frame
	
	local dropdown = Instance.new("TextButton")
	dropdown.Size = UDim2.new(0.6, -5, 1, 0)
	dropdown.Position = UDim2.new(0.4, 5, 0, 0)
	dropdown.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	dropdown.BorderSizePixel = 0
	dropdown.Text = default
	dropdown.TextColor3 = Color3.new(1, 1, 1)
	dropdown.TextScaled = true
	dropdown.Font = Enum.Font.SourceSans
	dropdown.Parent = frame
	
	-- Dropdown would expand on click (simplified for now)
	dropdown.MouseButton1Click:Connect(function()
		-- Cycle through options
		local currentIndex = table.find(options, dropdown.Text) or 1
		local nextIndex = (currentIndex % #options) + 1
		dropdown.Text = options[nextIndex]
		designerState.selectedArchetype = options[nextIndex]
	end)
	
	return frame
end

function createCurveControl(parent: Instance, label: string, curve: Types.Curve, order: number): Frame
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 0, 60)
	frame.BackgroundTransparency = 1
	frame.LayoutOrder = order
	frame.Parent = parent
	
	local labelObj = Instance.new("TextLabel")
	labelObj.Size = UDim2.new(1, 0, 0, 20)
	labelObj.BackgroundTransparency = 1
	labelObj.Text = label
	labelObj.TextColor3 = Color3.fromRGB(180, 180, 180)
	labelObj.TextScaled = true
	labelObj.TextXAlignment = Enum.TextXAlignment.Left
	labelObj.Font = Enum.Font.SourceSansBold
	labelObj.Parent = frame
	
	-- Mu slider
	local muSlider = createSlider(frame, "μ:", curve.lo, curve.hi, curve.mu, 1)
	muSlider.Position = UDim2.new(0, 0, 0, 20)
	muSlider.Size = UDim2.new(0.5, -5, 0, 40)
	
	-- Sigma slider
	local sigmaSlider = createSlider(frame, "σ:", 0, (curve.hi - curve.lo) / 4, curve.sigma, 2)
	sigmaSlider.Position = UDim2.new(0.5, 5, 0, 20)
	sigmaSlider.Size = UDim2.new(0.5, -5, 0, 40)
	
	return frame
end

-- Hotkey handling
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	
	if input.KeyCode == Enum.KeyCode.B and UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt) then
		-- Alt+B: Save Branch
		if designerState.mode == "branch" and designerState.currentBranch then
			saveBranchToSession(designerState.currentBranch)
		end
		
	elseif input.KeyCode == Enum.KeyCode.L and UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt) then
		-- Alt+L: Save Lamp
		if designerState.mode == "lamp" and designerState.currentLamp then
			saveLampToSession(designerState.currentLamp)
		end
		
	elseif input.KeyCode == Enum.KeyCode.R and UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt) then
		-- Alt+R: Reroll Pose channel
		print("Reroll pose parameters")
		
	elseif input.KeyCode == Enum.KeyCode.D and UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt) then
		-- Alt+D: Toggle designer visibility
		designerState.visible = not designerState.visible
		if designerUI then
			designerUI.Enabled = designerState.visible
		end
	end
end)

-- Clean up on stop
RunService:BindToRenderStep("LanternDesignerCleanup", Enum.RenderPriority.Last.Value, function()
	if not RunService:IsRunning() then
		local sessionFolder = workspace:FindFirstChild("__LanternDesignerSession")
		if sessionFolder then
			sessionFolder:Destroy()
		end
		RunService:UnbindFromRenderStep("LanternDesignerCleanup")
	end
end)

-- Initialize
local designerUI = createDesignerUI()
loadSession()

-- Watch for attribute changes to toggle UI
player:GetAttributeChangedSignal("LanternDesignerEnabled"):Connect(function()
	local enabled = player:GetAttribute("LanternDesignerEnabled")
	if enabled ~= nil then
		designerState.visible = enabled
		designerUI.Enabled = enabled
	end
end)

print("Lantern Designer initialized (Studio only)")
print("Hotkeys: Alt+B (Save Branch), Alt+L (Save Lamp), Alt+R (Reroll), Alt+D (Toggle UI)")
