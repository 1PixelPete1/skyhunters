--!strict
-- InventoryIntegrationService.luau
-- Links inventory with game mechanics (lanterns, oil, mobility, upgrades)
-- Provides server-side validation and persistent state management

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local Net = require(ReplicatedStorage.Shared.Net)
local InventoryTypes = require(ReplicatedStorage.Shared.Inventory.InventoryTypes)
local InventoryConfig = require(ReplicatedStorage.Shared.Inventory.InventoryConfig)

type InventoryItem = InventoryTypes.InventoryItem
type PlayerInventory = InventoryTypes.PlayerInventory

local InventoryIntegrationService = {}
InventoryIntegrationService.__index = InventoryIntegrationService

-- Service references
local services = nil

-- Debug mode
local DEBUG_MODE = true

local function debugPrint(...)
	if DEBUG_MODE then
		print("[InventoryIntegration]", ...)
	end
end

function InventoryIntegrationService.Init(servicesRef)
	services = servicesRef
	
	-- Setup integration remotes
	InventoryIntegrationService:SetupRemotes()
	
	-- Hook into existing services
	InventoryIntegrationService:HookServices()
	
	debugPrint("Initialized successfully")
end

function InventoryIntegrationService:SetupRemotes()
	-- Create integration-specific remotes
	Net.Event("ValidatePlacement")
	Net.Event("ValidateEquipment")
	Net.Event("ConsumeInventoryItem")
	
	-- Listen for validation requests
	Net.On("ValidatePlacement", function(player, itemId, position)
		debugPrint("Validating placement for", player.Name, "item:", itemId)
		local valid = InventoryIntegrationService:ValidatePlacement(player, itemId, position)
		Net.Fire(player, "PlacementValidated", itemId, valid)
	end)
end

function InventoryIntegrationService:HookServices()
	-- Hook into PlacementService for lantern/oil validation
	if services.PlacementService then
		debugPrint("Hooking into PlacementService")
		-- We'll modify the placement validation through the request system
	end
	
	-- Hook into MobilityService for equipment validation
	if services.MobilityService then
		debugPrint("Hooking into MobilityService")
		-- Equipment validation will be integrated through CheckEquipment method
	end
	
	-- Hook into LanternService for oil consumption
	if services.LanternService then
		debugPrint("Hooking into LanternService")
	end
	
	debugPrint("Service hooks installed")
end

-- Validation Functions

function InventoryIntegrationService:ValidateLanternInventory(player: Player, lanternType: string?): boolean
	local inventory = services.InventoryService:GetPlayerInventory(player)
	if not inventory then 
		debugPrint("No inventory found for player", player.Name)
		return false 
	end
	
	lanternType = lanternType or "basic_lantern"
	
	-- Check hotbar for specific lantern type
	for _, slot in pairs(inventory.hotbar) do
		if slot and slot.item and slot.item.category == "Lantern" then
			if not lanternType or slot.item.id == lanternType then
				debugPrint("Found lantern in hotbar:", slot.item.id)
				return true
			end
		end
	end
	
	-- Check building inventory
	for _, slot in pairs(inventory.buildingItems) do
		if slot and slot.item and slot.item.category == "Lantern" then
			if not lanternType or slot.item.id == lanternType then
				debugPrint("Found lantern in building inventory:", slot.item.id)
				return true
			end
		end
	end
	
	debugPrint("No lantern found in inventory for player", player.Name)
	return false
end

function InventoryIntegrationService:ConsumeLanternItem(player: Player, lanternType: string?): boolean
	local inventory = services.InventoryService:GetPlayerInventory(player)
	if not inventory then return false end
	
	lanternType = lanternType or "basic_lantern"
	
	-- Try to consume from hotbar first
	for slotNum, slot in pairs(inventory.hotbar) do
		if slot and slot.item and slot.item.category == "Lantern" then
			if not lanternType or slot.item.id == lanternType then
				local success = services.InventoryService:RemoveItem(player, slot.item.id, 1)
				if success then
					debugPrint("Consumed lantern from hotbar slot", slotNum, ":", slot.item.id)
					return true
				end
			end
		end
	end
	
	-- Then try building inventory
	for _, slot in pairs(inventory.buildingItems) do
		if slot and slot.item and slot.item.category == "Lantern" then
			if not lanternType or slot.item.id == lanternType then
				local success = services.InventoryService:RemoveItem(player, slot.item.id, 1)
				if success then
					debugPrint("Consumed lantern from building inventory:", slot.item.id)
					return true
				end
			end
		end
	end
	
	return false
end

function InventoryIntegrationService:ValidateOilCanister(player: Player): number
	local inventory = services.InventoryService:GetPlayerInventory(player)
	if not inventory then return 0 end
	
	local oilAmount = 0
	
	-- Check for oil canisters in inventory
	for _, slot in pairs(inventory.buildingItems) do
		if slot and slot.item and slot.item.id == "oil_cannister" then
			oilAmount = oilAmount + slot.quantity
		end
	end
	
	-- Check hotbar
	for _, slot in pairs(inventory.hotbar) do
		if slot and slot.item and slot.item.id == "oil_cannister" then
			oilAmount = oilAmount + slot.quantity
		end
	end
	
	debugPrint("Player", player.Name, "has", oilAmount, "oil canisters")
	return oilAmount
end

function InventoryIntegrationService:ConsumeOilCanister(player: Player, amount: number): boolean
	local inventory = services.InventoryService:GetPlayerInventory(player)
	if not inventory then return false end
	
	local available = InventoryIntegrationService:ValidateOilCanister(player)
	if available < amount then
		debugPrint("Not enough oil canisters. Has:", available, "Needs:", amount)
		return false
	end
	
	local success = services.InventoryService:RemoveItem(player, "oil_cannister", amount)
	if success then
		debugPrint("Consumed", amount, "oil canisters from", player.Name)
		
		-- Add oil to lantern storage
		if services.LanternService and services.LanternService.DepositOil then
			local oilPerCanister = 50 -- Each canister provides 50 oil units
			services.LanternService.DepositOil(player, amount * oilPerCanister)
		end
	end
	
	return success
end

function InventoryIntegrationService:ValidateMobilityEquipment(player: Player, abilityType: string): boolean
	local inventory = services.InventoryService:GetPlayerInventory(player)
	if not inventory then 
		debugPrint("No inventory for mobility check:", player.Name)
		return false 
	end
	
	-- Map ability types to equipment slots
	local equipmentMap = {
		["Leap"] = inventory.equipment.mobility.jump,
		["Dash"] = inventory.equipment.mobility.dash,
		["Grapple"] = inventory.equipment.mobility.grapple
	}
	
	local equipment = equipmentMap[abilityType]
	if equipment then
		debugPrint("Player", player.Name, "has", abilityType, "equipment:", equipment.name)
		return true
	end
	
	debugPrint("Player", player.Name, "missing", abilityType, "equipment")
	return false
end

function InventoryIntegrationService:ValidatePlotUpgrade(player: Player, upgradeType: string): boolean
	local inventory = services.InventoryService:GetPlayerInventory(player)
	if not inventory then return false end
	
	-- Check for specific plot upgrade items
	for _, slot in pairs(inventory.buildingItems) do
		if slot and slot.item and slot.item.category == "PlotUpgrade" then
			if slot.item.id == upgradeType then
				debugPrint("Player", player.Name, "has plot upgrade:", upgradeType)
				return true
			end
		end
	end
	
	debugPrint("Player", player.Name, "missing plot upgrade:", upgradeType)
	return false
end

function InventoryIntegrationService:ConsumePlotUpgrade(player: Player, upgradeType: string): boolean
	if not InventoryIntegrationService:ValidatePlotUpgrade(player, upgradeType) then
		return false
	end
	
	local success = services.InventoryService:RemoveItem(player, upgradeType, 1)
	if success then
		debugPrint("Consumed plot upgrade:", upgradeType, "from", player.Name)
		
		-- Apply the upgrade effects
		if upgradeType == "pond_excavator" then
			-- Enable pond placement for this player
			if services.PlotService then
				local profile = services.SaveService and services.SaveService.GetProfile(player)
				if profile then
					profile.upgrades = profile.upgrades or {}
					profile.upgrades.pondSlots = (profile.upgrades.pondSlots or 0) + 1
				end
			end
		end
	end
	
	return success
end

-- Equipment Effect Application

function InventoryIntegrationService:ApplyMobilityEffects(player: Player)
	local inventory = services.InventoryService:GetPlayerInventory(player)
	if not inventory then return end
	
	local character = player.Character
	if not character then return end
	
	-- Apply jump pack effects
	if inventory.equipment.mobility.jump then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			-- Increase jump power slightly
			humanoid.JumpPower = humanoid.JumpPower * 1.2
			debugPrint("Applied jump pack effects to", player.Name)
		end
	end
	
	-- Apply dash pack effects (visual indicator)
	if inventory.equipment.mobility.dash then
		-- Create visual indicator on character
		local indicator = character:FindFirstChild("DashPackIndicator")
		if not indicator then
			indicator = Instance.new("PointLight")
			indicator.Name = "DashPackIndicator"
			indicator.Color = Color3.fromRGB(100, 200, 255)
			indicator.Brightness = 2
			indicator.Range = 10
			indicator.Parent = character:FindFirstChild("HumanoidRootPart")
		end
	end
end

-- Curse Effects

function InventoryIntegrationService:ApplyCurseEffects(player: Player)
	local inventory = services.InventoryService:GetPlayerInventory(player)
	if not inventory then return end
	
	for _, curse in ipairs(inventory.equipment.curses) do
		if curse then
			debugPrint("Applying curse to", player.Name, ":", curse.name)
			
			if curse.id == "curse_of_greed" then
				-- Double rewards but increase storm damage
				local profile = services.SaveService and services.SaveService.GetProfile(player)
				if profile then
					profile.modifiers = profile.modifiers or {}
					profile.modifiers.rewardMultiplier = 2
					profile.modifiers.stormDamageMultiplier = 1.5
				end
			end
		end
	end
end

-- Lantern Head Effects

function InventoryIntegrationService:ApplyLanternHeadEffects(player: Player)
	local inventory = services.InventoryService:GetPlayerInventory(player)
	if not inventory or not inventory.equipment.lanternHead then return end
	
	local character = player.Character
	if not character then return end
	
	local head = character:FindFirstChild("Head")
	if not head then return end
	
	-- Remove existing lantern head light
	local existingLight = head:FindFirstChild("LanternHeadLight")
	if existingLight then
		existingLight:Destroy()
	end
	
	-- Create new lantern head light
	local light = Instance.new("PointLight")
	light.Name = "LanternHeadLight"
	light.Brightness = 3
	light.Range = 20
	light.Color = Color3.fromRGB(255, 220, 150)
	light.Parent = head
	
	debugPrint("Applied lantern head light to", player.Name)
end

-- Public Interface for other services

function InventoryIntegrationService:ValidatePlacement(player: Player, itemId: string, position: Vector3?): boolean
	-- Validate based on item type
	if string.find(itemId, "lantern") then
		return InventoryIntegrationService:ValidateLanternInventory(player, itemId)
	elseif string.find(itemId, "pond") then
		return InventoryIntegrationService:ValidatePlotUpgrade(player, "pond_excavator")
	elseif itemId == "oil_cannister" then
		return InventoryIntegrationService:ValidateOilCanister(player) > 0
	end
	
	return true -- Allow other items by default
end

function InventoryIntegrationService:OnItemPlaced(player: Player, itemId: string, success: boolean)
	if not success then return end
	
	-- Consume the appropriate item
	if string.find(itemId, "lantern") then
		InventoryIntegrationService:ConsumeLanternItem(player, itemId)
	elseif string.find(itemId, "pond") then
		InventoryIntegrationService:ConsumePlotUpgrade(player, "pond_excavator")
	end
end

-- Equipment change handler

function InventoryIntegrationService:OnEquipmentChanged(player: Player, slotType: string, item: InventoryItem?)
	debugPrint("Equipment changed for", player.Name, "- Slot:", slotType, "Item:", item and item.name or "none")
	
	-- Apply immediate effects
	if slotType == "LanternHead" then
		InventoryIntegrationService:ApplyLanternHeadEffects(player)
	elseif string.find(slotType, "Curse") then
		InventoryIntegrationService:ApplyCurseEffects(player)
	elseif slotType == "Jump" or slotType == "Dash" or slotType == "Grapple" then
		InventoryIntegrationService:ApplyMobilityEffects(player)
		
		-- Update MobilityService state
		if services.MobilityService then
			local state = services.MobilityService.playerStates and services.MobilityService.playerStates[player]
			if state then
				if slotType == "Jump" then
					state.Leap.IsEquipped = item ~= nil
				elseif slotType == "Dash" then
					state.Dash.IsEquipped = item ~= nil
				end
				
				-- Sync state to client
				if services.MobilityService.SyncState then
					services.MobilityService:SyncState(player)
				end
			end
		end
	end
end

return InventoryIntegrationService
