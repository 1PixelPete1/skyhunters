--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NetFolder = ReplicatedStorage:WaitForChild("Net")
local Remotes = NetFolder:WaitForChild("Remotes")

local Net = {}

-- Bump when changing any remote payload shape
Net.CONTRACT_VERSION = 1

Net.Functions = {
    -- Pond/Lanterns contracts
    RF_ClaimPond = "RF_ClaimPond",
    RF_DepositOil = "RF_DepositOil",
    RF_PlaceBaseLantern = "RF_PlaceBaseLantern",
    RF_RefillBaseLantern = "RF_RefillBaseLantern",
    RF_ToggleRunLantern = "RF_ToggleRunLantern",
    RF_ApplyBaseLantern = "RF_ApplyBaseLantern",
    RF_StartVoyage = "RF_StartVoyage",
}

Net.Events = {
    -- Lanterns & related
    RE_OnLanternStatesBatch = "RE_OnLanternStatesBatch",
    RE_OnMinionScatter = "RE_OnMinionScatter",
    RE_OnRunTension = "RE_OnRunTension",
    RE_OnFlameChanged = "RE_OnFlameChanged",
    RE_OnSafeZoneChanged = "RE_OnSafeZoneChanged",
    RE_OnCrowdDescriptor = "RE_OnCrowdDescriptor",
}

function Net:GetEvent(name: string): RemoteEvent
    return (Remotes:WaitForChild(name) :: any) :: RemoteEvent
end

function Net:GetFunction(name: string): RemoteFunction
    return (Remotes:WaitForChild(name) :: any) :: RemoteFunction
end

return Net
