--!strict

local RequireUtil = require(script.Parent.RequireUtil)

local GrowthVisualizer
local okGV, modGV = pcall(function()
    return RequireUtil.fromRelative(script.Parent.Parent, {"growth","GrowthVisualizer"})
        or RequireUtil.fromReplicatedStorage({"growth","GrowthVisualizer"})
end)
if okGV then
    GrowthVisualizer = modGV
end

local VisualScene = require(script.Parent.VisualScene)
local ModelResolver = require(script.Parent.ModelResolver)

local LoomConfigs
local okLC, modLC = pcall(function()
    return RequireUtil.fromRelative(script.Parent.Parent, {"looms","LoomConfigs"})
        or RequireUtil.fromReplicatedStorage({"looms","LoomConfigs"})
end)
if okLC and modLC then
    LoomConfigs = modLC
else
    LoomConfigs = {}
end

local previewProfile = { kind = "straight", params = {} }

local GrowthStylesCore = {}

function GrowthStylesCore.SetKind(kind: string)
    previewProfile.kind = kind
    previewProfile.params = {}
end

function GrowthStylesCore.SetParam(key: string, value: number)
    previewProfile.params[key] = value
end

function GrowthStylesCore.GetParam(key: string)
    return previewProfile.params[key]
end

function GrowthStylesCore.GetProfile()
    return previewProfile
end

local function ensureContainer()
    local folder = workspace:FindFirstChild("LS_PreviewCore")
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = "LS_PreviewCore"
        folder.Parent = workspace
    end
    folder:ClearAllChildren()
    local model = Instance.new("Model")
    model.Name = "PreviewStyle"
    model.Parent = folder
    VisualScene.SetPreviewModel(model)
end

function GrowthStylesCore.ApplyPreview()
    ensureContainer()

    if GrowthVisualizer and type(GrowthVisualizer.Render) == "function" then
        local design = { kind = previewProfile.kind }
        for k, v in pairs(previewProfile.params) do
            design[k] = v
        end
        local cfgId = "__gsc_preview"
        LoomConfigs[cfgId] = {
            profiles = { preview = design },
            branchAssignments = { trunkProfile = "preview" },
            models = { byDepth = {}, decorations = nil },
            growthDefaults = {},
        }
        GrowthVisualizer.Render(nil, {
            loomUid = 0,
            configId = cfgId,
            baseSeed = 12345,
            g = 100,
            overrides = {},
            scene = {
                Clear = VisualScene.Clear,
                Spawn = VisualScene.Spawn,
                ResolveModel = ModelResolver.ResolveFromList,
            },
        })
        LoomConfigs[cfgId] = nil
    else
        local cf = CFrame.new()
        for _ = 1, 5 do
            VisualScene.Spawn({
                class = "Part",
                shape = "Block",
                size = Vector3.new(1, 1, 2),
                cframe = cf,
                anchored = true,
                canCollide = false,
                material = Enum.Material.SmoothPlastic,
                color = Color3.new(1, 1, 1),
            })
            cf = cf * CFrame.new(0, 0, 2)
        end
    end
end

return GrowthStylesCore
