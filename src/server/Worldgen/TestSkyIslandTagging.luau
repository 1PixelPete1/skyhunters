-- Test script to verify the sky island tagging and cleanup system works
local CollectionService = game:GetService("CollectionService")

-- Import the fixed generator
local SkyIslandGenerator = require(script.Parent.SkyIslandGenerator_FIXED)

-- Create a simple test
local function testTaggingSystem()
    print("=== TESTING SKY ISLAND TAGGING SYSTEM ===")
    
    -- Create a test generator
    local generator = SkyIslandGenerator.new({
        HUB = { Radius = 200 }
    })
    
    -- Test 1: Create some test objects and tag them
    print("\n1. Testing tagging functionality...")
    
    local testFolder = Instance.new("Folder")
    testFolder.Name = "TestConstellationContent" 
    testFolder.Parent = workspace
    
    local testPart = Instance.new("Part")
    testPart.Name = "TestConstellationPart"
    testPart.Position = Vector3.new(1000, 100, 1000) -- Far from spawn
    testPart.Anchored = true
    testPart.Parent = testFolder
    
    -- Tag them
    generator:_tagConstellationContent(testFolder, "TestFolder")
    generator:_tagConstellationContent(testPart, "TestPart")
    
    -- Test 2: Check if tags were applied
    print("\n2. Checking if tags were applied...")
    local taggedItems = CollectionService:GetTagged("SkyIslandContent")
    print(string.format("Found %d tagged items", #taggedItems))
    
    for _, item in ipairs(taggedItems) do
        print(string.format("  - %s (%s) - Type: %s", item.Name, item.ClassName, item:GetAttribute("ConstellationType") or "unknown"))
    end
    
    -- Test 3: Test cleanup
    print("\n3. Testing cleanup...")
    generator:Cleanup()
    
    -- Test 4: Verify cleanup worked
    print("\n4. Verifying cleanup...")
    local remainingTaggedItems = CollectionService:GetTagged("SkyIslandContent")
    print(string.format("Remaining tagged items after cleanup: %d", #remainingTaggedItems))
    
    -- Check if test objects still exist
    local testStillExists = workspace:FindFirstChild("TestConstellationContent")
    if testStillExists then
        print("❌ ERROR: Test objects were not removed!")
        testStillExists:Destroy() -- Clean up manually
    else
        print("✅ SUCCESS: Test objects were properly removed!")
    end
    
    print("\n=== TEST COMPLETE ===")
end

-- Run the test
testTaggingSystem()
