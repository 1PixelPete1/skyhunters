--!strict
-- InventoryIntegrationController.client.luau
-- Client-side integration between inventory and game mechanics
-- Handles equipment changes, visual updates, and UI feedback

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer

local Net = require(ReplicatedStorage.Shared.Net)
local InventoryTypes = require(ReplicatedStorage.Shared.Inventory.InventoryTypes)
local MobilityConfig = require(ReplicatedStorage.Shared.Mobility.MobilityConfig)

type InventoryItem = InventoryTypes.InventoryItem
type PlayerInventory = InventoryTypes.PlayerInventory

local InventoryIntegrationController = {}

-- State
local currentInventory: PlayerInventory? = nil
local mobilityController = nil
local placementClient = nil
local lanternHUD = nil

-- Debug mode
local DEBUG_MODE = true

local function debugPrint(...)
	if DEBUG_MODE then
		print("[InventoryIntegration Client]", ...)
	end
end

function InventoryIntegrationController:Init()
	-- Connect to inventory updates
	Net.On("UpdateInventory", function(inventory: PlayerInventory)
		debugPrint("Received inventory update")
		currentInventory = inventory
		InventoryIntegrationController:OnInventoryUpdated(inventory)
	end)
	
	Net.On("EquipmentChanged", function(slotType: string, item: InventoryItem?)
		debugPrint("Equipment changed:", slotType, item and item.name or "none")
		InventoryIntegrationController:OnEquipmentChanged(slotType, item)
	end)
	
	Net.On("ItemAdded", function(item: InventoryItem, quantity: number)
		debugPrint("Item added:", item.name, "x", quantity)
		InventoryIntegrationController:ShowItemNotification(item, quantity, true)
	end)
	
	Net.On("ItemRemoved", function(itemId: string, quantity: number)
		debugPrint("Item removed:", itemId, "x", quantity)
		InventoryIntegrationController:ShowItemNotification(nil, quantity, false, itemId)
	end)
	
	Net.On("PlacementValidated", function(itemId: string, valid: boolean)
		if not valid then
			InventoryIntegrationController:ShowPlacementError(itemId)
		end
	end)
	
	-- Wait for other controllers to load
	task.spawn(function()
		task.wait(1)
		InventoryIntegrationController:FindControllers()
	end)
	
	debugPrint("Initialized")
end

function InventoryIntegrationController:FindControllers()
	-- Find MobilityController
	local clientScripts = player.PlayerScripts:GetChildren()
	for _, script in ipairs(clientScripts) do
		if script.Name == "MobilityClient" then
			local success, result = pcall(function()
				return require(script)
			end)
			if success then
				mobilityController = result
				debugPrint("Found MobilityController")
			end
		end
	end
	
	-- Find PlacementClient
	-- Find LanternHUD
	-- These would be similar searches or references passed during initialization
end

function InventoryIntegrationController:OnInventoryUpdated(inventory: PlayerInventory)
	-- Update placement restrictions based on inventory
	if placementClient then
		local lanternCount = 0
		local pondToolAvailable = false
		
		for _, slot in pairs(inventory.buildingItems) do
			if slot.item then
				if slot.item.category == "Lantern" then
					lanternCount = lanternCount + slot.quantity
				elseif slot.item.id == "pond_excavator" then
					pondToolAvailable = true
				end
			end
		end
		
		-- Update placement UI to show available items
		-- This would interface with your placement system
		debugPrint("Lanterns available:", lanternCount, "Pond tool:", pondToolAvailable)
	end
	
	-- Update mobility abilities based on equipment
	InventoryIntegrationController:UpdateMobilityAbilities(inventory)
end

function InventoryIntegrationController:OnEquipmentChanged(slotType: string, item: InventoryItem?)
	local character = player.Character
	if not character then return end
	
	if slotType == "LanternHead" then
		InventoryIntegrationController:UpdateLanternHead(character, item)
	elseif slotType == "Jump" or slotType == "Dash" or slotType == "Grapple" then
		InventoryIntegrationController:UpdateMobilityVisuals(character, slotType, item)
	elseif string.find(slotType, "Curse") then
		InventoryIntegrationController:UpdateCurseEffects(character, item)
	elseif slotType == "Weapon" then
		InventoryIntegrationController:UpdateWeapon(character, item)
	end
end

function InventoryIntegrationController:UpdateLanternHead(character: Model, item: InventoryItem?)
	local head = character:FindFirstChild("Head")
	if not head then return end
	
	-- Remove existing lantern head model
	local existingLantern = character:FindFirstChild("LanternHeadModel")
	if existingLantern then
		existingLantern:Destroy()
	end
	
	if item then
		-- Create lantern head model
		local lanternModel = Instance.new("Model")
		lanternModel.Name = "LanternHeadModel"
		lanternModel.Parent = character
		
		-- Create the lantern part
		local lanternPart = Instance.new("Part")
		lanternPart.Name = "Lantern"
		lanternPart.Size = Vector3.new(0.8, 0.8, 0.8)
		lanternPart.Material = Enum.Material.Neon
		lanternPart.BrickColor = BrickColor.new("Bright yellow")
		lanternPart.CanCollide = false
		lanternPart.Massless = true
		lanternPart.Parent = lanternModel
		
		-- Add point light
		local light = Instance.new("PointLight")
		light.Brightness = 2
		light.Range = 20
		light.Color = Color3.fromRGB(255, 220, 150)
		light.Parent = lanternPart
		
		-- Weld to head
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = head
		weld.Part1 = lanternPart
		weld.Parent = lanternPart
		
		-- Position above head
		lanternPart.CFrame = head.CFrame * CFrame.new(0, 1.5, 0)
		
		-- Add floating animation
		local floatTween = TweenService:Create(
			lanternPart,
			TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{CFrame = lanternPart.CFrame * CFrame.new(0, 0.2, 0)}
		)
		floatTween:Play()
		
		debugPrint("Lantern head equipped:", item.name)
	end
end

function InventoryIntegrationController:UpdateMobilityVisuals(character: Model, slotType: string, item: InventoryItem?)
	-- Update mobility pack visuals based on equipped items
	local mobilityPack = character:FindFirstChild("MobilityPack")
	if not mobilityPack then return end
	
	local indicator = nil
	if slotType == "Jump" then
		indicator = mobilityPack:FindFirstChild("LeapIndicator")
	elseif slotType == "Dash" then
		indicator = mobilityPack:FindFirstChild("DashIndicator")
	end
	
	if indicator then
		if item then
			-- Make indicator glow
			indicator.Material = Enum.Material.Neon
			indicator.BrickColor = BrickColor.new("Lime green")
			
			-- Add particle effect
			local attachment = Instance.new("Attachment")
			attachment.Parent = indicator
			
			local particle = Instance.new("ParticleEmitter")
			particle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			particle.Rate = 10
			particle.Lifetime = NumberRange.new(0.5, 1)
			particle.Speed = NumberRange.new(1)
			particle.SpreadAngle = Vector2.new(180, 180)
			particle.Parent = attachment
			
			debugPrint("Mobility visual updated for", slotType)
		else
			-- Dim indicator
			indicator.Material = Enum.Material.SmoothPlastic
			indicator.BrickColor = BrickColor.new("Dark grey")
			
			-- Remove particles
			for _, child in pairs(indicator:GetDescendants()) do
				if child:IsA("ParticleEmitter") then
					child:Destroy()
				end
			end
		end
	end
end

function InventoryIntegrationController:UpdateCurseEffects(character: Model, curse: InventoryItem?)
	if not curse then return end
	
	-- Apply visual curse effects
	if curse.id == "curse_of_greed" then
		-- Add golden aura
		local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
		if humanoidRootPart then
			local aura = humanoidRootPart:FindFirstChild("CurseAura") or Instance.new("PointLight")
			aura.Name = "CurseAura"
			aura.Color = Color3.fromRGB(255, 215, 0) -- Gold
			aura.Brightness = 1
			aura.Range = 15
			aura.Parent = humanoidRootPart
			
			-- Add sparkle particles
			local attachment = humanoidRootPart:FindFirstChild("CurseAttachment") or Instance.new("Attachment")
			attachment.Name = "CurseAttachment"
			attachment.Parent = humanoidRootPart
			
			local particles = attachment:FindFirstChild("CurseParticles") or Instance.new("ParticleEmitter")
			particles.Name = "CurseParticles"
			particles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			particles.Color = ColorSequence.new(Color3.fromRGB(255, 215, 0))
			particles.Rate = 20
			particles.Lifetime = NumberRange.new(2)
			particles.Speed = NumberRange.new(3)
			particles.SpreadAngle = Vector2.new(180, 180)
			particles.Parent = attachment
		end
	end
	
	debugPrint("Curse effects applied:", curse.name)
end

function InventoryIntegrationController:UpdateWeapon(character: Model, weapon: InventoryItem?)
	-- Handle weapon visuals
	-- This would interface with your combat system
	debugPrint("Weapon updated:", weapon and weapon.name or "none")
end

function InventoryIntegrationController:UpdateMobilityAbilities(inventory: PlayerInventory)
	-- Update which mobility abilities are available
	if not mobilityController then return end
	
	local hasJump = inventory.equipment.mobility.jump ~= nil
	local hasDash = inventory.equipment.mobility.dash ~= nil
	local hasGrapple = inventory.equipment.mobility.grapple ~= nil
	
	-- This would interface with your MobilityController
	-- to enable/disable abilities based on equipment
	
	debugPrint("Mobility abilities - Jump:", hasJump, "Dash:", hasDash, "Grapple:", hasGrapple)
end

function InventoryIntegrationController:ShowItemNotification(item: InventoryItem?, quantity: number, added: boolean, itemId: string?)
	-- Create a notification UI for item changes
	local screenGui = player.PlayerGui:FindFirstChild("Notifications") or Instance.new("ScreenGui")
	screenGui.Name = "Notifications"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = player.PlayerGui
	
	local notification = Instance.new("Frame")
	notification.Size = UDim2.new(0, 300, 0, 60)
	notification.Position = UDim2.new(1, 320, 1, -100 - (#screenGui:GetChildren() * 70))
	notification.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	notification.BorderSizePixel = 0
	notification.Parent = screenGui
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = notification
	
	local icon = Instance.new("ImageLabel")
	icon.Size = UDim2.new(0, 40, 0, 40)
	icon.Position = UDim2.new(0, 10, 0, 10)
	icon.BackgroundTransparency = 1
	icon.Image = item and item.icon or "rbxassetid://7734010488"
	icon.Parent = notification
	
	local text = Instance.new("TextLabel")
	text.Size = UDim2.new(1, -70, 1, 0)
	text.Position = UDim2.new(0, 60, 0, 0)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.SourceSans
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextScaled = true
	text.TextXAlignment = Enum.TextXAlignment.Left
	
	if added then
		text.Text = string.format("+ %d %s", quantity, item and item.name or "Item")
		notification.BackgroundColor3 = Color3.fromRGB(40, 60, 40)
	else
		text.Text = string.format("- %d %s", quantity, itemId or "Item")
		notification.BackgroundColor3 = Color3.fromRGB(60, 40, 40)
	end
	
	text.Parent = notification
	
	-- Animate in
	notification:TweenPosition(
		UDim2.new(1, -310, 1, -100 - (#screenGui:GetChildren() * 70)),
		Enum.EasingDirection.Out,
		Enum.EasingStyle.Quart,
		0.3,
		true
	)
	
	-- Remove after delay
	Debris:AddItem(notification, 3)
end

function InventoryIntegrationController:ShowPlacementError(itemId: string)
	-- Show error message for failed placement
	local message = string.format("Cannot place %s - item not in inventory!", itemId)
	
	-- Create error notification
	local screenGui = player.PlayerGui:FindFirstChild("Errors") or Instance.new("ScreenGui")
	screenGui.Name = "Errors"
	screenGui.Parent = player.PlayerGui
	
	local errorLabel = Instance.new("TextLabel")
	errorLabel.Size = UDim2.new(0, 400, 0, 50)
	errorLabel.Position = UDim2.new(0.5, -200, 0.5, -25)
	errorLabel.BackgroundColor3 = Color3.fromRGB(80, 20, 20)
	errorLabel.BorderSizePixel = 0
	errorLabel.Font = Enum.Font.SourceSansBold
	errorLabel.Text = message
	errorLabel.TextColor3 = Color3.new(1, 1, 1)
	errorLabel.TextScaled = true
	errorLabel.Parent = screenGui
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = errorLabel
	
	-- Fade out after 2 seconds
	task.wait(2)
	local tween = TweenService:Create(
		errorLabel,
		TweenInfo.new(0.5),
		{BackgroundTransparency = 1, TextTransparency = 1}
	)
	tween:Play()
	tween.Completed:Connect(function()
		errorLabel:Destroy()
	end)
end

return InventoryIntegrationController
