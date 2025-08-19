--!strict
-- LoomDesigner plugin. Manages a tiny state object representing the designer
-- selections and can export configs to a Lua file.

local RequireUtil = require(script.Parent.RequireUtil)

-- Prefer plugin-local GrowthVisualizer so Studio uses scene-driven version
local GrowthVisualizer = RequireUtil.fromRelative(script.Parent.Parent, {"growth","GrowthVisualizer"})
    or RequireUtil.fromReplicatedStorage({"growth","GrowthVisualizer"})
GrowthVisualizer = RequireUtil.must(GrowthVisualizer, "growth/GrowthVisualizer")
print("[LoomDesigner] GrowthVisualizer:", GrowthVisualizer._PLUGIN_VERSION or "unknown")

local LoomConfigs = RequireUtil.fromReplicatedStorage({"looms","LoomConfigs"})
    or RequireUtil.fromRelative(script.Parent.Parent, {"looms","LoomConfigs"})
LoomConfigs = RequireUtil.must(LoomConfigs, "looms/LoomConfigs")

local LoomConfigUtil = RequireUtil.fromReplicatedStorage({"looms","LoomConfigUtil"})
    or RequireUtil.fromRelative(script.Parent.Parent, {"looms","LoomConfigUtil"})
LoomConfigUtil = RequireUtil.must(LoomConfigUtil, "looms/LoomConfigUtil")

local VisualScene = RequireUtil.fromRelative(script.Parent, {"VisualScene"})
VisualScene = RequireUtil.must(VisualScene, "LoomDesigner/VisualScene")

local ModelResolver = RequireUtil.fromRelative(script.Parent, {"ModelResolver"})
ModelResolver = RequireUtil.must(ModelResolver, "LoomDesigner/ModelResolver")

local LoomDesigner = {}

local function firstConfigKey(configs)
        for k, v in pairs(configs) do
                if type(v) == "table" then return k end
        end
        return nil
end

local function resolveConfigId(configs, wantedId)
        if type(configs) ~= "table" then
                warn("[LoomDesigner] LoomConfigs is not a table; check module load path")
                return nil
        end
        if wantedId and type(configs[wantedId]) == "table" then
                return wantedId
        end
        local fallback = firstConfigKey(configs)
        if not fallback then
                warn("[LoomDesigner] No valid config tables found in LoomConfigs")
                return nil
        end
        if wantedId and type(configs[wantedId]) == "function" then
                warn(("[LoomDesigner] '%s' is a function, not a config. Falling back to '%s'")
                        :format(tostring(wantedId), tostring(fallback)))
        elseif wantedId and configs[wantedId] == nil then
                warn(("[LoomDesigner] Unknown configId '%s'. Falling back to '%s'")
                        :format(tostring(wantedId), tostring(fallback)))
        end
        return fallback
end

local function isConfigTable(x)
        return type(x) == "table" and (x.id ~= nil or x.uiName ~= nil or next(x) ~= nil)
end

local firstConfigId = firstConfigKey(LoomConfigs)

-- current working state used by the designer
local state = {
        configId = firstConfigId,
        baseSeed = 12345,
        g = 50, -- growth percent
        overrides = {
                materialization = { mode = "Model" },
                rotationRules = {},
                decorations = { enabled = false, types = {} },
        },

        -- Authoring state (Stage D)
        savedProfiles = {},
        branchAssignments = { trunkProfile = "", perDepth = {}, spacingN = {}, maxPerDepth = {} },
        modelLibrary = {},
        modelsByDepth = {},
        decoLibrary = {},
}

local function hashToInt(s)
        s = tostring(s)
        local h = 2166136261
        for i = 1, #s do
                h = (bit32.bxor(h, string.byte(s, i))) * 16777619 % 2^32
        end
        return h % 2147483647
end

local function normalizeSeed(seed)
        if typeof(seed) == "number" then
                return math.floor(seed)
        end
        return hashToInt(seed)
end

function LoomDesigner.Start(plugin)
        print("LoomDesigner plugin started", plugin)
        GrowthVisualizer.SetEditorMode(true)
        return state
end

function LoomDesigner.SetConfigId(id)
        state.configId = id
end

function LoomDesigner.SetSeed(seed)
        state.baseSeed = normalizeSeed(seed)
end

function LoomDesigner.RandomizeSeed()
        local rng = Random.new(os.clock() * 1e6)
        state.baseSeed = rng:NextInteger(1, 2^31 - 1)
        return state.baseSeed
end

function LoomDesigner.GetSeed()
        return state.baseSeed
end

function LoomDesigner.GetState()
        return state
end

function LoomDesigner.SetGrowthPercent(g)
	state.g = g
end

local function deepMerge(dst, src)
        for k, v in pairs(src) do
                if type(v) == "table" and type(dst[k]) == "table" then
                        deepMerge(dst[k], v)
                else
                        dst[k] = v
                end
        end
end

local function deepCopy(v)
        if type(v) ~= "table" then return v end
        local copy = {}
        for k, val in pairs(v) do
                copy[k] = deepCopy(val)
        end
        return copy
end

function LoomDesigner.SetOverrides(overrides)
        deepMerge(state.overrides, overrides)
end

function LoomDesigner.ClearOverride(pathList)
        local t = state.overrides
        for i = 1, #pathList - 1 do
                t = t[pathList[i]]
                if type(t) ~= "table" then return end
        end
        t[pathList[#pathList]] = nil
end

-- simple profile helpers ----------------------------------------------------
function LoomDesigner.CreateProfile(name: string, profile)
        state.savedProfiles[name] = profile or { kind = "straight", segmentCountMin = 1, segmentCountMax = 1 }
end

function LoomDesigner.DeleteProfile(name: string)
        state.savedProfiles[name] = nil
end

function LoomDesigner.RenameProfile(oldName: string, newName: string)
        if state.savedProfiles[oldName] then
                state.savedProfiles[newName] = state.savedProfiles[oldName]
                state.savedProfiles[oldName] = nil
        end
end

-- export/import -------------------------------------------------------------
local function rebuildLibraries()
        state.modelLibrary = {}
        for _, list in pairs(state.modelsByDepth) do
                for _, ref in ipairs(list) do
                        if not table.find(state.modelLibrary, ref) then
                                table.insert(state.modelLibrary, ref)
                        end
                end
        end
        state.decoLibrary = {}
        if state.overrides.decorations.enabled then
                for _, deco in ipairs(state.overrides.decorations.types) do
                        if deco.models then
                                for _, ref in ipairs(deco.models) do
                                        if not table.find(state.decoLibrary, ref) then
                                                table.insert(state.decoLibrary, ref)
                                        end
                                end
                        end
                end
        end
end

local function applyAuthoring()
        local cfgId = resolveConfigId(LoomConfigs, state.configId)
        if not cfgId then return end
        state.configId = cfgId

        local base = LoomConfigs[cfgId]
        if type(base) ~= "table" then
                warn("[LoomDesigner] Resolved config is not a table; creating new")
                base = { id = cfgId }
        end

        local authored = {
                profiles = LoomConfigUtil.deepCopy(state.savedProfiles),
                branchAssignments = LoomConfigUtil.deepCopy(state.branchAssignments),
                models = {
                        byDepth = LoomConfigUtil.deepCopy(state.modelsByDepth),
                        decorations = (state.overrides and state.overrides.decorations and state.overrides.decorations.enabled)
                                and LoomConfigUtil.deepCopy(state.overrides.decorations.types)
                                or (base.models and LoomConfigUtil.deepCopy(base.models.decorations)) or nil,
                },
        }

        local merged = LoomConfigUtil.mergeConfig(base, authored)

        LoomConfigs[cfgId] = merged
        return merged
end

function LoomDesigner.ImportAuthoring()
        local cfg = LoomConfigs[state.configId]
        if not cfg then return end
        state.savedProfiles = deepCopy(cfg.profiles or {})
        state.branchAssignments = deepCopy(cfg.branchAssignments or {trunkProfile="", perDepth={}, spacingN={}, maxPerDepth={}})
        local models = cfg.models or {}
        state.modelsByDepth = deepCopy(models.byDepth or {})
        if models.decorations then
                state.overrides.decorations = { enabled = true, types = deepCopy(models.decorations) }
        else
                state.overrides.decorations = { enabled = false, types = {} }
        end
        rebuildLibraries()
end

function LoomDesigner.ExportAuthoring()
        local cfg = applyAuthoring()
        LoomDesigner.ExportConfig(cfg)
end

LoomDesigner.ApplyAuthoring = applyAuthoring

function LoomDesigner.Reseed()
        return LoomDesigner.RandomizeSeed()
end

local function ensurePreviewParent()
        local folder = workspace:FindFirstChild("LoomPreview")
        if not folder then
                folder = Instance.new("Folder")
                folder.Name = "LoomPreview"
                folder.Parent = workspace
        end
        return folder
end

local function clearExistingPreview(parent)
        local old = parent:FindFirstChild("PreviewBranch")
        if old then
                old:Destroy()
        end
end

function LoomDesigner.RebuildPreview(_container)
        if not state.configId then return end

        -- ensure in-memory config reflects current authoring state
        applyAuthoring()

        -- robust configId fallback
        if not LoomConfigs[state.configId] then
                local firstId; for k in pairs(LoomConfigs) do firstId = k break end
                if firstId then
                        warn(("[LoomDesigner] Unknown configId '%s'. Using '%s'"):format(tostring(state.configId), firstId))
                        state.configId = firstId
                else
                        warn("[LoomDesigner] LoomConfigs empty; skipping preview")
                        return
                end
        end

        local parent = ensurePreviewParent()
        clearExistingPreview(parent)
        local model = Instance.new("Model")
        model.Name = "PreviewBranch"
        model.Parent = parent
        VisualScene.SetPreviewModel(model)

        GrowthVisualizer.Release(nil, 0)
        local ok, err = pcall(function()
                GrowthVisualizer.Render(nil, {
                        loomUid = 0,
                        configId = state.configId,
                        baseSeed = state.baseSeed,
                        g = state.g,
                        overrides = state.overrides,
                        scene = {
                                Clear = VisualScene.Clear,
                                Spawn = VisualScene.Spawn,
                                ResolveModel = ModelResolver.ResolveFromList,
                        },
                })
        end)

        if not ok then
                warn("RebuildPreview failed: ", err)
                return
        end

        local sb = Instance.new("SelectionBox")
        sb.Adornee = model
        sb.LineThickness = 0.05
        sb.Parent = model
        task.delay(2, function()
                sb:Destroy()
        end)

        local pp = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
        local pivot = pp and pp.Position or Vector3.new()
        local basePartCount = 0
        for _, d in ipairs(model:GetDescendants()) do
                if d:IsA("BasePart") then basePartCount += 1 end
        end
        print(string.format("Spawned PreviewBranch at %s with %d BaseParts", tostring(pivot), basePartCount))
        if basePartCount == 0 then
                VisualScene.Spawn({
                        name="DebugSegment",
                        shape=Enum.PartType.Ball,
                        size=Vector3.new(0.8,0.8,0.8),
                        cframe=CFrame.new(0,3,0),
                        color=Color3.fromRGB(255,0,0),
                        anchored=true,
                        canCollide=false,
                })
                warn("[LoomDesigner] Render produced 0 BaseParts; placed DebugSegment for visibility.")
        end
end

-- Simple validation that checks for expected field types. Returns true if the
-- config appears valid otherwise false and the problematic field name.
function LoomDesigner.ValidateConfig(config)
	if type(config) ~= "table" then
		return false, "config"
	end
	if type(config.id) ~= "string" then
		return false, "id"
	end
	if config.growthDefaults and type(config.growthDefaults.segmentCount) ~= "number" then
		return false, "segmentCount"
	end
	return true
end

local function serialize(value, indent)
	indent = indent or 0
	local t = type(value)
	if t == "table" then
		local pieces = {"{"}
		local nextIndent = indent + 4
		for k, v in pairs(value) do
			local key
			if type(k) == "string" and k:match("^%a[%w_]*$") then
				key = k .. " = "
			else
				key = "[" .. serialize(k) .. "] = "
			end
			table.insert(pieces, string.rep(" ", nextIndent) .. key .. serialize(v, nextIndent) .. ",")
		end
		table.insert(pieces, string.rep(" ", indent) .. "}")
		return table.concat(pieces, "\n")
	elseif t == "string" then
		return string.format("%q", value)
	else
		return tostring(value)
	end
end

-- Export the provided config to disk. The default destination matches the
-- runtime path but tests may provide their own path to avoid mutating the repo.
function LoomDesigner.ExportConfig(config, destPath)
	local ok, err = LoomDesigner.ValidateConfig(config)
	if not ok then return false, err end
	destPath = destPath or "src/shared/looms/LoomConfigs.luau"

	local existing = {}
	local success, loaded = pcall(dofile, destPath)
	if success and type(loaded) == "table" then
		for k, v in pairs(loaded) do
			existing[k] = v
		end
	end
	existing[config.id] = config

	local file = assert(io.open(destPath, "w"))
	file:write("--!strict\n")
	file:write("-- Generated by LoomDesigner.ExportConfig\n\n")
	file:write("local configs = {\n")
	for k, v in pairs(existing) do
		file:write("    [" .. serialize(k) .. "] = " .. serialize(v, 4) .. ",\n")
	end
	file:write("}\n\nreturn configs\n")
	file:close()
	return true
end

return LoomDesigner
