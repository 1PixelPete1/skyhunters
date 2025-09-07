--!strict

-- Event and interface contracts for Lanterns V2.
-- Mirrors Net.Functions / Net.Events to avoid string duplication.

local LanternEvents = {}

LanternEvents.Functions = {
    RF_DepositOil = "RF_DepositOil",
    RF_PlaceBaseLantern = "RF_PlaceBaseLantern",
    RF_RefillBaseLantern = "RF_RefillBaseLantern",
    RF_ToggleRunLantern = "RF_ToggleRunLantern",
}

LanternEvents.Events = {
    RE_OnLanternStatesBatch = "RE_OnLanternStatesBatch",
    RE_OnMinionScatter = "RE_OnMinionScatter",
    RE_OnRunTension = "RE_OnRunTension",
    RE_OnFlameChanged = "RE_OnFlameChanged",
}

return LanternEvents

