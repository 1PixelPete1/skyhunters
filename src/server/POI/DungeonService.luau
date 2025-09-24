--!strict
-- DungeonService.luau
-- Main orchestrator for POI dungeon systems (server-authoritative)

local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")

local SafeRequire = require(RS.Shared.SafeRequire)
local CollectionService = game:GetService("CollectionService")

local function load(inst: Instance?)
    local r = SafeRequire.load(inst)
    if r.ok then return r.mod end
    return nil
end

local WorldConfig = require(RS.Config.WorldConfig)
local DungeonGenerator = load(script.Parent:FindFirstChild("DungeonGenerator"))
local RoomBuilder = load(script.Parent:FindFirstChild("RoomBuilder"))

local DungeonService = {}

-- [plotKey] -> state
local activeDungeons: { [string]: any } = {}

local function ensureContainer(): Folder
    local f = workspace:FindFirstChild("Dungeons")
    if not f then
        f = Instance.new("Folder")
        f.Name = "Dungeons"
        f.Parent = workspace
    end
    return f
end

function DungeonService:Init(_services: any?)
    ensureContainer()
end

-- Spawn a dungeon for a given plot at a world position with a deterministic seed
-- key: unique id for the dungeon (e.g., POI id)
function DungeonService:SpawnDungeonPOI(key: string, position: Vector3, seed: number)
    ensureContainer()
    if not DungeonGenerator or not RoomBuilder then
        warn("[DungeonService] Missing generator or builder; aborting spawn")
        return nil
    end

    local poiCfg = WorldConfig.POI or {}
    local gridSize = poiCfg.DUNGEON_GRID_SIZE or 4

    -- Deterministic per-plot seed
    local dungeonSeed = (seed or 0) + #key
    local maxRooms = (function()
        math.randomseed(dungeonSeed)
        local roll = math.random()
        if roll < 0.5 then return (poiCfg.MAX_ROOMS_SMALL or 3)
        elseif roll < 0.85 then return (poiCfg.MAX_ROOMS_MEDIUM or 5)
        else return (poiCfg.MAX_ROOMS_LARGE or 7) end
    end)()

    local layout = DungeonGenerator:GenerateLayout({
        seed = dungeonSeed,
        maxRooms = maxRooms,
        gridSize = gridSize,
    })

    local dungeonModel = RoomBuilder:BuildDungeon(layout, CFrame.new(position))
    dungeonModel.Name = "Dungeon_" .. tostring(key)
    dungeonModel.Parent = ensureContainer()
    CollectionService:AddTag(dungeonModel, "SkyIslandContent")
    dungeonModel:SetAttribute("IsConstellation", true)
    dungeonModel:SetAttribute("ConstellationType", "Dungeon")

    activeDungeons[key] = {
        layout = layout,
        model = dungeonModel,
        position = position,
        seed = dungeonSeed,
        cleared = false,
        lootClaimed = false,
    }

    return dungeonModel
end

return DungeonService
