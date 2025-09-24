--!strict
-- BuildingInventoryUI.luau
-- UI creation and management for the building inventory

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InventoryConfig = require(ReplicatedStorage.Shared.Inventory.InventoryConfig)
local InventoryTypes = require(ReplicatedStorage.Shared.Inventory.InventoryTypes)

type InventoryItem = InventoryTypes.InventoryItem
type InventorySlot = InventoryTypes.InventorySlot

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local BuildingInventoryUI = {}
BuildingInventoryUI.__index = BuildingInventoryUI

-- Constants
local UI_CONFIG = InventoryConfig.UI.BuildingInventory
local COLORS = InventoryConfig.UI.Colors
local ANIMATIONS = InventoryConfig.UI.Animations
local CATEGORIES = InventoryConfig.Gameplay.BuildingCategories

function BuildingInventoryUI.new()
	local self = setmetatable({}, BuildingInventoryUI)
	
	self.gui = nil :: ScreenGui?
	self.container = nil :: Frame?
	self.categoryFrame = nil :: ScrollingFrame?
	self.gridFrame = nil :: ScrollingFrame?
	self.searchBox = nil :: TextBox?
	
	self.itemSlots = {} :: {[number]: Frame}
	self.categoryButtons = {} :: {[string]: TextButton}
	self.currentCategory = "all"
	self.isOpen = false
	
	self.onItemSelected = nil :: ((InventoryItem, number) -> ())?
	self.onItemDragStart = nil :: ((InventoryItem, Frame) -> ())?
	self.onItemDragEnd = nil :: (() -> ())?
	
	return self
end

function BuildingInventoryUI:Create()
	-- Create ScreenGui
	self.gui = Instance.new("ScreenGui")
	self.gui.Name = "BuildingInventoryUI"
	self.gui.ResetOnSpawn = false
	self.gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	self.gui.DisplayOrder = 10
	self.gui.Enabled = false
	self.gui.Parent = playerGui
	
	-- Create main container
	self.container = Instance.new("Frame")
	self.container.Name = "Container"
	self.container.Size = UI_CONFIG.Size
	self.container.Position = UI_CONFIG.Position
	self.container.AnchorPoint = Vector2.new(0.5, 1)
	self.container.BackgroundColor3 = COLORS.Background
	self.container.BorderSizePixel = 0
	self.container.Parent = self.gui
	
	-- Smooth corners
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UI_CONFIG.CornerRadius
	corner.Parent = self.container
	
	-- Add gradient
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(1, Color3.new(0.9, 0.9, 0.9))
	})
	gradient.Rotation = 90
	gradient.Parent = self.container
	
	-- Create header
	self:CreateHeader()
	
	-- Create category sidebar
	self:CreateCategorySidebar()
	
	-- Create item grid
	self:CreateItemGrid()
	
	-- Create search bar
	self:CreateSearchBar()
end

function BuildingInventoryUI:CreateHeader()
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 50)
	header.Position = UDim2.new(0, 0, 0, 0)
	header.BackgroundColor3 = COLORS.SecondaryBackground
	header.BorderSizePixel = 0
	header.Parent = self.container
	
	-- Title
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(0.5, 0, 1, 0)
	title.Position = UDim2.new(0, 20, 0, 0)
	title.BackgroundTransparency = 1
	title.Text = "Building Inventory"
	title.TextColor3 = COLORS.Text
	title.TextScaled = true
	title.Font = Enum.Font.SourceSansBold
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = header
	
	-- No close button in header anymore
	
	-- Separator
	local separator = Instance.new("Frame")
	separator.Size = UDim2.new(1, -20, 0, 1)
	separator.Position = UDim2.new(0, 10, 1, 0)
	separator.BackgroundColor3 = COLORS.Border
	separator.BorderSizePixel = 0
	separator.Parent = header
end

function BuildingInventoryUI:CreateCategorySidebar()
	-- Category container
	local categoryContainer = Instance.new("Frame")
	categoryContainer.Name = "CategoryContainer"
	categoryContainer.Size = UDim2.new(0, UI_CONFIG.CategoryWidth, 1, -110)
	categoryContainer.Position = UDim2.new(0, 0, 0, 60)
	categoryContainer.BackgroundColor3 = COLORS.SecondaryBackground
	categoryContainer.BorderSizePixel = 0
	categoryContainer.Parent = self.container
	
	-- Category list
	self.categoryFrame = Instance.new("ScrollingFrame")
	self.categoryFrame.Name = "CategoryList"
	self.categoryFrame.Size = UDim2.new(1, -10, 1, -10)
	self.categoryFrame.Position = UDim2.new(0, 5, 0, 5)
	self.categoryFrame.BackgroundTransparency = 1
	self.categoryFrame.BorderSizePixel = 0
	self.categoryFrame.ScrollBarThickness = 4
	self.categoryFrame.ScrollBarImageColor3 = COLORS.Border
	self.categoryFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	self.categoryFrame.Parent = categoryContainer
	
	-- Layout
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 5)
	layout.Parent = self.categoryFrame
	
	-- Create category buttons
	for i, category in ipairs(CATEGORIES) do
		local button = self:CreateCategoryButton(category, i)
		self.categoryButtons[category.id] = button
	end
	
	-- Update canvas size
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		self.categoryFrame.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y)
	end)
	
	-- Select "All" by default
	self:SelectCategory("all")
end

function BuildingInventoryUI:CreateCategoryButton(category: {id: string, name: string, icon: string}, order: number): TextButton
	local button = Instance.new("TextButton")
	button.Name = category.id
	button.Size = UDim2.new(1, 0, 0, 40)
	button.BackgroundColor3 = COLORS.Background
	button.BorderSizePixel = 0
	button.Text = ""
	button.LayoutOrder = order
	button.Parent = self.categoryFrame
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = button
	
	-- Icon
	local icon = Instance.new("ImageLabel")
	icon.Size = UDim2.new(0, 24, 0, 24)
	icon.Position = UDim2.new(0, 8, 0.5, 0)
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.BackgroundTransparency = 1
	icon.Image = category.icon
	icon.ImageColor3 = COLORS.TextSecondary
	icon.Parent = button
	
	-- Label
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -45, 1, 0)
	label.Position = UDim2.new(0, 40, 0, 0)
	label.BackgroundTransparency = 1
	label.Text = category.name
	label.TextColor3 = COLORS.TextSecondary
	label.TextScaled = true
	label.Font = Enum.Font.SourceSans
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = button
	
	-- Selection indicator
	local indicator = Instance.new("Frame")
	indicator.Name = "SelectionIndicator"
	indicator.Size = UDim2.new(0, 3, 0.6, 0)
	indicator.Position = UDim2.new(0, 0, 0.5, 0)
	indicator.AnchorPoint = Vector2.new(0, 0.5)
	indicator.BackgroundColor3 = COLORS.Accent
	indicator.BorderSizePixel = 0
	indicator.Visible = false
	indicator.Parent = button
	
	-- Hover effects
	button.MouseEnter:Connect(function()
		if self.currentCategory ~= category.id then
			TweenService:Create(
				button,
				TweenInfo.new(0.1),
				{BackgroundColor3 = COLORS.Border}
			):Play()
		end
	end)
	
	button.MouseLeave:Connect(function()
		if self.currentCategory ~= category.id then
			TweenService:Create(
				button,
				TweenInfo.new(0.1),
				{BackgroundColor3 = COLORS.Background}
			):Play()
		end
	end)
	
	button.MouseButton1Click:Connect(function()
		self:SelectCategory(category.id)
	end)
	
	return button
end

function BuildingInventoryUI:CreateItemGrid()
	-- Grid container
	local gridContainer = Instance.new("Frame")
	gridContainer.Name = "GridContainer"
	gridContainer.Size = UDim2.new(1, -UI_CONFIG.CategoryWidth - 20, 1, -110)
	gridContainer.Position = UDim2.new(0, UI_CONFIG.CategoryWidth + 10, 0, 60)
	gridContainer.BackgroundColor3 = COLORS.SecondaryBackground
	gridContainer.BorderSizePixel = 0
	gridContainer.Parent = self.container
	
	local gridCorner = Instance.new("UICorner")
	gridCorner.CornerRadius = UDim.new(0, 8)
	gridCorner.Parent = gridContainer
	
	-- Grid scroll frame
	self.gridFrame = Instance.new("ScrollingFrame")
	self.gridFrame.Name = "ItemGrid"
	self.gridFrame.Size = UDim2.new(1, -10, 1, -10)
	self.gridFrame.Position = UDim2.new(0, 5, 0, 5)
	self.gridFrame.BackgroundTransparency = 1
	self.gridFrame.BorderSizePixel = 0
	self.gridFrame.ScrollBarThickness = 6
	self.gridFrame.ScrollBarImageColor3 = COLORS.Border
	self.gridFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	self.gridFrame.Parent = gridContainer
	
	-- Grid layout
	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.new(0, UI_CONFIG.ItemSize, 0, UI_CONFIG.ItemSize)
	gridLayout.CellPadding = UDim2.new(0, UI_CONFIG.ItemSpacing, 0, UI_CONFIG.ItemSpacing)
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = self.gridFrame
	
	-- Create item slots
	for i = 1, UI_CONFIG.GridColumns * UI_CONFIG.GridRows do
		local slot = self:CreateItemSlot(i)
		self.itemSlots[i] = slot
	end
	
	-- Update canvas size
	gridLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		self.gridFrame.CanvasSize = UDim2.new(0, 0, 0, gridLayout.AbsoluteContentSize.Y)
	end)
end

function BuildingInventoryUI:CreateItemSlot(index: number): Frame
	local slot = Instance.new("Frame")
	slot.Name = "Slot" .. index
	slot.BackgroundColor3 = COLORS.Background
	slot.BorderSizePixel = 0
	slot.LayoutOrder = index
	slot.Parent = self.gridFrame
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = slot
	
	-- Border
	local border = Instance.new("UIStroke")
	border.Name = "Border"
	border.Color = COLORS.Border
	border.Thickness = 1
	border.Transparency = 0.5
	border.Parent = slot
	
	-- Item icon
	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.Size = UDim2.new(0.8, 0, 0.8, 0)
	icon.Position = UDim2.new(0.5, 0, 0.5, 0)
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.BackgroundTransparency = 1
	icon.Image = ""
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Visible = false
	icon.Parent = slot
	
	-- Quantity label
	local quantity = Instance.new("TextLabel")
	quantity.Name = "Quantity"
	quantity.Size = UDim2.new(0.4, 0, 0.3, 0)
	quantity.Position = UDim2.new(1, -2, 1, -2)
	quantity.AnchorPoint = Vector2.new(1, 1)
	quantity.BackgroundTransparency = 1
	quantity.Text = ""
	quantity.TextColor3 = COLORS.Text
	quantity.TextScaled = true
	quantity.Font = Enum.Font.SourceSansBold
	quantity.Visible = false
	quantity.Parent = slot
	
	-- Rarity indicator
	local rarityFrame = Instance.new("Frame")
	rarityFrame.Name = "RarityIndicator"
	rarityFrame.Size = UDim2.new(1, 0, 0, 3)
	rarityFrame.Position = UDim2.new(0, 0, 0, 0)
	rarityFrame.BackgroundColor3 = COLORS.Common
	rarityFrame.BorderSizePixel = 0
	rarityFrame.Visible = false
	rarityFrame.Parent = slot
	
	-- Interactive button
	local button = Instance.new("TextButton")
	button.Name = "Button"
	button.Size = UDim2.new(1, 0, 1, 0)
	button.BackgroundTransparency = 1
	button.Text = ""
	button.Parent = slot
	
	-- Hover effects
	button.MouseEnter:Connect(function()
		TweenService:Create(
			slot,
			TweenInfo.new(0.1),
			{Size = UDim2.new(1.05, 0, 1.05, 0)}
		):Play()
		
		TweenService:Create(
			border,
			TweenInfo.new(0.1),
			{Transparency = 0}
		):Play()
	end)
	
	button.MouseLeave:Connect(function()
		TweenService:Create(
			slot,
			TweenInfo.new(0.1),
			{Size = UDim2.new(1, 0, 1, 0)}
		):Play()
		
		TweenService:Create(
			border,
			TweenInfo.new(0.1),
			{Transparency = 0.5}
		):Play()
	end)
	
	return slot
end

function BuildingInventoryUI:CreateSearchBar()
	local searchContainer = Instance.new("Frame")
	searchContainer.Name = "SearchContainer"
	searchContainer.Size = UDim2.new(1, -20, 0, 40)
	searchContainer.Position = UDim2.new(0, 10, 1, -50)
	searchContainer.BackgroundColor3 = COLORS.SecondaryBackground
	searchContainer.BorderSizePixel = 0
	searchContainer.Parent = self.container
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = searchContainer
	
	-- Search icon
	local searchIcon = Instance.new("ImageLabel")
	searchIcon.Size = UDim2.new(0, 24, 0, 24)
	searchIcon.Position = UDim2.new(0, 10, 0.5, 0)
	searchIcon.AnchorPoint = Vector2.new(0, 0.5)
	searchIcon.BackgroundTransparency = 1
	searchIcon.Image = "rbxassetid://7734052925" -- Search icon
	searchIcon.ImageColor3 = COLORS.TextSecondary
	searchIcon.Parent = searchContainer
	
	-- Search box
	self.searchBox = Instance.new("TextBox")
	self.searchBox.Size = UDim2.new(1, -50, 1, -10)
	self.searchBox.Position = UDim2.new(0, 45, 0.5, 0)
	self.searchBox.AnchorPoint = Vector2.new(0, 0.5)
	self.searchBox.BackgroundTransparency = 1
	self.searchBox.PlaceholderText = "Search items..."
	self.searchBox.PlaceholderColor3 = COLORS.TextSecondary
	self.searchBox.Text = ""
	self.searchBox.TextColor3 = COLORS.Text
	self.searchBox.TextScaled = true
	self.searchBox.Font = Enum.Font.SourceSans
	self.searchBox.TextXAlignment = Enum.TextXAlignment.Left
	self.searchBox.ClearTextOnFocus = false
	self.searchBox.Parent = searchContainer
	
	self.searchBox:GetPropertyChangedSignal("Text"):Connect(function()
		self:OnSearchChanged(self.searchBox.Text)
	end)
end

function BuildingInventoryUI:SelectCategory(categoryId: string)
	-- Update current category
	self.currentCategory = categoryId
	
	-- Update button visuals
	for id, button in pairs(self.categoryButtons) do
		local indicator = button:FindFirstChild("SelectionIndicator")
		local label = button:FindFirstChildOfClass("TextLabel")
		local icon = button:FindFirstChildOfClass("ImageLabel")
		
		if id == categoryId then
			button.BackgroundColor3 = COLORS.Border
			if indicator then
				indicator.Visible = true
			end
			if label then
				label.TextColor3 = COLORS.Text
			end
			if icon then
				icon.ImageColor3 = COLORS.Text
			end
		else
			button.BackgroundColor3 = COLORS.Background
			if indicator then
				indicator.Visible = false
			end
			if label then
				label.TextColor3 = COLORS.TextSecondary
			end
			if icon then
				icon.ImageColor3 = COLORS.TextSecondary
			end
		end
	end
	
	-- Trigger category change callback
	if self.onCategoryChanged then
		self.onCategoryChanged(categoryId)
	end
end

function BuildingInventoryUI:UpdateItem(slotIndex: number, item: InventoryItem?, quantity: number?)
	local slot = self.itemSlots[slotIndex]
	if not slot then
		return
	end
	
	local icon = slot:FindFirstChild("Icon") :: ImageLabel
	local quantityLabel = slot:FindFirstChild("Quantity") :: TextLabel
	local rarityIndicator = slot:FindFirstChild("RarityIndicator") :: Frame
	
	if item then
		-- Update icon
		if icon then
			icon.Image = item.icon
			icon.Visible = true
		end
		
		-- Update quantity
		if quantityLabel then
			if quantity and quantity > 1 then
				quantityLabel.Text = tostring(quantity)
				quantityLabel.Visible = true
			else
				quantityLabel.Visible = false
			end
		end
		
		-- Update rarity indicator
		if rarityIndicator then
			rarityIndicator.BackgroundColor3 = COLORS[item.rarity] or COLORS.Common
			rarityIndicator.Visible = true
		end
		
		-- Store item data
		slot:SetAttribute("ItemId", item.id)
		slot:SetAttribute("Quantity", quantity or 1)
	else
		-- Clear slot
		if icon then
			icon.Visible = false
		end
		if quantityLabel then
			quantityLabel.Visible = false
		end
		if rarityIndicator then
			rarityIndicator.Visible = false
		end
		
		slot:SetAttribute("ItemId", nil)
		slot:SetAttribute("Quantity", nil)
	end
end

function BuildingInventoryUI:Open()
	if self.isOpen then
		return
	end
	
	self.isOpen = true
	self.gui.Enabled = true
	
	-- Animate in
	self.container.Position = UI_CONFIG.Position
	TweenService:Create(
		self.container,
		TweenInfo.new(
			ANIMATIONS.SlideSpeed,
			ANIMATIONS.EasingStyle,
			ANIMATIONS.EasingDirection
		),
		{Position = UI_CONFIG.AnimatedPosition}
	):Play()
	
	-- Trigger open callback
	if self.onOpen then
		self.onOpen()
	end
end

function BuildingInventoryUI:Close()
	if not self.isOpen then
		return
	end
	
	self.isOpen = false
	
	-- Animate out
	local tween = TweenService:Create(
		self.container,
		TweenInfo.new(
			ANIMATIONS.SlideSpeed,
			ANIMATIONS.EasingStyle,
			Enum.EasingDirection.In
		),
		{Position = UI_CONFIG.Position}
	)
	
	tween.Completed:Connect(function()
		self.gui.Enabled = false
	end)
	
	tween:Play()
	
	-- Trigger close callback
	if self.onClose then
		self.onClose()
	end
end

function BuildingInventoryUI:OnSearchChanged(searchText: string)
	-- Trigger search callback
	if self.onSearch then
		self.onSearch(searchText)
	end
end

function BuildingInventoryUI:SetOnItemSelected(callback: (InventoryItem, number) -> ())
	self.onItemSelected = callback
end

function BuildingInventoryUI:SetOnCategoryChanged(callback: (string) -> ())
	self.onCategoryChanged = callback
end

function BuildingInventoryUI:SetOnSearch(callback: (string) -> ())
	self.onSearch = callback
end

function BuildingInventoryUI:SetOnOpen(callback: () -> ())
	self.onOpen = callback
end

function BuildingInventoryUI:SetOnClose(callback: () -> ())
	self.onClose = callback
end

function BuildingInventoryUI:Destroy()
	if self.gui then
		self.gui:Destroy()
	end
end

return BuildingInventoryUI
