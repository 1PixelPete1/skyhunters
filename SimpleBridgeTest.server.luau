--!strict
-- SimpleBridgeTest.server.luau
-- Simple test to check if the mesh works at all

print("\n[SimpleBridgeTest] Starting simple bridge mesh test...")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Get the bridge model
local bridge = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Catalog"):WaitForChild("Models"):WaitForChild("bridge_pone_1")

print(string.format("[SimpleBridgeTest] Found bridge: %s", bridge.ClassName))

-- Check all children
print("[SimpleBridgeTest] Bridge contents:")
for _, child in ipairs(bridge:GetChildren()) do
    print(string.format("  - %s (%s)", child.Name, child.ClassName))
    
    if child:IsA("MeshPart") then
        print(string.format("    MeshId: %s", child.MeshId))
        print(string.format("    MeshSize: %s", tostring(child.MeshSize)))
        print(string.format("    Size: %s", tostring(child.Size)))
        
        -- Try to clone and place the mesh directly
        print("[SimpleBridgeTest] Testing direct mesh placement...")
        
        local testMesh = child:Clone()
        testMesh.Name = "DirectMeshTest"
        testMesh.Position = Vector3.new(0, 100, 0)
        testMesh.Anchored = true
        testMesh.CanCollide = true
        testMesh.Parent = workspace
        
        print("[SimpleBridgeTest] Direct mesh placed at (0, 100, 0)")
        
        -- Also test with the scaling that should be applied
        local scaledMesh = child:Clone()
        scaledMesh.Name = "ScaledMeshTest"
        scaledMesh.Position = Vector3.new(50, 100, 0)
        scaledMesh.Anchored = true
        scaledMesh.CanCollide = true
        
        -- Apply the 0.04 scaling
        if scaledMesh.MeshSize and scaledMesh.MeshSize.Magnitude > 0 then
            scaledMesh.Size = scaledMesh.MeshSize * Vector3.new(0.04, 0.04, 0.04)
            print(string.format("[SimpleBridgeTest] Scaled mesh size: %s", tostring(scaledMesh.Size)))
        else
            print("[SimpleBridgeTest] WARNING: MeshSize is invalid!")
        end
        
        scaledMesh.Parent = workspace
        print("[SimpleBridgeTest] Scaled mesh placed at (50, 100, 0)")
        
        break
    end
end

-- Check PrimaryPart
if bridge.PrimaryPart then
    print(string.format("[SimpleBridgeTest] PrimaryPart: %s (%s)", bridge.PrimaryPart.Name, bridge.PrimaryPart.ClassName))
else
    print("[SimpleBridgeTest] No PrimaryPart set!")
end

print("[SimpleBridgeTest] Test complete - check workspace at (0,100,0) and (50,100,0)")

-- Clean up after 60 seconds
wait(60)
for _, obj in pairs(workspace:GetChildren()) do
    if obj.Name == "DirectMeshTest" or obj.Name == "ScaledMeshTest" then
        obj:Destroy()
    end
end

script:Destroy()