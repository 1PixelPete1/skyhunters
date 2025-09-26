-- TestInventoryDragDrop.client.luau
-- Test script to verify inventory drag-drop functionality

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Only run in Studio for testing
if not RunService:IsStudio() then
    return
end

local player = Players.LocalPlayer

-- Wait for character and inventory system to load
task.wait(5)

print("=== Inventory Drag-Drop Test Starting ===")
print("Instructions:")
print("1. Press 'B' to open Building Inventory")
print("2. Items in the building inventory should be draggable")
print("3. Drag items to the hotbar slots at the bottom")
print("4. Items should snap to hotbar when dropped on valid slots")
print("5. Only building items (lanterns, oil, upgrades) should go to hotbar")
print("")
print("Common issues to check:")
print("- Are drag preview frames appearing?")
print("- Do hotbar slots highlight when hovering?")
print("- Does the server accept the move request?")
print("=== Test Ready ===")

-- Monitor for any errors
game:GetService("LogService").MessageOut:Connect(function(message, messageType)
    if messageType == Enum.MessageType.MessageError then
        if string.find(message, "Inventory") or string.find(message, "Drag") then
            warn("INVENTORY ERROR:", message)
        end
    end
end)
