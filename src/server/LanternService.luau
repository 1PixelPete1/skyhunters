--!strict
-- LanternService: placement + restore using LanternModelKit and SaveService helpers

local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local CS = game:GetService("CollectionService")

local Remotes = RS:FindFirstChild("Remotes") or Instance.new("Folder")
Remotes.Name = "Remotes"; Remotes.Parent = RS

local PondFieldService = require(SSS:WaitForChild("Server"):WaitForChild("PondFieldService"))
local PondFieldMath = require(RS.Shared.PondFieldMath)
local PondNetworkService = require(SSS:WaitForChild("Systems"):WaitForChild("PondNetworkService"))
local SaveStore = require(SSS:WaitForChild("Server"):WaitForChild("LanternSaveStore"))
local LanternModelKit = require(RS.Shared.LanternModelKit)

local LanternService = {}

local function ensurePlotLanternFolder(plotKey: string): Folder
    local plots = workspace:FindFirstChild("Plots") or Instance.new("Folder")
    plots.Name = "Plots"; plots.Parent = workspace
    local plotFolder = plots:FindFirstChild(plotKey) or Instance.new("Folder")
    plotFolder.Name = plotKey; plotFolder.Parent = plots
    local f = plotFolder:FindFirstChild("Lanterns") or Instance.new("Folder")
    f.Name = "Lanterns"; f.Parent = plotFolder
    return f
end

local function makeId(plotKey: string, pos: Vector3, yaw: number): string
    return string.format("lan|%s|%.2f|%.2f|%.2f|%.3f", plotKey, pos.X, pos.Y, pos.Z, yaw)
end

function LanternService.ApplyPlacement(player: Player, plotKey: string, worldPos: Vector3, yaw: number?): (boolean, string?)
    if type(plotKey) ~= "string" or typeof(worldPos) ~= "Vector3" then
        return false, "BAD_PARAMS"
    end
    -- Use pond network SDF to gate placement (oil connectivity); allow ring around ponds
    local pos2 = Vector2.new(worldPos.X, worldPos.Z)
    if not PondFieldMath.isInside(pos2, PondNetworkService.getSnapshot(), 1.25) then
        return false, "OUT_OF_BOUNDS"
    end

    local yawR = yaw or 0
    local cf = CFrame.new(worldPos) * CFrame.Angles(0, yawR, 0)
    local build = LanternModelKit.Build(cf, { seed = 0, segments = 2 })
    local model = build.model
    local folder = ensurePlotLanternFolder(plotKey)
    model.Parent = folder
    CS:AddTag(model, "Lantern")
    model:SetAttribute("LanternId", makeId(plotKey, worldPos, yawR))
    model:SetAttribute("PlotKey", plotKey)
    model:SetAttribute("Flame", 0)

    -- Persist
    SaveStore.upsertLantern({
        id = model:GetAttribute("LanternId"),
        pk = "lantern_basic",
        p = { worldPos.X, worldPos.Y, worldPos.Z },
        r = { 0, yawR, 0 },
        t = os.time(),
        u = player.UserId,
        seed = 0,
        seg = build.meta.segments,
    })

    print(string.format("[Lantern] place ok id=%s pk=%s pos=(%.1f,%.1f,%.1f)", model:GetAttribute("LanternId"), "lantern_basic", worldPos.X, worldPos.Y, worldPos.Z))
    return true, model:GetAttribute("LanternId")
end

function LanternService.RestoreForPlot(plotKey: string, plotModel: Instance)
    local folder = ensurePlotLanternFolder(plotKey)
    folder:ClearAllChildren()
    local items = SaveStore.loadLanternsForPlot(plotKey)
    local count = 0
    for _, rec in ipairs(items) do
        if type(rec) == "table" and type(rec.id) == "string" then
            local p = rec.p
            local r = rec.r
            local pos = Vector3.new(p[1] or 0, p[2] or 0, p[3] or 0)
            local yaw = r[2] or 0
            local cf = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
            local build = LanternModelKit.Build(cf, { seed = rec.seed or 0, segments = rec.seg or 2 })
            build.model.Parent = folder
            CS:AddTag(build.model, "Lantern")
            build.model:SetAttribute("LanternId", rec.id)
            build.model:SetAttribute("PlotKey", plotKey)
            build.model:SetAttribute("Flame", 0)
            count += 1
        end
    end
    print(string.format("[Lantern] restore count=%d pk=%s", count, plotKey))
end

return LanternService
