-- ProfileTemplate_M0.lua
-- Data structure additions for M0

local ProfileTemplate = {
    -- Existing data
    Gold = 0,
    Level = 1,
    Experience = 0,
    
    -- M0 Additions
    Plots = {
        -- [plotId] = {
        --     Lanterns = {
        --         [lanternId] = {
        --             ModelId = "lantern_basic",
        --             Position = {X = 0, Y = 0, Z = 0},
        --             Rarity = 1,
        --             Stats = {
        --                 GenerationRate = 0.1,
        --                 Range = 50,
        --                 Brightness = 1
        --             }
        --         }
        --     },
        --     ReservoirSnapshot = 0, -- Last saved reservoir amount
        --     LastSaveTime = 0 -- For offline generation calculation
        -- }
    },
    
    -- Statistics for UI/progression
    TotalResourceSold = 0,
    TotalGoldEarned = 0
}

return ProfileTemplate