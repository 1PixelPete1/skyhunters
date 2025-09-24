--!strict
-- InventoryCategoryManager.luau
-- Manages the proper categorization of items between the two inventory systems

local InventoryCategoryManager = {}

-- BUILDING INVENTORY: Items for base building and plot management
-- These items go into the main inventory and can be placed on the hotbar
local BUILDING_CATEGORIES = {
	"Lantern",       -- All types of lanterns
	"PlotUpgrade",   -- Oil cannisters, pond excavators, etc.
	"Oil",           -- Oil-related items
	"Decoration",    -- Decorative building items
	"Tool",          -- Building tools (pond, canal, removal tools)
}

-- EQUIPMENT INVENTORY: Items that are equipped on the character
-- These items go into equipment slots and do NOT use the hotbar
local EQUIPMENT_CATEGORIES = {
	"Weapon",        -- Swords, bows, etc.
	"LanternHead",   -- Head-mounted lantern equipment
	"Mobility",      -- Jump, dash, grapple abilities
	"Curse",         -- Curse items (up to 3 equipped)
	"Armor",         -- Future: armor pieces
	"Accessory",     -- Future: rings, amulets, etc.
}

-- Item database structure for clear categorization
local ITEM_DEFINITIONS = {
	-- BUILDING ITEMS
	building = {
		lanterns = {
			"basic_lantern",
			"enhanced_lantern", 
			"crystal_lantern",
			"ethereal_lantern",
			"storm_lantern"
		},
		plotUpgrades = {
			"oil_cannister",
			"pond_excavator",
			"canal_builder",
			"storage_expansion",
			"oil_refinery"
		},
		tools = {
			"pond_tool",
			"canal_tool",
			"removal_tool",
			"upgrade_tool"
		}
	},
	
	-- EQUIPMENT ITEMS
	equipment = {
		weapons = {
			"iron_sword",
			"steel_blade",
			"crystal_sword",
			"storm_breaker"
		},
		lanternHeads = {
			"lantern_headlamp",
			"crystal_crown",
			"storm_visor"
		},
		mobility = {
			jump = {"double_jump", "triple_jump", "feather_fall"},
			dash = {"dash_boots", "storm_dash", "phase_dash"},
			grapple = {"grappling_hook", "ethereal_chain", "storm_tether"}
		},
		curses = {
			"curse_of_greed",
			"curse_of_storms",
			"curse_of_shadows"
		}
	}
}

function InventoryCategoryManager.IsBuildingCategory(category: string): boolean
	for _, cat in ipairs(BUILDING_CATEGORIES) do
		if cat == category then
			return true
		end
	end
	return false
end

function InventoryCategoryManager.IsEquipmentCategory(category: string): boolean
	for _, cat in ipairs(EQUIPMENT_CATEGORIES) do
		if cat == category then
			return true
		end
	end
	return false
end

function InventoryCategoryManager.CanUseHotbar(category: string): boolean
	-- Only building items can be placed on the hotbar
	return InventoryCategoryManager.IsBuildingCategory(category)
end

function InventoryCategoryManager.GetInventoryType(category: string): "Building" | "Equipment" | nil
	if InventoryCategoryManager.IsBuildingCategory(category) then
		return "Building"
	elseif InventoryCategoryManager.IsEquipmentCategory(category) then
		return "Equipment"
	end
	return nil
end

function InventoryCategoryManager.ValidateItemPlacement(itemCategory: string, targetInventory: string): boolean
	local correctInventory = InventoryCategoryManager.GetInventoryType(itemCategory)
	return correctInventory == targetInventory
end

-- Helper function to get all items of a specific category
function InventoryCategoryManager.GetItemsByCategory(category: string): {string}
	local items = {}
	
	-- Search building items
	if category == "Lantern" then
		return ITEM_DEFINITIONS.building.lanterns
	elseif category == "PlotUpgrade" then
		return ITEM_DEFINITIONS.building.plotUpgrades
	elseif category == "Tool" then
		return ITEM_DEFINITIONS.building.tools
	end
	
	-- Search equipment items
	if category == "Weapon" then
		return ITEM_DEFINITIONS.equipment.weapons
	elseif category == "LanternHead" then
		return ITEM_DEFINITIONS.equipment.lanternHeads
	elseif category == "Curse" then
		return ITEM_DEFINITIONS.equipment.curses
	elseif category == "Mobility" then
		-- Combine all mobility types
		for _, mobItems in pairs(ITEM_DEFINITIONS.equipment.mobility) do
			for _, item in ipairs(mobItems) do
				table.insert(items, item)
			end
		end
		return items
	end
	
	return items
end

return InventoryCategoryManager
