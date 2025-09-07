--!strict
-- ServerBootPreflight: Non-fatal wiring checks with a single PASS/FAIL line.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local SafeRequire = require(ReplicatedStorage.Shared.SafeRequire)

export type PreflightResult = { ok: boolean, reasons: { string } }

local function existsFolder(parent: Instance?, name: string): (boolean, Instance?)
    if not parent then return false, nil end
    local inst = parent:FindFirstChild(name)
    return inst ~= nil and inst:IsA("Folder"), inst
end

local function existsModule(parent: Instance?, name: string): (boolean, Instance?)
    if not parent then return false, nil end
    local inst = parent:FindFirstChild(name)
    return inst ~= nil and inst:IsA("ModuleScript"), inst
end

local function existsClass(parent: Instance?, name: string, className: string): (boolean, Instance?)
    if not parent then return false, nil end
    local inst = parent:FindFirstChild(name)
    return inst ~= nil and inst:IsA(className), inst
end

local function preflight(): PreflightResult
    local reasons: { string } = {}

    local rs = ReplicatedStorage

    -- Check Shared.Net module
    local shared = rs:FindFirstChild("Shared")
    local netOk, netInst = existsModule(shared, "Net")
    if not netOk then
        table.insert(reasons, (("%s:%s"):format(netInst and netInst:GetFullName() or "ReplicatedStorage.Shared.Net", "class_mismatch")))
    end

    -- Check Net and Remotes folders
    local netFolderOk, netFolder = existsFolder(rs, "Net")
    if not netFolderOk then
        table.insert(reasons, "ReplicatedStorage.Net:not_found")
    end
    local remotesOk, remotes = existsFolder(netFolder, "Remotes")
    if not remotesOk then
        table.insert(reasons, "ReplicatedStorage.Net.Remotes:not_found")
    end

    -- RemoteFunctions needed
    if remotes then
        local function checkRF(name: string)
            local okRF, _ = existsClass(remotes, name, "RemoteFunction")
            if not okRF then
                table.insert(reasons, ("%s:%s"):format(remotes:GetFullName() .. "." .. name, "not_found"))
            end
        end
        checkRF("RF_PlaceBaseLantern")
        checkRF("RF_ApplyBaseLantern")
    end

    -- Optional: Config.Version present
    local config = rs:FindFirstChild("Config")
    local verOk, _ = existsModule(config, "Version")
    if not verOk then
        table.insert(reasons, (config and (config:GetFullName() .. ".Version") or "ReplicatedStorage.Config.Version") .. ":not_found")
    end

    -- Systems requireability/class check (direct children of Systems and Systems/Lantern)
    do
        local systems = ServerScriptService:FindFirstChild("Systems")
        if systems and systems:IsA("Folder") then
            local violators: { string } = {}
            for _, child in ipairs(systems:GetChildren()) do
                if child:IsA("Folder") then
                    if child.Name == "Lantern" then
                        for _, lc in ipairs(child:GetChildren()) do
                            if not (lc:IsA("Folder") or lc:IsA("ModuleScript")) then
                                table.insert(violators, ("%s:%s"):format(lc.Name, lc.ClassName))
                            end
                        end
                    end
                else
                    if not child:IsA("ModuleScript") then
                        table.insert(violators, ("%s:%s"):format(child.Name, child.ClassName))
                    end
                end
            end
            if #violators > 0 then
                table.insert(reasons, "SystemsClassCheck: [" .. table.concat(violators, ", ") .. "]")
            end
        end
    end

    -- BOM check (best-effort, Studio-only)
    do
        local sps = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
        local client = sps and sps:FindFirstChild("Client")
        local bomFiles: { string } = {}
        local function checkScript(scr: Instance)
            local ok, src = pcall(function()
                return (scr :: any).Source
            end)
            if ok and type(src) == "string" then
                if #src >= 3 then
                    local b1,b2,b3 = src:byte(1,3)
                    if b1 == 239 and b2 == 187 and b3 == 191 then
                        table.insert(bomFiles, scr:GetFullName())
                    end
                end
            end
        end
        if client and client:IsA("Folder") then
            for _, child in ipairs(client:GetDescendants()) do
                if child:IsA("ModuleScript") or child:IsA("LocalScript") then
                    checkScript(child)
                end
            end
        end
        if #bomFiles > 0 then
            table.insert(reasons, "BOM: [" .. table.concat(bomFiles, ", ") .. "]")
        end
    end

    local ok = #reasons == 0
    if ok then
        print("SERVER_PREFLIGHT: PASS")
    else
        print("SERVER_PREFLIGHT: FAIL [" .. table.concat(reasons, ", ") .. "]")
    end
    return { ok = ok, reasons = reasons }
end

-- World readiness preflight (runtime config + mappings)
local function worldPreflight()
    local reasons: { string } = {}

    -- Config presence and types
    local okCfg, WorldConfig = pcall(function()
        return require(ReplicatedStorage.Config.WorldConfig)
    end)
    if not okCfg or type(WorldConfig) ~= "table" then
        table.insert(reasons, "Config:WorldConfig:require_failed")
    else
        local function isNum(x) return type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge end
        local function isVec3(x) return typeof(x) == "Vector3" end

        local HUB = WorldConfig.HUB or {}
        if not isVec3(HUB.Center) then table.insert(reasons, "HUB.Center:type") end
        if not isNum(HUB.Radius) then table.insert(reasons, "HUB.Radius:type") end

        local PLOTS = WorldConfig.PLOTS or {}
        if not isNum(PLOTS.Slots) then table.insert(reasons, "PLOTS.Slots:type") end
        if not isNum(PLOTS.RadialOffset) then table.insert(reasons, "PLOTS.RadialOffset:type") end

        if not isNum(WorldConfig.EPSILON) then table.insert(reasons, "EPSILON:type") end

        local ISLANDS = WorldConfig.ISLANDS or {}
        local presetKey = ISLANDS.MainPresetKey or "plane_64m"
        local preset = (ISLANDS.Presets or {})[presetKey]
        if not preset then
            table.insert(reasons, "Preset:missing " .. tostring(presetKey))
        else
            local h = preset.HalfSize
            local hOk = (type(h) == "number" and isNum(h)) or isVec3(h)
            if not hOk then table.insert(reasons, "Preset:bad HalfSize") end
            if type(preset.Revision) ~= "number" then table.insert(reasons, "Preset:bad Revision") end
        end
        -- Default height naming tolerance
        local hasDefaultY = isNum(ISLANDS.DefaultHeightY)
        local hasDefault = isNum((ISLANDS :: any).DefaultHeight)
        if not (hasDefaultY or hasDefault) then
            table.insert(reasons, "ISLANDS.DefaultHeightY:type")
        end
    end

    -- Shared helpers require-able
    do
        local shared = ReplicatedStorage:FindFirstChild("Shared")
        local function assertMod(name: string)
            local ok, mod = pcall(function()
                return SafeRequire.load(shared and shared:FindFirstChild(name))
            end)
            if not ok or not mod or not (mod.ok) then
                table.insert(reasons, "Shared:" .. name .. ":require_failed")
            end
        end
        assertMod("WorldIndex")
        assertMod("TransformUtil")
        assertMod("PlaceValidator")
        assertMod("PlacementPolicy")
    end

    -- Remotes presence (decide claim remote = RF_ClaimPond)
    local claimRemoteName = "RF_ClaimPond"
    do
        local net = ReplicatedStorage:FindFirstChild("Net")
        local remotes = net and net:FindFirstChild("Remotes")
        if not (remotes and remotes:IsA("Folder")) then
            table.insert(reasons, "ReplicatedStorage.Net.Remotes:not_found")
        else
            local function assertRF(name: string)
                local inst = remotes:FindFirstChild(name)
                if not inst or not inst:IsA("RemoteFunction") then
                    table.insert(reasons, "RemoteFunction:missing " .. name)
                end
            end
            assertRF("RF_PlaceBaseLantern")
            assertRF("RF_ApplyBaseLantern")
            assertRF(claimRemoteName)
        end
    end

    -- Optional template presence
    local templateStatus = "ok"
    do
        local folder = ServerStorage:FindFirstChild("IslandTemplates")
        local plane = folder and folder:FindFirstChild("Plane")
        if not plane or not (plane:IsA("Model") or plane:IsA("Part")) then
            templateStatus = "missing->fallback"
        end
    end

    local ok = #reasons == 0
    if ok then
        -- Compose PASS line
        local cfg = require(ReplicatedStorage.Config.WorldConfig)
        local slots = (cfg.PLOTS and cfg.PLOTS.Slots) or 0
        local pkey = (cfg.ISLANDS and cfg.ISLANDS.MainPresetKey) or "plane_64m"
        print(("WORLD_PREFLIGHT: PASS [Slots=%d, Preset=%s, Template=%s]"):format(tonumber(slots) or 0, tostring(pkey), templateStatus))
    else
        print("WORLD_PREFLIGHT: FAIL [" .. table.concat(reasons, ", ") .. "]")
    end
end

return { Run = function()
    preflight()
    worldPreflight()
end }
