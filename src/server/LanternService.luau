--!strict
-- LanternService: placement + restore using LanternModelKit and SaveService helpers

local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local CS = game:GetService("CollectionService")
local Shared = RS:WaitForChild("Shared")
local Config = RS:WaitForChild("Config")


local Remotes = RS:FindFirstChild("Remotes") or Instance.new("Folder")
Remotes.Name = "Remotes"; Remotes.Parent = RS

local SafeRequire = require(Shared:WaitForChild("SafeRequire"))
local function load(inst: Instance?)
    local r = SafeRequire.load(inst)
    if r.ok then return r.mod end
    warn("[LanternService] require failed for", r.path or "[nil]", r.reason or "unknown")
    return nil
end

local PondFieldService = load(SSS:WaitForChild("Server"):WaitForChild("PondFieldService"))
local PondFieldMath = require(Shared:WaitForChild("PondFieldMath"))
local PondNetworkService = load(SSS:WaitForChild("Systems"):WaitForChild("PondNetworkService"))
local SaveStore = load(SSS:WaitForChild("Server"):WaitForChild("LanternSaveStore"))
local LanternModelKit = require(Shared:WaitForChild("LanternModelKit"))
local RunService = game:GetService("RunService")
local WorldConfig = require(Config:WaitForChild("WorldConfig"))

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

function LanternService.ApplyPlacement(player: Player, plotKey: string, worldPos: Vector3, yaw: number?, presetKey: string?): (boolean, string?)
    if type(plotKey) ~= "string" or typeof(worldPos) ~= "Vector3" then
        warn("[LanternService] ApplyPlacement - Invalid parameters:", plotKey, worldPos)
        return false, "BAD_PARAMS"
    end
    
    print(string.format("[LanternService] ApplyPlacement called - plotKey=%s, pos=(%.1f,%.1f,%.1f)", plotKey, worldPos.X, worldPos.Y, worldPos.Z))
    
    -- Use pond network SDF to gate placement (oil connectivity); allow ring around ponds
    local pos2 = Vector2.new(worldPos.X, worldPos.Z)
    local snapshot = PondNetworkService.getSnapshot()
    if not snapshot then
        warn("[LanternService] Could not get pond network snapshot")
        return false, "NETWORK_ERROR"
    end
    
    if not PondFieldMath.isInside(pos2, snapshot, 1.25) then
        print("[LanternService] Position out of bounds")
        return false, "OUT_OF_BOUNDS"
    end

    local yawR = yaw or 0
    local cf = CFrame.new(worldPos) * CFrame.Angles(0, yawR, 0)
    
    -- Get lantern type from preset configuration
    local actualPresetKey = presetKey or "lantern_basic"
    local presetConfig = WorldConfig.ISLANDS.Presets[actualPresetKey]
    if not presetConfig then
        warn("[LanternService] Unknown preset key: " .. tostring(actualPresetKey) .. ", falling back to lantern_basic")
        actualPresetKey = "lantern_basic"
        presetConfig = WorldConfig.ISLANDS.Presets[actualPresetKey]
    end
    
    local lanternType = presetConfig.LanternType or "Default"
    
    local ok, build = pcall(function()
        return LanternModelKit.Build(cf, { seed = 0, segments = 2, lanternType = lanternType })
    end)
    
    if not ok or not build or not build.model then
        warn("[LanternService] Failed to build lantern model:", build)
        return false, "BUILD_FAILED"
    end
    
    local model = build.model
    local folder = ensurePlotLanternFolder(plotKey)
    model.Parent = folder
    CS:AddTag(model, "Lantern")
    
    local lanternId = makeId(plotKey, worldPos, yawR)
    model:SetAttribute("LanternId", lanternId)
    model:SetAttribute("PlotKey", plotKey)
    model:SetAttribute("Flame", 0)

    -- Persist
    local saveOk, saveErr = pcall(function()
        SaveStore.upsertLantern({
            id = lanternId,
            pk = actualPresetKey, -- Use actual preset key instead of hardcoded
            p = { worldPos.X, worldPos.Y, worldPos.Z },
            r = { 0, yawR, 0 },
            t = os.time(),
            u = player.UserId,
            seed = 0,
            seg = build.meta and build.meta.segments or 2,
            lanternType = lanternType, -- NEW: save lantern type for restoration
        })
    end)
    
    if not saveOk then
        warn("[LanternService] Failed to save lantern:", saveErr)
        -- Don't fail placement for save errors, but log it
    end

    print(string.format("[Lantern] place ok id=%s pk=%s pos=(%.1f,%.1f,%.1f)", lanternId, "lantern_basic", worldPos.X, worldPos.Y, worldPos.Z))
    return true, lanternId
end

local LANTERNS_PER_FRAME = 1

function LanternService.RestoreForPlot(plotKey: string, plotModel: Instance)
    local folder = ensurePlotLanternFolder(plotKey)
    folder:ClearAllChildren()
    local items = SaveStore.loadLanternsForPlot(plotKey)
    local count = 0
    local placedThisFrame = 0
    for _, rec in ipairs(items) do
        if type(rec) == "table" and type(rec.id) == "string" then
            local p = rec.p
            local r = rec.r
            local pos = Vector3.new(p[1] or 0, p[2] or 0, p[3] or 0)
            local yaw = r[2] or 0
            local cf = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
            
            -- Determine lantern type from saved data or preset
            local lanternType = rec.lanternType
            if not lanternType then
                -- Fallback: get from preset key
                local presetKey = rec.pk or "lantern_basic"
                local presetConfig = WorldConfig.ISLANDS.Presets[presetKey]
                lanternType = (presetConfig and presetConfig.LanternType) or "Default"
            end
            
            local build = LanternModelKit.Build(cf, { 
                seed = rec.seed or 0, 
                segments = rec.seg or 2,
                lanternType = lanternType
            })
            build.model.Parent = folder
            CS:AddTag(build.model, "Lantern")
            placedThisFrame += 1
            if placedThisFrame >= LANTERNS_PER_FRAME then
                placedThisFrame = 0
                RunService.Heartbeat:Wait()
            end
            build.model:SetAttribute("LanternId", rec.id)
            build.model:SetAttribute("PlotKey", plotKey)
            build.model:SetAttribute("Flame", 0)
            build.model:SetAttribute("PresetKey", rec.pk or "lantern_basic") -- NEW: store preset for client reference
            count += 1
        end
    end
    print(string.format("[Lantern] restore count=%d pk=%s", count, plotKey))
end

return LanternService

