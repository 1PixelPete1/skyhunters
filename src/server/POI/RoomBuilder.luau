--!strict
-- RoomBuilder.luau
-- Constructs physical dungeon rooms from layout data

local RS = game:GetService("ReplicatedStorage")
local WorldConfig = require(RS.Config.WorldConfig)

local RoomBuilder = {}

local ROOM_SIZE = (WorldConfig.POI and WorldConfig.POI.ROOM_SIZE) or 30
local ROOM_HEIGHT = (WorldConfig.POI and WorldConfig.POI.ROOM_HEIGHT) or 15
local DOOR_W = (WorldConfig.POI and WorldConfig.POI.DOORWAY_WIDTH) or 8
local DOOR_H = (WorldConfig.POI and WorldConfig.POI.DOORWAY_HEIGHT) or 10
local WALL_T = (WorldConfig.POI and WorldConfig.POI.WALL_THICKNESS) or 2

local function part(name: string, size: Vector3, cframe: CFrame, mat: Enum.Material, color: Color3, anchored: boolean): Part
    local p = Instance.new("Part")
    p.Name = name
    p.Size = size
    p.CFrame = cframe
    p.Anchored = anchored
    p.Material = mat
    p.Color = color
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    return p
end

function RoomBuilder:BuildDungeon(layout: any, islandCFrame: CFrame)
    local model = Instance.new("Model")
    model.Name = "Dungeon"

    -- Build rooms
    for _, roomData in ipairs(layout.rooms or {}) do
        local room = self:_buildRoom(roomData, islandCFrame)
        room.Parent = model
    end

    -- Simple hallway connectors between adjacent rooms
    self:_buildHallways(model, layout)

    return model
end

function RoomBuilder:_buildRoom(roomData: any, islandCFrame: CFrame): Model
    local model = Instance.new("Model")
    model.Name = tostring(roomData.type or "Room")

    -- Position via grid
    local gx = (roomData.gridPos and roomData.gridPos.X) or 1
    local gy = (roomData.gridPos and roomData.gridPos.Y) or 1
    -- Place rooms slightly above terrain top for visibility on sky islands
    local gridOffset = Vector3.new((gx - 2.5) * ROOM_SIZE, 1, (gy - 2.5) * ROOM_SIZE)
    local baseCF = islandCFrame * CFrame.new(gridOffset)

    -- Floor
    local floor = part(
        "Floor",
        Vector3.new(ROOM_SIZE, 2, ROOM_SIZE),
        baseCF * CFrame.new(0, -1, 0),
        Enum.Material.Slate,
        Color3.fromRGB(60, 60, 60),
        true
    )
    floor.Parent = model

    -- Ceiling (optional)
    local ceiling = part(
        "Ceiling",
        Vector3.new(ROOM_SIZE, 2, ROOM_SIZE),
        baseCF * CFrame.new(0, ROOM_HEIGHT, 0),
        Enum.Material.Slate,
        Color3.fromRGB(40, 40, 40),
        true
    )
    ceiling.Transparency = 0.3
    ceiling.Parent = model

    -- Walls with doorways per exits
    self:_buildWalls(model, baseCF, roomData.exits or {})

    -- Simple decorations per type
    self:_decorate(model, roomData.type, baseCF)

    -- Attributes for hallway lookup
    model:SetAttribute("GridX", gx)
    model:SetAttribute("GridY", gy)

    return model
end

function RoomBuilder:_buildWalls(model: Model, baseCF: CFrame, exits: { [string]: boolean })
    local h = ROOM_HEIGHT

    local walls = {
        N = { size = Vector3.new(ROOM_SIZE, h, WALL_T), offset = Vector3.new(0, h * 0.5, ROOM_SIZE * 0.5) },
        S = { size = Vector3.new(ROOM_SIZE, h, WALL_T), offset = Vector3.new(0, h * 0.5, -ROOM_SIZE * 0.5) },
        E = { size = Vector3.new(WALL_T, h, ROOM_SIZE), offset = Vector3.new(ROOM_SIZE * 0.5, h * 0.5, 0) },
        W = { size = Vector3.new(WALL_T, h, ROOM_SIZE), offset = Vector3.new(-ROOM_SIZE * 0.5, h * 0.5, 0) },
    }

    for dir, w in pairs(walls) do
        if not exits[dir] then
            local wall = part(dir .. "_Wall", w.size, baseCF * CFrame.new(w.offset), Enum.Material.Cobblestone, Color3.fromRGB(100, 100, 100), true)
            wall.Parent = model
        else
            -- Doorway: split wall into left/right/top segments
            if dir == "N" or dir == "S" then
                local side = (ROOM_SIZE - DOOR_W) * 0.5
                local left = part(dir .. "_WallLeft", Vector3.new(side, h, w.size.Z), baseCF * CFrame.new(-ROOM_SIZE * 0.5 + side * 0.5, h * 0.5, w.offset.Z), Enum.Material.Cobblestone, Color3.fromRGB(100, 100, 100), true)
                local right = part(dir .. "_WallRight", Vector3.new(side, h, w.size.Z), baseCF * CFrame.new(ROOM_SIZE * 0.5 - side * 0.5, h * 0.5, w.offset.Z), Enum.Material.Cobblestone, Color3.fromRGB(100, 100, 100), true)
                local top = part(dir .. "_WallTop", Vector3.new(DOOR_W, math.max(0.5, h - DOOR_H), w.size.Z), baseCF * CFrame.new(0, DOOR_H * 0.5 + (h - DOOR_H) * 0.5, w.offset.Z), Enum.Material.Cobblestone, Color3.fromRGB(100, 100, 100), true)
                left.Parent = model; right.Parent = model; top.Parent = model
            else
                local side = (ROOM_SIZE - DOOR_W) * 0.5
                local left = part(dir .. "_WallLeft", Vector3.new(w.size.X, h, side), baseCF * CFrame.new(w.offset.X, h * 0.5, -ROOM_SIZE * 0.5 + side * 0.5), Enum.Material.Cobblestone, Color3.fromRGB(100, 100, 100), true)
                local right = part(dir .. "_WallRight", Vector3.new(w.size.X, h, side), baseCF * CFrame.new(w.offset.X, h * 0.5, ROOM_SIZE * 0.5 - side * 0.5), Enum.Material.Cobblestone, Color3.fromRGB(100, 100, 100), true)
                local top = part(dir .. "_WallTop", Vector3.new(w.size.X, math.max(0.5, h - DOOR_H), DOOR_W), baseCF * CFrame.new(w.offset.X, DOOR_H * 0.5 + (h - DOOR_H) * 0.5, 0), Enum.Material.Cobblestone, Color3.fromRGB(100, 100, 100), true)
                left.Parent = model; right.Parent = model; top.Parent = model
            end
        end
    end
end

function RoomBuilder:_decorate(model: Model, roomType: string?, baseCF: CFrame)
    local rt = roomType or ""
    if rt == "start" then
        local arch = part("EntranceArch", Vector3.new(12, 15, 3), baseCF * CFrame.new(0, 7, -ROOM_SIZE * 0.5 + 2), Enum.Material.Marble, Color3.fromRGB(163, 162, 165), true)
        arch.Parent = model
    elseif rt == "combat" then
        for i = 1, 3 do
            local ox = math.random(-10, 10)
            local oz = math.random(-10, 10)
            local cover = part("Cover" .. i, Vector3.new(4, 6, 4), baseCF * CFrame.new(ox, 3, oz), Enum.Material.Slate, Color3.fromRGB(60, 60, 60), true)
            cover.Parent = model
        end
    elseif rt == "elite" then
        local plat = part("ElitePlatform", Vector3.new(10, 3, 10), baseCF * CFrame.new(0, 1.5, 0), Enum.Material.Neon, Color3.fromRGB(255, 94, 19), true)
        plat.Parent = model
    elseif rt == "loot" then
        local chest = part("TreasureChest", Vector3.new(6, 4, 4), baseCF * CFrame.new(0, 2, 0), Enum.Material.Wood, Color3.fromRGB(98, 66, 43), true)
        chest.Parent = model
        local portal = Instance.new("Part")
        portal.Name = "ExitPortal"
        portal.Shape = Enum.PartType.Cylinder
        portal.Size = Vector3.new(0.5, 8, 8)
        portal.CFrame = baseCF * CFrame.new(0, 4, ROOM_SIZE * 0.5 - 3)
        portal.Material = Enum.Material.ForceField
        portal.BrickColor = BrickColor.new("Toothpaste")
        portal.Anchored = true
        portal.CanCollide = false
        portal.Parent = model
    end
end

local function findRoomModel(dungeonModel: Model, gx: number, gy: number): Model?
    for _, ch in ipairs(dungeonModel:GetChildren()) do
        if ch:GetAttribute("GridX") == gx and ch:GetAttribute("GridY") == gy then
            return ch :: any
        end
    end
    return nil
end

function RoomBuilder:_buildHallways(dungeonModel: Model, layout: any)
    for _, room in ipairs(layout.rooms or {}) do
        local gx = room.gridPos.X
        local gy = room.gridPos.Y
        local roomModel = findRoomModel(dungeonModel, gx, gy)
        if roomModel then
            for dir, has in pairs(room.exits or {}) do
                if has then
                    local agx = gx + ((dir == "E" and 1) or (dir == "W" and -1) or 0)
                    local agy = gy + ((dir == "N" and 1) or (dir == "S" and -1) or 0)
                    local other = findRoomModel(dungeonModel, agx, agy)
                    if other then
                        local name = string.format("Hallway_%d_%d_to_%d_%d", gx, gy, agx, agy)
                        if not dungeonModel:FindFirstChild(name) then
                            local hallway = Instance.new("Model")
                            hallway.Name = name
                            local a = (roomModel:FindFirstChild("Floor") :: BasePart).Position
                            local b = (other:FindFirstChild("Floor") :: BasePart).Position
                            local connector = part("Connector", Vector3.new(8, 2, 4), CFrame.new((a + b) * 0.5), Enum.Material.WoodPlanks, Color3.fromRGB(170, 85, 0), true)
                            connector.Parent = hallway
                            hallway.Parent = dungeonModel
                        end
                    end
                end
            end
        end
    end
end

return RoomBuilder
