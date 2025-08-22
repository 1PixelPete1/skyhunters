--!strict
-- LoomDesigner plugin. Manages a tiny state object representing the designer
-- selections and can export configs to a Lua file.

local RequireUtil = require(script.Parent.RequireUtil)
-- Import FlowTrace for rich tracing; every public function will be wrapped
local FT = require(script.Parent.FlowTrace)

-- Prefer plugin-local GrowthVisualizer so Studio uses scene-driven version
local GrowthVisualizer = RequireUtil.fromRelative(script.Parent.Parent, {"growth","GrowthVisualizer"})
    or RequireUtil.fromReplicatedStorage({"growth","GrowthVisualizer"})
GrowthVisualizer = RequireUtil.must(GrowthVisualizer, "growth/GrowthVisualizer")
print("[LoomDesigner] GrowthVisualizer:", GrowthVisualizer._PLUGIN_VERSION or "unknown")

local LoomConfigUtil = RequireUtil.fromRelative(script.Parent.Parent, {"looms","LoomConfigUtil"})
    or RequireUtil.fromReplicatedStorage({"looms","LoomConfigUtil"})
LoomConfigUtil = RequireUtil.must(LoomConfigUtil, "looms/LoomConfigUtil")
print("[LoomDesigner] Using LoomConfigUtil.deepCopy:", type(LoomConfigUtil and LoomConfigUtil.deepCopy))

local VisualScene = RequireUtil.fromRelative(script.Parent, {"VisualScene"})
VisualScene = RequireUtil.must(VisualScene, "LoomDesigner/VisualScene")

local ModelResolver = RequireUtil.fromRelative(script.Parent, {"ModelResolver"})
ModelResolver = RequireUtil.must(ModelResolver, "LoomDesigner/ModelResolver")

local LoomConfigs = RequireUtil.fromRelative(script.Parent.Parent, {"looms","LoomConfigs
    or RequireUtil.fromReplicatedStorage({"looms","LoomConfigs"})
if not LoomConfigs then
    FT.warn("LC.missing", "could not resolve looms/LoomConfigs; using stub")
    LoomConfigs = {}
end

-- Forward declare so we can use local deepCopy inside DC even if it’s defined later
local deepCopy
local ensureTrunk

-- DC: resilient deep copy that uses LoomConfigUtil if available, else local
local function DC(v)
    local f = LoomConfigUtil and LoomConfigUtil.deepCopy
    if type(f) == "function" then
        return f(v)
    end
    -- fall back to local deepCopy (defined below)
    return deepCopy and deepCopy(v) or v
end

local LoomDesigner = {}

-- Single source of truth for supported profile kinds
local SUPPORTED_KIND_LIST = {"straight","curved","zigzag","sigmoid","chaotic"}
local SUPPORTED_KINDS = {}
for _,k in ipairs(SUPPORTED_KIND_LIST) do SUPPORTED_KINDS[k] = true end
LoomDesigner.SUPPORTED_KIND_LIST = SUPPORTED_KIND_LIST
LoomDesigner.SUPPORTED_KINDS = SUPPORTED_KINDS

-- unified authoring state
local newState = {
        baseSeed = 12345,
        g = 50, -- growth percent
        overrides = {
                materialization = { mode = "Model" },
                rotationRules = {},
                decorations = { enabled = false, types = {} },
        },
        modelLibrary = {},
        modelsByDepth = {},
        decoLibrary = {},
        branches = {},
        assignments = {
                trunk = "",
                children = {},
        },
}

-- watch newState tables for trace logging
newState = select(1, FT.watchTable("newState", newState))
newState.overrides = select(1, FT.watchTable("newState.overrides", newState.overrides))
newState.branches = select(1, FT.watchTable("newState.branches", newState.branches))
newState.assignments = select(1, FT.watchTable("newState.assignments", newState.assignments))
newState.assignments.children = select(1, FT.watchTable("newState.assignments.children", newState.assignments.children))
newState.modelsByDepth = select(1, FT.watchTable("newState.modelsByDepth", newState.modelsByDepth))

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

        -- read optional tag filter and enable flag from plugin settings then init tracer
        local tagAllow
        local enabled = false
        if plugin and plugin.GetSetting then
                local ok, tags = pcall(plugin.GetSetting, plugin, "ld.ft.tags")
                if ok then tagAllow = tags end
                local okEnabled, en = pcall(plugin.GetSetting, plugin, "ld.ft.enabled")
                if okEnabled then enabled = en end
        end
        FT.init({enabled = enabled, tagAllow = tagAllow, maxStr = 160})

        -- checkpoint at start: do we have a GrowthVisualizer module?
        FT.check("Start.begin", {hasGV = GrowthVisualizer ~= nil})

        -- guard SetEditorMode presence before calling
        if FT.branch("GV.has.SetEditorMode", type(GrowthVisualizer.SetEditorMode) == "function") then
                GrowthVisualizer.SetEditorMode(true)
        else
                FT.warn("GV.missing.SetEditorMode", "skipped")
        end

        -- ensure a default branch exists for editing
        if next(newState.branches) == nil then
                newState.branches["branch1"] = {kind = "straight"}
                newState.assignments.trunk = "branch1"
        end

        return newState
end

function LoomDesigner.SetSeed(seed)
        newState.baseSeed = normalizeSeed(seed)
end

function LoomDesigner.RandomizeSeed()
        local rng = Random.new(os.clock() * 1e6)
        newState.baseSeed = rng:NextInteger(1, 2^31 - 1)
        return newState.baseSeed
end

function LoomDesigner.GetSeed()
        return newState.baseSeed
end

function LoomDesigner.GetState()
        return newState
end

function LoomDesigner.SetGrowthPercent(g)
        newState.g = g
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

deepCopy = function(v)
        if type(v) ~= "table" then return v end
        local copy = {}
        for k, val in pairs(v) do
                copy[k] = deepCopy(val)
        end
        return copy
end

-- Trace deepCopy helper as it is reused in multiple paths
deepCopy = FT.fn("Main.deepCopy", deepCopy)

function LoomDesigner.SetOverrides(overrides)
        deepMerge(newState.overrides, overrides)
end

function LoomDesigner.ClearOverride(pathList)
        local t = newState.overrides
        for i = 1, #pathList - 1 do
                t = t[pathList[i]]
                if type(t) ~= "table" then return end
        end
        t[pathList[#pathList]] = nil
end

-- branch layout helpers -----------------------------------------------------
function LoomDesigner.CreateBranch(name: string, design)
        design = design or { kind = "straight" }
        newState.branches[name] = DC(design)
end

function LoomDesigner.DeleteBranch(name: string)
        newState.branches[name] = nil
        if newState.assignments.trunk == name then
                newState.assignments.trunk = ""
        end
        for i = #newState.assignments.children, 1, -1 do
                local a = newState.assignments.children[i]
                if a.parent == name or a.child == name then
                        table.remove(newState.assignments.children, i)
                end
        end
end

function LoomDesigner.RenameBranch(oldName: string, newName: string)
        if newState.branches[oldName] then
                newState.branches[newName] = newState.branches[oldName]
                newState.branches[oldName] = nil
                if newState.assignments.trunk == oldName then
                        newState.assignments.trunk = newName
                end
                for _, a in ipairs(newState.assignments.children) do
                        if a.parent == oldName then a.parent = newName end
                        if a.child == oldName then a.child = newName end
                end
        end
end

function LoomDesigner.EditBranch(name: string, patch)
        local branch = newState.branches[name]
        if branch and patch then
                deepMerge(branch, patch)
        end
end

function LoomDesigner.GetBranches()
        local copy = {}
        for k, v in pairs(newState.branches) do
                copy[k] = v
        end
        return copy
end

-- assignments API ------------------------------------------------------------
function LoomDesigner.SetTrunk(name: string)
        newState.assignments.trunk = name
end

function LoomDesigner.AddChild(parent: string, child: string, placement: string, count: number)
        table.insert(newState.assignments.children, {
                parent = parent,
                child = child,
                placement = placement or "tip",
                count = count or 1,
        })
end

function LoomDesigner.RemoveChild(idx: number)
        table.remove(newState.assignments.children, idx)
end

function LoomDesigner.GetAssignments()
        local copy = { trunk = newState.assignments.trunk, children = {} }
        for i, a in ipairs(newState.assignments.children) do
                copy.children[i] = {
                        parent = a.parent,
                        child = a.child,
                        placement = a.placement,
                        count = a.count,
                }
        end
        return copy
end

-- export/import -------------------------------------------------------------
local function rebuildLibraries()
        newState.modelLibrary = {}
        for _, list in pairs(newState.modelsByDepth) do
                for _, ref in ipairs(list) do
                        if not table.find(newState.modelLibrary, ref) then
                                table.insert(newState.modelLibrary, ref)
                        end
                end
        end
        newState.decoLibrary = {}
        if newState.overrides.decorations.enabled then
                for _, deco in ipairs(newState.overrides.decorations.types) do
                        if deco.models then
                                for _, ref in ipairs(deco.models) do
                                        if not table.find(newState.decoLibrary, ref) then
                                                table.insert(newState.decoLibrary, ref)
                                        end
                                end
                        end
                end
        end
end

local function applyAuthoring()
        rebuildLibraries()
        return {
                branches = newState.branches,
                assignments = newState.assignments,
                models = {
                        byDepth = newState.modelsByDepth,
                        decorations = (newState.overrides and newState.overrides.decorations and newState.overrides.decorations.enabled)
                                and newState.overrides.decorations.types
                                or nil,
                },
                overrides = newState.overrides,
        }
end

-- Trace the local utility for visibility across calls
applyAuthoring = FT.fn("Main.applyAuthoring", applyAuthoring)

function LoomDesigner.ExportAuthoring()
        return {
                branches = DC(newState.branches),
                assignments = DC(newState.assignments),
        }
end

function LoomDesigner.ImportAuthoring(cfg)
        cfg = cfg or {}
        newState.branches = DC(cfg.branches or {})
        newState.branches = select(1, FT.watchTable("newState.branches", newState.branches))
        newState.assignments = DC(cfg.assignments or {trunk = "", children = {}})
        newState.assignments = select(1, FT.watchTable("newState.assignments", newState.assignments))
        newState.assignments.children = select(
                1,
                FT.watchTable("newState.assignments.children", newState.assignments.children)
        )
        if next(newState.branches) == nil then
                newState.branches["branch1"] = {kind = "straight"}
                newState.assignments.trunk = "branch1"
        elseif not newState.assignments.trunk or newState.assignments.trunk == "" then
                for name in pairs(newState.branches) do
                        newState.assignments.trunk = name
                        break
                end
        end
end

LoomDesigner.ApplyAuthoring = applyAuthoring

function LoomDesigner.Reseed()
        newState.baseSeed = LoomDesigner.RandomizeSeed()
        LoomDesigner.RebuildPreview(nil)
        return newState.baseSeed
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

local function renderBranch(name, depth)
       local design = newState.branches[name]
       if not design then return end

       local cfgId = "__ld_preview_" .. tostring(name)
       LoomConfigs[cfgId] = {
               profiles = { [name] = design },
               branchAssignments = { trunkProfile = name },
               models = {
                       byDepth = newState.modelsByDepth,
                       decorations = (newState.overrides and newState.overrides.decorations and newState.overrides.decorations.enabled)
                               and newState.overrides.decorations.types
                               or nil,
               },
               growthDefaults = {},
       }

       GrowthVisualizer.Render(nil, {
               loomUid = 0,
               configId = cfgId,
               baseSeed = newState.baseSeed,
               g = newState.g,
               overrides = newState.overrides,
               scene = {
                       Clear = VisualScene.Clear,
                       Spawn = VisualScene.Spawn,
                       ResolveModel = ModelResolver.ResolveFromList,
               },
       })

       for _, child in ipairs(newState.assignments.children) do
               if child.parent == name then
                       for i = 1, child.count do
                               renderBranch(child.child, depth + 1)
                       end
               end
       end

       -- remove preview config after render to avoid leaks
       LoomConfigs[cfgId] = nil
end

function LoomDesigner.RebuildPreview(_container)
       if next(newState.branches) == nil then
               newState.branches["branch1"] = {kind = "straight"}
               newState.assignments.trunk = "branch1"
       elseif not newState.assignments.trunk or newState.assignments.trunk == "" or not newState.branches[newState.assignments.trunk] then
               for name in pairs(newState.branches) do
                       newState.assignments.trunk = name
                       break
               end
       end

       local parent = ensurePreviewParent()
       clearExistingPreview(parent)
       local model = Instance.new("Model")
       model.Name = "PreviewBranch"
       model.Parent = parent
       VisualScene.SetPreviewModel(model)

       if GrowthVisualizer and type(GrowthVisualizer.Release) == "function" then
               GrowthVisualizer.Release(nil, 0)
       end

       VisualScene.Clear()
       renderBranch(newState.assignments.trunk, 0)

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
                       name = "DebugSegment",
                       shape = Enum.PartType.Ball,
                       size = Vector3.new(0.8, 0.8, 0.8),
                       cframe = CFrame.new(0, 3, 0),
                       color = Color3.fromRGB(255, 0, 0),
                       anchored = true,
                       canCollide = false,
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

-- Wrap exported table so all public methods are traced
LoomDesigner = FT.traceTable("Main", LoomDesigner)

return LoomDesigner
