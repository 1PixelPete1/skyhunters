--!strict
-- DragDropHandler.luau
-- Handles drag-and-drop functionality between inventories and hotbar

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InventoryConfig = require(ReplicatedStorage.Shared.Inventory.InventoryConfig)
local InventoryTypes = require(ReplicatedStorage.Shared.Inventory.InventoryTypes)
local Net = require(ReplicatedStorage.Shared.Net)

type InventoryItem = InventoryTypes.InventoryItem
type DragData = InventoryTypes.DragData

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local mouse = player:GetMouse()

local DragDropHandler = {}
DragDropHandler.__index = DragDropHandler

function DragDropHandler.new()
	local self = setmetatable({}, DragDropHandler)
	
	self.isDragging = false
	self.dragData = nil :: DragData?
	self.dragPreview = nil :: Frame?
	self.dragGui = nil :: ScreenGui?
	self.originalSlot = nil :: Frame?
	self.validDropTargets = {} :: {[Frame]: boolean}
	self.currentHoverTarget = nil :: Frame?
	
	self:Initialize()
	
	return self
end

function DragDropHandler:Initialize()
	-- Create drag preview GUI
	self.dragGui = Instance.new("ScreenGui")
	self.dragGui.Name = "DragPreview"
	self.dragGui.ResetOnSpawn = false
	self.dragGui.DisplayOrder = 100
	self.dragGui.Enabled = false
	self.dragGui.Parent = playerGui
	
	-- Setup mouse move tracking
	self:SetupMouseTracking()
end

function DragDropHandler:SetupMouseTracking()
	RunService.RenderStepped:Connect(function()
		if self.isDragging and self.dragPreview then
			-- Update drag preview position
			self.dragPreview.Position = UDim2.new(0, mouse.X - 25, 0, mouse.Y - 25)
			
			-- Check for hover targets
			self:CheckHoverTarget()
		end
	end)
	
	-- Handle mouse button release
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			if self.isDragging then
				self:EndDrag()
			end
		end
	end)
end

function DragDropHandler:StartDrag(item: InventoryItem, sourceType: string, sourceSlot: any, quantity: number, sourceFrame: Frame)
	if self.isDragging then
		return
	end
	
	self.isDragging = true
	self.originalSlot = sourceFrame
	
	-- Store drag data
	self.dragData = {
		item = item,
		sourceType = sourceType,
		sourceSlot = sourceSlot,
		quantity = quantity
	}
	
	-- Create drag preview
	self:CreateDragPreview(item, quantity)
	
	-- Make source slot semi-transparent
	if sourceFrame then
		TweenService:Create(
			sourceFrame,
			TweenInfo.new(0.1),
			{BackgroundTransparency = 0.5}
		):Play()
	end
	
	print("[DragDropHandler] Started dragging:", item.name, "from", sourceType)
end

function DragDropHandler:CreateDragPreview(item: InventoryItem, quantity: number)
	-- Create preview frame
	self.dragPreview = Instance.new("Frame")
	self.dragPreview.Name = "DragPreview"
	self.dragPreview.Size = UDim2.new(0, 50, 0, 50)
	self.dragPreview.BackgroundColor3 = InventoryConfig.UI.Colors.SecondaryBackground
	self.dragPreview.BorderSizePixel = 0
	self.dragPreview.ZIndex = 10
	self.dragPreview.Parent = self.dragGui
	
	-- Add transparency for preview
	self.dragPreview.BackgroundTransparency = 0.3
	
	-- Corner rounding
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = self.dragPreview
	
	-- Item icon
	local icon = Instance.new("ImageLabel")
	icon.Size = UDim2.new(0.8, 0, 0.8, 0)
	icon.Position = UDim2.new(0.5, 0, 0.5, 0)
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.BackgroundTransparency = 1
	icon.Image = item.icon
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Parent = self.dragPreview
	
	-- Quantity label
	if quantity > 1 then
		local quantityLabel = Instance.new("TextLabel")
		quantityLabel.Size = UDim2.new(0.4, 0, 0.3, 0)
		quantityLabel.Position = UDim2.new(1, -2, 1, -2)
		quantityLabel.AnchorPoint = Vector2.new(1, 1)
		quantityLabel.BackgroundTransparency = 1
		quantityLabel.Text = tostring(quantity)
		quantityLabel.TextColor3 = Color3.new(1, 1, 1)
		quantityLabel.TextScaled = true
		quantityLabel.Font = Enum.Font.SourceSansBold
		quantityLabel.Parent = self.dragPreview
	end
	
	-- Enable drag GUI
	self.dragGui.Enabled = true
end

function DragDropHandler:EndDrag()
	if not self.isDragging then
		return
	end
	
	self.isDragging = false
	
	-- Check if we have a valid drop target
	if self.currentHoverTarget and self.dragData then
		self:HandleDrop(self.currentHoverTarget)
	else
		-- Snap back to original position
		self:CancelDrag()
	end
	
	-- Clean up preview
	if self.dragPreview then
		self.dragPreview:Destroy()
		self.dragPreview = nil
	end
	
	self.dragGui.Enabled = false
	
	-- Reset original slot transparency
	if self.originalSlot then
		TweenService:Create(
			self.originalSlot,
			TweenInfo.new(0.1),
			{BackgroundTransparency = 0}
		):Play()
	end
	
	-- Clear hover effects
	if self.currentHoverTarget then
		self:ClearHoverEffect(self.currentHoverTarget)
		self.currentHoverTarget = nil
	end
	
	self.dragData = nil
	self.originalSlot = nil
end

function DragDropHandler:CancelDrag()
	print("[DragDropHandler] Drag cancelled - returning to original position")
	-- Could add animation here
end

function DragDropHandler:HandleDrop(target: Frame)
	if not self.dragData then
		return
	end
	
	local targetType = target:GetAttribute("DropType")
	local targetSlot = target:GetAttribute("SlotIndex") or target.Name
	
	print("[DragDropHandler] Dropping on:", targetType, targetSlot)
	
	-- Determine if this is a valid drop
	if not self:IsValidDrop(targetType) then
		self:CancelDrag()
		return
	end
	
	-- Send drop request to server
	local success = Net.Function("MoveItem"):InvokeServer(
		self.dragData.sourceType,
		self.dragData.sourceSlot,
		targetType,
		targetSlot
	)
	
	if success then
		print("[DragDropHandler] Drop successful!")
		-- The server will handle updating the UI
	else
		print("[DragDropHandler] Drop failed!")
		self:CancelDrag()
	end
end

function DragDropHandler:IsValidDrop(targetType: string): boolean
	if not self.dragData then
		return false
	end
	
	-- Check if item category allows this drop target
	local item = self.dragData.item
	
	-- Building items can go to hotbar
	if targetType == "Hotbar" then
		-- Only building items can go on hotbar
		return item.category == "Lantern" or 
		       item.category == "PlotUpgrade" or 
		       item.category == "Oil" or
		       item.category == "Tool"
	end
	
	-- Items can move between inventory slots
	if targetType == "BuildingSlot" then
		return true -- Any item can go in building inventory for now
	end
	
	-- Equipment slots have specific requirements
	if targetType == "EquipmentSlot" then
		-- Check if item matches equipment type
		-- This would be more complex based on your equipment system
		return item.category == "Weapon" or 
		       item.category == "LanternHead" or
		       item.category == "Mobility" or
		       item.category == "Curse"
	end
	
	return false
end

function DragDropHandler:RegisterDropTarget(frame: Frame, dropType: string, slotIndex: any)
	-- Set attributes for identification
	frame:SetAttribute("DropType", dropType)
	frame:SetAttribute("SlotIndex", slotIndex)
	
	-- Mark as valid drop target
	self.validDropTargets[frame] = true
end

function DragDropHandler:UnregisterDropTarget(frame: Frame)
	self.validDropTargets[frame] = nil
end

function DragDropHandler:CheckHoverTarget()
	if not self.isDragging then
		return
	end
	
	-- Get GUI objects at mouse position
	local guisAtPosition = playerGui:GetGuiObjectsAtPosition(mouse.X, mouse.Y)
	
	local newTarget = nil
	for _, gui in ipairs(guisAtPosition) do
		if self.validDropTargets[gui] then
			newTarget = gui
			break
		end
	end
	
	-- Update hover effects
	if newTarget ~= self.currentHoverTarget then
		-- Remove old hover effect
		if self.currentHoverTarget then
			self:ClearHoverEffect(self.currentHoverTarget)
		end
		
		-- Add new hover effect
		if newTarget then
			if self:IsValidDrop(newTarget:GetAttribute("DropType")) then
				self:ApplyHoverEffect(newTarget)
			end
		end
		
		self.currentHoverTarget = newTarget
	end
end

function DragDropHandler:ApplyHoverEffect(frame: Frame)
	-- Find or create hover border
	local hoverBorder = frame:FindFirstChild("DragHoverBorder")
	if not hoverBorder then
		hoverBorder = Instance.new("UIStroke")
		hoverBorder.Name = "DragHoverBorder"
		hoverBorder.Parent = frame
	end
	
	hoverBorder.Color = InventoryConfig.UI.Colors.Accent
	hoverBorder.Thickness = 2
	hoverBorder.Transparency = 0
	
	-- Slight scale effect
	TweenService:Create(
		frame,
		TweenInfo.new(0.1, Enum.EasingStyle.Sine),
		{Size = UDim2.new(frame.Size.X.Scale * 1.05, frame.Size.X.Offset, frame.Size.Y.Scale * 1.05, frame.Size.Y.Offset)}
	):Play()
end

function DragDropHandler:ClearHoverEffect(frame: Frame)
	local hoverBorder = frame:FindFirstChild("DragHoverBorder")
	if hoverBorder then
		TweenService:Create(
			hoverBorder,
			TweenInfo.new(0.1),
			{Transparency = 1}
		):Play()
	end
	
	-- Reset scale
	local originalSize = frame:GetAttribute("OriginalSize")
	if originalSize then
		-- Restore original size
	else
		-- Best guess reset
		TweenService:Create(
			frame,
			TweenInfo.new(0.1, Enum.EasingStyle.Sine),
			{Size = UDim2.new(frame.Size.X.Scale / 1.05, frame.Size.X.Offset, frame.Size.Y.Scale / 1.05, frame.Size.Y.Offset)}
		):Play()
	end
end

function DragDropHandler:EnableDragForSlot(frame: Frame, getItemFunc: () -> (InventoryItem?, number?), sourceType: string, sourceSlot: any)
	local button = frame:FindFirstChildWhichIsA("TextButton") or frame:FindFirstChildWhichIsA("ImageButton")
	if not button then
		-- Create an invisible button for interaction
		button = Instance.new("TextButton")
		button.Name = "DragButton"
		button.Size = UDim2.new(1, 0, 1, 0)
		button.BackgroundTransparency = 1
		button.Text = ""
		button.ZIndex = frame.ZIndex + 1
		button.Parent = frame
	end
	
	local dragConnection
	local isDragReady = false
	local startPos = nil
	
	button.MouseButton1Down:Connect(function()
		isDragReady = true
		startPos = Vector2.new(mouse.X, mouse.Y)
		
		-- Start checking for drag threshold
		dragConnection = RunService.Heartbeat:Connect(function()
			if isDragReady then
				local currentPos = Vector2.new(mouse.X, mouse.Y)
				local distance = (currentPos - startPos).Magnitude
				
				-- Drag threshold to prevent accidental drags
				if distance > 5 then
					isDragReady = false
					dragConnection:Disconnect()
					
					local item, quantity = getItemFunc()
					if item then
						self:StartDrag(item, sourceType, sourceSlot, quantity or 1, frame)
					end
				end
			end
		end)
	end)
	
	button.MouseButton1Up:Connect(function()
		isDragReady = false
		if dragConnection then
			dragConnection:Disconnect()
		end
	end)
	
	button.MouseLeave:Connect(function()
		isDragReady = false
		if dragConnection then
			dragConnection:Disconnect()
		end
	end)
end

return DragDropHandler
