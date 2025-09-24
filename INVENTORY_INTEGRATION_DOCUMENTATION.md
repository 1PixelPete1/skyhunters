# Inventory Integration System Documentation

## Overview
The Inventory Integration System connects the inventory with all game mechanics including lanterns, oil, mobility equipment, plot upgrades, and curses. It provides server-side validation, persistent state management, and secure item consumption.

## Architecture

### Server Components

#### 1. InventoryService (`src/server/Systems/InventoryService.luau`)
- Core inventory management
- Item database
- Player inventory storage
- Equipment management
- Hotbar system
- Persistence through SaveService

#### 2. InventoryIntegrationService (`src/server/Systems/InventoryIntegrationService.luau`)
**Key Functions:**
- `ValidateLanternInventory(player, lanternType?)` - Checks if player has lantern items
- `ConsumeLanternItem(player, lanternType?)` - Removes lantern from inventory after placement
- `ValidateOilCanister(player)` - Returns number of oil canisters available
- `ConsumeOilCanister(player, amount)` - Consumes oil and adds to lantern storage
- `ValidateMobilityEquipment(player, abilityType)` - Checks if mobility equipment is equipped
- `ValidatePlotUpgrade(player, upgradeType)` - Validates plot upgrade availability
- `ConsumePlotUpgrade(player, upgradeType)` - Consumes and applies plot upgrades
- `OnEquipmentChanged(player, slotType, item)` - Handles equipment change effects

**Service Hooks:**
- PlacementService - Validates inventory before placing items
- MobilityService - Validates equipment before allowing abilities
- LanternService - Integrates oil consumption from inventory

### Client Components

#### InventoryIntegrationController (`src/client/Inventory/InventoryIntegrationController.client.luau`)
- Visual feedback for equipment changes
- Item consumption notifications
- Placement validation feedback
- Equipment visual effects (lantern head light, curse auras, mobility indicators)

## Item Categories

### Lanterns
- `basic_lantern` - Standard light source
- `enhanced_lantern` - Extended range
- `crystal_lantern` - Magical properties

### Plot Upgrades
- `oil_cannister` - Increases oil storage by 50 units
- `pond_excavator` - Allows pond placement

### Mobility Equipment
- `double_jump` - Equips to Jump slot, enables leap ability
- `dash_boots` - Equips to Dash slot, enables dash ability
- `grappling_hook` - Equips to Grapple slot, enables grappling

### Lantern Heads
- `lantern_headlamp` - Wearable light source

### Curses
- `curse_of_greed` - Double rewards, increased storm damage

## Integration Points

### 1. Placement System Integration

**Before Placement:**
```lua
-- PlacementService checks inventory
local hasItem = InventoryIntegration:ValidatePlacement(player, itemId, position)
if not hasItem then
    return false, "NO_INVENTORY_ITEM"
end
```

**After Successful Placement:**
```lua
-- Consume the placed item
InventoryIntegration:OnItemPlaced(player, itemId, true)
```

### 2. Mobility System Integration

**Equipment Check:**
```lua
-- MobilityService validates equipment
function MobilityService:CheckEquipment(player, abilityType)
    local InventoryIntegration = self.services.InventoryIntegrationService
    return InventoryIntegration:ValidateMobilityEquipment(player, abilityType)
end
```

**Equipment States:**
- Jump equipment enables Leap ability
- Dash equipment enables Dash ability
- Grapple equipment enables Grappling ability

### 3. Lantern System Integration

**Oil Refilling:**
```lua
-- LanternService checks inventory for oil canisters
local oilCanisters = InventoryIntegration:ValidateOilCanister(player)
if oilCanisters > 0 then
    -- Consume canisters instead of stored oil
    InventoryIntegration:ConsumeOilCanister(player, canistersNeeded)
end
```

## Security Features

### Server-Side Validation
- All item consumption validated on server
- Inventory state changes only through secure remotes
- Equipment requirements enforced server-side
- Placement validation before item consumption

### Anti-Cheat Measures
- Sequence number validation for ability requests
- Position validation for placed items
- Cooldown enforcement server-side
- Item quantity validation

### Debug Features
When `DEBUG_MODE = true`:
- Detailed console logging
- Failed validation reasons
- Item consumption tracking
- Equipment state changes

## Usage Examples

### Granting Items to Players
```lua
-- Give player starter items
InventoryService:AddItem(player, "basic_lantern", 3)
InventoryService:AddItem(player, "oil_cannister", 1)
InventoryService:AddItem(player, "double_jump", 1)
```

### Equipping Mobility Gear
```lua
-- Player equips jump pack
InventoryService:EquipItem(player, "double_jump", "Jump")
-- This enables the Leap ability in MobilityService
```

### Placing Lanterns
1. Player selects lantern from hotbar/inventory
2. PlacementService validates inventory
3. On successful placement:
   - Lantern created in world
   - Item consumed from inventory
   - Client notified of consumption

### Using Oil Canisters
1. Player interacts with lantern
2. LanternService checks for oil canisters
3. If available:
   - Canisters consumed from inventory
   - Oil added to lantern
4. If not available:
   - Falls back to stored oil

## Configuration

### Inventory Limits
- Building slots: 48 (8x6 grid)
- Equipment slots: Various (weapon, lanternHead, mobility x3, curses x3)
- Hotbar slots: 10
- Max stack size: 999 (default)

### Item Stacking
- Lanterns: Stackable (max 10 for basic, 5 for enhanced)
- Oil Canisters: Stackable (max 20)
- Equipment: Not stackable
- Upgrades: Stackable (varies by type)

## Testing

### Studio Testing Commands
```lua
-- Grant test items
game.ReplicatedStorage.Net.Remotes.RF_GrantItem:InvokeServer("basic_lantern", 5)

-- Equip mobility gear
game.ReplicatedStorage.Net.Remotes.RF_EquipItem:InvokeServer("double_jump", "Jump")

-- Test placement validation
game.ReplicatedStorage.Net.Remotes.RF_PlaceLantern:InvokeServer(CFrame.new(), "basic_lantern")
```

### Debug Prints
Enable `DEBUG_MODE` in both server and client integration services to see:
- Item validation results
- Consumption events
- Equipment changes
- Failed placement reasons

## Future Enhancements

### Planned Features
1. **Crafting System** - Combine items to create better equipment
2. **Trading System** - Player-to-player item exchanges
3. **Item Durability** - Equipment degradation over time
4. **Enchantments** - Upgrade equipment with special properties
5. **Item Rarity Tiers** - Different drop rates and power levels

### Integration Points
- Combat system for weapon equipment
- Building system for construction materials
- Quest system for reward distribution
- Achievement system for unlockable items

## Troubleshooting

### Common Issues

**"NO_INVENTORY_ITEM" error when placing:**
- Player lacks the required item
- Item is in equipment slot, not inventory
- Item type mismatch

**Mobility abilities not working:**
- Equipment not in correct slot
- RequiresEquipment flag disabled
- Client-server desync

**Oil canisters not consuming:**
- Inventory full
- Invalid canister quantity
- Integration service not initialized

### Debug Commands
```lua
-- Check player inventory
local inventory = InventoryService:GetPlayerInventory(player)
print(inventory)

-- Validate specific item
local hasItem = InventoryIntegrationService:ValidateLanternInventory(player, "basic_lantern")
print("Has lantern:", hasItem)

-- Force equipment update
InventoryIntegrationService:OnEquipmentChanged(player, "Jump", item)
```

## Performance Considerations

- Inventory updates batched to reduce network traffic
- Equipment effects cached locally
- Validation results cached for short duration
- Item database loaded once at startup

## Best Practices

1. Always validate on server before consuming items
2. Provide clear feedback for failed actions
3. Use debug mode during development
4. Test edge cases (full inventory, multiple consumptions)
5. Document new item types in item database
6. Keep integration service hooks minimal
