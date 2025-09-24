--!strict
-- InventoryController.client.luau
-- Main inventory orchestrator that manages all inventory systems

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local InventoryConfig = require(ReplicatedStorage.Shared.Inventory.InventoryConfig)
local InventoryTypes = require(ReplicatedStorage.Shared.Inventory.InventoryTypes)
local Net = require(ReplicatedStorage.Shared.Net)

local HotbarController = require(script.Parent.HotbarController)
local BuildingInventoryUI = require(script.Parent.Building.BuildingInventoryUI)
local EquipmentInventoryUI = require(script.Parent.Equipment.EquipmentInventoryUI)
local DragDropHandler = require(script.Parent.DragDropHandler)

type InventoryItem = InventoryTypes.InventoryItem
type PlayerInventory = InventoryTypes.PlayerInventory

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Constants
local KEYBINDS = InventoryConfig.Gameplay.Keybinds
local BUTTON_CONFIG = InventoryConfig.UI.Buttons
local ANIMATIONS = InventoryConfig.UI.Animations

-- Main Controller
local InventoryController = {}

local hotbar: typeof(HotbarController.new())
local buildingInventory: typeof(BuildingInventoryUI.new())
local equipmentInventory: typeof(EquipmentInventoryUI.new())
local dragDropHandler: typeof(DragDropHandler.new())

local inventoryButtons = {}
local playerInventoryData: PlayerInventory? = nil

local buildingCloseButton: ImageButton? = nil

local currentOpenInventory: string? = nil
local isInitialized = false

-- Initialize the inventory system
function InventoryController:Initialize()
	if isInitialized then
		return
	end
	isInitialized = true
	
	print("[InventoryController] Initializing inventory system...")
	
	-- Create controllers
	hotbar = HotbarController.new()
	buildingInventory = BuildingInventoryUI.new()
	equipmentInventory = EquipmentInventoryUI.new()
	dragDropHandler = DragDropHandler.new()
	
	-- Create UIs
	buildingInventory:Create()
	equipmentInventory:Create()
	
	-- Create inventory toggle buttons
	self:CreateInventoryButtons()
	
	-- Setup callbacks
	self:SetupCallbacks()
	
	-- Setup input handling
	self:SetupInputHandling()
	
	-- Connect to server
	self:ConnectRemotes()
	
	-- Request initial inventory data
	self:RequestInventoryData()
	
	-- Setup drag and drop
	self:SetupDragAndDrop()
	
	print("[InventoryController] Inventory system initialized!")
end

-- Create the inventory toggle buttons
function InventoryController:CreateInventoryButtons()
	local gui = Instance.new("ScreenGui")
	gui.Name = "InventoryButtons"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 2
	gui.Parent = playerGui

	-- Building inventory button
	local buildingButton = Instance.new("TextButton")
	buildingButton.Name = "BuildingButton"
	buildingButton.Size = BUTTON_CONFIG.BuildingButton.Size
	buildingButton.Position = BUTTON_CONFIG.BuildingButton.Position
	buildingButton.AnchorPoint = Vector2.new(0.5, 1)
	buildingButton.BackgroundColor3 = InventoryConfig.UI.Colors.SecondaryBackground
	buildingButton.BorderSizePixel = 0
	buildingButton.Text = ""
	buildingButton.AutoButtonColor = false
	buildingButton.Parent = gui

	local buildingCorner = Instance.new("UICorner")
	buildingCorner.CornerRadius = UDim.new(0, 8)
	buildingCorner.Parent = buildingButton

	local buildingIcon = Instance.new("ImageLabel")
	buildingIcon.Size = UDim2.new(0.6, 0, 0.6, 0)
	buildingIcon.Position = UDim2.new(0.5, 0, 0.5, 0)
	buildingIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	buildingIcon.BackgroundTransparency = 1
	buildingIcon.Image = BUTTON_CONFIG.BuildingButton.Icon
	buildingIcon.ImageColor3 = InventoryConfig.UI.Colors.Text
	buildingIcon.Parent = buildingButton

	-- Equipment inventory button
	local equipmentButton = Instance.new("TextButton")
	equipmentButton.Name = "EquipmentButton"
	equipmentButton.Size = BUTTON_CONFIG.EquipmentButton.Size
	equipmentButton.Position = BUTTON_CONFIG.EquipmentButton.Position
	equipmentButton.AnchorPoint = Vector2.new(0.5, 1)
	equipmentButton.BackgroundColor3 = InventoryConfig.UI.Colors.SecondaryBackground
	equipmentButton.BorderSizePixel = 0
	equipmentButton.Text = ""
	equipmentButton.AutoButtonColor = false
	equipmentButton.Parent = gui

	local equipmentCorner = Instance.new("UICorner")
	equipmentCorner.CornerRadius = UDim.new(0, 8)
	equipmentCorner.Parent = equipmentButton

	local equipmentIcon = Instance.new("ImageLabel")
	equipmentIcon.Size = UDim2.new(0.6, 0, 0.6, 0)
	equipmentIcon.Position = UDim2.new(0.5, 0, 0.5, 0)
	equipmentIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	equipmentIcon.BackgroundTransparency = 1
	equipmentIcon.Image = BUTTON_CONFIG.EquipmentButton.Icon
	equipmentIcon.ImageColor3 = InventoryConfig.UI.Colors.Text
	equipmentIcon.Parent = equipmentButton

	-- Collapse button shown while building inventory is open
	buildingCloseButton = Instance.new("ImageButton")
	buildingCloseButton.Name = "BuildingCloseButton"
	buildingCloseButton.Size = UDim2.new(0, 48, 0, 48)
	buildingCloseButton.AnchorPoint = Vector2.new(0.5, 1)
	buildingCloseButton.BackgroundColor3 = InventoryConfig.UI.Colors.SecondaryBackground
	buildingCloseButton.BorderSizePixel = 0
	buildingCloseButton.AutoButtonColor = false
	buildingCloseButton.ZIndex = 3
	buildingCloseButton.Visible = false
	buildingCloseButton.Active = false
	buildingCloseButton.Position = self:GetBuildingCloseButtonPosition(false)
	buildingCloseButton.Parent = gui

	local collapseCorner = Instance.new("UICorner")
	collapseCorner.CornerRadius = UDim.new(0, 8)
	collapseCorner.Parent = buildingCloseButton

	local collapseIcon = Instance.new("ImageLabel")
	collapseIcon.Name = "Icon"
	collapseIcon.Size = UDim2.new(0.6, 0, 0.6, 0)
	collapseIcon.Position = UDim2.new(0.5, 0, 0.5, 0)
	collapseIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	collapseIcon.BackgroundTransparency = 1
	collapseIcon.Image = "rbxassetid://3926305904"
	collapseIcon.ImageRectOffset = Vector2.new(4, 36)
	collapseIcon.ImageRectSize = Vector2.new(24, 24)
	collapseIcon.ImageColor3 = InventoryConfig.UI.Colors.Text
	collapseIcon.Parent = buildingCloseButton

	buildingCloseButton.MouseButton1Click:Connect(function()
		if currentOpenInventory == "building" then
			buildingInventory:Close()
		end
	end)

	-- Button interactions
	buildingButton.MouseButton1Click:Connect(function()
		self:ToggleBuildingInventory()
	end)

	equipmentButton.MouseButton1Click:Connect(function()
		self:ToggleEquipmentInventory()
	end)

	-- Hover effects
	local function addHoverEffect(button)
		local baseSize = button.Size
		local hoverScale = ANIMATIONS.HoverScale or 1.05

		button.MouseEnter:Connect(function()
			local target = UDim2.new(
				baseSize.X.Scale * hoverScale, baseSize.X.Offset * hoverScale,
				baseSize.Y.Scale * hoverScale, baseSize.Y.Offset * hoverScale
			)
			TweenService:Create(button, TweenInfo.new(0.12, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Size = target}):Play()
		end)

		button.MouseLeave:Connect(function()
			TweenService:Create(button, TweenInfo.new(0.12, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Size = baseSize}):Play()
		end)

		button.MouseButton1Click:Connect(function()
			TweenService:Create(button, TweenInfo.new(0.1, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Size = baseSize}):Play()
		end)
	end

	addHoverEffect(buildingButton)
	addHoverEffect(equipmentButton)

	inventoryButtons.building = buildingButton
	inventoryButtons.equipment = equipmentButton
end

function InventoryController:GetBuildingCloseButtonPosition(isOpen: boolean): UDim2
	local config = InventoryConfig.UI.BuildingInventory
	if isOpen then
		local openPos = config.AnimatedPosition
		local topY = openPos.Y.Offset - config.Size.Y.Offset
		return UDim2.new(openPos.X.Scale, openPos.X.Offset, openPos.Y.Scale, topY)
	else
		local closedPos = config.Position
		return UDim2.new(closedPos.X.Scale, closedPos.X.Offset, closedPos.Y.Scale, closedPos.Y.Offset + 60)
	end
end

function InventoryController:ShowBuildingCloseButton()
	if not buildingCloseButton then
		return
	end
	buildingCloseButton.Visible = true
	buildingCloseButton.Active = true
	TweenService:Create(
		buildingCloseButton,
		TweenInfo.new(ANIMATIONS.SlideSpeed, ANIMATIONS.EasingStyle, ANIMATIONS.EasingDirection),
		{Position = self:GetBuildingCloseButtonPosition(true)}
	):Play()
end

function InventoryController:HideBuildingCloseButton()
	if not buildingCloseButton then
		return
	end
	local target = self:GetBuildingCloseButtonPosition(false)
	buildingCloseButton.Active = false
	local tween = TweenService:Create(
		buildingCloseButton,
		TweenInfo.new(ANIMATIONS.SlideSpeed, ANIMATIONS.EasingStyle, ANIMATIONS.EasingDirection),
		{Position = target}
	)
	tween.Completed:Connect(function()
		if currentOpenInventory ~= "building" then
			buildingCloseButton.Visible = false
		end
	end)
	tween:Play()
end

-- Setup callbacks for inventory UIs
function InventoryController:SetupCallbacks()
	-- Building inventory callbacks
	buildingInventory:SetOnOpen(function()
		currentOpenInventory = "building"
			self:HideInventoryButtons()
		self:ShowBuildingCloseButton()
	end)
	
	buildingInventory:SetOnClose(function()
		currentOpenInventory = nil
			self:HideBuildingCloseButton()
		self:ShowInventoryButtons()
	end)
	
	buildingInventory:SetOnCategoryChanged(function(category)
		self:FilterBuildingItems(category)
	end)
	
	buildingInventory:SetOnSearch(function(searchText)
		self:SearchBuildingItems(searchText)
	end)
	
	-- Equipment inventory callbacks
	equipmentInventory:SetOnOpen(function()
		currentOpenInventory = "equipment"
		self:HideInventoryButtons()
		self:HideBuildingCloseButton()
		hotbar:Hide() -- Hide hotbar in equipment view
	end)
	
	equipmentInventory:SetOnClose(function()
		currentOpenInventory = nil
		self:ShowInventoryButtons()
		hotbar:Show() -- Show hotbar again
	end)
	
	equipmentInventory:SetOnCategoryChanged(function(category)
		self:FilterEquipmentItems(category)
	end)
end

-- Setup keyboard input handling
function InventoryController:SetupInputHandling()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		
		-- Building inventory key
		if input.KeyCode == KEYBINDS.OpenBuildingInventory then
			self:ToggleBuildingInventory()
		
		-- Equipment inventory key
		elseif input.KeyCode == KEYBINDS.OpenEquipmentInventory then
			self:ToggleEquipmentInventory()
		
		-- Close any open inventory
		elseif input.KeyCode == KEYBINDS.CloseInventory then
			self:CloseAllInventories()
		end
	end)
end

-- Toggle building inventory
function InventoryController:ToggleBuildingInventory()
	if currentOpenInventory ~= nil and currentOpenInventory ~= "building" then
		return
	end

	if currentOpenInventory == "building" then
		buildingInventory:Close()
		return
	end

	buildingInventory:Open()
end

-- Toggle equipment inventory
function InventoryController:ToggleEquipmentInventory()
	if currentOpenInventory ~= nil and currentOpenInventory ~= "equipment" then
		return
	end

	if currentOpenInventory == "equipment" then
		equipmentInventory:Close()
		return
	end

	equipmentInventory:Open()
end

-- Close all inventories
function InventoryController:CloseAllInventories()
	if currentOpenInventory == "building" then
		buildingInventory:Close()
	elseif currentOpenInventory == "equipment" then
		equipmentInventory:Close()
	end
	self:HideBuildingCloseButton()
end

-- Hide inventory buttons
function InventoryController:HideInventoryButtons()
	for _, button in pairs(inventoryButtons) do
		button.Visible = false
		button.Active = false
	end
end

-- Show inventory buttons
function InventoryController:ShowInventoryButtons()
	if currentOpenInventory ~= nil then
		return
	end
	for name, button in pairs(inventoryButtons) do
		local config = name == "building" and BUTTON_CONFIG.BuildingButton or BUTTON_CONFIG.EquipmentButton
		button.Position = config.Position
		button.Visible = true
		button.Active = true
	end
end


-- Connect to server remotes
function InventoryController:ConnectRemotes()
	-- Inventory updates
	Net.Event("UpdateInventory").OnClientEvent:Connect(function(inventory: PlayerInventory)
		self:OnInventoryUpdate(inventory)
	end)
	
	-- Item added
	Net.Event("ItemAdded").OnClientEvent:Connect(function(item: InventoryItem, quantity: number)
		self:OnItemAdded(item, quantity)
	end)
	
	-- Item removed
	Net.Event("ItemRemoved").OnClientEvent:Connect(function(itemId: string, quantity: number)
		self:OnItemRemoved(itemId, quantity)
	end)
	
	-- Equipment changed
	Net.Event("EquipmentChanged").OnClientEvent:Connect(function(slotType: string, item: InventoryItem?)
		self:OnEquipmentChanged(slotType, item)
	end)
end

-- Request initial inventory data from server
function InventoryController:RequestInventoryData()
	local success, inventory = pcall(function()
		return Net.Function("GetPlayerInventory"):InvokeServer()
	end)
	
	if success and inventory then
		self:OnInventoryUpdate(inventory)
	else
		warn("[InventoryController] Failed to get initial inventory data")
	end
end

-- Setup drag and drop functionality
function InventoryController:SetupDragAndDrop()
	-- Register hotbar slots as drop targets
	for i = 1, 10 do
		local hotbarSlot = hotbar.slots[i]
		if hotbarSlot then
			dragDropHandler:RegisterDropTarget(hotbarSlot, "Hotbar", i)
			
			-- Enable dragging from hotbar
			dragDropHandler:EnableDragForSlot(hotbarSlot, function()
				local slotData = hotbar:GetSlotData(i)
				if slotData then
					return slotData.item, slotData.quantity
				end
				return nil, nil
			end, "Hotbar", i)
		end
	end
	
	-- Register building inventory slots as drag sources and drop targets
	for i = 1, InventoryConfig.Gameplay.MaxBuildingSlots do
		local slot = buildingInventory.itemSlots[i]
		if slot then
			dragDropHandler:RegisterDropTarget(slot, "BuildingSlot", i)
			
			-- Enable dragging from building inventory
			dragDropHandler:EnableDragForSlot(slot, function()
				local itemId = slot:GetAttribute("ItemId")
				local quantity = slot:GetAttribute("Quantity")
				if itemId and playerInventoryData then
					-- Find item in inventory
					for _, invSlot in pairs(playerInventoryData.buildingItems) do
						if invSlot.item and invSlot.item.id == itemId then
							return invSlot.item, quantity
						end
					end
				end
				return nil, nil
			end, "Building", i)
		end
	end
	
	print("[InventoryController] Drag and drop setup complete")
end

-- Handle inventory update from server
function InventoryController:OnInventoryUpdate(inventory: PlayerInventory)
	playerInventoryData = inventory
	
	-- Update building inventory
	local slotIndex = 1
	for itemId, slot in pairs(inventory.buildingItems) do
		if slot.item then
			buildingInventory:UpdateItem(slotIndex, slot.item, slot.quantity)
			slotIndex = slotIndex + 1
		end
	end
	
	-- Clear remaining slots
	for i = slotIndex, InventoryConfig.Gameplay.MaxBuildingSlots do
		buildingInventory:UpdateItem(i, nil, nil)
	end
	
	-- Update equipment
	equipmentInventory:UpdateEquipmentSlot("Weapon", inventory.equipment.weapon)
	equipmentInventory:UpdateEquipmentSlot("LanternHead", inventory.equipment.lanternHead)
	equipmentInventory:UpdateEquipmentSlot("Jump", inventory.equipment.mobility.jump)
	equipmentInventory:UpdateEquipmentSlot("Dash", inventory.equipment.mobility.dash)
	equipmentInventory:UpdateEquipmentSlot("Grapple", inventory.equipment.mobility.grapple)

	for i = 1, InventoryConfig.Gameplay.MaxCurseSlots do
		local curse = inventory.equipment.curses[i]
		equipmentInventory:UpdateEquipmentSlot("Curse" .. i, curse)
	end
	
	-- Update hotbar
	for slotNum, hotbarSlot in pairs(inventory.hotbar) do
		hotbar:UpdateSlot(slotNum, hotbarSlot.item, hotbarSlot.quantity)
	end
end

-- Handle item added
function InventoryController:OnItemAdded(item: InventoryItem, quantity: number)
	-- Find empty slot and add item
	-- This would be implemented based on the item category
	print("[InventoryController] Item added:", item.name, "x" .. quantity)
end

-- Handle item removed
function InventoryController:OnItemRemoved(itemId: string, quantity: number)
	-- Find and remove/reduce item
	print("[InventoryController] Item removed:", itemId, "x" .. quantity)
end

-- Handle equipment changed
function InventoryController:OnEquipmentChanged(slotType: string, item: InventoryItem?)
	equipmentInventory:UpdateEquipmentSlot(slotType, item)
	print("[InventoryController] Equipment changed:", slotType, item and item.name or "empty")
end

-- Filter building items by category
function InventoryController:FilterBuildingItems(category: string)
	if not playerInventoryData then
		return
	end
	
	-- Implementation would filter items based on category
	print("[InventoryController] Filtering building items by:", category)
end

-- Search building items
function InventoryController:SearchBuildingItems(searchText: string)
	if not playerInventoryData then
		return
	end
	
	-- Implementation would search items by name
	print("[InventoryController] Searching building items:", searchText)
end

-- Filter equipment items by category
function InventoryController:FilterEquipmentItems(category: string)
	-- Implementation would filter equipment by category
	print("[InventoryController] Filtering equipment by:", category)
end

-- Initialize on player spawn
local function onCharacterAdded(character)
	-- Wait a bit for everything to load
	task.wait(1)
	InventoryController:Initialize()
end

if player.Character then
	onCharacterAdded(player.Character)
end

player.CharacterAdded:Connect(onCharacterAdded)

return InventoryController









