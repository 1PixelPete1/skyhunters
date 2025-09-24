-- LoadingScreenBridge.client.luau
-- Patches existing LoadingScreen to wait for AsyncPondLoader completion
-- This fixes the 5+ second gap where screen hides before ponds finish loading

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local LogService = game:GetService("LogService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local LoadingScreenBridge = {}

-- Monitor for pond loading completion
local isWaitingForPonds = true
local pondLoadingComplete = false

-- Get existing LoadingScreen module
local function getLoadingScreenModule()
    local clientFolder = script.Parent
    local loadingScreenModule = clientFolder:FindFirstChild("LoadingScreen")
    if loadingScreenModule and loadingScreenModule:IsA("ModuleScript") then
        return require(loadingScreenModule)
    end
    return nil
end

-- Monitor AsyncPondLoader progress via remote events
local function setupProgressMonitoring()
    spawn(function()
        -- Wait for the Net folder and remotes
        local Net = ReplicatedStorage:WaitForChild("Net", 10)
        if not Net then
            warn("[LoadingScreenBridge] Net folder not found")
            isWaitingForPonds = false
            return
        end
        
        local Remotes = Net:WaitForChild("Remotes", 5)
        if not Remotes then
            warn("[LoadingScreenBridge] Remotes folder not found")
            isWaitingForPonds = false
            return
        end
        
        -- Look for progress remote
        local progressRemote = Remotes:WaitForChild("RE_LoadingProgress", 5)
        if progressRemote then
            print("[LoadingScreenBridge] Connected to AsyncPondLoader progress")
            
            progressRemote.OnClientEvent:Connect(function(progressData)
                if progressData and progressData.status then
                    local source = progressData.source
                    local progressPercent = math.floor((progressData.progress or 0) * 100 * 10) / 10  -- Round to 1 decimal
                    -- Only log prominently for async loader; render queue may be noisy
                    if source == "AsyncPondLoader" and not pondLoadingComplete then
                        print(`[LoadingScreenBridge] Pond loading: {progressData.status} - {progressPercent}%`)
                    end
                    
                    -- Check for completion only for async loader
                    if not pondLoadingComplete and ((source == "AsyncPondLoader" and (progressData.status == "Complete" or 
                       (progressData.progress and progressData.progress >= 1))) or progressData.completed == true) then
                        print("[LoadingScreenBridge] Pond loading complete!")
                        pondLoadingComplete = true
                        isWaitingForPonds = false
                    end
                end
            end)
        else
            warn("[LoadingScreenBridge] RE_LoadingProgress not found - using timeout")
            
            -- Fallback timeout
            wait(15)
            print("[LoadingScreenBridge] Timeout - assuming pond loading complete")
            pondLoadingComplete = true
            isWaitingForPonds = false
        end
    end)
end

-- Monitor console logs for AsyncPondLoader completion as backup
local function setupLogMonitoring()
    local connection
    connection = LogService.MessageOut:Connect(function(message, messageType)
        if (not pondLoadingComplete) and message:find("AsyncPondLoader.*Complete") then
            print("[LoadingScreenBridge] Detected pond loading completion via logs")
            pondLoadingComplete = true
            isWaitingForPonds = false
            connection:Disconnect()
        end
    end)
    
    -- Cleanup after timeout
    spawn(function()
        wait(20)
        if connection then
            connection:Disconnect()
        end
    end)
end

-- Patch LoadingScreen Hide function
local function patchLoadingScreen()
    local LoadingScreen = getLoadingScreenModule()
    if not LoadingScreen then
        warn("[LoadingScreenBridge] LoadingScreen module not found")
        return
    end
    
    -- Store original Hide function
    local originalHide = LoadingScreen.Hide
    if not originalHide then
        warn("[LoadingScreenBridge] LoadingScreen.Hide function not found")
        return
    end
    
    -- Replace Hide function with patched version
    LoadingScreen.Hide = function(...)
        if isWaitingForPonds then
            print("[LoadingScreenBridge] LoadingScreen.Hide() called but waiting for pond loading...")
            
            -- Update the loading screen to show pond loading status
            if LoadingScreen.UpdateProgress then
                LoadingScreen:UpdateProgress({
                    percentage = 75,
                    message = "Loading water systems and terrain..."
                })
            end
            
            -- Wait for pond loading to complete
            local timeout = 0
            while isWaitingForPonds and timeout < 25 do -- 25 second timeout
                wait(0.1)
                timeout = timeout + 0.1
                
                -- Update dots animation
                if timeout % 1 < 0.1 and LoadingScreen.UpdateProgress then
                    local dots = math.floor(timeout) % 4
                    LoadingScreen:UpdateProgress({
                        percentage = 75 + (timeout / 25) * 20, -- 75% to 95%
                        message = "Loading water systems and terrain" .. string.rep(".", dots)
                    })
                end
            end
            
            if timeout >= 25 then
                warn("[LoadingScreenBridge] Timeout waiting for pond loading")
            else
                print("[LoadingScreenBridge] Pond loading complete, proceeding with hide")
            end
        end
        
        -- Now actually hide the loading screen
        print("[LoadingScreenBridge] Actually hiding loading screen")
        return originalHide(...)
    end
    
    print("[LoadingScreenBridge] Successfully patched LoadingScreen.Hide()")
end

-- Monitor GUI directly as fallback
local function setupGuiMonitoring()
    spawn(function()
        wait(1) -- Let initial systems start
        
        local loadingGui = playerGui:FindFirstChild("LoadingScreen")
        if not loadingGui then return end
        
        local connection
        connection = loadingGui:GetPropertyChangedSignal("Enabled"):Connect(function()
            if not loadingGui.Enabled and isWaitingForPonds then
                print("[LoadingScreenBridge] Loading GUI disabled early - re-enabling for pond loading")
                wait() -- Brief yield
                
                -- Re-enable if still waiting
                if isWaitingForPonds then
                    loadingGui.Enabled = true
                    
                    -- Update status message
                    local container = loadingGui:FindFirstChild("Background")
                        and loadingGui.Background:FindFirstChild("Container")
                    
                    if container then
                        local statusMessage = container:FindFirstChild("StatusMessage")
                        if statusMessage then
                            statusMessage.Text = "Building water systems..."
                        end
                    end
                end
            elseif not isWaitingForPonds and loadingGui.Enabled then
                print("[LoadingScreenBridge] Pond loading complete - allowing GUI hide")
                connection:Disconnect()
            end
        end)
    end)
end

-- Initialize the bridge
local function initializeBridge()
    print("[LoadingScreenBridge] Initializing loading screen bridge...")
    
    -- Setup monitoring systems
    setupProgressMonitoring()
    setupLogMonitoring()
    
    -- Patch immediately; LoadingBootstrap shows the UI very early
    patchLoadingScreen()
    setupGuiMonitoring()
    
    -- Safety timeout - always allow hiding after reasonable time
    spawn(function()
        wait(30) -- 30 second absolute maximum
        if isWaitingForPonds then
            warn("[LoadingScreenBridge] Absolute timeout reached - forcing completion")
            isWaitingForPonds = false
            pondLoadingComplete = true
        end
    end)
end

-- Start the bridge
initializeBridge()

return LoadingScreenBridge
