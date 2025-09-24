--!strict
-- BridgeMeshPartDiagnostic.server.luau
-- Targeted diagnostic to see exactly how BridgeMeshService processes your bridge_pone_1 model

print("\n[BridgeMeshPartDiag] =======================================")
print("[BridgeMeshPartDiag] BRIDGE MESH PART DIAGNOSTIC")
print("[BridgeMeshPartDiag] =======================================\n")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Find the bridge model
local function getBridgeModel()
    local shared = ReplicatedStorage:FindFirstChild("Shared")
    local catalog = shared and shared:FindFirstChild("Catalog")
    local models = catalog and catalog:FindFirstChild("Models")
    local bridge = models and models:FindFirstChild("bridge_pone_1")
    
    if not bridge then
        warn("[BridgeMeshPartDiag] Could not find bridge_pone_1 model!")
        return nil
    end
    
    print(string.format("[BridgeMeshPartDiag] Found bridge_pone_1: %s", bridge.ClassName))
    return bridge
end

-- Simulate what BridgeMeshService._getMeshPart does
local function simulateMeshExtraction(bridgeModel)
    print("\n[BridgeMeshPartDiag] Simulating BridgeMeshService mesh extraction...")
    
    if bridgeModel:IsA("Model") then
        print("[BridgeMeshPartDiag] Bridge is a Model, looking for parts...")
        
        -- Check PrimaryPart first
        local primaryPart = bridgeModel.PrimaryPart
        if primaryPart then
            print(string.format("[BridgeMeshPartDiag] Found PrimaryPart: %s", primaryPart.ClassName))
            if primaryPart:IsA("MeshPart") then
                print(string.format("[BridgeMeshPartDiag] PrimaryPart is MeshPart with MeshId: %s", primaryPart.MeshId))
                print(string.format("[BridgeMeshPartDiag] PrimaryPart MeshSize: %s", tostring(primaryPart.MeshSize)))
                return primaryPart
            else
                print("[BridgeMeshPartDiag] PrimaryPart is not a MeshPart")
            end
        else
            print("[BridgeMeshPartDiag] No PrimaryPart set")
        end
        
        -- Look for first BasePart child
        print("[BridgeMeshPartDiag] Looking for first BasePart child...")
        for _, child in ipairs(bridgeModel:GetChildren()) do
            print(string.format("[BridgeMeshPartDiag] Child: %s (%s)", child.Name, child.ClassName))
            
            if child:IsA("BasePart") then
                print(string.format("[BridgeMeshPartDiag] Found BasePart: %s", child.Name))
                
                if child:IsA("MeshPart") then
                    print(string.format("[BridgeMeshPartDiag] Is MeshPart with MeshId: %s", child.MeshId))
                    print(string.format("[BridgeMeshPartDiag] MeshSize: %s", tostring(child.MeshSize)))
                    print(string.format("[BridgeMeshPartDiag] Size: %s", tostring(child.Size)))
                    
                    -- Test cloning
                    local clone = child:Clone()
                    print(string.format("[BridgeMeshPartDiag] Clone MeshId: %s", clone.MeshId))
                    print(string.format("[BridgeMeshPartDiag] Clone MeshSize: %s", tostring(clone.MeshSize)))
                    clone:Destroy()
                else
                    print("[BridgeMeshPartDiag] Is regular Part, not MeshPart")
                end
                
                return child
            end
        end
        
        print("[BridgeMeshPartDiag] No BasePart children found")
    else
        print(string.format("[BridgeMeshPartDiag] Bridge is a %s, not a Model", bridgeModel.ClassName))
        return bridgeModel
    end
    
    return nil
end

-- Test the bridge scaling calculation
local function testScaling(meshPart)
    if not meshPart or not meshPart:IsA("MeshPart") then
        print("[BridgeMeshPartDiag] Cannot test scaling - not a MeshPart")
        return
    end
    
    print(string.format("\n[BridgeMeshPartDiag] Testing scaling for MeshPart: %s", meshPart.Name))
    
    local meshSize = meshPart.MeshSize
    local baseScale = Vector3.new(0.04, 0.04, 0.04)
    local targetLength = 100 -- Example bridge length
    
    print(string.format("[BridgeMeshPartDiag] Original MeshSize: %s", tostring(meshSize)))
    print(string.format("[BridgeMeshPartDiag] Base scale: %s", tostring(baseScale)))
    print(string.format("[BridgeMeshPartDiag] Target length: %d", targetLength))
    
    if meshSize and meshSize.Magnitude > 0 then
        local scale = baseScale
        local originalLength = meshSize.Z * scale.Z
        
        print(string.format("[BridgeMeshPartDiag] Original scaled length: %.3f", originalLength))
        
        if originalLength > 0 then
            local stretchFactor = targetLength / originalLength
            stretchFactor = math.clamp(stretchFactor, 0.5, 1.5) -- maxStretch = 1.5
            
            local finalScale = Vector3.new(
                scale.X,
                scale.Y,
                scale.Z * stretchFactor
            )
            
            print(string.format("[BridgeMeshPartDiag] Stretch factor: %.3f", stretchFactor))
            print(string.format("[BridgeMeshPartDiag] Final scale: %s", tostring(finalScale)))
            
            -- Calculate final size
            local finalSize = meshSize * finalScale
            print(string.format("[BridgeMeshPartDiag] Final size would be: %s", tostring(finalSize)))
        else
            print("[BridgeMeshPartDiag] Original length is 0 - scaling issue!")
        end
    else
        print("[BridgeMeshPartDiag] MeshSize is invalid!")
    end
end

-- Create a test bridge tile
local function createTestBridge(meshPart)
    if not meshPart then
        print("[BridgeMeshPartDiag] Cannot create test - no mesh part")
        return
    end
    
    print(string.format("\n[BridgeMeshPartDiag] Creating test bridge with: %s", meshPart.Name))
    
    local clone = meshPart:Clone()
    clone.Name = "TestBridgeTile"
    clone.Anchored = true
    clone.CanCollide = true
    
    -- Apply scaling like BridgeMeshService does
    if clone:IsA("MeshPart") and clone.MeshSize then
        local baseScale = Vector3.new(0.04, 0.04, 0.04)
        clone.Size = clone.MeshSize * baseScale
        print(string.format("[BridgeMeshPartDiag] Applied scaling - new Size: %s", tostring(clone.Size)))
    end
    
    -- Place in workspace for visual inspection
    clone.Position = Vector3.new(0, 200, 0) -- High up so you can see it
    clone.Parent = workspace
    
    print("[BridgeMeshPartDiag] Test bridge created at (0, 200, 0) - check workspace!")
    
    -- Clean up after 30 seconds
    game:GetService("Debris"):AddItem(clone, 30)
    
    return clone
end

-- Run diagnostics
local bridgeModel = getBridgeModel()
if not bridgeModel then
    return
end

local extractedPart = simulateMeshExtraction(bridgeModel)
if extractedPart then
    testScaling(extractedPart)
    createTestBridge(extractedPart)
else
    warn("[BridgeMeshPartDiag] Failed to extract part from bridge model!")
end

print("\n[BridgeMeshPartDiag] =======================================")
print("[BridgeMeshPartDiag] DIAGNOSTIC COMPLETE")
print("[BridgeMeshPartDiag] Check workspace at (0, 200, 0) for test bridge")
print("[BridgeMeshPartDiag] =======================================")

-- Self-destruct
wait(35)
script:Destroy()