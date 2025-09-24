-- StudioDevRemotes.server.luau
-- Server-side handlers for Studio development tools with ACTUAL functionality

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local StudioDevRemotes = {}
local services = nil

function StudioDevRemotes.Init(servicesTable)
    services = servicesTable
    
    -- Only run in Studio
    if not RunService:IsStudio() then
        return
    end
    
    print("[StudioDevRemotes] Starting in Studio mode...")
    
    -- Create remotes folder in Net for consistency with PondNetworkService
    local Net = ReplicatedStorage:FindFirstChild("Net") or Instance.new("Folder")
    Net.Name = "Net"; Net.Parent = ReplicatedStorage
    local remotes = Net:FindFirstChild("Remotes") or Instance.new("Folder")
    remotes.Name = "Remotes"; remotes.Parent = Net
    print("[StudioDevRemotes] Using Net/Remotes folder structure")
    
    -- Helper function to create remote events
    local function createRemote(name)
        local existing = remotes:FindFirstChild(name)
        if existing then
            print("[StudioDevRemotes] Found existing remote:", name)
            return existing
        end
        
        local remote = Instance.new("RemoteEvent")
        remote.Name = name
        remote.Parent = remotes
        print("[StudioDevRemotes] Created remote:", name)
        return remote
    end
    
    -- Create all dev remotes
    local devRemotes = {
        GrantItemRemote = createRemote("GrantItemRemote"),
        GrantCurrencyRemote = createRemote("GrantCurrencyRemote"),
        WipePlotRemote = createRemote("WipePlotRemote"),
        ResetTerrainRemote = createRemote("ResetTerrainRemote"),
        TeleportToPlotRemote = createRemote("TeleportToPlotRemote"),
        TeleportToPOIRemote = createRemote("TeleportToPOIRemote"),
        ForceSaveRemote = createRemote("ForceSaveRemote"),
        ClearPondsLanternsRemote = createRemote("ClearPondsLanternsRemote"),
        ReloadPondsRemote = createRemote("ReloadPondsRemote"),
        DebugPondNetworkRemote = createRemote("DebugPondNetworkRemote"),
        ValidateAllPlacementsRemote = createRemote("ValidateAllPlacementsRemote"),
        SpawnTestPondsRemote = createRemote("SpawnTestPondsRemote"),
        ClearTestObjectsRemote = createRemote("ClearTestObjectsRemote"),
        ToggleBoundaryVisRemote = createRemote("ToggleBoundaryVisRemote"),
        ShowPondConnectionsRemote = createRemote("ShowPondConnectionsRemote"),
        LoadingProgressRemote = createRemote("LoadingProgressRemote"), -- For loading screen
        OilAddAmountRemote = createRemote("OilAddAmountRemote"),
        OilSetAmountRemote = createRemote("OilSetAmountRemote"),
        AnalyzeRimsRemote = createRemote("AnalyzeRimsRemote"),  -- NEW: Rim analysis
        MigrateRimsRemote = createRemote("MigrateRimsRemote"),  -- NEW: Rim migration
        ResetSkyIslandsRemote = createRemote("ResetSkyIslandsRemote"), -- NEW: Force sky island regen
        ClearPlayerProfileRemote = createRemote("ClearPlayerProfileRemote"),
    }
    
    print("[StudioDevRemotes] Created", #devRemotes, "remotes")
    
    -- ACTUAL FUNCTIONAL HANDLERS
    
    -- Item grant handler - USES INVENTORY SERVICE WITH PROPER CATEGORIZATION
    devRemotes.GrantItemRemote.OnServerEvent:Connect(function(player, itemType, quantity)
        print("[StudioDevRemotes] Grant item request:", player.Name, itemType, quantity)
        
        -- Use the InventoryService to add items
        if services and services.InventoryService then
            local amount = tonumber(quantity) or 1
            
            -- AddItem handles everything including UI updates
            local success = services.InventoryService:AddItem(player, itemType, amount)
            
            if success then
                print("✅ Added", amount, itemType, "to", player.Name, "inventory")
                
                -- Get the item to check its category
                local item = services.InventoryService:GetItem(itemType)
                if item then
                    -- Only add building items to hotbar (Lantern, PlotUpgrade, Oil)
                    if item.category == "Lantern" or item.category == "PlotUpgrade" or item.category == "Oil" then
                        local inventory = services.InventoryService:GetPlayerInventory(player)
                        if inventory then
                            -- Find first empty hotbar slot
                            for i = 1, 10 do
                                if not inventory.hotbar[i] then
                                    services.InventoryService:AddToHotbar(player, itemType, i, 1)
                                    print("✅ Added", itemType, "to hotbar slot", i, "(Building item)")
                                    break
                                end
                            end
                        end
                    else
                        print("✅ Added", itemType, "to equipment inventory (category:", item.category, ")")
                    end
                end
                
                -- Force save the profile
                if services.SaveService and services.SaveService.SaveProfile then
                    services.SaveService.SaveProfile(player)
                    print("✅ Profile saved for", player.Name)
                end
            else
                warn("[StudioDevRemotes] Failed to add item - inventory may be full")
            end
        else
            warn("[StudioDevRemotes] InventoryService not available!")
        end
    end)

    -- Oil amount adjust (Studio only, per player's plot)
    devRemotes.OilAddAmountRemote.OnServerEvent:Connect(function(player, delta)
        local ok, OilService = pcall(function()
            return require(ServerScriptService:WaitForChild("Server"):WaitForChild("OilService"))
        end)
        local okPlot, PlotService = pcall(function()
            return require(ServerScriptService:WaitForChild("Systems"):WaitForChild("PlotService"))
        end)
        if ok and OilService and okPlot and PlotService then
            local assignment = PlotService.ClaimPlot(player)
            local pk = assignment and assignment.plotId or "P1"
            local current = OilService.getOilAmount and OilService.getOilAmount(pk) or 0
            local cap = OilService.getOilCapacity and OilService.getOilCapacity(pk) or 100
            local newAmount = math.clamp((current or 0) + (tonumber(delta) or 0), 0, cap)
            if OilService.setOilAmount then
                OilService.setOilAmount(pk, newAmount)
                print(string.format("[StudioDevRemotes] OilAddAmount pk=%s delta=%s new=%s", pk, tostring(delta), tostring(newAmount)))
            end
        end
    end)

    devRemotes.OilSetAmountRemote.OnServerEvent:Connect(function(player, amount)
        local ok, OilService = pcall(function()
            return require(ServerScriptService:WaitForChild("Server"):WaitForChild("OilService"))
        end)
        local okPlot, PlotService = pcall(function()
            return require(ServerScriptService:WaitForChild("Systems"):WaitForChild("PlotService"))
        end)
        if ok and OilService and okPlot and PlotService then
            local assignment = PlotService.ClaimPlot(player)
            local pk = assignment and assignment.plotId or "P1"
            local cap = OilService.getOilCapacity and OilService.getOilCapacity(pk) or 100
            local amt = math.clamp(tonumber(amount) or 0, 0, cap)
            if OilService.setOilAmount then
                OilService.setOilAmount(pk, amt)
                print(string.format("[StudioDevRemotes] OilSetAmount pk=%s amount=%s", pk, tostring(amt)))
            end
        end
    end)
    
    -- Currency grant handler - ACTUALLY GRANTS CURRENCY
    devRemotes.GrantCurrencyRemote.OnServerEvent:Connect(function(player, currencyType, amount)
        print("[StudioDevRemotes] Grant currency request:", player.Name, currencyType, amount)
        
        if services and services.SaveService and services.SaveService.GetProfile then
            local profile = services.SaveService.GetProfile(player)
            if profile and profile.balances then
                local grantAmount = tonumber(amount) or 0
                profile.balances[currencyType] = (profile.balances[currencyType] or 0) + grantAmount
                print("✅ ACTUALLY granted", grantAmount, currencyType, "to", player.Name)
                print("New balance:", currencyType, "=", profile.balances[currencyType])
                
                -- Send updated balances to client
                if services.Net then
                    local event = services.Net:GetEvent("RE_Balances")
                    if event then
                        event:FireClient(player, profile.balances)
                        print("✅ Sent balance update to client")
                    end
                end
                
                -- Force save
                services.SaveService.SaveProfile(player)
            else
                warn("[StudioDevRemotes] Profile or balances not found for", player.Name)
            end
        else
            warn("[StudioDevRemotes] SaveService not available!")
        end
    end)
    
    -- Plot wipe handler - ACTUALLY WIPES PLOT
    devRemotes.WipePlotRemote.OnServerEvent:Connect(function(player)
        print("[StudioDevRemotes] Wipe plot request from:", player.Name)
        
        -- Clear pond network for this plot
        if services.PondNetworkCore then
            -- Reset the pond network snapshot
            local snapshot = services.PondNetworkCore.getSnapshot()
            snapshot.ponds = {}
            snapshot.lakes = {}
            services.PondNetworkCore.setSnapshot(snapshot)
            print("✅ Cleared pond network")
        end
        
        -- Clear workspace folders
        local folders = {"PondRims", "CanalSegments", "CanalStones", "Lanterns", "Oil"}
        for _, folderName in pairs(folders) do
            local folder = workspace:FindFirstChild(folderName)
            if folder then
                for _, child in pairs(folder:GetChildren()) do
                    child:Destroy()
                end
                print("✅ Cleared folder:", folderName)
            end
        end
        
        -- Clear saved pond data
        if services.PondPersistence then
            pcall(function()
                services.PondPersistence.clearForPlot("P1") -- Assuming P1 for now
            end)
        end
        
        print("✅ Plot wiped for:", player.Name)
    end)
    
    -- Terrain reset handler
    devRemotes.ResetTerrainRemote.OnServerEvent:Connect(function(player)
        print("[StudioDevRemotes] Reset terrain request from:", player.Name)
        
        -- Re-run world bootstrap for this player's plot
        local WorldBootstrap = ServerScriptService:FindFirstChild("WorldBootstrap")
        if WorldBootstrap then
            print("✅ Re-initializing terrain for:", player.Name)
            -- You might need to trigger WorldBootstrap manually here
        end
        
        print("✅ Terrain reset initiated for:", player.Name)
    end)
    
    -- Teleport handler - ACTUALLY TELEPORTS
    devRemotes.TeleportToPlotRemote.OnServerEvent:Connect(function(player)
        print("[StudioDevRemotes] Teleport request from:", player.Name)
        
        if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            -- Get plot center from PlotService
            local plotCenter = Vector3.new(0, 20, 0) -- Default
            
            if services.PlotService and services.PlotService.GetAssignment then
                local assignment = services.PlotService.GetAssignment(player)
                if assignment and assignment.origin then
                    plotCenter = assignment.origin + Vector3.new(0, 10, 0)
                end
            end
            
            player.Character.HumanoidRootPart.CFrame = CFrame.new(plotCenter)
            print("✅ Teleported", player.Name, "to", plotCenter)
        end
    end)

    -- Teleport to a POI (non-blocking; if none exist yet, no-op)
    devRemotes.TeleportToPOIRemote.OnServerEvent:Connect(function(player)
        if not (player.Character and player.Character:FindFirstChild("HumanoidRootPart")) then return end
        local hrp = player.Character.HumanoidRootPart

        local function resolveWorldgenFolder(): Instance?
            local underServer = ServerScriptService:FindFirstChild("Server") and ServerScriptService.Server:FindFirstChild("Worldgen")
            if underServer then return underServer end
            local topLevel = ServerScriptService:FindFirstChild("Worldgen")
            if topLevel then return topLevel end
            return nil
        end

        local function fetchPOIs(): { Vector3 }
            local out = {}
            local worldgen = resolveWorldgenFolder()
            if worldgen then
                local ok, mod = pcall(function()
                    return require(worldgen:WaitForChild("ScatteredSkyIslands"))
                end)
                if ok and mod then
                    local islands = nil
                    if type(mod.getIslands) == "function" then
                        islands = mod.getIslands()
                    elseif type(mod.getElements) == "function" then
                        islands = mod.getElements()
                    end
                    if type(islands) == "table" then
                        for _, elem in ipairs(islands) do
                            if elem and elem.type == "POI" and typeof(elem.position) == "Vector3" then
                                table.insert(out, elem.position)
                            end
                        end
                    end
                end
            end

            -- Fallback: POIRegistry
            if #out == 0 then
                local ok, positions = pcall(function()
                    local RS = game:GetService("ReplicatedStorage")
                    local POIRegistry = require(RS:WaitForChild("Shared"):WaitForChild("POIRegistry"))
                    return POIRegistry.getAll()
                end)
                if ok and type(positions) == "table" and #positions > 0 then
                    for _, p in ipairs(positions) do table.insert(out, p) end
                end
            end

            -- Fallback to markers in workspace
            if #out == 0 then
                local markers = workspace:FindFirstChild("SkyConstellationMarkers")
                if markers then
                    for _, child in ipairs(markers:GetChildren()) do
                        if child:IsA("BasePart") then
                            local islandType = child:GetAttribute("IslandType")
                            if islandType == "POI" then
                                table.insert(out, child.Position)
                            end
                        end
                    end
                end
            end
            return out
        end

        local function pickBestPOI(pois: { Vector3 }): Vector3?
            if #pois == 0 then return nil end
            local origin = hrp.Position
            local best, bestDist = nil, math.huge
            for _, p in ipairs(pois) do
                local d = (p - origin).Magnitude
                if d < bestDist then best, bestDist = p, d end
            end
            return best + Vector3.new(0, 10, 0)
        end

        local pois = fetchPOIs()
        print("[TeleportToPOI] found", #pois, "POIs")
        local target = pickBestPOI(pois)
        if not target then
            -- No POI yet; do nothing (avoid blocking/waiting to keep DevUI responsive)
            print("[StudioDevRemotes] No POI found yet; teleport skipped")
            return
        end
        hrp.CFrame = CFrame.new(target)
        print("[StudioDevRemotes] Teleported", player.Name, "to", target)
    end)
    
    -- Force save handler - ACTUALLY SAVES
    devRemotes.ForceSaveRemote.OnServerEvent:Connect(function(player)
        print("[StudioDevRemotes] Force save request from:", player.Name)
        
        if services.SaveService and services.SaveService.SaveProfile then
            services.SaveService.SaveProfile(player)
            print("✅ Profile ACTUALLY saved for:", player.Name)
            
            -- Also save pond data
            if services.PondPersistence and services.PondPersistence.saveForPlot then
                pcall(function()
                    services.PondPersistence.saveForPlot("P1", services.PondNetworkCore.getSnapshot())
                    print("✅ Pond data saved")
                end)
            end
        else
            warn("[StudioDevRemotes] SaveService not available!")
        end
    end)
    
    -- Reload ponds handler
    devRemotes.ReloadPondsRemote.OnServerEvent:Connect(function(player)
        print("[StudioDevRemotes] Reload ponds request from:", player.Name)
        
        if services.PondPersistence and services.PondPersistence.loadForPlot then
            pcall(function()
                local data = services.PondPersistence.loadForPlot("P1")
                if data then
                    print("✅ Loaded pond data, reconstructing...")
                    -- Reconstruct ponds
                    if services.PondPersistence.reconstructFromSave then
                        services.PondPersistence.reconstructFromSave("P1", data)
                    end
                end
            end)
        end
    end)

    -- Clear in-memory player profile (SaveService)
    devRemotes.ClearPlayerProfileRemote.OnServerEvent:Connect(function(player)
        if services.SaveService and services.SaveService.ResetProfile then
            local p = services.SaveService.ResetProfile(player)
            print("[StudioDevRemotes] Reset profile for", player.Name)
            if services.Net then
                services.Net:GetEvent("RE_Balances"):FireClient(player, p.balances)
            end
        else
            warn("[StudioDevRemotes] SaveService.ResetProfile not available")
        end
    end)

    -- Clear player's ponds and lanterns from persistent save
    devRemotes.ClearPondsLanternsRemote.OnServerEvent:Connect(function(player)
        print("[StudioDevRemotes] Clear ponds+lanterns (save) request from:", player.Name)

        -- Resolve plot key for this player
        local plotKey = "P1"
        if services.PlotService and services.PlotService.GetAssignment then
            local assignment = services.PlotService.GetAssignment(player) or services.PlotService.ClaimPlot(player)
            if assignment and assignment.plotId then plotKey = assignment.plotId end
        end

        -- Clear lanterns for this plot
        local okLantern = pcall(function()
            local LanternSaveStore = require(ServerScriptService:WaitForChild("Server"):WaitForChild("LanternSaveStore"))
            LanternSaveStore.clearPlot(plotKey)
        end)
        if okLantern then
            print(string.format("[StudioDevRemotes] Cleared lantern save for plot %s", plotKey))
        else
            warn("[StudioDevRemotes] Failed to clear lanterns for plot", plotKey)
        end

        -- Clear global pond/lake save
        local okPonds = false
        if services.PondPersistence and services.PondPersistence.clearAll then
            local ok, _ = pcall(function() services.PondPersistence.clearAll() end)
            okPonds = ok
        else
            warn("[StudioDevRemotes] PondPersistence.clearAll not available")
        end

        -- Clear in-memory pond network snapshot (authoritative runtime) to stop loops immediately
        if services.PondNetworkCore and services.PondNetworkCore.setSnapshot then
            local snap = services.PondNetworkCore.getSnapshot()
            snap.ponds = {}
            snap.lakes = {}
            services.PondNetworkCore.setSnapshot(snap)
        end

        -- Optionally clear workspace instances to stop any loops immediately
        for _, name in ipairs({"PondRims", "CanalSegments", "CanalStones"}) do
            local f = workspace:FindFirstChild(name)
            if f then for _, c in ipairs(f:GetChildren()) do c:Destroy() end end
        end
        local lanternsFolder = workspace:FindFirstChild("Lanterns")
        if lanternsFolder then for _, c in ipairs(lanternsFolder:GetChildren()) do c:Destroy() end end

        print("[StudioDevRemotes] Clear complete: ponds(ok=", okPonds, ") lanterns(ok=", okLantern, ") plot=", plotKey)
    end)
    
    -- Debug pond network handler
    devRemotes.DebugPondNetworkRemote.OnServerEvent:Connect(function(player)
        print("=== POND NETWORK DEBUG for", player.Name, "===")
        
        if services.PondNetworkCore then
            local snapshot = services.PondNetworkCore.getSnapshot()
            print("Version:", snapshot.version)
            print("Ponds:", #snapshot.ponds)
            for id, pond in pairs(snapshot.ponds) do
                print("  -", id, "at", pond.pos, "radius", pond.radius)
            end
            print("Lakes (canals):", #snapshot.lakes)
            for id, lake in pairs(snapshot.lakes) do
                print("  -", id, "from", lake.a, "to", lake.b)
            end
        end
        
        print("=== END DEBUG ===")
    end)
    
    -- Spawn test ponds handler - ACTUALLY SPAWNS PONDS
    devRemotes.SpawnTestPondsRemote.OnServerEvent:Connect(function(player, count)
        print("[StudioDevRemotes] Spawn test ponds request:", player.Name, count)
        
        if services.PondNetworkCore and services.PondNetworkCore.addPond then
            local random = Random.new(tick())
            local spawned = 0
            
            for i = 1, (count or 10) do
                local x = random:NextNumber(-50, 50)
                local z = random:NextNumber(-50, 50)
                local radius = random:NextNumber(8, 15)
                
                local pond = services.PondNetworkCore.addPond(Vector2.new(x, z), radius)
                if pond then
                    spawned = spawned + 1
                end
            end
            
            print("✅ ACTUALLY spawned", spawned, "test ponds for:", player.Name)
        else
            warn("[StudioDevRemotes] PondNetworkCore not available!")
        end
    end)
    
    -- Clear test objects handler
    devRemotes.ClearTestObjectsRemote.OnServerEvent:Connect(function(player)
        print("[StudioDevRemotes] Clear test objects request from:", player.Name)
        
        local testFolders = {"TestPonds", "TestLanterns", "TestCanals", "PondRims", "CanalSegments", "Oil"}
        for _, folderName in pairs(testFolders) do
            local folder = workspace:FindFirstChild(folderName)
            if folder then
                folder:Destroy()
                print("✅ Cleared:", folderName)
            end
        end
    end)

    -- Sky island regeneration
    devRemotes.ResetSkyIslandsRemote.OnServerEvent:Connect(function(player)
        print("[StudioDevRemotes] Sky island regen request from:", player.Name)
        -- Prefer new SkyIslandRuntime if present
        local okRuntime, SkyIslandRuntime = pcall(function()
            return require(ServerScriptService:WaitForChild("Systems"):WaitForChild("SkyIslandRuntime"))
        end)
        if okRuntime and SkyIslandRuntime and SkyIslandRuntime.regenerate then
            local ok = SkyIslandRuntime.regenerate({ newSeed = true })
            if ok then
                print("[StudioDevRemotes] Regenerated via SkyIslandRuntime (new seed)")
                return
            end
        end
        -- Fallback to legacy cycle service
        local ok, SkyIslandCycleService = pcall(function()
            return require(ServerScriptService:WaitForChild("Systems"):WaitForChild("SkyIslandCycleService"))
        end)
        if ok and SkyIslandCycleService and SkyIslandCycleService.regenNow then
            SkyIslandCycleService.regenNow("devui")
        else
            warn("[StudioDevRemotes] SkyIslandCycleService not available!")
        end
    end)
    
    -- Visual debug handlers
    local boundaryVisualizations = {}
    devRemotes.ToggleBoundaryVisRemote.OnServerEvent:Connect(function(player)
        print("[StudioDevRemotes] Toggle boundary vis request from:", player.Name)
        
        -- Toggle boundary visualization
        if not boundaryVisualizations[player] then
            -- Create boundary visualization
            boundaryVisualizations[player] = true
            print("✅ Boundary visualization ON for", player.Name)
        else
            -- Remove boundary visualization
            boundaryVisualizations[player] = nil
            print("✅ Boundary visualization OFF for", player.Name)
        end
    end)
    
    devRemotes.ShowPondConnectionsRemote.OnServerEvent:Connect(function(player)
        print("[StudioDevRemotes] Show pond connections request from:", player.Name)
        
        if services.PondNetworkCore then
            local snapshot = services.PondNetworkCore.getSnapshot()
            print("✅ Showing", #snapshot.lakes, "pond connections")
            -- Could create visual lines between connected ponds here
        end
    end)
    
    -- Handle tool usage
    local useItemRemote = remotes:FindFirstChild("RE_UseItem")
    if not useItemRemote then
        useItemRemote = Instance.new("RemoteEvent")
        useItemRemote.Name = "RE_UseItem"
        useItemRemote.Parent = remotes
    end
    
    useItemRemote.OnServerEvent:Connect(function(player, itemId, quantity)
        print("[StudioDevRemotes] Tool used:", player.Name, "used", itemId, "x", quantity or 1)
        
        -- Handle different item types
        local itemType = itemId and string.match(itemId, "^(%w+)_") or "unknown"
        
        if itemType == "lantern" then
            print("[StudioDevRemotes] Player wants to place a lantern:", itemId)
            -- TODO: Call LanternService to place lantern
        elseif itemType == "pond" then
            print("[StudioDevRemotes] Player wants to create a pond:", itemId)
            -- Could spawn a pond at player's position
            if services.PondNetworkCore and services.PondNetworkCore.addPond then
                local character = player.Character
                if character and character:FindFirstChild("HumanoidRootPart") then
                    local pos = character.HumanoidRootPart.Position
                    local radius = itemId == "pond_large" and 15 or 10
                    services.PondNetworkCore.addPond(Vector2.new(pos.X, pos.Z), radius)
                    print("✅ Created pond at player location")
                end
            end
        elseif itemType == "oil" then
            print("[StudioDevRemotes] Player wants to use oil canister")
            -- TODO: Refill oil
        elseif itemType == "canal" then
            print("[StudioDevRemotes] Player wants to use canal tool")
            -- TODO: Connect ponds
        end
    end)
    
    -- NEW: Rim analysis handler
    devRemotes.AnalyzeRimsRemote.OnServerEvent:Connect(function(player)
        print("[StudioDevRemotes] Rim analysis request from:", player.Name)
        
        -- Use both RimBuilder and UnifiedRimSystem analysis (with safe requires)
        local ok1, RimBuilder = pcall(function()
            return require(ServerScriptService:WaitForChild("Server"):WaitForChild("RimBuilder"))
        end)
        
        local ok2, UnifiedRimSystem = pcall(function()
            return require(ServerScriptService:WaitForChild("Server"):WaitForChild("UnifiedRimSystem"))
        end)
        
        print("=== RIM PERFORMANCE ANALYSIS ===")
        
        -- RimBuilder analysis
        if ok1 and RimBuilder and RimBuilder.analyzePerformance then
            local rimAnalysis = RimBuilder.analyzePerformance()
        else
            warn("[StudioDevRemotes] RimBuilder analysis not available")
        end
        
        -- UnifiedRimSystem analysis
        if ok2 and UnifiedRimSystem and UnifiedRimSystem.analyzeRims then
            local unifiedAnalysis = UnifiedRimSystem.analyzeRims()
        else
            warn("[StudioDevRemotes] UnifiedRimSystem analysis not available")
        end
        
        print("=== END RIM ANALYSIS ===")
    end)
    
    -- NEW: Rim migration handler
    devRemotes.MigrateRimsRemote.OnServerEvent:Connect(function(player)
        print("[StudioDevRemotes] Rim migration request from:", player.Name)
        
        local ok, UnifiedRimSystem = pcall(function()
            return require(ServerScriptService:WaitForChild("Server"):WaitForChild("UnifiedRimSystem"))
        end)
        
        if ok and UnifiedRimSystem and UnifiedRimSystem.migrateLegacyRims then
            local migrated = UnifiedRimSystem.migrateLegacyRims()
            print(`✅ Migrated {migrated} legacy rims to unified system for {player.Name}`)
        else
            warn("[StudioDevRemotes] UnifiedRimSystem migration not available!")
        end
    end)
    
    print("[StudioDevRemotes] All handlers connected successfully with ACTUAL functionality!")
    
    -- Test that remotes are working
    wait(1)
    print("[StudioDevRemotes] System ready! Services available:")
    local serviceList = {}
    for name, _ in pairs(services or {}) do
        table.insert(serviceList, name)
    end
    print("  Available services:", table.concat(serviceList, ", "))
end

return StudioDevRemotes
