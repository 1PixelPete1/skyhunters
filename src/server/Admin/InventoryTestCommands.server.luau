--!strict
-- InventoryTestCommands.server.luau
-- Test commands for verifying inventory integration
-- Only runs in Studio for testing

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- Only run in Studio
if not RunService:IsStudio() then
    return
end

local function getServices()
    local services = {}
    
    -- Try to get services
    pcall(function()
        local Systems = ServerScriptService:WaitForChild("Systems")
        services.InventoryService = require(Systems:WaitForChild("InventoryService"))
        services.InventoryIntegrationService = require(Systems:WaitForChild("InventoryIntegrationService"))
        services.MobilityService = require(Systems:WaitForChild("Mobility"):WaitForChild("MobilityService"))
        services.PlotService = require(Systems:WaitForChild("PlotService"))
        services.SaveService = require(Systems:WaitForChild("SaveService"))
    end)
    
    return services
end

local services = getServices()

-- Chat commands for testing
Players.PlayerAdded:Connect(function(player)
    player.Chatted:Connect(function(msg)
        local args = string.split(msg, " ")
        local cmd = args[1]
        
        -- Test inventory system
        if cmd == "/inv" then
            local subcmd = args[2]
            
            if subcmd == "test" then
                -- Full integration test
                print("=== INVENTORY INTEGRATION TEST ===")
                
                if not services.InventoryService then
                    warn("InventoryService not available")
                    return
                end
                
                -- Test 1: Add items
                print("Test 1: Adding items to inventory...")
                local items = {
                    {id = "basic_lantern", qty = 5},
                    {id = "enhanced_lantern", qty = 3},
                    {id = "oil_cannister", qty = 10},
                    {id = "pond_excavator", qty = 2},
                    {id = "double_jump", qty = 1},
                    {id = "dash_boots", qty = 1},
                    {id = "lantern_headlamp", qty = 1},
                    {id = "curse_of_greed", qty = 1},
                    {id = "iron_sword", qty = 1}
                }
                
                for _, item in ipairs(items) do
                    local success = services.InventoryService:AddItem(player, item.id, item.qty)
                    if success then
                        print("  ✅ Added", item.qty, "x", item.id)
                    else
                        warn("  ❌ Failed to add", item.id)
                    end
                end
                
                -- Test 2: Check inventory
                print("\nTest 2: Checking inventory contents...")
                local inventory = services.InventoryService:GetPlayerInventory(player)
                if inventory then
                    print("  Building items:", #inventory.buildingItems, "slots used")
                    print("  Capacity:", inventory.usedSlots, "/", inventory.capacity)
                    
                    -- Count items by category
                    local categories = {}
                    for _, slot in pairs(inventory.buildingItems) do
                        if slot.item then
                            local cat = slot.item.category
                            categories[cat] = (categories[cat] or 0) + slot.quantity
                        end
                    end
                    
                    for cat, count in pairs(categories) do
                        print("  ", cat, ":", count, "items")
                    end
                end
                
                -- Test 3: Add to hotbar
                print("\nTest 3: Adding items to hotbar...")
                services.InventoryService:AddToHotbar(player, "basic_lantern", 1, 1)
                services.InventoryService:AddToHotbar(player, "oil_cannister", 2, 1)
                services.InventoryService:AddToHotbar(player, "pond_excavator", 3, 1)
                print("  ✅ Added 3 items to hotbar")
                
                -- Test 4: Equip mobility items
                print("\nTest 4: Equipping mobility gear...")
                services.InventoryService:EquipItem(player, "double_jump", "Jump")
                services.InventoryService:EquipItem(player, "dash_boots", "Dash")
                print("  ✅ Equipped jump and dash gear")
                
                -- Test 5: Equip other items
                print("\nTest 5: Equipping other gear...")
                services.InventoryService:EquipItem(player, "lantern_headlamp", "LanternHead")
                services.InventoryService:EquipItem(player, "iron_sword", "Weapon")
                services.InventoryService:EquipItem(player, "curse_of_greed", "Curse1")
                print("  ✅ Equipped lantern head, weapon, and curse")
                
                -- Test 6: Validate with integration service
                if services.InventoryIntegrationService then
                    print("\nTest 6: Testing integration validation...")
                    
                    local hasLantern = services.InventoryIntegrationService:ValidateLanternInventory(player)
                    print("  Has lantern:", hasLantern)
                    
                    local oilCount = services.InventoryIntegrationService:ValidateOilCanister(player)
                    print("  Oil canisters:", oilCount)
                    
                    local hasJump = services.InventoryIntegrationService:ValidateMobilityEquipment(player, "Leap")
                    print("  Has jump equipment:", hasJump)
                    
                    local hasDash = services.InventoryIntegrationService:ValidateMobilityEquipment(player, "Dash")
                    print("  Has dash equipment:", hasDash)
                    
                    local hasPondUpgrade = services.InventoryIntegrationService:ValidatePlotUpgrade(player, "pond_excavator")
                    print("  Has pond excavator:", hasPondUpgrade)
                end
                
                print("\n=== TEST COMPLETE ===")
                
            elseif subcmd == "show" then
                -- Show current inventory
                local inventory = services.InventoryService:GetPlayerInventory(player)
                if inventory then
                    print("=== INVENTORY FOR", player.Name, "===")
                    print("Building Items:")
                    for slotId, slot in pairs(inventory.buildingItems) do
                        if slot.item then
                            print("  Slot", slotId, ":", slot.item.name, "x", slot.quantity)
                        end
                    end
                    
                    print("\nHotbar:")
                    for i = 1, 10 do
                        local slot = inventory.hotbar[i]
                        if slot and slot.item then
                            print("  Slot", i, ":", slot.item.name, "x", slot.quantity)
                        else
                            print("  Slot", i, ": [empty]")
                        end
                    end
                    
                    print("\nEquipment:")
                    print("  Weapon:", inventory.equipment.weapon and inventory.equipment.weapon.name or "none")
                    print("  Lantern Head:", inventory.equipment.lanternHead and inventory.equipment.lanternHead.name or "none")
                    print("  Jump:", inventory.equipment.mobility.jump and inventory.equipment.mobility.jump.name or "none")
                    print("  Dash:", inventory.equipment.mobility.dash and inventory.equipment.mobility.dash.name or "none")
                    print("  Grapple:", inventory.equipment.mobility.grapple and inventory.equipment.mobility.grapple.name or "none")
                    
                    print("\nCurses:")
                    for i, curse in ipairs(inventory.equipment.curses) do
                        print("  Curse", i, ":", curse.name)
                    end
                    
                    print("\nStats:")
                    print("  Used Slots:", inventory.usedSlots, "/", inventory.capacity)
                else
                    print("No inventory found for", player.Name)
                end
                
            elseif subcmd == "clear" then
                -- Clear inventory
                print("Clearing inventory for", player.Name)
                local inventory = services.InventoryService:GetPlayerInventory(player)
                if inventory then
                    -- Clear all items
                    inventory.buildingItems = {}
                    inventory.hotbar = {}
                    inventory.equipment = {
                        weapon = nil,
                        lanternHead = nil,
                        mobility = {
                            jump = nil,
                            dash = nil,
                            grapple = nil
                        },
                        curses = {}
                    }
                    inventory.usedSlots = 0
                    
                    -- Send update to client
                    local Net = require(ReplicatedStorage.Shared.Net)
                    Net.Fire(player, "UpdateInventory", inventory)
                    
                    print("✅ Inventory cleared")
                end
                
            elseif subcmd == "validate" then
                -- Test placement validation
                print("=== PLACEMENT VALIDATION TEST ===")
                
                if services.InventoryIntegrationService then
                    -- Test different item types
                    local tests = {
                        {id = "basic_lantern", pos = Vector3.new(0, 10, 0)},
                        {id = "enhanced_lantern", pos = Vector3.new(10, 10, 0)},
                        {id = "pond_excavator", pos = Vector3.new(0, 10, 10)},
                        {id = "oil_cannister", pos = Vector3.new(10, 10, 10)}
                    }
                    
                    for _, test in ipairs(tests) do
                        local valid = services.InventoryIntegrationService:ValidatePlacement(player, test.id, test.pos)
                        print("  ", test.id, ":", valid and "✅ Valid" or "❌ Invalid")
                    end
                else
                    warn("InventoryIntegrationService not available")
                end
                
            elseif subcmd == "consume" then
                -- Test item consumption
                print("=== CONSUMPTION TEST ===")
                
                if services.InventoryIntegrationService then
                    -- Try to consume a lantern
                    local consumed = services.InventoryIntegrationService:ConsumeLanternItem(player, "basic_lantern")
                    print("  Lantern consumed:", consumed)
                    
                    -- Try to consume oil
                    local oilConsumed = services.InventoryIntegrationService:ConsumeOilCanister(player, 1)
                    print("  Oil consumed:", oilConsumed)
                    
                    -- Try to consume pond excavator
                    local pondConsumed = services.InventoryIntegrationService:ConsumePlotUpgrade(player, "pond_excavator")
                    print("  Pond excavator consumed:", pondConsumed)
                else
                    warn("InventoryIntegrationService not available")
                end
                
            else
                print("Usage:")
                print("  /inv test - Run full integration test")
                print("  /inv show - Show current inventory")
                print("  /inv clear - Clear inventory")
                print("  /inv validate - Test placement validation")
                print("  /inv consume - Test item consumption")
            end
            
        -- Quick grant commands
        elseif cmd == "/give" then
            local itemId = args[2]
            local quantity = tonumber(args[3]) or 1
            
            if itemId and services.InventoryService then
                local success = services.InventoryService:AddItem(player, itemId, quantity)
                if success then
                    print("✅ Gave", quantity, "x", itemId, "to", player.Name)
                else
                    warn("Failed to give", itemId)
                end
            else
                print("Usage: /give <itemId> [quantity]")
                print("Examples:")
                print("  /give basic_lantern 5")
                print("  /give oil_cannister 10")
                print("  /give double_jump 1")
            end
            
        -- Quick equip command
        elseif cmd == "/equip" then
            local itemId = args[2]
            local slotType = args[3]
            
            if itemId and slotType and services.InventoryService then
                local success = services.InventoryService:EquipItem(player, itemId, slotType)
                if success then
                    print("✅ Equipped", itemId, "to", slotType)
                else
                    warn("Failed to equip", itemId)
                end
            else
                print("Usage: /equip <itemId> <slotType>")
                print("Slot types: Weapon, LanternHead, Jump, Dash, Grapple, Curse1, Curse2, Curse3")
            end
        end
    end)
end)

print("=== Inventory Test Commands Loaded ===")
print("Available commands:")
print("  /inv test - Run full integration test")
print("  /inv show - Show current inventory")
print("  /inv clear - Clear inventory")
print("  /inv validate - Test placement validation")
print("  /inv consume - Test item consumption")
print("  /give <itemId> [quantity] - Give items")
print("  /equip <itemId> <slotType> - Equip items")
