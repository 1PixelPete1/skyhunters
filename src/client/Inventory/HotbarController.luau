--!strict
-- HotbarController.luau
-- Manages the player's hotbar UI and interactions

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local InventoryConfig = require(ReplicatedStorage.Shared.Inventory.InventoryConfig)
local InventoryTypes = require(ReplicatedStorage.Shared.Inventory.InventoryTypes)
local Net = require(ReplicatedStorage.Shared.Net)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

type HotbarSlot = InventoryTypes.HotbarSlot
type InventoryItem = InventoryTypes.InventoryItem

local HotbarController = {}
HotbarController.__index = HotbarController

-- Constants
local HOTBAR_CONFIG = InventoryConfig.UI.Hotbar
local ANIMATION_CONFIG = InventoryConfig.UI.Animations
local KEYBINDS = InventoryConfig.Gameplay.Keybinds.Hotbar

function HotbarController.new()
	local self = setmetatable({}, HotbarController)
	
	self.gui = nil :: ScreenGui?
	self.container = nil :: Frame?
	self.slots = {} :: {[number]: Frame}
	self.slotData = {} :: {[number]: HotbarSlot?}
	self.selectedSlot = 1
	self.isVisible = true
	self.isDragging = false
	self.dragPreview = nil :: Frame?
	
	self:Initialize()
	
	return self
end

function HotbarController:Initialize()
	self:CreateUI()
	self:SetupInputHandling()
	self:ConnectRemotes()
end

function HotbarController:CreateUI()
	-- Create ScreenGui
	self.gui = Instance.new("ScreenGui")
	self.gui.Name = "HotbarUI"
	self.gui.ResetOnSpawn = false
	self.gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	self.gui.DisplayOrder = 1
	self.gui.Parent = playerGui
	
	-- Create main container
	self.container = Instance.new("Frame")
	self.container.Name = "HotbarContainer"
	self.container.Size = UDim2.new(
		0, 
		(HOTBAR_CONFIG.SlotSize * HOTBAR_CONFIG.MaxSlots) + (HOTBAR_CONFIG.Spacing * (HOTBAR_CONFIG.MaxSlots - 1)),
		0,
		HOTBAR_CONFIG.SlotSize
	)
	self.container.Position = HOTBAR_CONFIG.Position
	self.container.AnchorPoint = Vector2.new(0.5, 1)
	self.container.BackgroundColor3 = InventoryConfig.UI.Colors.Background
	self.container.BorderSizePixel = 0
	self.container.Parent = self.gui
	
	-- Add corner rounding
	local corner = Instance.new("UICorner")
	corner.CornerRadius = HOTBAR_CONFIG.CornerRadius
	corner.Parent = self.container
	
	-- Add padding
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 5)
	padding.PaddingRight = UDim.new(0, 5)
	padding.PaddingTop = UDim.new(0, 5)
	padding.PaddingBottom = UDim.new(0, 5)
	padding.Parent = self.container
	
	-- Create hotbar slots
	for i = 1, HOTBAR_CONFIG.MaxSlots do
		local slot = self:CreateSlot(i)
		self.slots[i] = slot
	end
	
	-- Select first slot by default
	self:SelectSlot(1)
end

function HotbarController:CreateSlot(index: number): Frame
	local slot = Instance.new("Frame")
	slot.Name = "Slot" .. index
	slot.Size = UDim2.new(0, HOTBAR_CONFIG.SlotSize, 0, HOTBAR_CONFIG.SlotSize)
	slot.Position = UDim2.new(
		0,
		(index - 1) * (HOTBAR_CONFIG.SlotSize + HOTBAR_CONFIG.Spacing),
		0,
		0
	)
	slot.BackgroundColor3 = InventoryConfig.UI.Colors.SecondaryBackground
	slot.BorderSizePixel = 0
	slot.Parent = self.container
	
	-- Corner rounding
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = slot
	
	-- Selection border (hidden by default)
	local selectionBorder = Instance.new("UIStroke")
	selectionBorder.Name = "SelectionBorder"
	selectionBorder.Color = InventoryConfig.UI.Colors.Accent
	selectionBorder.Thickness = 2
	selectionBorder.Transparency = 1
	selectionBorder.Parent = slot
	
	-- Keybind label
	local keybindLabel = Instance.new("TextLabel")
	keybindLabel.Name = "KeybindLabel"
	keybindLabel.Size = UDim2.new(0, 20, 0, 20)
	keybindLabel.Position = UDim2.new(0, 2, 0, 2)
	keybindLabel.BackgroundTransparency = 1
	keybindLabel.Text = tostring(index % 10)
	keybindLabel.TextColor3 = InventoryConfig.UI.Colors.TextSecondary
	keybindLabel.TextScaled = true
	keybindLabel.Font = Enum.Font.SourceSansBold
	keybindLabel.Parent = slot
	
	-- Item icon
	local itemIcon = Instance.new("ImageLabel")
	itemIcon.Name = "ItemIcon"
	itemIcon.Size = UDim2.new(1, -10, 1, -10)
	itemIcon.Position = UDim2.new(0.5, 0, 0.5, 0)
	itemIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	itemIcon.BackgroundTransparency = 1
	itemIcon.Image = ""
	itemIcon.ScaleType = Enum.ScaleType.Fit
	itemIcon.Visible = false
	itemIcon.Parent = slot
	
	-- Quantity label
	local quantityLabel = Instance.new("TextLabel")
	quantityLabel.Name = "QuantityLabel"
	quantityLabel.Size = UDim2.new(0, 30, 0, 20)
	quantityLabel.Position = UDim2.new(1, -2, 1, -2)
	quantityLabel.AnchorPoint = Vector2.new(1, 1)
	quantityLabel.BackgroundTransparency = 1
	quantityLabel.Text = ""
	quantityLabel.TextColor3 = InventoryConfig.UI.Colors.Text
	quantityLabel.TextScaled = true
	quantityLabel.Font = Enum.Font.SourceSansBold
	quantityLabel.Visible = false
	quantityLabel.Parent = slot
	
	-- Add hover effects
	local button = Instance.new("TextButton")
	button.Name = "Button"
	button.Size = UDim2.new(1, 0, 1, 0)
	button.BackgroundTransparency = 1
	button.Text = ""
	button.Parent = slot
	
	button.MouseEnter:Connect(function()
		if index ~= self.selectedSlot then
			TweenService:Create(
				slot,
				TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{BackgroundColor3 = InventoryConfig.UI.Colors.Border}
			):Play()
		end
	end)
	
	button.MouseLeave:Connect(function()
		if index ~= self.selectedSlot then
			TweenService:Create(
				slot,
				TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{BackgroundColor3 = InventoryConfig.UI.Colors.SecondaryBackground}
			):Play()
		end
	end)
	
	button.MouseButton1Click:Connect(function()
		self:SelectSlot(index)
	end)
	
	button.MouseButton2Click:Connect(function()
		self:OnSlotRightClick(index)
	end)
	
	return slot
end

function HotbarController:SelectSlot(index: number)
	if index < 1 or index > HOTBAR_CONFIG.MaxSlots then
		return
	end
	
	-- Deselect previous slot
	if self.selectedSlot and self.slots[self.selectedSlot] then
		local prevSlot = self.slots[self.selectedSlot]
		local prevBorder = prevSlot:FindFirstChild("SelectionBorder")
		if prevBorder then
			TweenService:Create(
				prevBorder,
				TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{Transparency = 1}
			):Play()
		end
	end
	
	-- Select new slot
	self.selectedSlot = index
	local slot = self.slots[index]
	local border = slot:FindFirstChild("SelectionBorder")
	if border then
		TweenService:Create(
			border,
			TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{Transparency = 0}
		):Play()
	end
	
	-- Fire selection event
	Net.Event("HotbarSlotSelected"):FireServer(index)
end

function HotbarController:UpdateSlot(index: number, item: InventoryItem?, quantity: number?)
	local slot = self.slots[index]
	if not slot then
		return
	end
	
	local icon = slot:FindFirstChild("ItemIcon") :: ImageLabel
	local quantityLabel = slot:FindFirstChild("QuantityLabel") :: TextLabel
	
	if item then
		-- Update slot data
		self.slotData[index] = {
			item = item,
			quantity = quantity or 1,
			slotNumber = index,
			keybind = KEYBINDS[index]
		}
		
		-- Update UI
		if icon then
			icon.Image = item.icon
			icon.Visible = true
		end
		
		if quantityLabel and quantity and quantity > 1 then
			quantityLabel.Text = tostring(quantity)
			quantityLabel.Visible = true
		elseif quantityLabel then
			quantityLabel.Visible = false
		end
	else
		-- Clear slot
		self.slotData[index] = nil
		
		if icon then
			icon.Image = ""
			icon.Visible = false
		end
		
		if quantityLabel then
			quantityLabel.Text = ""
			quantityLabel.Visible = false
		end
	end
end

function HotbarController:SetupInputHandling()
	-- Number key hotbar selection
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		
		for i, keybind in ipairs(KEYBINDS) do
			if input.KeyCode == keybind then
				self:SelectSlot(i)
				break
			end
		end
	end)
	
	-- Mouse wheel scrolling
	UserInputService.InputChanged:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			local direction = input.Position.Z > 0 and -1 or 1
			local newSlot = self.selectedSlot + direction
			
			if newSlot < 1 then
				newSlot = HOTBAR_CONFIG.MaxSlots
			elseif newSlot > HOTBAR_CONFIG.MaxSlots then
				newSlot = 1
			end
			
			self:SelectSlot(newSlot)
		end
	end)
end

function HotbarController:OnSlotRightClick(index: number)
	-- Open context menu or trigger action
	local slotData = self.slotData[index]
	if slotData and slotData.item then
		-- Fire use item event
		Net.Event("UseHotbarItem"):FireServer(index)
	end
end

function HotbarController:ConnectRemotes()
	-- Listen for hotbar updates from server
	Net.Event("UpdateHotbar").OnClientEvent:Connect(function(hotbarData)
		for i = 1, HOTBAR_CONFIG.MaxSlots do
			local data = hotbarData[i]
			if data then
				self:UpdateSlot(i, data.item, data.quantity)
			else
				self:UpdateSlot(i, nil, nil)
			end
		end
	end)
	
	-- Listen for single slot updates
	Net.Event("UpdateHotbarSlot").OnClientEvent:Connect(function(index, item, quantity)
		self:UpdateSlot(index, item, quantity)
	end)
end

function HotbarController:Show()
	if self.gui then
		self.gui.Enabled = true
		self.isVisible = true
	end
end

function HotbarController:Hide()
	if self.gui then
		self.gui.Enabled = false
		self.isVisible = false
	end
end

function HotbarController:AnimateUp(offset: number)
	if not self.container then
		return
	end
	
	local targetPosition = UDim2.new(0.5, 0, 1, -80 - offset)
	
	TweenService:Create(
		self.container,
		TweenInfo.new(
			ANIMATION_CONFIG.SlideSpeed,
			ANIMATION_CONFIG.EasingStyle,
			ANIMATION_CONFIG.EasingDirection
		),
		{Position = targetPosition}
	):Play()
end

function HotbarController:AnimateDown()
	if not self.container then
		return
	end
	
	TweenService:Create(
		self.container,
		TweenInfo.new(
			ANIMATION_CONFIG.SlideSpeed,
			ANIMATION_CONFIG.EasingStyle,
			ANIMATION_CONFIG.EasingDirection
		),
		{Position = HOTBAR_CONFIG.Position}
	):Play()
end

function HotbarController:GetSelectedItem(): InventoryItem?
	local slotData = self.slotData[self.selectedSlot]
	return slotData and slotData.item
end

function HotbarController:GetSlotData(index: number): HotbarSlot?
	return self.slotData[index]
end

function HotbarController:Destroy()
	if self.gui then
		self.gui:Destroy()
	end
end

return HotbarController