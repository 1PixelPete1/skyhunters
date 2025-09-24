--!strict
-- Robust server boot with SafeRequire, Net fallback, grouped logs, and BOOT summary

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SafeRequire = require(ReplicatedStorage.Shared.SafeRequire)

local Systems = script.Parent:WaitForChild("Systems")

type Failure = { name: string, reason: string, path: string? }

local function logFailure(name: string, reason: string, path: string?)
    local where = path or name
    print(("BOOT_FAIL %s:%s [%s]"):format(name, reason, tostring(where)))
end

-- Preflight (non-fatal)
 do
    local preflightRes = SafeRequire.load(script.Parent:FindFirstChild("ServerBootPreflight"))
    if preflightRes.ok and preflightRes.mod and preflightRes.mod.Run then
        preflightRes.mod.Run()
    end
end

-- Net (with fallback)
local Net: any
local netFailure: Failure? = nil
 do
    local sharedFolder = ReplicatedStorage:FindFirstChild("Shared")
    local netInst = sharedFolder and sharedFolder:FindFirstChild("Net") or nil
    local v = SafeRequire.validate(netInst)
    if not v.ok then
        netFailure = { name = "Net", reason = v.reason or "not_found", path = v.path }
        logFailure("Net", netFailure.reason, v.path)
        local stubLoad = SafeRequire.load(script.Parent:FindFirstChild("NetStub"))
        Net = (stubLoad.ok and stubLoad.mod) or {}
    else
        local l = SafeRequire.load(netInst)
        if l.ok then
            Net = l.mod
        else
            netFailure = { name = "Net", reason = l.reason or "pcall_error", path = l.path }
            logFailure("Net", netFailure.reason, l.path)
            local stubLoad = SafeRequire.load(script.Parent:FindFirstChild("NetStub"))
            Net = (stubLoad.ok and stubLoad.mod) or {}
        end
    end
end

local services: any = { Net = Net }

-- Loading helpers
local failures: { Failure } = {}
local failuresByReason: { [string]: { string } } = {}
local okCount = 0
local skipped = 0
local seen: { [string]: boolean } = {}

local function loadService(name: string, inst: Instance?)
    if seen[name] then
        warn(("DUPLICATE_SERVICE: %s (skipped)"):format(name))
        return
    end
    seen[name] = true
    local res = SafeRequire.load(inst)
    if res.ok then
        services[name] = res.mod
        okCount += 1
    else
        table.insert(failures, { name = name, reason = res.reason or "pcall_error", path = res.path })
        local r = res.reason or "pcall_error"
        failuresByReason[r] = failuresByReason[r] or {}
        table.insert(failuresByReason[r], name)
        if r ~= "class_mismatch" then
            logFailure(name, r, res.path)
        end
    end
end

-- Core services
loadService("MetricsService", Systems:FindFirstChild("MetricsService"))
loadService("ProfilerService", Systems:FindFirstChild("ProfilerService"))
loadService("ContentService", Systems:FindFirstChild("ContentService"))
loadService("SaveService", Systems:FindFirstChild("SaveService"))
loadService("PlotService", Systems:FindFirstChild("PlotService"))
loadService("ValidationService", Systems:FindFirstChild("ValidationService"))
loadService("SpatialIndexService", Systems:FindFirstChild("SpatialIndexService"))
loadService("JobQueueService", Systems:FindFirstChild("JobQueueService"))
loadService("ThreadVisualizationService", Systems:FindFirstChild("ThreadVisualizationService"))
loadService("EconomyService", Systems:FindFirstChild("EconomyService"))
loadService("InventoryService", Systems:FindFirstChild("InventoryService"))
loadService("InventoryIntegrationService", Systems:FindFirstChild("InventoryIntegrationService"))
loadService("ToolService", Systems:FindFirstChild("ToolService"))
loadService("ExpeditionService", Systems:FindFirstChild("ExpeditionService"))
loadService("StreamingService", Systems:FindFirstChild("StreamingService"))
loadService("MemoryPoolService", Systems:FindFirstChild("MemoryPoolService"))
loadService("NetworkOptimizationService", Systems:FindFirstChild("NetworkOptimizationService"))
loadService("AntiCheatService", Systems:FindFirstChild("AntiCheatService"))
loadService("StateHashService", Systems:FindFirstChild("StateHashService"))
loadService("ZoneService", Systems:FindFirstChild("ZoneService"))
loadService("RemovalSystem", Systems:FindFirstChild("RemovalSystem"))
-- Load our top-level pond network service under a unique key to avoid name collision
loadService("PondNetworkCore", Systems:FindFirstChild("PondNetworkService"))
loadService("PondPersistence", Systems:FindFirstChild("PondPersistence"))

-- Enhanced Systems (New)
loadService("EnhancedRemovalSystem", Systems:FindFirstChild("EnhancedRemovalSystem"))
loadService("AsyncLoadingSystem", Systems:FindFirstChild("AsyncLoadingSystem"))
loadService("EnhancedCanalStones", Systems:FindFirstChild("EnhancedCanalStones"))
loadService("StudioDevRemotes", Systems:FindFirstChild("StudioDevRemotes"))
loadService("RenderQueueSystem", Systems:FindFirstChild("RenderQueueSystem"))
-- Async pond/canal loader (progressive, for loading screen)
loadService("AsyncPondLoader", Systems:FindFirstChild("AsyncPondLoader"))

-- Storm System
loadService("StormService", Systems:FindFirstChild("StormService"))

-- Mobility System
local Mobility = Systems:FindFirstChild("Mobility")
if Mobility then
    loadService("MobilityService", Mobility:FindFirstChild("MobilityService"))
else
    skipped += 1
end

-- Lanterns V2 services
local Lantern = Systems:FindFirstChild("Lantern")
if Lantern then
    loadService("LanternTimerQueue", Lantern:FindFirstChild("LanternTimerQueue"))
    loadService("LanternReplication", Lantern:FindFirstChild("LanternReplication"))
    loadService("LanternService", Lantern:FindFirstChild("LanternService"))
    loadService("PondNetworkService", Lantern:FindFirstChild("PondNetworkService"))
    loadService("VoyageService", Lantern:FindFirstChild("VoyageService"))
else
    skipped += 5
end
loadService("PlacementGateway", Systems:FindFirstChild("PlacementGateway"))
loadService("ApplyGateway", Systems:FindFirstChild("ApplyGateway"))

-- Initialize services that expose Init
for name, svc in pairs(services) do
    if type(svc) == "table" and svc.Init then
        local ok, _ = pcall(function()
            svc.Init(services)
        end)
        if not ok then
            table.insert(failures, { name = tostring(name) .. ".Init", reason = "pcall_error", path = nil })
            logFailure(tostring(name) .. ".Init", "pcall_error", nil)
        end
    end
end

-- Start zone service after Init wiring
 do
    local zs = services.ZoneService
    if zs and zs.Start then
        local ok, _ = pcall(function() zs.Start() end)
        if not ok then
            table.insert(failures, { name = "ZoneService.Start", reason = "pcall_error", path = nil })
            logFailure("ZoneService.Start", "pcall_error", nil)
        end
    end
end

-- New pond/voyage stubs (NYI)
Net:GetFunction(Net.Functions.RF_ClaimPond).OnServerInvoke = function(player, pondId)
    return { ok = false, err = "NYI" }
end
Net:GetFunction(Net.Functions.RF_StartVoyage).OnServerInvoke = function(player, routeId)
    return { ok = false, err = "NYI" }
end

-- Lanterns V2: Client -> Server RPCs
Net:GetFunction(Net.Functions.RF_DepositOil).OnServerInvoke = function(player, amount)
    if services.LanternService and services.LanternService.DepositOil then
        return services.LanternService.DepositOil(player, amount)
    end
    return { ok = false, err = "UNBOUND" }
end

-- Gateways bind and health log
 do
    if services.PlacementGateway and services.PlacementGateway.Bind then
        local h = services.PlacementGateway.Bind(services)
        if h then print(("GATEWAY PlacementGateway bound=%s reason=%s"):format(tostring(h.bound), tostring(h.reason))) end
    end
    if services.ApplyGateway and services.ApplyGateway.Bind then
        local h = services.ApplyGateway.Bind(services)
        if h then print(("GATEWAY ApplyGateway bound=%s reason=%s"):format(tostring(h.bound), tostring(h.reason))) end
    end
end

Net:GetFunction(Net.Functions.RF_RefillBaseLantern).OnServerInvoke = function(player, lanternId, amount)
    if services.LanternService and services.LanternService.RefillBaseLantern then
        return services.LanternService.RefillBaseLantern(player, lanternId, amount)
    end
    return { ok = false, err = "UNBOUND" }
end
Net:GetFunction(Net.Functions.RF_ToggleRunLantern).OnServerInvoke = function(player, on)
    if services.LanternService and services.LanternService.ToggleRunLantern then
        return services.LanternService.ToggleRunLantern(player, on)
    end
    return { ok = false, err = "UNBOUND" }
end

-- Gateway health contributes to degraded count
local degraded = 0
local function noteGatewayHealth(name: string, gw: any)
    if gw and gw.GetHealth then
        local h = gw.GetHealth()
        if not h.bound then
            degraded += 1
            if h.reason then
                table.insert(failures, { name = name, reason = h.reason })
            end
        end
    end
end
noteGatewayHealth("PlacementGateway", services.PlacementGateway)
noteGatewayHealth("ApplyGateway", services.ApplyGateway)

-- BOOT summary + grouped class_mismatch line
 do
    local failureParts = {}
    local cm = failuresByReason["class_mismatch"]
    if cm and #cm > 0 then
        print(("BOOT_FAIL class_mismatch count=%d examples=[%s]"):format(#cm, table.concat(cm, ", ")))
    end
    for _, f in ipairs(failures) do
        table.insert(failureParts, ("%s:%s"):format(f.name, f.reason))
    end
    local okNet = netFailure == nil and 1 or 0
    local totalOk = okCount + okNet
    print(("BOOT ok=%d degraded=%d skipped=%d failures=[%s]")
        :format(totalOk, degraded, skipped, table.concat(failureParts, ", ")))
end
