--!strict
-- InventoryTypes.luau
-- Type definitions for the inventory system

export type ItemCategory = "Lantern" | "PlotUpgrade" | "Decoration" | "Weapon" | "Mobility" | "Curse" | "LanternHead"
export type MobilityType = "Jump" | "Dash" | "Grapple"
export type EquipmentSlot = "Weapon" | "Jump" | "Dash" | "Grapple" | "LanternHead" | "Curse1" | "Curse2" | "Curse3"

export type InventoryItem = {
	id: string,
	name: string,
	description: string,
	category: ItemCategory,
	icon: string, -- Asset ID or path
	stackable: boolean,
	maxStack: number?,
	rarity: "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary",
	mobilityType: MobilityType?, -- For mobility items
	metadata: {[string]: any}?
}

export type InventorySlot = {
	item: InventoryItem?,
	quantity: number,
	slotIndex: number,
	locked: boolean
}

export type HotbarSlot = {
	item: InventoryItem?,
	quantity: number,
	slotNumber: number, -- 1-10
	keybind: Enum.KeyCode
}

export type Equipment = {
    weapon: InventoryItem?,
    lanternHead: InventoryItem?,
    mobility: {
        jump: InventoryItem?,
        dash: InventoryItem?,
        grapple: InventoryItem?
    },
	curses: {InventoryItem}
}

export type PlayerInventory = {
	playerId: number,
	buildingItems: {[string]: InventorySlot},
	equipment: Equipment,
	hotbar: {[number]: HotbarSlot},
	capacity: number,
	usedSlots: number
}

export type DragData = {
	item: InventoryItem,
	sourceType: "Building" | "Equipment" | "Hotbar",
	sourceSlot: number | string,
	quantity: number
}

export type InventoryUpdate = {
	updateType: "Add" | "Remove" | "Move" | "Equip" | "Unequip",
	item: InventoryItem?,
	targetSlot: number | string?,
	sourceSlot: number | string?,
	quantity: number?,
	metadata: {[string]: any}?
}

return nil
