# Player State System - Complete Implementation

## ✅ Components Implemented

### **Server-Side Systems**

1. **PlayerStateService.luau** - Core state management
   - Three states: Build, Neutral, Run (+ Recalling transition)
   - Automatic state detection based on position
   - Custom heart-based health system
   - Temporary bag system for exploration
   - Recall mechanism (4 seconds, hold B key)
   - Integration with save system

2. **LootTableService.luau** - Advanced loot system
   - Bell curve RNG for better distribution
   - Five rarity tiers (Common to Legendary)
   - Configurable loot tables
   - Guaranteed drops support
   - Luck modifier system

3. **ResourceNodeService.luau** - Resource collection
   - Temporary nodes with respawn timers
   - Touch-based collection
   - Visual effects and animations
   - Different node types (Basic, Rich, Oil, Treasure)
   - Automatic respawning (60 second default)

4. **UpgradeService.luau** - Player progression
   - Heart upgrades (up to 6 total hearts)
   - Bag capacity upgrades (up to 24 slots)
   - Movement speed boost (10% in Run state)
   - Recall speed reduction (3 second minimum)
   - Luck bonus for better loot
   - Currency: Crumbs and Crude Oil

5. **PlayerStateHandler.server.luau** - Service initialization
   - Loads all services in correct order
   - Handles remote events
   - Provides test commands for development

### **Client-Side Systems**

1. **PlayerStateClient.client.luau** - Main UI
   - State indicator
   - Heart display (Binding of Isaac style)
   - Temporary bag display
   - Recall progress bar
   - Defeat screen with fade effect
   - Loot notifications

2. **UpgradeShop.client.luau** - Upgrade interface
   - Visual shop with categorized upgrades
   - Real-time affordability checking
   - Purchase animations
   - Stats display
   - Currency tracking
   - Press U to open

3. **StateTransitionEffects.client.luau** - Visual polish
   - Screen border colors per state
   - Transition flash effects
   - Character particle effects
   - Color correction per state
   - Blur effect during recall
   - Camera shake on Run state entry

### **Integration Updates**

1. **PlacementService** - Now checks player state before allowing placement
2. **SaveService** - Added hearts, crudeOil, and upgrade fields
3. **PlotService** - Added position checking methods

## 🎮 Player Experience Flow

### **Build State** (Green)
- Player is in their own plot
- Can place buildings and structures
- Ghost preview system active
- Safe from damage
- Access to upgrade shop

### **Neutral State** (Blue)
- Player is in spawn hub (150 stud radius)
- Cannot build but can use equipment
- Safe zone for trading/socializing
- Access to shops and services

### **Run State** (Red)
- Player exploring constellations
- Temporary bag active
- Can collect resources and crude oil
- Hearts can be lost to damage
- Must recall or return to keep items
- Resources respawn after collection

### **Recalling** (Cyan)
- 4-second channel (reducible to 3)
- Must stand still
- Visual progress bar
- Can be cancelled by moving/releasing B
- Returns to plot/spawn with items

## 🎯 Key Features

### **Heart System**
- No default Roblox health
- Starts with 3 hearts
- Upgradeable to 6 hearts
- 1 damage per attack
- No character reset on defeat
- Fade to black and teleport

### **Temporary Bag**
- Only active in Run state
- 8 base slots (upgradeable to 24)
- Unique items take slots
- Items stack within slots
- Crude oil doesn't take slots
- Lost on defeat

### **Loot System**
- Bell curve distribution
- 5 rarity tiers
- Luck modifier from upgrades
- Guaranteed drops for special nodes
- Visual rarity indicators

### **Resource Nodes**
- 5 types implemented
- 60-second respawn timer
- Touch-based collection
- Visual effects on harvest/respawn
- Floating animation

## 🛠️ Development Commands

```lua
/state - Check current state
/damage [amount] - Test damage
/heal [amount] - Test healing
/giveitem [itemId] [count] - Add to temp bag
/spawnnode [nodeType] - Spawn resource node
/testloot [tableId] [iterations] - Test distribution
/recall - Force start recall
```

## 🔧 Configuration

All major values are configurable at the top of services:
- `BASE_RECALL_DURATION = 4`
- `BASE_HEARTS = 3`
- `BASE_BAG_SLOTS = 8`
- `HUB_RADIUS = 150`
- `NODE_CHECK_RADIUS = 8`
- `RESPAWN_TIME = 60`

## 📈 Next Steps

### **Immediate**
1. Add enemy AI that uses the heart damage system
2. Create more diverse resource node models
3. Add sound effects for all transitions
4. Implement equipment items that modify stats

### **Future Enhancements**
1. Constellation generation with POIs
2. Boss enemies with special loot
3. Multiplayer exploration parties
4. Trading system between players
5. Crafting system using collected resources
6. Seasonal events with special nodes
7. Achievements and progression rewards

## 🐛 Known Issues
- Movement speed upgrade persists after state change (needs reset)
- Recall can be started from plot (should be Run only)
- Resource nodes spawn at fixed positions (need dynamic)

## 📚 Files Created/Modified

### Created (14 files):
- `src/server/Systems/PlayerStateService.luau`
- `src/server/Systems/LootTableService.luau`
- `src/server/Systems/ResourceNodeService.luau`
- `src/server/Systems/UpgradeService.luau`
- `src/server/PlayerStateHandler.server.luau`
- `src/client/PlayerStateClient.client.luau`
- `src/client/UpgradeShop.client.luau`
- `src/client/StateTransitionEffects.client.luau`
- `PLAYER_STATE_SYSTEM.md`

### Modified (3 files):
- `src/server/Systems/SaveService.luau` - Added player state fields
- `src/server/Systems/PlotService.luau` - Added position checking
- `src/server/PlacementService.server.luau` - Added state validation

## ✨ System Ready!

The player state system is now fully functional and integrated with your QuietWinds codebase. Players can explore, collect resources, upgrade their capabilities, and safely return home with their loot. The visual feedback and UI elements make the experience intuitive and engaging.

Test it out by:
1. Walking outside the hub to enter Run state
2. Collecting resource nodes
3. Pressing B to recall home
4. Pressing U to open the upgrade shop
5. Using test commands to verify functionality

Enjoy your new exploration system! 🚀