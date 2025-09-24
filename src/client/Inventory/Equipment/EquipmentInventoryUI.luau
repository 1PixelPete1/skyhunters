--!strict
-- EquipmentInventoryUI.luau
-- UI creation and management for the equipment inventory

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

local InventoryConfig = require(ReplicatedStorage.Shared.Inventory.InventoryConfig)
local InventoryTypes = require(ReplicatedStorage.Shared.Inventory.InventoryTypes)

type InventoryItem = InventoryTypes.InventoryItem

type EquipmentSlotDefinition = {
	center: Vector2,
	size: number,
	labelOffset: number,
	isDiamond: boolean?,
}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local EquipmentInventoryUI = {}
EquipmentInventoryUI.__index = EquipmentInventoryUI

local UI_CONFIG = InventoryConfig.UI.EquipmentInventory
local COLORS = InventoryConfig.UI.Colors
local ANIMATIONS = InventoryConfig.UI.Animations
local CATEGORIES = InventoryConfig.Gameplay.EquipmentCategories

local DEFAULT_ITEM_COLUMNS = 9  -- Optimized column count
local DEFAULT_ITEM_SPACING = 6  -- Better spacing
local DEFAULT_ITEM_SIZE = 64  -- Larger, more visible slots

local VIEWPORT_INITIAL_SIZE = UDim2.new(1, 0, 1, 0)
local VIEWPORT_INITIAL_POSITION = UDim2.new(0.5, 0, 0.5, 0)
local VIEWPORT_TARGET_SIZE = UDim2.new(0.55, 0, 0.85, 0)
local VIEWPORT_TARGET_POSITION = UDim2.new(0.76, 0, 0.44, 0)  -- Nudge northeast to align with slots
local VIEWPORT_CAMERA_OFFSET = CFrame.new(0, 3.4, -10) * CFrame.Angles(math.rad(-5), math.rad(-18), 0)
local VIEWPORT_LOOK_OFFSET = Vector3.new(0, 1.6, 0)
local OVERLAY_TARGET_TRANSPARENCY = 0
local OVERLAY_START_TRANSPARENCY = 0.05
local CLOSE_BUTTON_MARGIN = Vector2.new(60, 30)  -- Positioned above inventory

local function safeTween(instance: Instance, info: TweenInfo, props: any): Tween
	local tween = TweenService:Create(instance, info, props)
	tween:Play()
	return tween
end

function EquipmentInventoryUI.new()
	local self = setmetatable({}, EquipmentInventoryUI)

	self.gui = nil :: ScreenGui?
	self.backgroundFrame = nil :: Frame?
	self.viewportFrame = nil :: ViewportFrame?
	self.viewportWorld = nil :: WorldModel?
	self.viewportCamera = nil :: Camera?
	self.viewportCharacter = nil :: Model?

	self.container = nil :: Frame?
	self.categoryFrame = nil :: Frame?
	self.itemListFrame = nil :: ScrollingFrame?
	self.equipmentSlotsFrame = nil :: Frame?
	self.closeButton = nil :: TextButton?

	self.categoryButtons = {} :: {[string]: TextButton}
	self.itemSlots = {} :: {[number]: Frame}
	self.equipmentSlots = {} :: {[string]: Frame}

	self.currentCategory = "all"
	self.isOpen = false

	self.originalCamera = nil :: CFrame?
	self.originalCameraType = nil :: Enum.CameraType?
	self.cameraTween = nil :: Tween?
	self.originalLighting = {}
	self.viewportFrameTween = nil :: Tween?
	self.viewportCameraTween = nil :: Tween?
	self.viewportTargetCameraCFrame = nil :: CFrame?
	self.basePivotCFrame = nil :: CFrame?
	self.originalTransparency = {} :: {[Instance]: number}
	self.originalWeatherStates = nil :: {[Instance]: any}?
	self.isDragging = false :: boolean
	self.dragStartX = 0 :: number
	self.viewportRotation = 0 :: number
	self.dragConnections = nil :: {[string]: RBXScriptConnection}?

	self.onCategoryChanged = nil :: ((string) -> ())?
	self.onOpen = nil :: (() -> ())?
	self.onClose = nil :: (() -> ())?

	return self
end

function EquipmentInventoryUI:Create()
	self.gui = Instance.new("ScreenGui")
	self.gui.Name = "EquipmentInventoryUI"
	self.gui.ResetOnSpawn = false
	self.gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	self.gui.DisplayOrder = 11
	self.gui.IgnoreGuiInset = true
	self.gui.Enabled = false
	self.gui.Parent = playerGui

	self.backgroundFrame = Instance.new("Frame")
	self.backgroundFrame.Name = "Background"
	self.backgroundFrame.Size = UDim2.new(1, 0, 1, 0)
	self.backgroundFrame.BackgroundColor3 = Color3.fromRGB(28, 30, 36)
	self.backgroundFrame.BackgroundTransparency = 1
	self.backgroundFrame.BorderSizePixel = 0
	self.backgroundFrame.ZIndex = 1
	self.backgroundFrame.Parent = self.gui

	self.viewportFrame = Instance.new("ViewportFrame")
	self.viewportFrame.Name = "CharacterViewport"
	self.viewportFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	-- Use final/static size and position from the start (no open tween)
	self.viewportFrame.Size = VIEWPORT_TARGET_SIZE
	self.viewportFrame.Position = VIEWPORT_TARGET_POSITION
	self.viewportFrame.BackgroundTransparency = 1
	self.viewportFrame.BorderSizePixel = 0
	self.viewportFrame.LightColor = Color3.new(1, 1, 1)
	self.viewportFrame.Ambient = Color3.fromRGB(78, 80, 92)
	self.viewportFrame.Visible = false
	self.viewportFrame.ZIndex = 2
	self.viewportFrame.Parent = self.gui

	self.viewportWorld = Instance.new("WorldModel")
	self.viewportWorld.Name = "ViewportWorld"
	self.viewportWorld.Parent = self.viewportFrame

	self.viewportCamera = Instance.new("Camera")
	self.viewportCamera.Name = "ViewportCamera"
	self.viewportCamera.FieldOfView = 38
	self.viewportCamera.Parent = self.viewportFrame
	self.viewportFrame.CurrentCamera = self.viewportCamera

	self.container = Instance.new("Frame")
	self.container.Name = "Container"
	self.container.Size = UDim2.new(0.4, 0, 0.85, 0)  -- Narrower container
	self.container.Position = UDim2.new(0.05, 0, 0.5, 0)
	self.container.AnchorPoint = Vector2.new(0, 0.5)
	self.container.BackgroundTransparency = 0.3  -- Semi-transparent background
	self.container.BackgroundColor3 = COLORS.Background
	self.container.BorderSizePixel = 0
	self.container.ZIndex = 3
	self.container.Parent = self.gui
	
	local containerCorner = Instance.new("UICorner")
	containerCorner.CornerRadius = UI_CONFIG.CornerRadius
	containerCorner.Parent = self.container

	self.closeButton = Instance.new("TextButton")
	self.closeButton.Name = "CloseButton"
	self.closeButton.AnchorPoint = Vector2.new(1, 0)
	self.closeButton.Position = UDim2.new(1, -CLOSE_BUTTON_MARGIN.X, 0, CLOSE_BUTTON_MARGIN.Y)
	self.closeButton.Size = UDim2.new(0, 48, 0, 48)
	self.closeButton.BackgroundColor3 = COLORS.Border
	self.closeButton.Text = "="  -- Changed to = symbol
	self.closeButton.TextColor3 = COLORS.Text
	self.closeButton.TextScaled = true
	self.closeButton.Font = Enum.Font.Gotham
	self.closeButton.ZIndex = 5
	self.closeButton.Parent = self.gui

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 10)
	closeCorner.Parent = self.closeButton

	self.closeButton.MouseButton1Click:Connect(function()
		self:Close()
	end)

	self:CreateHeader()
	self:CreateCategoryTabs()
	self:CreateItemList()
	self:CreateEquipmentSlots()
	self:SelectCategory("all")
	
	-- Setup dragging after UI is created
	self:SetupViewportDragging()
end

function EquipmentInventoryUI:SetupViewportDragging()
	local UserInputService = game:GetService("UserInputService")
	
	-- Store connections to clean them up later
	self.dragConnections = {}
	
	self.dragConnections.mouseDown = self.viewportFrame.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			self.isDragging = true
			self.dragStartX = UserInputService:GetMouseLocation().X
		end
	end)
	
	self.dragConnections.mouseUp = UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			self.isDragging = false
		end
	end)
	
	self.dragConnections.mouseMove = UserInputService.InputChanged:Connect(function(input)
		if self.isDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			local currentX = UserInputService:GetMouseLocation().X
			local deltaX = currentX - self.dragStartX
			self.dragStartX = currentX
			
			-- Rotate based on horizontal drag
			self.viewportRotation = self.viewportRotation + (deltaX * 0.5)
			
			-- Update camera position
			self:UpdateViewportCamera()
		end
	end)
end

function EquipmentInventoryUI:CreateHeader()
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 56)
	header.BackgroundColor3 = COLORS.SecondaryBackground
	header.BorderSizePixel = 0
	header.ZIndex = 3
	header.Parent = self.container

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(0.7, 0, 1, 0)
	title.Position = UDim2.new(0, 20, 0, 0)
	title.Text = "Equipment"
	title.TextColor3 = COLORS.Text
	title.TextScaled = true
	title.Font = Enum.Font.GothamBold
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.ZIndex = 4
	title.Parent = header
end

function EquipmentInventoryUI:CreateCategoryTabs()
	self.categoryFrame = Instance.new("Frame")
	self.categoryFrame.Name = "CategoryTabs"
	self.categoryFrame.Size = UDim2.new(1, -20, 0, 44)
	self.categoryFrame.Position = UDim2.new(0, 10, 0, 64)
	self.categoryFrame.BackgroundTransparency = 1
	self.categoryFrame.ZIndex = 3
	self.categoryFrame.Parent = self.container

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = self.categoryFrame

	for _, category in ipairs(CATEGORIES) do
		local tab = Instance.new("TextButton")
		tab.Name = category.id
		tab.Size = UDim2.new(1 / #CATEGORIES, -6, 1, 0)
		tab.BackgroundColor3 = COLORS.SecondaryBackground
		tab.BorderSizePixel = 0
		tab.Text = ""
		tab.ZIndex = 3
		tab.Parent = self.categoryFrame

		local tabCorner = Instance.new("UICorner")
		tabCorner.CornerRadius = UDim.new(0, 8)
		tabCorner.Parent = tab

		local icon = Instance.new("ImageLabel")
		icon.Name = "Icon"
		icon.BackgroundTransparency = 1
		icon.Size = UDim2.fromOffset(20, 20)
		icon.Position = UDim2.new(0, 10, 0.5, 0)
		icon.AnchorPoint = Vector2.new(0, 0.5)
		icon.Image = category.icon
		icon.ImageColor3 = COLORS.TextSecondary
		icon.ZIndex = 4
		icon.Parent = tab

		local label = Instance.new("TextLabel")
		label.Name = "Label"
		label.BackgroundTransparency = 1
		label.Size = UDim2.new(1, -38, 1, 0)
		label.Position = UDim2.new(0, 36, 0, 0)
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Text = category.name
		label.TextColor3 = COLORS.TextSecondary
		label.Font = Enum.Font.Gotham
		label.TextSize = 16
		label.ZIndex = 4
		label.Parent = tab

		tab.MouseButton1Click:Connect(function()
			self:SelectCategory(category.id)
		end)

		tab.MouseEnter:Connect(function()
			if self.currentCategory ~= category.id then
				safeTween(tab, TweenInfo.new(0.12), {BackgroundColor3 = COLORS.Border})
			end
		end)

		tab.MouseLeave:Connect(function()
			if self.currentCategory ~= category.id then
				safeTween(tab, TweenInfo.new(0.12), {BackgroundColor3 = COLORS.SecondaryBackground})
			end
		end)

		self.categoryButtons[category.id] = tab
	end
end

function EquipmentInventoryUI:CreateItemList()
	-- Create item list container with full background
	local itemContainer = Instance.new("Frame")
	itemContainer.Name = "ItemContainer"
	itemContainer.Size = UDim2.new(1.15, 0, 1, -156)  -- Wider than container for grid
	itemContainer.Position = UDim2.new(0, 0, 0, 116)
	itemContainer.BackgroundTransparency = 1  -- Fully transparent
	itemContainer.BorderSizePixel = 0
	itemContainer.ZIndex = 2
	itemContainer.ClipsDescendants = true
	itemContainer.Parent = self.container
	
	self.itemListFrame = Instance.new("ScrollingFrame")
	self.itemListFrame.Name = "ItemList"
	self.itemListFrame.Size = UDim2.new(1, -10, 1, 0)
	self.itemListFrame.Position = UDim2.new(0, 5, 0, 0)
	self.itemListFrame.BackgroundTransparency = 1
	self.itemListFrame.BorderSizePixel = 0
	self.itemListFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	self.itemListFrame.ScrollBarThickness = 6
	self.itemListFrame.ZIndex = 3
	self.itemListFrame.Parent = itemContainer

	local columns = UI_CONFIG.GridColumns or DEFAULT_ITEM_COLUMNS
	local spacing = UI_CONFIG.ItemSpacing or DEFAULT_ITEM_SPACING
	local slotSize = UI_CONFIG.SlotSize or DEFAULT_ITEM_SIZE

	-- Adjust grid to fill the width properly
	local containerActualWidth = self.itemListFrame.AbsoluteSize.X
	if containerActualWidth == 0 then
		-- Use estimated width based on expanded item area
		containerActualWidth = (0.4 * 1.15 * 1920) - 10
	end
	
	-- Calculate optimal slot size to fill width
	local totalSpacing = (columns - 1) * spacing
	local availableWidth = containerActualWidth - 6  -- Account for scrollbar
	local optimalSlotSize = math.floor((availableWidth - totalSpacing) / columns)
	local finalSlotSize = math.min(optimalSlotSize, slotSize)  -- Don't exceed max size
	
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(finalSlotSize, finalSlotSize)
	grid.CellPadding = UDim2.fromOffset(spacing, spacing)
	grid.FillDirectionMaxCells = columns
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = self.itemListFrame

	-- Calculate slots to fill viewport without scrollbar
	-- Item grid takes up more width than container
	local containerWidth = (0.4 * 1.15 * 1920) - 10  -- Expanded width for items
	local containerHeight = (0.85 * 1080) - 156  -- 85% of screen height minus header/tabs
	local columns = DEFAULT_ITEM_COLUMNS
	local slotSize = DEFAULT_ITEM_SIZE
	local spacing = DEFAULT_ITEM_SPACING
	
	-- Calculate rows that fit without scrollbar
	local availableHeight = containerHeight - 20  -- Account for padding
	local rowHeight = slotSize + spacing
	local maxRows = math.floor(availableHeight / rowHeight)
	local maxSlots = columns * maxRows
	
	for slotIndex = 1, maxSlots do
		local slot = Instance.new("Frame")
		slot.Name = "ItemSlot" .. slotIndex
		slot.BackgroundColor3 = COLORS.SecondaryBackground
		slot.BorderSizePixel = 0
		slot.ZIndex = 3
		slot.Parent = self.itemListFrame

		local slotCorner = Instance.new("UICorner")
		slotCorner.CornerRadius = UDim.new(0, 8)
		slotCorner.Parent = slot

		local icon = Instance.new("ImageLabel")
		icon.Name = "Icon"
		icon.BackgroundTransparency = 1
		icon.Size = UDim2.new(0.82, 0, 0.82, 0)
		icon.Position = UDim2.new(0.5, 0, 0.5, 0)
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.Visible = false
		icon.ZIndex = 4
		icon.Parent = slot

		self.itemSlots[slotIndex] = slot
	end

	grid:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		self.itemListFrame.CanvasSize = UDim2.new(0, 0, 0, grid.AbsoluteContentSize.Y)
	end)
end

function EquipmentInventoryUI:CreateEquipmentSlots()
	self.equipmentSlotsFrame = Instance.new("Frame")
	self.equipmentSlotsFrame.Name = "EquipmentSlots"
	local SLOT_FRAME_SIZE = Vector2.new(360, 520)
	self.equipmentSlotsFrame.Size = UDim2.fromOffset(SLOT_FRAME_SIZE.X, SLOT_FRAME_SIZE.Y)
	self.equipmentSlotsFrame.Position = self.viewportFrame.Position
	self.equipmentSlotsFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	self.equipmentSlotsFrame.BackgroundTransparency = 1
	self.equipmentSlotsFrame.ZIndex = 4
	self.equipmentSlotsFrame.Parent = self.gui

	-- Equipment slots positioned around the viewport playermodel
	local labelOffsetAbove = -(UI_CONFIG.SlotSize * 0.5 + 30)
	local labelOffsetBelow = UI_CONFIG.SlotSize * 0.5 + 34
	local function layout(xPercent: number, yPercent: number, offset: number): EquipmentSlotDefinition
		return {
			center = Vector2.new(SLOT_FRAME_SIZE.X * xPercent, SLOT_FRAME_SIZE.Y * yPercent),
			size = UI_CONFIG.SlotSize,
			labelOffset = offset
		}
	end

	local definitions: {[string]: EquipmentSlotDefinition} = {
		LanternHead = layout(0.5, 0.18, labelOffsetAbove),
		Weapon = layout(0.78, 0.45, labelOffsetAbove),
		Grapple = layout(0.22, 0.45, labelOffsetAbove),
		Jump = layout(0.32, 0.73, labelOffsetBelow),
		Dash = layout(0.68, 0.73, labelOffsetBelow),
	}

	for slotType, def in pairs(definitions) do
		self.equipmentSlots[slotType] = self:CreateEquipmentSlot(slotType, def)
	end

	local CURSE_LABEL_OFFSET = UI_CONFIG.CurseSlotSize * 0.5 + 34
	local curseCenters = {
		Vector2.new(SLOT_FRAME_SIZE.X * 0.36, SLOT_FRAME_SIZE.Y * 0.86),
		Vector2.new(SLOT_FRAME_SIZE.X * 0.5, SLOT_FRAME_SIZE.Y * 0.92),
		Vector2.new(SLOT_FRAME_SIZE.X * 0.64, SLOT_FRAME_SIZE.Y * 0.86),
	}

	for index, center in ipairs(curseCenters) do
		self.equipmentSlots["Curse" .. index] = self:CreateEquipmentSlot("Curse" .. index, {
			center = center,
			size = UI_CONFIG.CurseSlotSize,
			labelOffset = CURSE_LABEL_OFFSET,
			isDiamond = true,
		})
	end
end

function EquipmentInventoryUI:CreateEquipmentSlot(slotType: string, def: EquipmentSlotDefinition): Frame
	local size = def.size
	local slot = Instance.new("Frame")
	slot.Name = slotType .. "Slot"
	slot.Size = UDim2.fromOffset(size, size)
	slot.AnchorPoint = Vector2.new(0.5, 0.5)
	slot.Position = UDim2.fromOffset(def.center.X, def.center.Y)
	slot.BackgroundColor3 = COLORS.Background
	slot.BackgroundTransparency = 0.1
	slot.BorderSizePixel = 0
	slot.ZIndex = 5
	slot.Parent = self.equipmentSlotsFrame

	if def.isDiamond then
		slot.Rotation = 45
	else
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 12)
		corner.Parent = slot
	end

	local stroke = Instance.new("UIStroke")
	stroke.Color = COLORS.Border
	stroke.Transparency = 0.2
	stroke.Thickness = 2
	stroke.Parent = slot

	local iconHolder = Instance.new("Frame")
	iconHolder.Name = "IconHolder"
	iconHolder.BackgroundTransparency = 1
	iconHolder.Size = UDim2.new(0.82, 0, 0.82, 0)
	iconHolder.Position = UDim2.fromScale(0.5, 0.5)
	iconHolder.AnchorPoint = Vector2.new(0.5, 0.5)
	iconHolder.Rotation = def.isDiamond and -45 or 0
	iconHolder.ZIndex = slot.ZIndex + 1
	iconHolder.Parent = slot

	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.Size = UDim2.new(1, 0, 1, 0)
	icon.Image = ""
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Visible = false
	icon.ZIndex = iconHolder.ZIndex + 1
	icon.Parent = iconHolder

	local dropArea = Instance.new("TextButton")
	dropArea.Name = "DropArea"
	dropArea.BackgroundTransparency = 1
	dropArea.Size = UDim2.new(1, 0, 1, 0)
	dropArea.Text = ""
	dropArea.AutoButtonColor = false
	dropArea.ZIndex = slot.ZIndex + 2
	dropArea.Parent = slot

	local labelOffset = def.labelOffset or -(size * 0.5 + 28)
	local labelAnchorY = labelOffset < 0 and 1 or 0
	local label = Instance.new("TextLabel")
	label.Name = slotType .. "Label"
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(0, size + 32, 0, 22)
	label.Position = UDim2.fromOffset(def.center.X, def.center.Y + labelOffset)
	label.AnchorPoint = Vector2.new(0.5, labelAnchorY)
	local pretty = slotType
	if slotType == "LanternHead" then pretty = "Lantern Head" end
	label.Text = pretty
	label.TextColor3 = COLORS.TextSecondary
	label.Font = Enum.Font.GothamMedium
	label.TextSize = 16
	label.ZIndex = slot.ZIndex
	label.Parent = self.equipmentSlotsFrame

	return slot
end

function EquipmentInventoryUI:SelectCategory(categoryId: string)
	self.currentCategory = categoryId

	for id, tab in pairs(self.categoryButtons) do
		local icon = tab:FindFirstChild("Icon") :: ImageLabel?
		local label = tab:FindFirstChild("Label") :: TextLabel?
		local active = id == categoryId
		local targetColor = active and COLORS.Accent or COLORS.SecondaryBackground
		safeTween(tab, TweenInfo.new(0.15), {BackgroundColor3 = targetColor})

		if icon then
			icon.ImageColor3 = active and COLORS.Text or COLORS.TextSecondary
		end
		if label then
			label.TextColor3 = active and COLORS.Text or COLORS.TextSecondary
		end
	end

	if self.onCategoryChanged then
		self.onCategoryChanged(categoryId)
	end
end

function EquipmentInventoryUI:UpdateItem(slotIndex: number, item: InventoryItem?)
	local slot = self.itemSlots[slotIndex]
	if not slot then
		return
	end

	local icon = slot:FindFirstChild("Icon") :: ImageLabel?
	if not icon then
		return
	end

	if item and item.icon and item.icon ~= "" then
		icon.Image = item.icon
		icon.Visible = true
		icon.ImageTransparency = 0
	else
		icon.Visible = false
		icon.Image = ""
	end
end

function EquipmentInventoryUI:UpdateEquipmentSlot(slotType: string, item: InventoryItem?)
	local slot = self.equipmentSlots[slotType]
	if not slot then
		return
	end

	local iconHolder = slot:FindFirstChild("IconHolder")
	local icon = iconHolder and iconHolder:FindFirstChild("Icon") :: ImageLabel?
	if not icon then
		return
	end

	if item and item.icon and item.icon ~= "" then
		icon.Image = item.icon
		icon.Visible = true
	else
		icon.Visible = false
		icon.Image = ""
	end
end

function EquipmentInventoryUI:SetOnCategoryChanged(callback: (string) -> ())
	self.onCategoryChanged = callback
end

function EquipmentInventoryUI:SetOnOpen(callback: () -> ())
	self.onOpen = callback
end

function EquipmentInventoryUI:SetOnClose(callback: () -> ())
	self.onClose = callback
end

local function prepareClone(model: Model)
    for _, descendant in ipairs(model:GetDescendants()) do
        if descendant:IsA("BasePart") then
            -- Anchor parts to avoid physics cost inside the viewport; animations still pose via joints.
            descendant.Anchored = true
            descendant.CanCollide = false
        elseif descendant:IsA("BaseScript") then
            descendant:Destroy()
        elseif descendant:IsA("ParticleEmitter") then
            descendant.Enabled = false
        end
    end
end

function EquipmentInventoryUI:SyncViewport()
	if not self.viewportWorld or not self.viewportCamera then
		return
	end

	self.viewportWorld:ClearAllChildren()
	self.viewportCharacter = nil
	self.viewportTargetCameraCFrame = nil

	local character = player.Character
	local camera = Workspace.CurrentCamera
	if not (character and camera) then
		return
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart
	if not rootPart then
		return
	end

	local archivable = character.Archivable
	if not archivable then
		character.Archivable = true
	end

	local ok, clone = pcall(function()
		return character:Clone()
	end)

	if not archivable then
		character.Archivable = false
	end

	if not ok or not clone then
		return
	end

	prepareClone(clone)
	clone.Parent = self.viewportWorld
	self.viewportCharacter = clone

	-- Replace Humanoid with AnimationController for low-cost animation playback
	local humanoid = clone:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid:Destroy()
	end
	local animController = clone:FindFirstChildOfClass("AnimationController")
	if not animController then
		animController = Instance.new("AnimationController")
		animController.Parent = clone
	end
	if not animController:FindFirstChildOfClass("Animator") then
		local animator = Instance.new("Animator")
		animator.Parent = animController
	end

	-- Reset all joint/bone transforms for a default standing pose (no snapshot keyframe)
	for _, d in ipairs(clone:GetDescendants()) do
		if d:IsA("Motor6D") then
			d.Transform = CFrame.new()
		elseif d.ClassName == "Bone" then
			d.Transform = CFrame.new()
		end
	end

	-- Position character to face forward (workspace camera will handle rotation)
	local basePos = Vector3.new(0, 0, 0)
	local finalCFrame = CFrame.new(basePos)
	clone:PivotTo(finalCFrame)
	self.basePivotCFrame = finalCFrame
	
	-- Reset rotation for drag
	self.viewportRotation = 0

	-- Set viewport camera to view the character
	local cloneRoot = clone:FindFirstChild("HumanoidRootPart") or clone.PrimaryPart
	if cloneRoot then
		local targetPos = (cloneRoot.CFrame * VIEWPORT_CAMERA_OFFSET).Position
		local targetLook = cloneRoot.Position + cloneRoot.CFrame:VectorToWorldSpace(VIEWPORT_LOOK_OFFSET)
		self.viewportCamera.CFrame = CFrame.new(targetPos, targetLook)
		self.viewportTargetCameraCFrame = self.viewportCamera.CFrame
	end
	-- Do not mirror or play animations; keep default standing pose
end

function EquipmentInventoryUI:UpdateViewportCamera()
	-- Handle drag rotation only; keep camera fixed
	if not self.viewportCharacter or not self.viewportCamera then
		return
	end

	-- Simply rotate the character model in place
	local cloneRoot = self.viewportCharacter:FindFirstChild("HumanoidRootPart") or self.viewportCharacter.PrimaryPart
	if cloneRoot then
		-- Rotate character around Y axis smoothly
		local rotation = CFrame.Angles(0, math.rad(self.viewportRotation), 0)
		self.viewportCharacter:PivotTo(CFrame.new(0, 0, 0) * rotation)
	end
end

-- Animation mirroring: play the same animations in the viewport as the player
function EquipmentInventoryUI:StartMirroringAnimations()
	-- No-op: viewport uses a static pose snapshot now.
end

function EquipmentInventoryUI:StopMirroringAnimations()
	-- No-op placeholder to keep teardown calls safe.
end
-- No idle animation function; viewport uses default standing pose

function EquipmentInventoryUI:SetCharacterVisible(isVisible: boolean)
	local character = player.Character
	if not character then
		if isVisible then
			table.clear(self.originalTransparency)
		end
		return
	end

	if isVisible then
		for inst, value in pairs(self.originalTransparency) do
			if inst:IsA("BasePart") then
				inst.LocalTransparencyModifier = value
			elseif inst:IsA("Decal") then
				inst.Transparency = value
			end
		end
		table.clear(self.originalTransparency)
	else
		if next(self.originalTransparency) ~= nil then
			return
		end
		for _, descendant in ipairs(character:GetDescendants()) do
			if descendant:IsA("BasePart") then
				self.originalTransparency[descendant] = descendant.LocalTransparencyModifier
				descendant.LocalTransparencyModifier = 1
			elseif descendant:IsA("Decal") then
				self.originalTransparency[descendant] = descendant.Transparency
				descendant.Transparency = 1
			end
		end
	end
end

function EquipmentInventoryUI:Open()
    if self.isOpen then
        return
    end
    self.isOpen = true
    -- Do not modify the workspace camera; show UI immediately.
    self:ShowInventoryUI()
end

function EquipmentInventoryUI:ShowInventoryUI()
	if self.gui then
		self.gui.Enabled = true
	end

	if self.backgroundFrame then
		self.backgroundFrame.BackgroundTransparency = OVERLAY_START_TRANSPARENCY
		safeTween(self.backgroundFrame, TweenInfo.new(ANIMATIONS.FadeSpeed), {BackgroundTransparency = OVERLAY_TARGET_TRANSPARENCY})
	end

    if self.viewportFrame then
        -- Show immediately at final size/position (no tween)
        self.viewportFrame.Visible = true
        self.viewportFrame.AnchorPoint = Vector2.new(0.5, 0.5)
        self.viewportFrame.Size = VIEWPORT_TARGET_SIZE
        self.viewportFrame.Position = VIEWPORT_TARGET_POSITION
    end

	-- Sync viewport (character will be facing forward)
	self:SyncViewport()
    -- Keep player visible; do not hide the live character

    -- No viewport frame tween on open

	if InventoryConfig.Performance.DisableWeatherInMenu then
		-- Store original lighting settings
		self.originalLighting.FogEnd = Lighting.FogEnd
		self.originalLighting.FogStart = Lighting.FogStart
		self.originalLighting.Brightness = Lighting.Brightness
		self.originalLighting.Ambient = Lighting.Ambient
		self.originalLighting.OutdoorAmbient = Lighting.OutdoorAmbient
		
		-- Disable fog and optimize lighting
		Lighting.FogEnd = 100000
		Lighting.FogStart = 100000
		
		-- Disable weather particle effects in workspace
		self:DisableWeatherEffects()
	end

	if self.container then
		self.container.BackgroundTransparency = 1
		safeTween(self.container, TweenInfo.new(ANIMATIONS.FadeSpeed), {BackgroundTransparency = 0.3})
	end

	if self.onOpen then
		self.onOpen()
	end
end

function EquipmentInventoryUI:Close()
	if not self.isOpen then
		return
	end

	self.isOpen = false

	-- Fade UI out in sync before disabling the GUI

    -- Only restore camera if we had changed it (we no longer do).
    if self.originalCamera or self.originalCameraType then
        local camera = Workspace.CurrentCamera
        if camera then
            if self.cameraTween then
                self.cameraTween:Cancel()
                self.cameraTween = nil
            end

            if self.originalCamera then
                camera.CameraType = Enum.CameraType.Scriptable
                local targetType = self.originalCameraType or Enum.CameraType.Custom
                self.cameraTween = safeTween(
                    camera,
                    TweenInfo.new(ANIMATIONS.SlideSpeed, ANIMATIONS.EasingStyle, ANIMATIONS.EasingDirection),
                    {CFrame = self.originalCamera}
                )
                self.cameraTween.Completed:Connect(function()
                    camera.CameraType = targetType
                    self.cameraTween = nil
                end)
            elseif self.originalCameraType then
                camera.CameraType = self.originalCameraType
            end
        end
        self.originalCamera = nil
        self.originalCameraType = nil
    end

	if InventoryConfig.Performance.DisableWeatherInMenu then
		-- Restore original lighting
		for propertyName, value in pairs(self.originalLighting) do
			Lighting[propertyName] = value
		end
		self.originalLighting = {}
		
		-- Re-enable weather effects
		self:EnableWeatherEffects()
	end

	if self.viewportCameraTween then
		self.viewportCameraTween:Cancel()
		self.viewportCameraTween = nil
	end

	local function teardownViewport()
		if self.viewportWorld then
			self:StopMirroringAnimations()
			self.viewportWorld:ClearAllChildren()
		end
		if self.viewportFrame then
			self.viewportFrame.Visible = false
		end
		self.viewportCharacter = nil
		self.viewportTargetCameraCFrame = nil
	end

	-- Fade out container and background together, then disable GUI and teardown viewport
	if self.container then
		safeTween(self.container, TweenInfo.new(ANIMATIONS.FadeSpeed), {BackgroundTransparency = 1})
	end
	if self.backgroundFrame then
		safeTween(self.backgroundFrame, TweenInfo.new(ANIMATIONS.FadeSpeed), {BackgroundTransparency = 1})
	end

	task.delay(ANIMATIONS.FadeSpeed, function()
		teardownViewport()
		if not self.isOpen and self.gui then
			self.gui.Enabled = false
		end
	end)

	if self.onClose then
		self.onClose()
	end
end

function EquipmentInventoryUI:DisableWeatherEffects()
	-- Find and disable weather particle effects
	for _, obj in ipairs(Workspace:GetDescendants()) do
		if obj:IsA("ParticleEmitter") or obj:IsA("Beam") then
			local name = obj.Name:lower()
			if name:find("rain") or name:find("snow") or name:find("fog") or 
			   name:find("storm") or name:find("weather") or name:find("wind") then
				if not self.originalWeatherStates then
					self.originalWeatherStates = {}
				end
				self.originalWeatherStates[obj] = obj.Enabled
				obj.Enabled = false
			end
		elseif obj:IsA("Atmosphere") then
			if not self.originalWeatherStates then
				self.originalWeatherStates = {}
			end
			self.originalWeatherStates[obj] = {
				Density = obj.Density,
				Haze = obj.Haze
			}
			obj.Density = 0
			obj.Haze = 0
		end
	end
end

function EquipmentInventoryUI:EnableWeatherEffects()
	if not self.originalWeatherStates then return end
	
	for obj, state in pairs(self.originalWeatherStates) do
		if obj and obj.Parent then
			if obj:IsA("ParticleEmitter") or obj:IsA("Beam") then
				obj.Enabled = state
			elseif obj:IsA("Atmosphere") then
				obj.Density = state.Density
				obj.Haze = state.Haze
			end
		end
	end
	
	self.originalWeatherStates = nil
end

function EquipmentInventoryUI:Destroy()
	self:SetCharacterVisible(true)
	self:EnableWeatherEffects()
	
	-- Clean up drag connections
	if self.dragConnections then
		for _, connection in pairs(self.dragConnections) do
			connection:Disconnect()
		end
		self.dragConnections = nil
	end

	if self.cameraTween then
		self.cameraTween:Cancel()
		self.cameraTween = nil
	end
	if self.viewportCameraTween then
		self.viewportCameraTween:Cancel()
		self.viewportCameraTween = nil
	end
	if self.viewportFrameTween then
		self.viewportFrameTween:Cancel()
		self.viewportFrameTween = nil
	end

	if self.gui then
		self.gui:Destroy()
	end

	self.viewportWorld = nil
	self.viewportCamera = nil
	self.viewportCharacter = nil
end

return EquipmentInventoryUI
