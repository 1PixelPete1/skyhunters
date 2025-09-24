--!strict
print("[CLIENT_BOOT] init.client starting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- Note: Avoid hard requires before showing the loading screen.
-- SafeRequire was unused here and could fail early; removed to ensure UI always shows.

-- Loading Screen Integration
local LoadingScreen
do
    local loadingScreenMod = script.Parent:FindFirstChild("LoadingScreen")
    if loadingScreenMod and loadingScreenMod:IsA("ModuleScript") then
        local ok, mod = pcall(function() return require(loadingScreenMod) end)
        if ok and mod then
            LoadingScreen = mod
            LoadingScreen:Show()
            LoadingScreen:UpdateProgress({percentage = 5, message = "Initializing QuietWinds..."})
            print("[LoadingScreen] Show (client bootstrap)")
        else
            warn("[CLIENT_BOOT] Failed to require LoadingScreen module:", mod)
        end
    else
        warn("[CLIENT_BOOT] LoadingScreen ModuleScript not found under Client folder")
    end
end

-- Policy and Report (safe load with fallbacks)
local Policy: any = { timeoutSeconds = function() return 5.0 end, debugLoggingEnabled = function() return false end }
 do
    local m = script.Parent:FindFirstChild("ClientBootPolicy")
    if m and m:IsA("ModuleScript") then
        local ok, p = pcall(function() return require(m) end)
        if ok and type(p) == "table" then Policy = p end
    end
end

local Report: any = { noteMissing=function() end, noteTimeout=function() end, degraded=function() return false end, summary=function() end }
 do
    local m = script.Parent:FindFirstChild("ClientBootReport")
    if m and m:IsA("ModuleScript") then
        local ok, r = pcall(function() return require(m) end)
        if ok and type(r) == "table" then Report = r end
    end
end

local function fullPath(inst: Instance?): string
    if inst == nil then return "[nil]" end
    local ok, name = pcall(function() return inst:GetFullName() end)
    return ok and name or tostring(inst)
end

local function waitChild(parent: Instance, name: string, timeout: number): Instance?
    local inst = parent:FindFirstChild(name)
    if inst then return inst end
    inst = parent:WaitForChild(name, timeout)
    if not inst then
        warn(("[CLIENT_BOOT] Timeout waiting for %s after %.1fs"):format(fullPath(parent) .. "." .. name, timeout))
        Report.noteMissing(fullPath(parent) .. "." .. name)
        Report.noteTimeout()
    end
    return inst
end

local TIMEOUT = (Policy and Policy.timeoutSeconds and Policy.timeoutSeconds()) or 5.0

-- UIRouter (only require ModuleScript; LocalScript runs itself)
 do
    if LoadingScreen then LoadingScreen:UpdateProgress({percentage = 20, message = "Loading UI Router..."}) end
    local uiRouter = waitChild(script.Parent, "UIRouter", TIMEOUT)
    if uiRouter and uiRouter:IsA("ModuleScript") then
        local ok, err = pcall(function() require(uiRouter) end)
        if not ok then warn("[CLIENT_BOOT] UIRouter require failed", err); Report.noteMissing(fullPath(uiRouter)) end
    end
end

-- ExpeditionClient (only require ModuleScript; LocalScript runs itself)
 do
    if LoadingScreen then LoadingScreen:UpdateProgress({percentage = 35, message = "Loading Expedition System..."}) end
    local exp = waitChild(script.Parent, "ExpeditionClient", TIMEOUT)
    if exp and exp:IsA("ModuleScript") then
        local ok, err = pcall(function() require(exp) end)
        if not ok then warn("[CLIENT_BOOT] ExpeditionClient require failed", err); Report.noteMissing(fullPath(exp)) end
    end
end

-- Lanterns V2 client FX + HUD
if LoadingScreen then LoadingScreen:UpdateProgress({percentage = 50, message = "Loading Lantern Systems..."}) end
local systems = waitChild(ReplicatedStorage, "systems", TIMEOUT)
local lanternFolder = systems and waitChild(systems, "Lantern", TIMEOUT) or nil
local runLanternClient = lanternFolder and waitChild(lanternFolder, "RunLanternClient", TIMEOUT) or nil
if runLanternClient then
    local ok, mod = pcall(function() return require(runLanternClient) end)
    if ok and mod and mod.Init then
        mod.Init()
    else
        warn("[CLIENT_BOOT] RunLanternClient require/init failed")
        Report.noteMissing(fullPath(runLanternClient))
    end
end

local uiFolder = waitChild(script.Parent, "UI", TIMEOUT)
local lanternHudMod = uiFolder and waitChild(uiFolder, "LanternHUD", TIMEOUT) or nil
if lanternHudMod and lanternHudMod:IsA("ModuleScript") then
    local ok, mod = pcall(function() return require(lanternHudMod) end)
    if ok and mod and mod.Init then
        mod.Init()
    else
        warn("[CLIENT_BOOT] LanternHUD require/init failed")
        Report.noteMissing(fullPath(lanternHudMod))
    end
end

-- Oil HUD (loading bar style)
if LoadingScreen then LoadingScreen:UpdateProgress({percentage = 65, message = "Loading Oil HUD..."}) end
local oilHudMod = uiFolder and waitChild(uiFolder, "OilHUD", TIMEOUT) or nil
if oilHudMod and oilHudMod:IsA("ModuleScript") then
    local ok, mod = pcall(function() return require(oilHudMod) end)
    if ok and mod and mod.Init then
        mod.Init()
        print("[CLIENT_BOOT] OilHUD initialized")
    else
        warn("[CLIENT_BOOT] OilHUD require/init failed")
        Report.noteMissing(fullPath(oilHudMod))
    end
else
    warn("[CLIENT_BOOT] OilHUD not found or not a ModuleScript")
    Report.noteMissing(fullPath(uiFolder) .. ".OilHUD")
end

-- Net subscriptions for new events (optional)
 do
    if LoadingScreen then LoadingScreen:UpdateProgress({percentage = 80, message = "Establishing Network..."}) end
    local shared = ReplicatedStorage:FindFirstChild("Shared")
    local netMod = shared and shared:FindFirstChild("Net") or nil
    if netMod and netMod:IsA("ModuleScript") then
        local ok, Net = pcall(function() return require(netMod) end)
        if ok and Net then
            local ok1, _ = pcall(function()
                Net:GetEvent(Net.Events.RE_OnSafeZoneChanged).OnClientEvent:Connect(function(_payload) end)
            end)
            if not ok1 then warn("[CLIENT_BOOT] Failed to bind RE_OnSafeZoneChanged") end
            local ok2, _ = pcall(function()
                Net:GetEvent(Net.Events.RE_OnCrowdDescriptor).OnClientEvent:Connect(function(_pondId, _descriptor) end)
            end)
            if not ok2 then warn("[CLIENT_BOOT] Failed to bind RE_OnCrowdDescriptor") end
        else
            warn("[CLIENT_BOOT] Net require failed; skipping client subscriptions")
            Report.noteMissing(shared and (fullPath(shared) .. ".Net") or "ReplicatedStorage.Shared.Net")
        end
    else
        warn("[CLIENT_BOOT] Missing/invalid Shared.Net; skipping client subscriptions")
        Report.noteMissing(shared and (fullPath(shared) .. ".Net") or "ReplicatedStorage.Shared.Net")
    end
end

-- Mobility System
 do
    if LoadingScreen then LoadingScreen:UpdateProgress({percentage = 85, message = "Loading Mobility System..."}) end
    local mobilityFolder = waitChild(script.Parent, "Mobility", TIMEOUT)
    local mobilityController = mobilityFolder and waitChild(mobilityFolder, "MobilityController", TIMEOUT) or nil
    if mobilityController and mobilityController:IsA("ModuleScript") then
        local ok, mod = pcall(function() return require(mobilityController) end)
        if ok and mod then
            local controller = mod.new()
            if controller and controller.Init then
                controller:Init()
                print("[CLIENT_BOOT] MobilityController initialized")
            end
        else
            warn("[CLIENT_BOOT] MobilityController require/init failed")
            Report.noteMissing(fullPath(mobilityController))
        end
    end
 end

-- Start crowd controller (deterministic client simulation stubs)
 do
    if LoadingScreen then LoadingScreen:UpdateProgress({percentage = 90, message = "Loading Crowd Systems..."}) end
    local crowds = waitChild(script.Parent, "Crowds", TIMEOUT)
    local controller = crowds and waitChild(crowds, "CrowdController", TIMEOUT) or nil
    if controller then
        local ok, mod = pcall(function() return require(controller) end)
        if ok and mod and mod.Start then
            mod.Start()
        else
            warn("[CLIENT_BOOT] CrowdController require/start failed")
            Report.noteMissing(fullPath(controller))
        end
    end
end

-- Studio Dev UI (Studio only)
 do
    local RunService = game:GetService("RunService")
    if RunService:IsStudio() then
        local studioDevUI = script.Parent:FindFirstChild("StudioDevUI")
        if studioDevUI and studioDevUI:IsA("LocalScript") then
            -- LocalScript will run automatically
            print("[CLIENT_BOOT] StudioDevUI LocalScript found - will run automatically")
        else
            warn("[CLIENT_BOOT] StudioDevUI LocalScript not found")
            Report.noteMissing(fullPath(script.Parent) .. ".StudioDevUI")
        end
    end
end

-- Loading Screen is handled at the beginning of this script

Report.summary()

-- Complete loading
do
    if LoadingScreen then
        -- If server exposes RE_LoadingProgress, let server drive completion
        local net = ReplicatedStorage:FindFirstChild("Net")
        local remotes = net and net:FindFirstChild("Remotes")
        local hasServerProgress = remotes and remotes:FindFirstChild("RE_LoadingProgress")
        if hasServerProgress then
            print("[LoadingScreen] Waiting on server progress...")
            local progressHeard = false
            local progressRemote = remotes:FindFirstChild("RE_LoadingProgress")
            if progressRemote and progressRemote:IsA("RemoteEvent") then
                progressRemote.OnClientEvent:Connect(function()
                    progressHeard = true
                end)
            end
            task.delay(8, function()
                if LoadingScreen and not progressHeard then
                    warn("[LoadingScreen] No server progress within 8s; hiding (fallback)")
                    LoadingScreen:UpdateProgress({percentage = 100, message = "Ready"})
                    LoadingScreen:Hide()
                end
            end)
        else
            -- Remote not present yet; keep the loading screen while we wait briefly
            print("[LoadingScreen] Server progress remote not ready; waiting for replication...")
            local tries = 0
            local found = false
            while tries < 30 do -- ~15s total
                tries += 1
                task.wait(0.5)
                local net2 = ReplicatedStorage:FindFirstChild("Net")
                local rem2 = net2 and net2:FindFirstChild("Remotes")
                if rem2 and rem2:FindFirstChild("RE_LoadingProgress") then
                    found = true
                    print("[LoadingScreen] Progress remote appeared; deferring hide to server")
                    break
                end
            end
            if not found then
                warn("[LoadingScreen] Progress remote missing after wait; hiding (long fallback)")
                LoadingScreen:UpdateProgress({percentage = 100, message = "Ready"})
                LoadingScreen:Hide()
            end
        end
    end
end
