--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SafeRequire = require(ReplicatedStorage.Shared.SafeRequire)

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
    local uiRouter = waitChild(script.Parent, "UIRouter", TIMEOUT)
    if uiRouter and uiRouter:IsA("ModuleScript") then
        local ok, err = pcall(function() require(uiRouter) end)
        if not ok then warn("[CLIENT_BOOT] UIRouter require failed", err); Report.noteMissing(fullPath(uiRouter)) end
    end
end

-- ExpeditionClient (only require ModuleScript; LocalScript runs itself)
 do
    local exp = waitChild(script.Parent, "ExpeditionClient", TIMEOUT)
    if exp and exp:IsA("ModuleScript") then
        local ok, err = pcall(function() require(exp) end)
        if not ok then warn("[CLIENT_BOOT] ExpeditionClient require failed", err); Report.noteMissing(fullPath(exp)) end
    end
end

-- Lanterns V2 client FX + HUD
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

-- Net subscriptions for new events (optional)
 do
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

-- Start crowd controller (deterministic client simulation stubs)
 do
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

Report.summary()