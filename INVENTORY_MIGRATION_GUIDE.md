# Inventory Integration Migration Guide

## Overview
This guide helps migrate existing game systems to use the new integrated inventory system with proper validation and persistence.

## Quick Start Checklist

- [x] InventoryService initialized
- [x] InventoryIntegrationService added to server init
- [x] PlacementService hooks inventory validation
- [x] MobilityService checks equipment
- [x] LanternService integrates oil consumption
- [ ] SaveService stores inventory data
- [ ] Client UI updated for inventory
- [ ] Testing suite implemented

## Migration Steps

### Step 1: Update Server Initialization

In `src/server/init.server.luau`, ensure services load in correct order:

```lua
loadService("InventoryService", Systems:FindFirstChild("InventoryService"))
loadService("InventoryIntegrationService", Systems:FindFirstChild("InventoryIntegrationService"))
loadService("ToolService", Systems:FindFirstChild("ToolService"))
```

### Step 2: Update PlacementService

Replace direct placement with inventory validation:

**Old Code:**
```lua
RF.OnServerInvoke = function(player, cframe, presetKey)
    -- Direct placement without checking inventory
    local success = LanternService.ApplyPlacement(player, plotId, pos, yaw, presetKey)
    return success
end
```

**New Code:**
```lua
RF.OnServerInvoke = function(player, cframe, presetKey)
    -- Validate inventory first
    local InventoryIntegration = load(SSS:WaitForChild("Systems"):WaitForChild("InventoryIntegrationService"))
    if InventoryIntegration then
        local hasItem = InventoryIntegration:ValidatePlacement(player, presetKey, cframe.Position)
        if not hasItem then
            return false, "NO_INVENTORY_ITEM"
        end
    end
    
    -- Place and consume on success
    local success = LanternService.ApplyPlacement(player, plotId, pos, yaw, presetKey)
    if success and InventoryIntegration then
        InventoryIntegration:OnItemPlaced(player, presetKey, true)
    end
    return success
end
```

### Step 3: Update MobilityService

Enable equipment requirements:

**In MobilityConfig.luau:**
```lua
-- Change from:
RequiresEquipment = false

-- To:
RequiresEquipment = true -- Enable in production
RequiresEquipment = false -- Keep disabled for testing
```

**Equipment validation is now automatic through CheckEquipment method**

### Step 4: Update Tool System

Replace tool granting with inventory items:

**Old Code:**
```lua
-- Direct tool creation
ToolService.GrantTool(player, "lantern_basic")
```

**New Code:**
```lua
-- Add to inventory instead
InventoryService:AddItem(player, "lantern_basic", 1)
-- Tool automatically appears in hotbar/inventory UI
```

### Step 5: Update Save System

Add inventory to player profile:

```lua
-- In SaveService profile template:
local defaultProfile = {
    -- Existing data...
    inventory = nil, -- Will be serialized by InventoryService
    equipment = nil,
    upgrades = {}
}
```

### Step 6: Update Client UI

Replace old tool UI with inventory UI:

**Add to client initialization:**
```lua
-- In your main client script
local InventoryController = require(script.Parent.Inventory.InventoryController)
local InventoryIntegrationController = require(script.Parent.Inventory.InventoryIntegrationController)

InventoryController:Init()
InventoryIntegrationController:Init()
```

## Common Migration Patterns

### Pattern 1: Item Granting

**Before:**
```lua
-- Various systems granting items differently
player.Backpack:FindFirstChild("Lantern"):Clone()
ToolService.GrantTool(player, "lantern")
CreateLanternTool(player)
```

**After:**
```lua
-- Unified through InventoryService
InventoryService:AddItem(player, "lantern_basic", 1)
```

### Pattern 2: Item Consumption

**Before:**
```lua
-- Direct removal without validation
local tool = player.Backpack:FindFirstChild("Lantern")
if tool then tool:Destroy() end
```

**After:**
```lua
-- Validated consumption
local success = InventoryService:RemoveItem(player, "lantern_basic", 1)
if not success then
    -- Handle failure
end
```

### Pattern 3: Equipment Checks

**Before:**
```lua
-- Check for tool in backpack
local hasJumpPack = player.Backpack:FindFirstChild("JumpPack") ~= nil
```

**After:**
```lua
-- Check equipped items
local inventory = InventoryService:GetPlayerInventory(player)
local hasJumpPack = inventory.equipment.mobility.jump ~= nil
```

### Pattern 4: Upgrade Validation

**Before:**
```lua
-- Check data stores or attributes
local hasPondUpgrade = player:GetAttribute("HasPondUpgrade")
```

**After:**
```lua
-- Check inventory for upgrade items
local hasUpgrade = InventoryIntegrationService:ValidatePlotUpgrade(player, "pond_excavator")
```

## Testing Migration

### Test Commands

```lua
-- Test inventory granting
local player = game.Players.LocalPlayer
game.ReplicatedStorage.Net:GetFunction("GrantItem"):InvokeServer("basic_lantern", 5)

-- Test equipment
game.ReplicatedStorage.Net:GetFunction("EquipItem"):InvokeServer("double_jump", "Jump")

-- Test placement with inventory
local testCFrame = CFrame.new(0, 10, 0)
local success, reason = game.ReplicatedStorage.Net.Remotes.RF_PlaceLantern:InvokeServer(testCFrame, "basic_lantern")
print("Placement result:", success, reason)
```

### Validation Checklist

1. **Lantern Placement**
   - [ ] Player must have lantern in inventory
   - [ ] Lantern consumed on successful placement
   - [ ] Error shown if no lantern available

2. **Oil System**
   - [ ] Oil canisters consumed from inventory
   - [ ] Falls back to stored oil if no canisters
   - [ ] UI updates oil amount

3. **Mobility Equipment**
   - [ ] Abilities disabled without equipment
   - [ ] Visual indicators for equipped items
   - [ ] Proper cooldown management

4. **Plot Upgrades**
   - [ ] Pond placement requires excavator
   - [ ] Upgrade consumed on use
   - [ ] Effects properly applied

## Rollback Plan

If issues arise, disable integration without breaking core systems:

1. **Disable inventory validation:**
   ```lua
   -- In InventoryIntegrationService:ValidatePlacement
   return true -- Always allow placement
   ```

2. **Disable equipment requirements:**
   ```lua
   -- In MobilityConfig
   RequiresEquipment = false
   ```

3. **Use legacy tool system:**
   ```lua
   -- Re-enable ToolService granting
   ToolService.GrantTool(player, itemId)
   ```

## Performance Optimization

### Caching Strategies

```lua
-- Cache inventory locally to reduce lookups
local inventoryCache = {}
local CACHE_DURATION = 5 -- seconds

function getCachedInventory(player)
    local cached = inventoryCache[player]
    if cached and tick() - cached.time < CACHE_DURATION then
        return cached.inventory
    end
    
    local inventory = InventoryService:GetPlayerInventory(player)
    inventoryCache[player] = {
        inventory = inventory,
        time = tick()
    }
    return inventory
end
```

### Batch Operations

```lua
-- Batch multiple item additions
local itemsToAdd = {
    {id = "basic_lantern", quantity = 3},
    {id = "oil_cannister", quantity = 5},
    {id = "double_jump", quantity = 1}
}

for _, item in ipairs(itemsToAdd) do
    InventoryService:AddItem(player, item.id, item.quantity)
end

-- Send single update to client
Net.Fire(player, "UpdateInventory", inventory)
```

## Troubleshooting

### Issue: Items not appearing in inventory
- Check item exists in itemDatabase
- Verify inventory capacity not exceeded
- Ensure client UI is initialized

### Issue: Equipment not enabling abilities
- Verify MobilityConfig.RequiresEquipment setting
- Check equipment is in correct slot
- Ensure MobilityService has services reference

### Issue: Placement failing with inventory items
- Check InventoryIntegrationService is initialized
- Verify PlacementService has integration hooks
- Test with DEBUG_MODE enabled

### Issue: Oil canisters not consuming
- Verify canister item ID matches database
- Check LanternService has services reference
- Ensure integration service is loaded

## Support

For questions or issues:
1. Check debug output with DEBUG_MODE = true
2. Review INVENTORY_INTEGRATION_DOCUMENTATION.md
3. Test with provided debug commands
4. Check service initialization order
