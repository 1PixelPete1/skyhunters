-- ForceBridgeTest.server.luau
-- Forces creation of multiple bridges to test the current weight distribution

local BridgeMeshService = require(script.Parent.src.server.Worldgen.BridgeMeshService)
local UpdatedBridgeConfig = require(script.Parent.src.server.Worldgen.UpdatedBridgeConfig)

print("\n🧪 FORCE BRIDGE TEST")
print("="*50)

-- Get the current configuration
local configs = UpdatedBridgeConfig.GetConfigs()
print("\n📊 Current Bridge Configuration:")
for i, config in ipairs(configs) do
    print(string.format("  %d. %s - Weight: %d%% - Catalog: %s", 
        i, config.name, config.weight, tostring(config.useCatalogModel)))
end

-- Initialize bridge service
local bridgeService = BridgeMeshService.new(configs)

-- Create test folder
local testFolder = workspace:FindFirstChild("ForceBridgeTest") or Instance.new("Folder")
testFolder.Name = "ForceBridgeTest"
testFolder.Parent = workspace

-- Clear existing tests
testFolder:ClearAllChildren()

print("\n🔨 Creating 20 test bridges to see distribution...")

-- Track results
local results = {}
for _, config in ipairs(configs) do
    results[config.name] = 0
end

-- Create 20 bridges to test the distribution
for i = 1, 20 do
    local startPos = Vector3.new(-100 + i * 20, 100, 0)
    local endPos = Vector3.new(-100 + i * 20, 100, 50)
    
    local bridge = bridgeService:CreateBridge({
        startPos = startPos,
        endPos = endPos,
        parent = testFolder
    })
    
    if bridge then
        local bridgeType = bridge:GetAttribute("BridgeType")
        if bridgeType then
            results[bridgeType] = (results[bridgeType] or 0) + 1
        end
        
        -- Add a label
        local label = Instance.new("Part")
        label.Name = "Label"
        label.Size = Vector3.new(1, 1, 1)
        label.Position = startPos + Vector3.new(0, 10, 0)
        label.Anchored = true
        label.CanCollide = false
        label.BrickColor = if bridgeType == "CatalogBridge" then BrickColor.new("Bright green") else BrickColor.new("Bright red")
        label.Parent = testFolder
        
        local gui = Instance.new("SurfaceGui")
        gui.Face = Enum.NormalId.Top
        gui.Parent = label
        
        local textLabel = Instance.new("TextLabel")
        textLabel.Size = UDim2.new(1, 0, 1, 0)
        textLabel.BackgroundTransparency = 1
        textLabel.Text = bridgeType or "Unknown"
        textLabel.TextColor3 = Color3.new(1, 1, 1)
        textLabel.TextStrokeTransparency = 0
        textLabel.TextScaled = true
        textLabel.Parent = gui
    end
end

print("\n📊 RESULTS AFTER 20 BRIDGES:")
for configName, count in pairs(results) do
    local percentage = (count / 20) * 100
    print(string.format("  %s: %d/20 (%.1f%%)", configName, count, percentage))
end

print("\n🎯 EXPECTED vs ACTUAL:")
for _, config in ipairs(configs) do
    local actualCount = results[config.name] or 0
    local actualPercent = (actualCount / 20) * 100
    local expectedPercent = config.weight
    local diff = actualPercent - expectedPercent
    local status = if math.abs(diff) < 15 then "✅" else "⚠️"
    print(string.format("  %s %s: Expected %.0f%%, Got %.1f%% (diff: %+.1f%%)", 
        status, config.name, expectedPercent, actualPercent, diff))
end

print("\n💡 WHAT TO LOOK FOR:")
print("- CatalogBridge should appear ~90% of the time (green labels)")
print("- FallbackPlank should appear ~10% of the time (red labels)")
print("- If you see mostly red labels, the bridge_pone_1 model isn't imported properly")

print("\n" .. "="*50)
print("🏁 FORCE TEST COMPLETE")

-- Clean up after 60 seconds
wait(60)
if testFolder and testFolder.Parent then
    testFolder:Destroy()
end
script:Destroy()
