--!strict
-- InventoryService.luau (Enhanced)
-- Server-side inventory management with full feature support

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local InventoryTypes = require(ReplicatedStorage.Shared.Inventory.InventoryTypes)
local InventoryConfig = require(ReplicatedStorage.Shared.Inventory.InventoryConfig)
local Net = require(ReplicatedStorage.Shared.Net)

type InventoryItem = InventoryTypes.InventoryItem
type PlayerInventory = InventoryTypes.PlayerInventory
type Equipment = InventoryTypes.Equipment
type HotbarSlot = InventoryTypes.HotbarSlot
type InventoryUpdate = InventoryTypes.InventoryUpdate

local InventoryService = {}
InventoryService.__index = InventoryService

local DEBUG_MODE = false

local function debugPrint(...)
	if DEBUG_MODE then
		print('[InventoryService]', ...)
	end
end

-- Storage
local playerInventories = {} :: {[Player]: PlayerInventory}
local itemDatabase = {} :: {[string]: InventoryItem}

-- Services reference
local services = nil

function InventoryService.Init(servicesRef)
	services = servicesRef
	
	-- Setup remotes
	InventoryService:SetupRemotes()
	
	-- Load item database
	InventoryService:LoadItemDatabase()
	
	-- Setup player connections
	Players.PlayerAdded:Connect(function(player)
		InventoryService:OnPlayerJoined(player)
	end)
	
	Players.PlayerRemoving:Connect(function(player)
		InventoryService:OnPlayerLeaving(player)
	end)
	
	print("[InventoryService] Initialized")
end

function InventoryService:SetupRemotes()
	-- Create remote events
	local events = {
		"UpdateInventory",
		"UpdateHotbar", 
		"UpdateHotbarSlot",
		"ItemAdded",
		"ItemRemoved",
		"EquipmentChanged",
		"HotbarSlotSelected",
		"UseHotbarItem"
	}
	
	for _, eventName in ipairs(events) do
		Net.Event(eventName)
	end
	
	-- Create remote functions
	Net.OnInvoke("GetPlayerInventory", function(player)
		return InventoryService:GetPlayerInventory(player)
	end)
	
	Net.OnInvoke("MoveItem", function(player, sourceType, sourceSlot, targetType, targetSlot)
		return InventoryService:MoveItem(player, sourceType, sourceSlot, targetType, targetSlot)
	end)
	
	Net.OnInvoke("EquipItem", function(player, itemId, slotType)
		return InventoryService:EquipItem(player, itemId, slotType)
	end)
	
	Net.OnInvoke("UnequipItem", function(player, slotType)
		return InventoryService:UnequipItem(player, slotType)
	end)
	
	Net.OnInvoke("SwapHotbarSlots", function(player, slot1, slot2)
		return InventoryService:SwapHotbarSlots(player, slot1, slot2)
	end)
	
	Net.OnInvoke("DropItem", function(player, itemId, quantity)
		return InventoryService:DropItem(player, itemId, quantity)
	end)
	
	-- Listen for hotbar events
	Net.On("HotbarSlotSelected", function(player, slotNumber)
		InventoryService:OnHotbarSlotSelected(player, slotNumber)
	end)
	
	Net.On("UseHotbarItem", function(player, slotNumber)
		InventoryService:UseHotbarItem(player, slotNumber)
	end)
end

function InventoryService:LoadItemDatabase()
	-- Load items from a configuration module or datastore
	-- For now, we'll create some example items
	
	local exampleItems = {
		-- Lanterns
		{
			id = "basic_lantern",
			name = "Basic Lantern",
			description = "A simple lantern that provides basic light",
			category = "Lantern",
			icon = "rbxassetid://7734003107",
			stackable = true,
			maxStack = 10,
			rarity = "Common"
		},
		{
			id = "enhanced_lantern",
			name = "Enhanced Lantern",
			description = "An improved lantern with extended range",
			category = "Lantern",
			icon = "rbxassetid://7734003107",
			stackable = true,
			maxStack = 5,
			rarity = "Uncommon"
		},
		
		-- Plot Upgrades
		{
			id = "oil_cannister",
			name = "Oil Cannister",
			description = "Increases oil storage capacity by 50",
			category = "PlotUpgrade",
			icon = "rbxassetid://7734042139",
			stackable = true,
			maxStack = 20,
			rarity = "Common"
		},
		{
			id = "pond_excavator",
			name = "Pond Excavator",
			description = "Allows placement of a new pond",
			category = "PlotUpgrade",
			icon = "rbxassetid://7734042139",
			stackable = true,
			maxStack = 5,
			rarity = "Rare"
		},
		
		-- Weapons
		{
			id = "iron_sword",
			name = "Iron Sword",
			description = "A sturdy iron blade",
			category = "Weapon",
			icon = "rbxassetid://7734022107",
			stackable = false,
			rarity = "Common"
		},
		
		-- Lantern head gear
		{
			id = "lantern_headlamp",
			name = "Lantern Headlamp",
			description = "A luminous helm that brightens your path",
			category = "LanternHead",
			icon = "rbxassetid://7734003107",
			stackable = false,
			rarity = "Uncommon"
		},
		
		-- Mobility
		{
			id = "double_jump",
			name = "Double Jump",
			description = "Allows an additional jump in mid-air",
			category = "Mobility",
			icon = "rbxassetid://7734053426",
			stackable = false,
			rarity = "Uncommon",
			mobilityType = "Jump"
		},
		{
			id = "dash_boots",
			name = "Dash Boots",
			description = "Quick dash in any direction",
			category = "Mobility",
			icon = "rbxassetid://7734053426",
			stackable = false,
			rarity = "Uncommon",
			mobilityType = "Dash"
		},
		{
			id = "grappling_hook",
			name = "Grappling Hook",
			description = "Launch a hook to swing across gaps",
			category = "Mobility",
			icon = "rbxassetid://7734053426",
			stackable = false,
			rarity = "Rare",
			mobilityType = "Grapple"
		},
		
		-- Curses
		{
			id = "curse_of_greed",
			name = "Curse of Greed",
			description = "Double rewards but increased danger",
			category = "Curse",
			icon = "rbxassetid://7733955511",
			stackable = false,
			rarity = "Epic"
		}
	}
	
	for _, item in ipairs(exampleItems) do
		itemDatabase[item.id] = item
	end
	
	print("[InventoryService] Loaded", #exampleItems, "items")
end

function InventoryService:OnPlayerJoined(player: Player)
	-- Load or create player inventory
	local inventory = InventoryService:LoadPlayerInventory(player)
	playerInventories[player] = inventory
	
	-- Send initial inventory to client
	task.wait(2) -- Wait for client to load
	Net.Fire(player, "UpdateInventory", inventory)
	
	print("[InventoryService] Player inventory loaded for", player.Name)
end

function InventoryService:OnPlayerLeaving(player: Player)
	-- Save player inventory
	local inventory = playerInventories[player]
	if inventory then
		InventoryService:SavePlayerInventory(player, inventory)
		playerInventories[player] = nil
	end
	
	print("[InventoryService] Player inventory saved for", player.Name)
end

function InventoryService:LoadPlayerInventory(player: Player): PlayerInventory
	-- Load from datastore (integrated with SaveService)
	local profile = services and services.SaveService and services.SaveService.GetProfile(player)
	
	if profile and profile.inventory then
		-- Convert saved data to proper inventory structure
		return InventoryService:DeserializeInventory(profile.inventory)
	end
	
	-- Create default inventory
	local defaultInventory: PlayerInventory = {
		playerId = player.UserId,
		buildingItems = {},
		equipment = {
			weapon = nil,
			lanternHead = nil,
			mobility = {
				jump = nil,
				dash = nil,
				grapple = nil
			},
			curses = {}
		},
		hotbar = {},
		capacity = InventoryConfig.Gameplay.MaxBuildingSlots,
		usedSlots = 0
	}
	
	-- Give starter items
	InventoryService:GiveStarterItems(player, defaultInventory)
	
	return defaultInventory
end

function InventoryService:SavePlayerInventory(player: Player, inventory: PlayerInventory)
	-- Save to datastore (integrated with SaveService)
	local profile = services and services.SaveService and services.SaveService.GetProfile(player)
	
	if profile then
		profile.inventory = InventoryService:SerializeInventory(inventory)
	end
end

function InventoryService:SerializeInventory(inventory: PlayerInventory): any
	-- Convert inventory to saveable format
	local serialized = {
		buildingItems = {},
		equipment = {
			weapon = inventory.equipment.weapon and inventory.equipment.weapon.id,
			lanternHead = inventory.equipment.lanternHead and inventory.equipment.lanternHead.id,
			mobility = {
				jump = inventory.equipment.mobility.jump and inventory.equipment.mobility.jump.id,
				dash = inventory.equipment.mobility.dash and inventory.equipment.mobility.dash.id,
				grapple = inventory.equipment.mobility.grapple and inventory.equipment.mobility.grapple.id
			},
			curses = {}
		},
		hotbar = {}
	}
	
	-- Serialize building items
	for slotId, slot in pairs(inventory.buildingItems) do
		if slot.item then
			serialized.buildingItems[slotId] = {
				itemId = slot.item.id,
				quantity = slot.quantity
			}
		end
	end
	
	-- Serialize curses
	for i, curse in ipairs(inventory.equipment.curses) do
		serialized.equipment.curses[i] = curse.id
	end
	
	-- Serialize hotbar
	for slotNum, slot in pairs(inventory.hotbar) do
		if slot.item then
			serialized.hotbar[slotNum] = {
				itemId = slot.item.id,
				quantity = slot.quantity
			}
		end
	end
	
	return serialized
end

function InventoryService:DeserializeInventory(data: any): PlayerInventory
	local safeData = typeof(data) == "table" and data or {}
	local equipmentData = typeof(safeData.equipment) == "table" and safeData.equipment or {}
	local mobilityData = typeof(equipmentData.mobility) == "table" and equipmentData.mobility or {}
	local cursesData = typeof(equipmentData.curses) == "table" and equipmentData.curses or {}
	local buildingData = typeof(safeData.buildingItems) == "table" and safeData.buildingItems or {}
	local hotbarData = typeof(safeData.hotbar) == "table" and safeData.hotbar or {}

	local inventory: PlayerInventory = {
		playerId = 0,
		buildingItems = {},
		equipment = {
			weapon = equipmentData.weapon and itemDatabase[equipmentData.weapon] or nil,
			lanternHead = equipmentData.lanternHead and itemDatabase[equipmentData.lanternHead] or nil,
			mobility = {
				jump = mobilityData.jump and itemDatabase[mobilityData.jump] or nil,
				dash = mobilityData.dash and itemDatabase[mobilityData.dash] or nil,
				grapple = mobilityData.grapple and itemDatabase[mobilityData.grapple] or nil
			},
			curses = {}
		},
		hotbar = {},
		capacity = InventoryConfig.Gameplay.MaxBuildingSlots,
		usedSlots = 0
	}

	for slotId, slotData in pairs(buildingData) do
		local itemId = slotData and slotData.itemId
		local item = itemId and itemDatabase[itemId]
		if item then
			inventory.buildingItems[slotId] = {
				item = item,
				quantity = slotData.quantity,
				slotIndex = tonumber(slotId) or 1,
				locked = false
			}
			inventory.usedSlots = inventory.usedSlots + 1
		end
	end

	for _, curseId in ipairs(cursesData) do
		local curse = itemDatabase[curseId]
		if curse then
			table.insert(inventory.equipment.curses, curse)
		end
	end

	for slotNum, slotData in pairs(hotbarData) do
		local itemId = slotData and slotData.itemId
		local item = itemId and itemDatabase[itemId]
		if item then
			inventory.hotbar[slotNum] = {
				item = item,
				quantity = slotData.quantity or 1
			}
		end
	end

	return inventory
end


function InventoryService:GiveStarterItems(player: Player, inventory: PlayerInventory)
	-- Give default starting items
	InventoryService:AddItem(player, "basic_lantern", 3, inventory)
	InventoryService:AddItem(player, "oil_cannister", 1, inventory)
end

function InventoryService:GetPlayerInventory(player: Player): PlayerInventory?
	return playerInventories[player]
end

function InventoryService:GetItem(itemId: string): InventoryItem?
	return itemDatabase[itemId]
end

function InventoryService:AddItem(player: Player, itemId: string, quantity: number, inventory: PlayerInventory?)
	inventory = inventory or playerInventories[player]
	if not inventory then
		warn("[InventoryService] No inventory found for player", player.Name)
		return false
	end
	
	local item = itemDatabase[itemId]
	if not item then
		warn("[InventoryService] Unknown item:", itemId)
		return false
	end
	
	-- Check if item already exists in inventory (for stackable items)
	if item.stackable then
		for slotId, slot in pairs(inventory.buildingItems) do
			if slot.item and slot.item.id == itemId then
				-- Add to existing stack
				local maxStack = item.maxStack or InventoryConfig.Gameplay.DefaultMaxStack
				local canAdd = math.min(quantity, maxStack - slot.quantity)
				
				if canAdd > 0 then
					slot.quantity = slot.quantity + canAdd
					quantity = quantity - canAdd
					
					-- Update client
					Net.Fire(player, "ItemAdded", item, canAdd)
					
					if quantity <= 0 then
						return true
					end
				end
			end
		end
	end
	
	-- Add to new slot(s)
	while quantity > 0 and inventory.usedSlots < inventory.capacity do
		local slotIndex = InventoryService:FindEmptySlot(inventory)
		if not slotIndex then
			warn("[InventoryService] Inventory full for player", player.Name)
			return false
		end
		
		local stackSize = quantity
		if item.stackable then
			local maxStack = item.maxStack or InventoryConfig.Gameplay.DefaultMaxStack
			stackSize = math.min(quantity, maxStack)
		else
			stackSize = 1
		end
		
		inventory.buildingItems[tostring(slotIndex)] = {
			item = item,
			quantity = stackSize,
			slotIndex = slotIndex,
			locked = false
		}
		
		inventory.usedSlots = inventory.usedSlots + 1
		quantity = quantity - stackSize
		
		-- Update client
		Net.Fire(player, "ItemAdded", item, stackSize)
	end
	
	-- Send full inventory update
	Net.Fire(player, "UpdateInventory", inventory)
	
	return quantity == 0
end

function InventoryService:RemoveItem(player: Player, itemId: string, quantity: number): boolean
	local inventory = playerInventories[player]
	if not inventory then
		return false
	end
	
	local item = itemDatabase[itemId]
	if not item then
		return false
	end
	
	local totalRemoved = 0
	
	-- Remove from building items
	for slotId, slot in pairs(inventory.buildingItems) do
		if slot.item and slot.item.id == itemId then
			local toRemove = math.min(slot.quantity, quantity - totalRemoved)
			slot.quantity = slot.quantity - toRemove
			totalRemoved = totalRemoved + toRemove
			
			if slot.quantity <= 0 then
				inventory.buildingItems[slotId] = nil
				inventory.usedSlots = inventory.usedSlots - 1
			end
			
			if totalRemoved >= quantity then
				break
			end
		end
	end
	
	-- Check hotbar
	for slotNum, slot in pairs(inventory.hotbar) do
		if slot.item and slot.item.id == itemId and totalRemoved < quantity then
			local toRemove = math.min(slot.quantity, quantity - totalRemoved)
			slot.quantity = slot.quantity - toRemove
			totalRemoved = totalRemoved + toRemove
			
			if slot.quantity <= 0 then
				inventory.hotbar[slotNum] = nil
			end
		end
	end
	
	if totalRemoved > 0 then
		Net.Fire(player, "ItemRemoved", itemId, totalRemoved)
		Net.Fire(player, "UpdateInventory", inventory)
		return true
	end
	
	return false
end

function InventoryService:FindEmptySlot(inventory: PlayerInventory): number?
	for i = 1, inventory.capacity do
		if not inventory.buildingItems[tostring(i)] then
			return i
		end
	end
	return nil
end

function InventoryService:MoveItem(player: Player, sourceType: string, sourceSlot: any, targetType: string, targetSlot: any): boolean
	local inventory = playerInventories[player]
	if not inventory then
		return false
	end
	
	-- Implementation for moving items between slots/inventories
	-- This would handle drag and drop logic
	
	print("[InventoryService] Move item:", sourceType, sourceSlot, "->", targetType, targetSlot)
	
	-- Update client
	Net.Fire(player, "UpdateInventory", inventory)
	
	return true
end

function InventoryService:EquipItem(player: Player, itemId: string, slotType: string): boolean
	local inventory = playerInventories[player]
	if not inventory then
		return false
	end
	
	local item = itemDatabase[itemId]
	if not item then
		return false
	end
	
	-- Check if item can be equipped in this slot
    if slotType == "Weapon" and item.category == "Weapon" then
        -- Unequip current weapon if any
        if inventory.equipment.weapon then
            -- Move current weapon back to inventory
            InventoryService:AddItem(player, inventory.equipment.weapon.id, 1)
        end
        
        inventory.equipment.weapon = item
        InventoryService:RemoveItem(player, itemId, 1)
        Net.Fire(player, "EquipmentChanged", "Weapon", item)
    elseif slotType == "LanternHead" and item.category == "LanternHead" then
        if inventory.equipment.lanternHead then
            InventoryService:AddItem(player, inventory.equipment.lanternHead.id, 1)
        end
        inventory.equipment.lanternHead = item
        InventoryService:RemoveItem(player, itemId, 1)
        Net.Fire(player, "EquipmentChanged", "LanternHead", item)
		
	elseif item.category == "Mobility" and item.mobilityType then
		local mobilitySlot = string.lower(item.mobilityType)
		if inventory.equipment.mobility[mobilitySlot] then
			-- Move current item back to inventory
			InventoryService:AddItem(player, inventory.equipment.mobility[mobilitySlot].id, 1)
		end
		
		inventory.equipment.mobility[mobilitySlot] = item
		InventoryService:RemoveItem(player, itemId, 1)
		Net.Fire(player, "EquipmentChanged", item.mobilityType, item)
		
	elseif item.category == "Curse" and string.find(slotType, "Curse") then
		local curseIndex = tonumber(string.sub(slotType, 6))
		if curseIndex and curseIndex >= 1 and curseIndex <= 3 then
			if inventory.equipment.curses[curseIndex] then
				-- Move current curse back to inventory
				InventoryService:AddItem(player, inventory.equipment.curses[curseIndex].id, 1)
			end
			
			inventory.equipment.curses[curseIndex] = item
			InventoryService:RemoveItem(player, itemId, 1)
			Net.Fire(player, "EquipmentChanged", slotType, item)
		end
	else
		return false
	end
	
	Net.Fire(player, "UpdateInventory", inventory)
	return true
end

function InventoryService:UnequipItem(player: Player, slotType: string): boolean
	local inventory = playerInventories[player]
	if not inventory then
		return false
	end
	
	local item = nil
	
    if slotType == "Weapon" then
        item = inventory.equipment.weapon
        inventory.equipment.weapon = nil
    elseif slotType == "LanternHead" then
        item = inventory.equipment.lanternHead
        inventory.equipment.lanternHead = nil
		
	elseif slotType == "Jump" or slotType == "Dash" or slotType == "Grapple" then
		local mobilitySlot = string.lower(slotType)
		item = inventory.equipment.mobility[mobilitySlot]
		inventory.equipment.mobility[mobilitySlot] = nil
		
	elseif string.find(slotType, "Curse") then
		local curseIndex = tonumber(string.sub(slotType, 6))
		if curseIndex and curseIndex >= 1 and curseIndex <= 3 then
			item = inventory.equipment.curses[curseIndex]
			inventory.equipment.curses[curseIndex] = nil
		end
	end
	
	if item then
		InventoryService:AddItem(player, item.id, 1)
		Net.Fire(player, "EquipmentChanged", slotType, nil)
		Net.Fire(player, "UpdateInventory", inventory)
		return true
	end
	
	return false
end

function InventoryService:SwapHotbarSlots(player: Player, slot1: number, slot2: number): boolean
	local inventory = playerInventories[player]
	if not inventory then
		return false
	end
	
	local temp = inventory.hotbar[slot1]
	inventory.hotbar[slot1] = inventory.hotbar[slot2]
	inventory.hotbar[slot2] = temp
	
	-- Update slot numbers
	if inventory.hotbar[slot1] then
		inventory.hotbar[slot1].slotNumber = slot1
	end
	if inventory.hotbar[slot2] then
		inventory.hotbar[slot2].slotNumber = slot2
	end
	
	Net.Fire(player, "UpdateHotbar", inventory.hotbar)
	
	return true
end

function InventoryService:AddToHotbar(player: Player, itemId: string, slotNumber: number, quantity: number?): boolean
	local inventory = playerInventories[player]
	if not inventory then
		debugPrint("No inventory found for AddToHotbar")
		return false
	end
	
	local item = itemDatabase[itemId]
	if not item then
		debugPrint("Item not found:", itemId)
		return false
	end
	
	-- Check if slot number is valid
	if slotNumber < 1 or slotNumber > 10 then
		debugPrint("Invalid hotbar slot:", slotNumber)
		return false
	end
	
	-- Clear existing item in slot if any
	if inventory.hotbar[slotNumber] then
		-- Return existing item to inventory
		local existingItem = inventory.hotbar[slotNumber]
		if existingItem and existingItem.item then
			InventoryService:AddItem(player, existingItem.item.id, existingItem.quantity)
		end
	end
	
	-- Check if we have this item in inventory first
	local hasItem = false
	for _, slot in pairs(inventory.buildingItems) do
		if slot.item and slot.item.id == itemId then
			hasItem = true
			break
		end
	end
	
	if not hasItem then
		debugPrint("Item not in inventory, adding it first:", itemId)
		-- Add the item to inventory first if not present
		local added = InventoryService:AddItem(player, itemId, quantity or 1)
		if not added then
			return false
		end
	end
	
	-- Add new item to hotbar
	inventory.hotbar[slotNumber] = {
		item = item,
		quantity = quantity or 1,
		slotNumber = slotNumber,
		keybind = InventoryConfig.Gameplay.Keybinds.Hotbar[slotNumber]
	}
	
	-- Remove from inventory (don't remove if it wasn't there originally)
	if hasItem then
		InventoryService:RemoveItem(player, itemId, quantity or 1)
	end
	
	Net.Fire(player, "UpdateHotbarSlot", slotNumber, item, quantity or 1)
	debugPrint("Added", itemId, "to hotbar slot", slotNumber)
	
	return true
end

function InventoryService:OnHotbarSlotSelected(player: Player, slotNumber: number)
	local inventory = playerInventories[player]
	if not inventory then
		return
	end
	
	local slot = inventory.hotbar[slotNumber]
	if slot and slot.item then
		print("[InventoryService]", player.Name, "selected hotbar slot", slotNumber, "with item", slot.item.name)
		
		-- Trigger any selection effects
		-- Check if ToolService exists and has the method
		if services and services.ToolService then
			-- Safe call to ToolService if it has SelectTool method
			local toolService = services.ToolService
			if type(toolService.SelectTool) == "function" then
				toolService:SelectTool(player, slot.item.id)
			elseif type(toolService.OnToolSelected) == "function" then
				-- Fallback to alternative method name
				toolService:OnToolSelected(player, slot.item.id)
			else
				-- Just log if no method exists
				debugPrint("ToolService exists but no SelectTool method found")
			end
		end
	end
end

function InventoryService:UseHotbarItem(player: Player, slotNumber: number)
	local inventory = playerInventories[player]
	if not inventory then
		return
	end
	
	local slot = inventory.hotbar[slotNumber]
	if slot and slot.item then
		print("[InventoryService]", player.Name, "used item", slot.item.name, "from hotbar slot", slotNumber)
		
		-- Trigger item use
		-- Check if ToolService exists and has the method
		if services and services.ToolService then
			local toolService = services.ToolService
			if type(toolService.UseTool) == "function" then
				toolService:UseTool(player, slot.item.id)
			elseif type(toolService.OnToolUsed) == "function" then
				-- Fallback to alternative method name
				toolService:OnToolUsed(player, slot.item.id)
			else
				-- Handle tool use locally if no ToolService method
				debugPrint("ToolService exists but no UseTool method found")
				-- Placeholder for local handling
				if slot.item.category == "Lantern" then
					-- Handle lantern placement
					debugPrint("Would place lantern:", slot.item.name)
				end
			end
		end
		
		-- Consume item if consumable
		if slot.item.consumable then
			slot.quantity = slot.quantity - 1
			if slot.quantity <= 0 then
				inventory.hotbar[slotNumber] = nil
				Net.Fire(player, "UpdateHotbarSlot", slotNumber, nil, 0)
			else
				Net.Fire(player, "UpdateHotbarSlot", slotNumber, slot.item, slot.quantity)
			end
		end
	end
end

function InventoryService:DropItem(player: Player, itemId: string, quantity: number): boolean
	local character = player.Character
	if not character then
		return false
	end
	
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then
		return false
	end
	
	-- Remove item from inventory
	if InventoryService:RemoveItem(player, itemId, quantity) then
		-- Create physical item drop in world
		-- This would integrate with your existing item drop system
		print("[InventoryService]", player.Name, "dropped", quantity, "x", itemId)
		
		-- Create drop model (placeholder)
		-- You would replace this with your actual item drop creation
		
		return true
	end
	
	return false
end

-- Legacy compatibility functions
function InventoryService.GrantItem(player: Player, itemId: string, count: number)
	return InventoryService:AddItem(player, itemId, count)
end

function InventoryService.ConsumeItem(player: Player, itemId: string, count: number)
	return InventoryService:RemoveItem(player, itemId, count)
end

function InventoryService.HasUpgrade(player: Player, upgradeId: string): boolean
	local inventory = playerInventories[player]
	if not inventory then
		return false
	end
	
	-- Check if upgrade exists in inventory
	for _, slot in pairs(inventory.buildingItems) do
		if slot.item and slot.item.id == upgradeId then
			return true
		end
	end
	
	return false
end

return InventoryService
