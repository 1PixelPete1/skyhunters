--!strict
-- OilReservoirService: placement + restore using OilReservoirModelKit

local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local CS = game:GetService("CollectionService")

local Remotes = RS:FindFirstChild("Remotes") or Instance.new("Folder")
Remotes.Name = "Remotes"; Remotes.Parent = RS

local OilReservoirModelKit = require(RS.Shared.OilReservoirModelKit)
local WorldConfig = require(RS.Config.WorldConfig)
local SaveStore = require(SSS:WaitForChild("Server"):WaitForChild("OilReservoirSaveStore"))

local OilReservoirService = {}

local function ensurePlotReservoirFolder(plotKey: string): Folder
    local plots = workspace:FindFirstChild("Plots") or Instance.new("Folder")
    plots.Name = "Plots"; plots.Parent = workspace
    local plotFolder = plots:FindFirstChild(plotKey) or Instance.new("Folder")
    plotFolder.Name = plotKey; plotFolder.Parent = plots
    local f = plotFolder:FindFirstChild("OilReservoirs") or Instance.new("Folder")
    f.Name = "OilReservoirs"; f.Parent = plotFolder
    return f
end

local function makeId(plotKey: string, pos: Vector3, reservoirSize: string): string
    return string.format("res|%s|%.2f|%.2f|%.2f|%s", plotKey, pos.X, pos.Y, pos.Z, reservoirSize)
end

function OilReservoirService.ApplyPlacement(player: Player, plotKey: string, worldPos: Vector3, presetKey: string?): (boolean, string?)
    if type(plotKey) ~= "string" or typeof(worldPos) ~= "Vector3" then
        warn("[OilReservoirService] ApplyPlacement - Invalid parameters:", plotKey, worldPos)
        return false, "BAD_PARAMS"
    end
    
    print(string.format("[OilReservoirService] ApplyPlacement called - plotKey=%s, pos=(%.1f,%.1f,%.1f)", plotKey, worldPos.X, worldPos.Y, worldPos.Z))
    
    -- Get reservoir configuration from preset
    local actualPresetKey = presetKey or "oil_reservoir_small"
    local presetConfig = WorldConfig.ISLANDS.Presets[actualPresetKey]
    if not presetConfig or presetConfig.PlaceableType ~= "OilReservoir" then
        warn("[OilReservoirService] Invalid or non-reservoir preset key: " .. tostring(actualPresetKey))
        return false, "INVALID_PRESET"
    end
    
    local reservoirSize = presetConfig.ReservoirSize or "small"
    local capacity = presetConfig.OilCapacity or 25
    
    -- Basic surface validation (simpler than lanterns - just needs to be on terrain)
    local origin = worldPos + Vector3.new(0, 200, 0)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Whitelist
    params.FilterDescendantsInstances = { workspace.Terrain }
    params.IgnoreWater = true
    
    local hit = workspace:Raycast(origin, Vector3.new(0, -500, 0), params)
    if not hit or hit.Instance ~= workspace.Terrain then
        return false, "BAD_SURFACE"
    end
    
    -- Check for minimum spacing from other reservoirs (6 studs)
    local MIN_SPACING = 6.0
    for _, inst in CS:GetTagged("OilReservoir") do
        if inst:IsA("Model") and inst.PrimaryPart then
            if (inst.PrimaryPart.Position - worldPos).Magnitude < MIN_SPACING then
                return false, "TOO_CLOSE"
            end
        end
    end
    
    local cf = CFrame.new(worldPos)
    
    local ok, build = pcall(function()
        return OilReservoirModelKit.Build(cf, { 
            seed = 0, 
            size = reservoirSize,
            capacity = capacity
        })
    end)
    
    if not ok or not build or not build.model then
        warn("[OilReservoirService] Failed to build reservoir model:", build)
        return false, "BUILD_FAILED"
    end
    
    local model = build.model
    local folder = ensurePlotReservoirFolder(plotKey)
    model.Parent = folder
    CS:AddTag(model, "OilReservoir")
    
    local reservoirId = makeId(plotKey, worldPos, reservoirSize)
    model:SetAttribute("ReservoirId", reservoirId)
    model:SetAttribute("PlotKey", plotKey)
    model:SetAttribute("PresetKey", actualPresetKey)
    model:SetAttribute("OilCapacity", capacity)

    -- Persist via SaveStore (DataStore-backed)
    SaveStore.upsertReservoir({
        id = reservoirId,
        pk = actualPresetKey,
        p = { worldPos.X, worldPos.Y, worldPos.Z },
        size = reservoirSize,
        capacity = capacity,
        t = os.time(),
        u = player.UserId,
    })

    print(string.format("[OilReservoir] place ok id=%s pk=%s pos=(%.1f,%.1f,%.1f) capacity=%d", reservoirId, actualPresetKey, worldPos.X, worldPos.Y, worldPos.Z, capacity))
    
    -- Update plot oil capacity
    local OilService = require(SSS:WaitForChild("Server"):WaitForChild("OilService"))
    if OilService and OilService.addCapacityForPlot then
        OilService.addCapacityForPlot(plotKey, capacity)
    end
    
    return true, reservoirId
end

function OilReservoirService.RestoreForPlot(plotKey: string, plotModel: Instance)
    local folder = ensurePlotReservoirFolder(plotKey)
    folder:ClearAllChildren()
    
    local items = SaveStore.loadReservoirsForPlot(plotKey)
    local count = 0
    local totalCapacity = 0
    
    for _, rec in ipairs(items) do
        if type(rec) == "table" and type(rec.id) == "string" then
            local p = rec.p
            local pos = Vector3.new(p[1] or 0, p[2] or 0, p[3] or 0)
            local cf = CFrame.new(pos)
            
            local build = OilReservoirModelKit.Build(cf, { 
                seed = 0,
                size = rec.size or "small",
                capacity = rec.capacity or 25
            })
            
            build.model.Parent = folder
            CS:AddTag(build.model, "OilReservoir")
            build.model:SetAttribute("ReservoirId", rec.id)
            build.model:SetAttribute("PlotKey", plotKey)
            build.model:SetAttribute("PresetKey", rec.pk or "oil_reservoir_small")
            build.model:SetAttribute("OilCapacity", rec.capacity or 25)
            
            count += 1
            totalCapacity += rec.capacity or 25
        end
    end
    
    -- Update plot oil capacity
    local OilService = require(SSS:WaitForChild("Server"):WaitForChild("OilService"))
    if OilService and OilService.setCapacityForPlot then
        OilService.setCapacityForPlot(plotKey, totalCapacity)
    end
    
    print(string.format("[OilReservoir] restore count=%d totalCapacity=%d pk=%s", count, totalCapacity, plotKey))
end

-- Remove reservoir and update capacity
function OilReservoirService.RemoveReservoir(player: Player, reservoirId: string): (boolean, string?)
    if type(reservoirId) ~= "string" then
        return false, "BAD_PARAMS"
    end
    
    -- Find and remove from workspace
    local removed = false
    local removedCapacity = 0
    local plotKey = ""
    
    for _, inst in CS:GetTagged("OilReservoir") do
        if inst:GetAttribute("ReservoirId") == reservoirId then
            removedCapacity = inst:GetAttribute("OilCapacity") or 0
            plotKey = inst:GetAttribute("PlotKey") or ""
            inst:Destroy()
            removed = true
            break
        end
    end
    
    if not removed then
        return false, "NOT_FOUND"
    end
    
    -- Remove from save store
    SaveStore.removeReservoir(reservoirId)
    
    -- Update plot oil capacity
    local OilService = require(SSS:WaitForChild("Server"):WaitForChild("OilService"))
    if OilService and OilService.removeCapacityForPlot then
        OilService.removeCapacityForPlot(plotKey, removedCapacity)
    end
    
    print(string.format("[OilReservoir] removed id=%s capacity=%d pk=%s", reservoirId, removedCapacity, plotKey))
    return true, nil
end

return OilReservoirService
