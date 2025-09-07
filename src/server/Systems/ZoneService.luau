--!strict

-- ZoneService: server-authoritative safe-zone membership
-- Tags: CollectionService tag "SafeZone" on invisible Parts (Box/Sphere)
-- Attributes on each ZonePart:
--   ZoneId: string
--   Priority: number (default 0)
--   Shape: "Box"|"Sphere" (optional; infer from Part shape if absent)

local ZoneService = {}

-- Dependencies to require (leave as TODOs/wires):
-- local CollectionService = game:GetService("CollectionService")
-- local Players = game:GetService("Players")
-- local RunService = game:GetService("RunService")
-- local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- local Net = require(ReplicatedStorage.Shared.Net)

-- Config (symbolic; read later from LanternShared or a ZoneShared if preferred)
ZoneService.Config = {
    MovementRecheckInterval = 0.5,        -- seconds (base)
    FastSpeedThreshold = 40,              -- studs/sec
    FastRecheckInterval = 0.2,            -- seconds when fast
    CellSize = 128,                       -- spatial grid cell size
    EnterLeaveDebounce = 0.1,             -- seconds
}

-- Runtime state (stubs)
-- ZoneService._grid : cellKey -> { ZonePart }
-- ZoneService._playerState[player] = { lastPos:Vector3, zoneId:string?, lastChange:number }
-- ZoneService._zoneMembers[zoneId] = { [player] = true }

-- Public API (stubs)
function ZoneService.Start()
    -- TODO: index all ZoneParts by grid cell; connect addition/removal signals
    -- TODO: hook Touched/TouchEnded on ZoneParts (server-side) targeting humanoid root parts
    -- TODO: start a stepped loop that revalidates players based on movement distance & interval
end

-- Utility: returns nearest top-priority zoneId containing pos, or nil
function ZoneService.FindContainingZoneIdForPosition(worldPos: Vector3): string?
    -- TODO: grid lookup -> candidate parts -> containment math -> choose by Priority then distance
    return nil
end

-- Internal: enter/leave transitions (server â†’ client event)
function ZoneService._SetPlayerZone(player: Player, zoneId: string?)
    -- TODO: debounce rapid churn using EnterLeaveDebounce
    -- TODO: update _playerState and _zoneMembers
    -- TODO: Net:GetEvent("RE_OnSafeZoneChanged"):FireClient(player, { inZone = zoneId ~= nil, zoneId = zoneId })
end

return ZoneService

