-- AsyncLoadingSystem.server.luau
-- Prevents freezing during large pond/lantern reconstruction

local RunService = RunService or game:GetService("RunService")
local ReplicatedStorage = ReplicatedStorage or game:GetService("ReplicatedStorage")
local Players = Players or game:GetService("Players")

local AsyncLoadingSystem = {}

-- Configuration
local LOADING_CONFIG = {
    maxItemsPerFrame = 3, -- Maximum items to process per frame
    frameBuffer = 0.016, -- Target 60 FPS (16ms per frame)
    progressUpdateInterval = 5, -- Update progress every N items
}

-- Create loading remotes
local function setupRemotes()
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if not remotes then
        remotes = Instance.new("Folder")
        remotes.Name = "Remotes"
        remotes.Parent = ReplicatedStorage
    end
    
    local progressRemote = remotes:FindFirstChild("LoadingProgressRemote")
    if not progressRemote then
        progressRemote = Instance.new("RemoteEvent")
        progressRemote.Name = "LoadingProgressRemote"
        progressRemote.Parent = remotes
    end
    
    return progressRemote
end

local progressRemote = setupRemotes()

-- Send loading progress to client
local function updateProgress(player, current, total, message)
    local percentage = math.floor((current / total) * 100)
    progressRemote:FireClient(player, {
        current = current,
        total = total,
        percentage = percentage,
        message = message
    })
end

-- Process items with async yielding to prevent frame drops
function AsyncLoadingSystem:ProcessItemsAsync(player, items, processor, itemTypeName)
    local totalItems = #items
    if totalItems == 0 then
        return
    end
    
    updateProgress(player, 0, totalItems, "Loading " .. itemTypeName .. "...")
    
    local processed = 0
    local frameStartTime = tick()
    
    for i, item in ipairs(items) do
        -- Check if we need to yield to prevent frame drops
        if tick() - frameStartTime > LOADING_CONFIG.frameBuffer then
            RunService.Heartbeat:Wait() -- Yield for one frame
            frameStartTime = tick()
        end
        
        -- Process the item
        local success, error = pcall(function()
            processor(item, i)
        end)
        
        if not success then
            warn(string.format("[AsyncLoadingSystem] Error processing %s item %d: %s", itemTypeName, i, error))
        end
        
        processed = processed + 1
        
        -- Update progress
        if processed % LOADING_CONFIG.progressUpdateInterval == 0 or processed == totalItems then
            updateProgress(player, processed, totalItems, "Loading " .. itemTypeName .. "... (" .. processed .. "/" .. totalItems .. ")")
        end
    end
    
    print(string.format("[AsyncLoadingSystem] Completed loading %d %s for %s", totalItems, itemTypeName, player.Name))
end

-- Batch processing for large operations
function AsyncLoadingSystem:ProcessLargeBatch(player, items, processor, itemName)
    return self:ProcessItemsAsync(player, items, processor, itemName)
end

-- Simple loading wrapper with progress reporting
function AsyncLoadingSystem:LoadWithProgress(player, loadFunction, itemName)
    updateProgress(player, 0, 1, "Loading " .. itemName .. "...")
    
    local success, result = pcall(loadFunction)
    
    if success then
        updateProgress(player, 1, 1, itemName .. " loaded successfully!")
    else
        updateProgress(player, 1, 1, "Failed to load " .. itemName)
        warn("Loading failed:", result)
    end
    
    -- Hide loading screen after a short delay
    wait(1)
    progressRemote:FireClient(player, {
        completed = true
    })
    
    return success, result
end

-- Utility function to measure and report loading performance
function AsyncLoadingSystem:MeasureLoadingPerformance(player, loadFunction, itemName)
    local startTime = tick()
    
    local success, result = self:LoadWithProgress(player, loadFunction, itemName)
    
    local endTime = tick()
    local duration = endTime - startTime
    
    print(string.format("Loading performance for %s (%s): %.2f seconds", player.Name, itemName, duration))
    
    return success, result, duration
end

-- Enhanced loading for pond data (compatible with existing systems)
function AsyncLoadingSystem:LoadPondDataAsync(player, pondData, loadPondFunction)
    if not pondData or type(pondData) ~= "table" then
        return
    end
    
    -- Convert pond data to array format for processing
    local pondArray = {}
    for pondId, pond in pairs(pondData) do
        table.insert(pondArray, {id = pondId, data = pond})
    end
    
    -- Process asynchronously
    self:ProcessItemsAsync(player, pondArray, function(pondItem, index)
        if loadPondFunction then
            loadPondFunction(pondItem.id, pondItem.data)
        end
    end, "ponds")
end

-- Enhanced loading for lantern data (compatible with existing systems)
function AsyncLoadingSystem:LoadLanternDataAsync(player, lanternData, loadLanternFunction)
    if not lanternData or type(lanternData) ~= "table" then
        return
    end
    
    -- Convert lantern data to array format for processing
    local lanternArray = {}
    for lanternId, lantern in pairs(lanternData) do
        table.insert(lanternArray, {id = lanternId, data = lantern})
    end
    
    -- Process asynchronously
    self:ProcessItemsAsync(player, lanternArray, function(lanternItem, index)
        if loadLanternFunction then
            loadLanternFunction(lanternItem.id, lanternItem.data)
        end
    end, "lanterns")
end

-- Integration function for existing systems
function AsyncLoadingSystem:LoadPlotDataAsync(player, plotKey, saveData)
    if not saveData then
        print("[AsyncLoadingSystem] No save data provided for", player.Name)
        return
    end
    
    print("Starting async plot load for:", player.Name)
    
    -- Count total items for progress tracking
    local totalItems = 0
    local ponds = saveData.ponds or {}
    local lanterns = saveData.lanterns or {}
    
    for _ in pairs(ponds) do totalItems = totalItems + 1 end
    for _ in pairs(lanterns) do totalItems = totalItems + 1 end
    
    if totalItems == 0 then
        updateProgress(player, 1, 1, "Plot loaded!")
        return
    end
    
    -- Start loading sequence
    updateProgress(player, 0, totalItems, "Preparing to load plot...")
    
    -- Wait one frame to allow UI to update
    RunService.Heartbeat:Wait()
    
    -- Load ponds first
    if ponds and next(ponds) then
        self:LoadPondDataAsync(player, ponds, function(pondId, pondData)
            -- Integration point: call your existing pond loading logic here
            print(string.format("[AsyncLoadingSystem] Loading pond %s", pondId))
        end)
    end
    
    -- Then load lanterns
    if lanterns and next(lanterns) then
        self:LoadLanternDataAsync(player, lanterns, function(lanternId, lanternData)
            -- Integration point: call your existing lantern loading logic here
            print(string.format("[AsyncLoadingSystem] Loading lantern %s", lanternId))
        end)
    end
    
    -- Completion
    updateProgress(player, totalItems, totalItems, "Plot loaded successfully!")
    
    -- Hide loading screen after a short delay
    wait(1)
    progressRemote:FireClient(player, {
        completed = true
    })
    
    print("Async plot load completed for:", player.Name)
end

return AsyncLoadingSystem