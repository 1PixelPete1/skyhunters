--[[
    RoomLibrary.luau
    Defines room prefab types and their available variations
    Used by DungeonGenerator for room selection
]]

local RoomLibrary = {}

-- Room type definitions
local ROOM_TYPES = {
    start = {
        "basic_start",
        "columned_start",
        "ceremonial_start"
    },
    combat = {
        "open_arena",
        "pillared_arena", 
        "scattered_cover",
        "multi_level",
        "corner_alcoves"
    },
    elite = {
        "central_platform",
        "elevated_throne",
        "ritual_circle",
        "champion_arena"
    },
    puzzle = {
        "pressure_plates",
        "lantern_sequence",
        "timed_switches",
        "maze_section",
        "bridge_crossing"
    },
    loot = {
        "treasure_chamber",
        "vault_room",
        "shrine_reward",
        "portal_exit"
    }
}

-- Special room requirements (for future expansion)
local ROOM_REQUIREMENTS = {
    -- start rooms always need south exit (entrance)
    start = {
        requiredExits = {"S"}
    },
    -- loot rooms need at least one exit but could be dead ends
    loot = {
        allowDeadEnd = true
    },
    -- elite rooms prefer central placement
    elite = {
        preferCentral = true
    }
}

-- Room difficulty scaling
local ROOM_DIFFICULTY = {
    start = 0,
    combat = 1,
    puzzle = 2,
    elite = 3,
    loot = 1
}

function RoomLibrary:GetPrefabsForType(roomType: string): {string}
    return ROOM_TYPES[roomType] or {"basic_room"}
end

function RoomLibrary:GetRoomRequirements(roomType: string): any
    return ROOM_REQUIREMENTS[roomType] or {}
end

function RoomLibrary:GetRoomDifficulty(roomType: string): number
    return ROOM_DIFFICULTY[roomType] or 1
end

function RoomLibrary:GetAllRoomTypes(): {string}
    local types = {}
    for roomType, _ in pairs(ROOM_TYPES) do
        table.insert(types, roomType)
    end
    return types
end

function RoomLibrary:ValidateRoomConfiguration(roomType: string, exits: {[string]: boolean}): boolean
    local requirements = self:GetRoomRequirements(roomType)
    
    -- Check required exits
    if requirements.requiredExits then
        for _, requiredExit in ipairs(requirements.requiredExits) do
            if not exits[requiredExit] then
                return false
            end
        end
    end
    
    -- Check if room can be a dead end
    if not requirements.allowDeadEnd then
        local exitCount = 0
        for _, hasExit in pairs(exits) do
            if hasExit then exitCount = exitCount + 1 end
        end
        if exitCount < 1 then
            return false
        end
    end
    
    return true
end

-- For future expansion: prefab metadata
function RoomLibrary:GetPrefabMetadata(prefabId: string)
    -- This would eventually load from room prefab models
    -- For now, return basic metadata
    return {
        id = prefabId,
        size = Vector3.new(40, 20, 40), -- matches WorldConfig
        decorationLevel = "basic",
        lightingStyle = "dungeon"
    }
end

return RoomLibrary