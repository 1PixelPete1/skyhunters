# Player State System Documentation

## Overview
The Player State System manages three distinct player states in QuietWinds:
- **Build**: Player is in their own plot and can place buildings
- **Neutral**: Player is in the spawn hub area
- **Run**: Player is exploring constellations and collecting resources

## Features

### 1. **State Management**
- Automatic state detection based on player position
- State transitions with validation rules
- State history tracking
- Client-server synchronization

### 2. **Custom Health System**
- Heart-based health (like Binding of Isaac)
- Attacks deal 1 damage per heart
- No character reset on death
- Fade to black and teleport on defeat
- Upgradeable maximum hearts

### 3. **Temporary Bag System**
- Active only in "Run" state
- Limited slots for unique items (upgradeable)
- Stackable items within slots
- Crude oil collection (special resource)
- Items transfer to permanent inventory on safe return
- Items lost if player is defeated

### 4. **Recall System**
- Press 'B' to start recall (4-second channel)
- Must stand still during recall
- Release 'B' to cancel
- Returns player to spawn/plot with collected items
- Visual progress bar during recall

### 5. **Loot System**
- Bell curve RNG for better loot distribution
- Multiple rarity tiers: Common, Uncommon, Rare, Epic, Legendary
- Configurable loot tables for different node types
- Guaranteed drops for special nodes
- Luck modifier support

### 6. **Resource Nodes**
- Temporary nodes spawn around the world
- Touch-based collection (simplified for testing)
- Visual effects and animations
- Respawn timer (60 seconds default)
- Different node types with unique loot tables

## Usage

### Test Commands (Development)
```
/state - Check your current state
/damage [amount] - Test damage system
/heal [amount] - Test healing system
/giveitem [itemId] [count] - Add item to temporary bag
/spawnnode [nodeType] - Spawn resource node
/testloot [tableId] [iterations] - Test loot distribution
/recall - Force start recall
```

### Node Types
- `BasicResource` - Common materials (wood, stone, fiber)
- `RichResource` - Better materials (iron, gold, crystals)
- `CrudeOilNode` - Crude oil deposits
- `TreasureChest` - Mixed loot with guaranteed oil
- `EpicChest` - Rare items with high oil rewards

### Client Controls
- **B Key**: Start/Cancel recall (hold to recall, release to cancel)
- **Movement**: Cancel recall if moving

## Integration Points

### With Existing Systems
1. **PlotService**: Determines if player is in their plot for Build state
2. **SaveService**: Stores hearts, crude oil, inventory, and upgrades
3. **WorldConfig**: Uses hub radius and spawn position settings
4. **PlacementService**: Should check player state before allowing placement

### Files Modified
- `SaveService.luau` - Added hearts, crudeOil, and upgrade fields to player profile
- `PlotService.luau` - Added position checking functions

### New Files Created
- `PlayerStateService.luau` - Core state management
- `LootTableService.luau` - Loot table and RNG system
- `ResourceNodeService.luau` - Resource node spawning and harvesting
- `PlayerStateClient.client.luau` - Client UI and controls
- `PlayerStateHandler.server.luau` - Server initialization and remotes

## Next Steps

### Immediate
1. Connect to existing placement system to check Build state
2. Add more diverse resource node models
3. Implement proper enemy system that uses hearts

### Future Enhancements
1. Equipment system to increase hearts
2. Bag upgrade shop/crafting
3. More complex loot tables with conditional drops
4. Resource node placement on sky islands
5. Enemy AI that damages players
6. Special abilities for each state
7. Persistent resource nodes with ownership
8. Trading system for collected resources

## Configuration

### Constants (PlayerStateService)
```lua
RECALL_DURATION = 4 -- seconds
BASE_HEARTS = 3
BASE_BAG_SLOTS = 8
HUB_RADIUS = 150 -- studs from spawn
SPAWN_POSITION = Vector3.new(0, 100, 0)
```

### Resource Node Settings
```lua
NODE_CHECK_RADIUS = 8 -- studs
RESPAWN_TIME = 60 -- seconds
```

## Troubleshooting

### Common Issues
1. **State not updating**: Check player position detection and plot boundaries
2. **Hearts not showing**: Ensure client UI is properly initialized
3. **Bag items disappearing**: Verify state transitions and transfer logic
4. **Recall not working**: Check input handling and state requirements

### Debug Output
Enable debug messages in server console to track:
- State transitions
- Item collection
- Damage/healing events
- Recall progress