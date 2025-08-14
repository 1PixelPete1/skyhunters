local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

-- RemoteEvents and RemoteFunctions are created before requiring modules to
-- avoid circular waits when modules like DebugCommands expect them at load time.
local getPlayerData = Instance.new("RemoteFunction")
getPlayerData.Name = "GetPlayerData"
getPlayerData.Parent = ReplicatedStorage

local sellAether = Instance.new("RemoteFunction")
sellAether.Name = "SellAether"
sellAether.Parent = ReplicatedStorage

local sellItem = Instance.new("RemoteFunction")
sellItem.Name = "SellItem"
sellItem.Parent = ReplicatedStorage

local purchaseUpgrade = Instance.new("RemoteFunction")
purchaseUpgrade.Name = "PurchaseUpgrade"
purchaseUpgrade.Parent = ReplicatedStorage

local debugAddCrumbs = Instance.new("RemoteFunction")
debugAddCrumbs.Name = "DebugAddCrumbs"
debugAddCrumbs.Parent = ReplicatedStorage

local debugGiveSeed = Instance.new("RemoteFunction")
debugGiveSeed.Name = "DebugGiveSeed"
debugGiveSeed.Parent = ReplicatedStorage

local spawnProducer = Instance.new("RemoteFunction")
spawnProducer.Name = "SpawnProducer"
spawnProducer.Parent = ReplicatedStorage

-- Aether RemoteEvents and RemoteFunctions
local aetherSnapshot = Instance.new("RemoteEvent")
aetherSnapshot.Name = "Aether_Snapshot"
aetherSnapshot.Parent = ReplicatedStorage

local aetherRequestSell = Instance.new("RemoteFunction")
aetherRequestSell.Name = "Aether_RequestSell"
aetherRequestSell.Parent = ReplicatedStorage

local aetherReachedCapacity = Instance.new("RemoteEvent")
aetherReachedCapacity.Name = "Aether_ReachedCapacity"
aetherReachedCapacity.Parent = ReplicatedStorage

local Economy = require(script:WaitForChild("Economy"))
local Aether = require(script:WaitForChild("Aether"))
local PlayerManager = require(script:WaitForChild("PlayerManager"))
local DebugCommands = require(script:WaitForChild("DebugCommands"))
local InventoryBridge = require(script:WaitForChild("InventoryBridge"))
local InventoryService = require(script:WaitForChild("InventoryService"))
local InventoryRemotes = require(script:WaitForChild("InventoryRemotes"))

local SaveScheduler = require(script:WaitForChild("SaveScheduler"))

DebugCommands.SetAetherSnapshot(aetherSnapshot)

game:BindToClose(function()
    SaveScheduler.flush()
end)


local function sendSnapshot(player, data)
    local payload = {
        aether = Aether.Snapshot(data),
        crumbs = data.crumbs,
        v = 1,
    }
    aetherSnapshot:FireClient(player, payload)
    InventoryBridge.OnSnapshotComposed(player, payload)

    if payload.aether and payload.aether.atCap then
        aetherReachedCapacity:FireClient(player)
    end
end


getPlayerData.OnServerInvoke = function(player)
    local data = PlayerManager.GetPlayerData(player)
    -- Send aether snapshot when player gets data
    print("Sending aether snapshot to", player.Name)
    sendSnapshot(player, data)
    return data
end

sellAether.OnServerInvoke = function(player)
    local data = PlayerManager.GetPlayerData(player)
    local gain = Economy.SellAether(data)
    PlayerManager.SavePlayerData(player, data)
    sendSnapshot(player, data)

    return gain, data.crumbs
end

sellItem.OnServerInvoke = function(player, itemId, qty)
    local data = PlayerManager.GetPlayerData(player)
    local gain = Economy.SellItem(data, itemId, qty)
    PlayerManager.SavePlayerData(player, data)
    return gain, data.crumbs
end

purchaseUpgrade.OnServerInvoke = function(player, upgradeId)
    local data = PlayerManager.GetPlayerData(player)
    local success = Economy.PurchaseUpgrade(data, upgradeId)
    PlayerManager.SavePlayerData(player, data)
    if success then
        Aether.ApplyUpgrade(data, upgradeId)
        sendSnapshot(player, data)
    end
    return success, data.crumbs
end

debugAddCrumbs.OnServerInvoke = function(player, amount)
    local data = PlayerManager.GetPlayerData(player)
    local success = Economy.ApplyCrumbsDelta(data, amount, "grant")
    PlayerManager.SavePlayerData(player, data)
    return success, data.crumbs
end

debugGiveSeed.OnServerInvoke = function(player)
    InventoryService.Add(player, "prod_cube_basic", 1)
    local data = PlayerManager.GetPlayerData(player)
    PlayerManager.SavePlayerData(player, data)
    return true
end

-- Aether RequestSell handler
aetherRequestSell.OnServerInvoke = function(player)
    local data = PlayerManager.GetPlayerData(player)
    local gain = Aether.RequestSell(data)
    PlayerManager.SavePlayerData(player, data)
    sendSnapshot(player, data)

    return gain, data.crumbs
end

spawnProducer.OnServerInvoke = function(player)
    local workspace = game:GetService("Workspace")
    local data = PlayerManager.GetPlayerData(player)
    
    -- Spawn a simple producer object
    local producer = Instance.new("Part")
    producer.Name = "Producer"
    producer.Size = Vector3.new(2, 2, 2)
    producer.Position = Vector3.new(math.random(-10, 10), 2, math.random(-10, 10))
    producer.Color = Color3.new(0.2, 0.8, 0.3)
    producer.Material = Enum.Material.Neon
    producer.Parent = workspace
    
    -- Add ClickDetector
    local clickDetector = Instance.new("ClickDetector")
    clickDetector.Parent = producer
    
    -- Add producer to aether system
    local uid = Aether.AddProducer(data, "Spawned", 0.5)
    PlayerManager.SavePlayerData(player, data)
    sendSnapshot(player, data)

    
    -- Make it clickable to remove
    clickDetector.MouseClick:Connect(function(clickingPlayer)
        if clickingPlayer == player then
            Aether.RemoveProducer(data, uid)
            PlayerManager.SavePlayerData(player, data)
            sendSnapshot(player, data)

            producer:Destroy()
            print("Removed producer", uid)
        end
    end)
    
    print("Spawned producer", uid, "for", player.Name)
    return true
end

-- Automatic Aether system test
local function runAetherTest()
    print("\n=== AETHER SYSTEM TEST ===")
    
    -- Create a test player data
    local testPlayer = {
        v = 1,
        id = 12345,
        crumbs = 0,
        inventory = {},
        upgrades = {},
        aether = {
            current = 0,
            target = 20,
            decayRate = 0.08,
            purityBase = 0.55,
            totalRate = 0,
            lastSettleTs = time(),
        },
        producers = {},
        timestamps = {},
    }
    
    -- Test 1: Initialize aether system
    print("1. Initializing aether system...")
    Aether.Init(testPlayer)
    print("   Current:", testPlayer.aether.current, "Target:", testPlayer.aether.target)
    
    -- Test 2: Add producers
    print("2. Adding producers...")
    local uid1 = Aether.AddProducer(testPlayer, "Basic", 1.0)
    local uid2 = Aether.AddProducer(testPlayer, "Advanced", 2.0)
    print("   Added producers:", uid1, uid2)
    print("   Total rate:", testPlayer.aether.totalRate)
    
    -- Test 3: Wait and settle (simulate 5 seconds)
    print("3. Simulating 5 seconds of growth...")
    testPlayer.aether.lastSettleTs = time() - 5
    Aether.Settle(testPlayer)
    print("   After 5s - Current:", testPlayer.aether.current)
    
    -- Test 4: Burst aether
    print("4. Adding burst aether...")
    Aether.ApplyBurst(testPlayer, 30)
    print("   After burst - Current:", testPlayer.aether.current)
    
    -- Test 5: Sell aether
    print("5. Selling aether...")
    local gain = Aether.RequestSell(testPlayer)
    print("   Gain:", gain, "crumbs, Remaining aether:", testPlayer.aether.current)
    
    -- Test 6: List producers
    print("6. Producer summary...")
    local producers = Aether.ListProducers(testPlayer)
    print("   Active producers:", #producers, "Total rate:", testPlayer.aether.totalRate)
    
    print("=== AETHER TEST COMPLETE ===\n")
end
-- Create static placement plane for item placement
local function createPlacementArea()
    local workspace = game:GetService("Workspace")

    local plane = Instance.new("Part")
    plane.Name = "PlacementArea"
    plane.Size = Vector3.new(200, 1, 200)
    plane.Position = Vector3.new(0, 0, 0)
    plane.Anchored = true
    plane.Material = Enum.Material.SmoothPlastic
    plane.Color = Color3.new(0.8, 0.8, 0.8)
    plane.Transparency = 0.5
    plane.Parent = workspace
end


-- Create static placement plane for item placement
local function createPlacementArea()
    local workspace = game:GetService("Workspace")

    local plane = Instance.new("Part")
    plane.Name = "PlacementArea"
    plane.Size = Vector3.new(200, 1, 200)
    plane.Position = Vector3.new(0, 0, 0)
    plane.Anchored = true
    plane.Material = Enum.Material.SmoothPlastic
    plane.Color = Color3.new(0.8, 0.8, 0.8)
    plane.Transparency = 0.5
    plane.Parent = workspace
end

createPlacementArea()

-- Create physical aether canister at spawn
local function createAetherCanister()
    local workspace = game:GetService("Workspace")
    
    local canister = Instance.new("Part")
    canister.Name = "AetherCanister"
    canister.Size = Vector3.new(4, 6, 4)
    canister.Position = Vector3.new(0, 3, 0)
    canister.Anchored = true
    canister.Shape = Enum.PartType.Cylinder
    canister.Material = Enum.Material.Neon
    canister.Color = Color3.new(0.3, 0.7, 1)
    canister.Parent = workspace
    
    -- Add SurfaceGui for the gauge
    local surfaceGui = Instance.new("SurfaceGui")
    surfaceGui.Name = "AetherGauge"
    surfaceGui.Face = Enum.NormalId.Front
    surfaceGui.Parent = canister

    print("Created aether canister at spawn (0,0,0)")
end

createAetherCanister()

-- Create sell lever with ProximityPrompt
local function createSellLever()
    local workspace = game:GetService("Workspace")
    local model = Instance.new("Model")
    model.Name = "SellLever"
    model.Parent = workspace

    local base = Instance.new("Part")
    base.Name = "Base"
    base.Size = Vector3.new(1, 1, 1)
    base.Anchored = true
    base.Position = Vector3.new(6, 1, 0)
    base.Parent = model

    local handle = Instance.new("Part")
    handle.Name = "Handle"
    handle.Size = Vector3.new(0.5, 3, 0.5)
    handle.Anchored = true
    handle.Position = Vector3.new(6, 2.5, 0)
    handle.Parent = model

    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = "Sell"
    prompt.ObjectText = "Aether"
    prompt.HoldDuration = 0.75
    prompt.Parent = handle

    local pivot = handle.CFrame
    prompt.Triggered:Connect(function(player)
        -- lever animation
        local down = TweenService:Create(handle, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            CFrame = pivot * CFrame.Angles(math.rad(-45), 0, 0)
        })
        local up = TweenService:Create(handle, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
            CFrame = pivot
        })
        down:Play()
        down.Completed:Wait()
        up:Play()

        local data = PlayerManager.GetPlayerData(player)
        local gain = Aether.RequestSell(data)
        PlayerManager.SavePlayerData(player, data)
        sendSnapshot(player, data)
        print("Lever sell", player.Name, gain)
    end)
end

createSellLever()

-- Run test 2 seconds after server starts
wait(2)
runAetherTest()

print("Economy server initialized!")
print("Aether system tested automatically on startup.")
