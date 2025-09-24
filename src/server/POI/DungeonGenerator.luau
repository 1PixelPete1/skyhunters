--[[
    DungeonGenerator.luau
    Grid-based dungeon layout generation with room connectivity
]]

local DungeonGenerator = {}

local RoomLibrary = require(script.Parent.RoomLibrary)

type Room = {
    type: string,
    gridPos: Vector2,
    rotation: number,
    exits: {[string]: boolean}, -- N/E/S/W
    prefabId: string,
    id: string
}

type Layout = {
    rooms: {Room},
    gridSize: number,
    startRoom: Room?,
    endRoom: Room?,
    seed: number
}

local function generateRoomId(): string
    return "room_" .. tostring(math.random(100000, 999999))
end

function DungeonGenerator:GenerateLayout(params): Layout
    local seed = params.seed or tick()
    local maxRooms = params.maxRooms or 5
    local gridSize = params.gridSize or 4
    
    math.randomseed(seed)
    
    local layout: Layout = {
        rooms = {},
        gridSize = gridSize,
        startRoom = nil,
        endRoom = nil,
        seed = seed
    }
    
    local grid = {} -- [x][y] = room or nil
    for x = 1, gridSize do
        grid[x] = {}
    end
    
    -- Place start room at center-bottom
    local startPos = Vector2.new(math.floor(gridSize/2) + 1, 1)
    local startRoom = self:_createRoom("start", startPos, seed)
    grid[startPos.X][startPos.Y] = startRoom
    layout.startRoom = startRoom
    table.insert(layout.rooms, startRoom)
    
    -- Expansion frontier using breadth-first approach
    local frontier = {startRoom}
    local roomCount = 1
    
    -- Main path generation
    while roomCount < maxRooms and #frontier > 0 do
        local currentRoom = table.remove(frontier, math.random(#frontier))
        local possibleExpansions = self:_getPossibleExpansions(
            currentRoom, grid, gridSize
        )
        
        if #possibleExpansions > 0 then
            -- Pick 1-2 expansions for branching, weighted towards fewer branches early
            local maxExpansions = roomCount < maxRooms * 0.4 and 1 or 2
            local numExpansions = math.random(1, math.min(maxExpansions, #possibleExpansions))
            
            for i = 1, numExpansions do
                if roomCount >= maxRooms then break end
                
                local expansion = table.remove(
                    possibleExpansions, 
                    math.random(#possibleExpansions)
                )
                
                -- Determine room type based on progression
                local roomType = self:_selectRoomType(roomCount, maxRooms, seed + roomCount)
                local newRoom = self:_createRoom(roomType, expansion.pos, seed + roomCount)
                
                -- Connect rooms bidirectionally
                currentRoom.exits[expansion.direction] = true
                newRoom.exits[self:_oppositeDir(expansion.direction)] = true
                
                grid[expansion.pos.X][expansion.pos.Y] = newRoom
                table.insert(layout.rooms, newRoom)
                table.insert(frontier, newRoom)
                roomCount = roomCount + 1
                
                -- Mark as end room if last
                if roomCount == maxRooms then
                    newRoom.type = "loot"
                    layout.endRoom = newRoom
                end
            end
        end
    end
    
    -- Ensure we have an end room
    if not layout.endRoom and #layout.rooms > 1 then
        layout.rooms[#layout.rooms].type = "loot"
        layout.endRoom = layout.rooms[#layout.rooms]
    end
    
    -- Validate the layout
    if not self:_validateLayout(layout) then
        warn("[DungeonGenerator] Generated invalid layout, attempting repair")
        self:_repairLayout(layout)
    end
    
    return layout
end

function DungeonGenerator:_createRoom(type: string, gridPos: Vector2, roomSeed: number): Room
    math.randomseed(roomSeed)
    local prefabs = RoomLibrary:GetPrefabsForType(type)
    return {
        type = type,
        gridPos = gridPos,
        rotation = math.random(0, 3) * 90,
        exits = {},
        prefabId = prefabs[math.random(#prefabs)],
        id = generateRoomId()
    }
end

function DungeonGenerator:_getPossibleExpansions(room: Room, grid, gridSize)
    local expansions = {}
    local directions = {
        {dir = "N", offset = Vector2.new(0, 1)},
        {dir = "E", offset = Vector2.new(1, 0)},
        {dir = "S", offset = Vector2.new(0, -1)},
        {dir = "W", offset = Vector2.new(-1, 0)}
    }
    
    for _, data in ipairs(directions) do
        local newPos = room.gridPos + data.offset
        
        -- Check bounds
        if newPos.X >= 1 and newPos.X <= gridSize and
           newPos.Y >= 1 and newPos.Y <= gridSize then
            -- Check if empty
            if not grid[newPos.X][newPos.Y] then
                table.insert(expansions, {
                    pos = newPos,
                    direction = data.dir
                })
            end
        end
    end
    
    return expansions
end

function DungeonGenerator:_selectRoomType(currentCount: number, maxRooms: number, roomSeed: number): string
    math.randomseed(roomSeed)
    local progress = currentCount / maxRooms
    
    -- Early rooms: mostly combat
    if progress < 0.3 then
        return "combat"
    -- Middle rooms: mix of combat and puzzle
    elseif progress < 0.6 then
        return math.random() < 0.7 and "combat" or "puzzle"
    -- Late rooms: elite encounters and final loot
    elseif progress < 0.9 then
        return math.random() < 0.4 and "elite" or "combat"
    else
        return "loot"
    end
end

function DungeonGenerator:_oppositeDir(dir: string): string
    local opposites = {N = "S", S = "N", E = "W", W = "E"}
    return opposites[dir]
end

function DungeonGenerator:_validateLayout(layout: Layout): boolean
    -- Check that all rooms are connected
    if #layout.rooms == 0 then return false end
    
    local visited = {}
    local function dfs(room: Room)
        if visited[room.id] then return end
        visited[room.id] = true
        
        -- Find connected rooms
        for direction, hasExit in pairs(room.exits) do
            if hasExit then
                local adjacentPos = self:_getAdjacentGridPos(room.gridPos, direction)
                local adjacentRoom = self:_findRoomByGridPos(layout.rooms, adjacentPos)
                if adjacentRoom and not visited[adjacentRoom.id] then
                    dfs(adjacentRoom)
                end
            end
        end
    end
    
    -- Start DFS from start room
    if layout.startRoom then
        dfs(layout.startRoom)
    end
    
    -- Check if all rooms were visited
    for _, room in ipairs(layout.rooms) do
        if not visited[room.id] then
            return false
        end
    end
    
    return true
end

function DungeonGenerator:_repairLayout(layout: Layout)
    -- Simple repair: ensure start room has at least one exit
    if layout.startRoom and next(layout.startRoom.exits) == nil then
        layout.startRoom.exits["N"] = true
        
        -- Find room to north and connect back
        local northPos = layout.startRoom.gridPos + Vector2.new(0, 1)
        local northRoom = self:_findRoomByGridPos(layout.rooms, northPos)
        if northRoom then
            northRoom.exits["S"] = true
        end
    end
end

function DungeonGenerator:_getAdjacentGridPos(gridPos: Vector2, direction: string): Vector2
    local offsets = {
        N = Vector2.new(0, 1),
        S = Vector2.new(0, -1),
        E = Vector2.new(1, 0),
        W = Vector2.new(-1, 0)
    }
    return gridPos + (offsets[direction] or Vector2.new(0, 0))
end

function DungeonGenerator:_findRoomByGridPos(rooms: {Room}, gridPos: Vector2): Room?
    for _, room in ipairs(rooms) do
        if room.gridPos.X == gridPos.X and room.gridPos.Y == gridPos.Y then
            return room
        end
    end
    return nil
end

-- Debug utility
function DungeonGenerator:DebugPrintLayout(layout: Layout)
    print("=== Dungeon Layout Debug ===")
    print("Grid Size:", layout.gridSize)
    print("Total Rooms:", #layout.rooms)
    print("Seed:", layout.seed)
    
    for _, room in ipairs(layout.rooms) do
        local exits = {}
        for dir, hasExit in pairs(room.exits) do
            if hasExit then table.insert(exits, dir) end
        end
        print(string.format("Room %s (%s) at (%d,%d) - Exits: [%s]", 
            room.id, room.type, room.gridPos.X, room.gridPos.Y, table.concat(exits, ",")))
    end
end

return DungeonGenerator