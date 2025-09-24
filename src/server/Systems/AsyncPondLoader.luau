--!strict
-- AsyncPondLoader: Non-blocking pond loading system with progress indicators
-- INTEGRATION NOTE: This system communicates with LoadingScreenBridge.client.luau
-- to ensure loading screen stays visible until pond loading is complete

local AsyncPondLoader = {}

local PondPersistence = require(script.Parent:WaitForChild("PondPersistence"))
local DataStoreService = game:GetService("DataStoreService")
local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

-- NEW: Unified rim creation (optional - fallback if not available)
local UnifiedRimSystem = nil
local hasUnifiedRimSystem = pcall(function()
    UnifiedRimSystem = require(SSS:WaitForChild("Server"):WaitForChild("UnifiedRimSystem"))
end)

if hasUnifiedRimSystem then
    print("[AsyncPondLoader] UnifiedRimSystem loaded successfully")
else
    warn("[AsyncPondLoader] UnifiedRimSystem not available - using fallback rim creation")
end

-- Create loading status remote events
local Net = RS:FindFirstChild("Net") or Instance.new("Folder")
Net.Name = "Net"; Net.Parent = RS
local Remotes = Net:FindFirstChild("Remotes") or Instance.new("Folder")
Remotes.Name = "Remotes"; Remotes.Parent = Net

local RE_LoadingProgress = Remotes:FindFirstChild("RE_LoadingProgress") or Instance.new("RemoteEvent")
RE_LoadingProgress.Name = "RE_LoadingProgress"; RE_LoadingProgress.Parent = Remotes

-- Loading state
local isLoading = false
local loadingProgress = 0
local loadingStatus = "Idle"
local lastBroadcast = 0
local lastProgress = -1
local anyClientReady = false
local activeJobs = 0 -- track background item jobs (e.g., stones)

-- Tuning knobs for staggered restores
local STONES_PER_FRAME = 1 -- restore one stone per frame for smoothness

local function broadcastProgress(progress: number, status: string, detail: string?)
    loadingProgress = progress
    loadingStatus = status
    local now = os.clock()
    local changed = (math.floor((progress or 0)*100) ~= math.floor((lastProgress or 0)*100))
    if status == "Complete" or (changed or (now - lastBroadcast) > 0.25) then
        lastBroadcast = now
        lastProgress = progress
        RE_LoadingProgress:FireAllClients({
            source = "AsyncPondLoader",
            progress = progress,
            status = status,
            detail = detail or "",
            isLoading = isLoading
        })
        print(string.format("[AsyncPondLoader] %s: %.1f%% - %s", status, progress * 100, detail or ""))
    end
end

local function getPondNetworkService()
    local ok, PNS = pcall(function()
        return require(SSS:WaitForChild("Systems"):WaitForChild("PondNetworkService"))
    end)
    return ok and PNS or nil
end

local function getRenderQueue()
    local ok, rq = pcall(function()
        return require(SSS:WaitForChild("Systems"):WaitForChild("RenderQueueSystem"))
    end)
    return ok and rq or nil
end

-- Async pond loading with yield points
function AsyncPondLoader.loadAsync()
    if isLoading then
        warn("[AsyncPondLoader] Already loading, ignoring duplicate request")
        return false
    end
    
    isLoading = true
    broadcastProgress(0, "Starting", "Initializing pond loader")
    
    local PNS = getPondNetworkService()
    if not PNS then 
        broadcastProgress(0, "Error", "PondNetworkService not available")
        isLoading = false
        return false 
    end
    
    broadcastProgress(0.1, "Loading", "Connecting to DataStore")
    
    local pondStore = DataStoreService:GetDataStore("DynamicPonds_v2")
    local success, data = pcall(function()
        return pondStore:GetAsync("WorldPonds")
    end)
    
    if not success then
        if RunService:IsStudio() then
            broadcastProgress(0, "Error", "Enable 'Allow Studio Access to API Services'")
        else
            broadcastProgress(0, "Error", "DataStore connection failed")
        end
        isLoading = false
        return false
    end
    
    if not data then
        broadcastProgress(1, "Complete", "No saved data found")
        isLoading = false
        return true
    end
    
    broadcastProgress(0.2, "Loading", "Data retrieved from server")
    
    -- Count total items to load
    local totalPonds = 0
    local totalLakes = 0
    for _ in pairs(data.ponds or {}) do totalPonds += 1 end
    for _ in pairs(data.lakes or {}) do totalLakes += 1 end
    
    local totalItems = totalPonds + totalLakes
    if totalItems == 0 then
        broadcastProgress(1, "Complete", "No ponds to load")
        isLoading = false
        return true
    end
    
    broadcastProgress(0.3, "Loading", string.format("Found %d ponds, %d canals", totalPonds, totalLakes))
    
    local itemsLoaded = 0
    local pondsLoaded = 0
    local lakesLoaded = 0
    
    -- Load ponds with yield points
    for id, pondData in pairs(data.ponds or {}) do
        local pos = Vector2.new(pondData.pos.X, pondData.pos.Y)
        -- Pass skipValidation=true for restored ponds
        local pond = PNS.addPond(pos, pondData.radius, nil, true)
        
        if pond then
            pondsLoaded += 1
            
            -- UNIFIED rim restoration (replaces old dense rim system)
            task.spawn(function()
                task.wait(0.05)  -- Brief delay for pond to initialize
                
                if hasUnifiedRimSystem and UnifiedRimSystem then
                    -- Use unified rim creation for consistent density
                    local centerPos = Vector3.new(pos.X, 0, pos.Y)  -- Convert Vector2 to Vector3
                    UnifiedRimSystem.createRimFromPersistence(pond.id, centerPos, pondData.radius, pondData.rimStones)
                    print(`[AsyncPondLoader] Created unified rim for pond {pond.id}`)
                else
                    -- Fallback: skip rim creation or use legacy method
                    print(`[AsyncPondLoader] Skipping rim creation for pond {pond.id} - UnifiedRimSystem not available`)
                end
            end)
        end
        
        itemsLoaded += 1
        local progress = 0.3 + (itemsLoaded / totalItems) * 0.4 -- 30% to 70% for ponds
        broadcastProgress(progress, "Loading", string.format("Loaded pond %d/%d", pondsLoaded, totalPonds))
        
        -- Yield every few ponds to prevent freezing
        if itemsLoaded % 3 == 0 then
            task.wait()
        end
    end
    
    broadcastProgress(0.7, "Loading", "All ponds loaded, starting canals")
    
    -- Small delay for pond initialization
    task.wait(0.5)
    
    -- Load lakes/canals with yield points
    for id, lakeData in pairs(data.lakes or {}) do
        if lakeData.a and lakeData.b then
            local lake = PNS.connectPonds(lakeData.a, lakeData.b, lakeData.width)
            
            if lake then
                lakesLoaded += 1
                
                -- Enhanced canal stone restoration (async)
                if lakeData.schema == "v2" and lakeData.stoneData then
                    task.spawn(function()
                        task.wait(0.1)
                        local rq = getRenderQueue()
                        local canalSegments = workspace:FindFirstChild("CanalSegments")
                        if rq and canalSegments then
                            local canalFolder = canalSegments:FindFirstChild(lake.id)
                            if canalFolder then
                                for _, child in ipairs(canalFolder:GetChildren()) do
                                    if child.Name == "CanalStone" then child:Destroy() end
                                end
                                for _, stoneData in ipairs(lakeData.stoneData) do
                                    local cf = CFrame.new(Vector3.new(stoneData.position.X, stoneData.position.Y, stoneData.position.Z))
                                    cf *= CFrame.fromOrientation(math.rad(stoneData.rotation.X), math.rad(stoneData.rotation.Y), math.rad(stoneData.rotation.Z))
                                rq.EnqueueCanalStone(canalFolder, {
                                        Size = Vector3.new(stoneData.size.X, stoneData.size.Y, stoneData.size.Z),
                                        CFrame = cf,
                                        Color = Color3.fromRGB(118, 116, 112),
                                        Material = Enum.Material.Rock,
                                        Name = "CanalStone",
                                        Attributes = { lakeId = lake.id },
                                    })
                                end
                            end
                        end
                    end)
                end
            end
        end
        
        itemsLoaded += 1
        local progress = 0.7 + ((itemsLoaded - totalPonds) / totalLakes) * 0.3 -- 70% to 100% for canals
        broadcastProgress(progress, "Loading", string.format("Loaded canal %d/%d", lakesLoaded, totalLakes))
        
        -- Yield every few canals
        if (itemsLoaded - totalPonds) % 2 == 0 then
            task.wait()
        end
    end
    
    -- Wait for render queue to drain (ensures stones are actually placed)
    do
        local rq = getRenderQueue()
        local guard = 0
        while rq and rq.IsBusy() and guard < 6000 do -- ~100s max guard
            RunService.Heartbeat:Wait()
            guard += 1
        end
    end

    broadcastProgress(1, "Complete", string.format("Loaded %d ponds, %d canals", pondsLoaded, lakesLoaded))

    -- FIXED: Ensure completion signal is sent properly
    RE_LoadingProgress:FireAllClients({
        source = "AsyncPondLoader",
        progress = 1,
        status = "Complete",
        detail = string.format("Loaded %d ponds, %d canals", pondsLoaded, lakesLoaded),
        isLoading = false,
        completed = true  -- Explicit completion flag
    })
    
    -- Small delay before clearing loading state
    task.wait(0.2)
    isLoading = false
    
    return true
end

-- Get current loading status
function AsyncPondLoader.getStatus()
    return {
        isLoading = isLoading,
        progress = loadingProgress,
        status = loadingStatus
    }
end

-- Initialize the async loader (replaces PondPersistence.Init)
function AsyncPondLoader.Init(services: any)
    print("[AsyncPondLoader] Initializing async pond loading system")
    -- Greet client readiness events via RenderQueue's ready remote if present
    local ok, rq = pcall(function()
        return require(SSS:WaitForChild("Systems"):WaitForChild("RenderQueueSystem"))
    end)
    -- No explicit handler needed here; queue system tracks readiness
    
    -- Start loading after a delay
    task.spawn(function()
        task.wait(3)  -- Give time for world generation
        AsyncPondLoader.loadAsync()
    end)
    
    -- Auto-save every 5 minutes (using original PondPersistence)
    task.spawn(function()
        while true do
            task.wait(300)
            if not isLoading then -- Don't save while loading
                PondPersistence.save()
            end
        end
    end)
end

-- Save on server shutdown
game:BindToClose(function()
    if not isLoading then
        print("[AsyncPondLoader] Server shutting down, saving ponds...")
        PondPersistence.save()
        task.wait(2)
    end
end)

return AsyncPondLoader
