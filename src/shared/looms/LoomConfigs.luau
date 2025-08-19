--!strict
-- Shared Loom configuration defaults used by GrowthService and GrowthVisualizer.
-- Designers author these via the LoomDesigner plugin. Runtime code may override
-- any numeric field but should not mutate this table directly.

-- This file intentionally avoids type annotations so that it can be executed by
-- the plain Lua interpreter used in unit tests.

local configs = {
    tree_basic = {
        id = "tree_basic",
        uiName = "Basic Tree",
        growthDefaults = {
            segmentCount = 24,
            branchDepthMax = 3,
            branchSpawnChance = 0.45,
            segmentScaleJitter = { length = 0.15, thickness = 0.10 },
            relativeScaleTie = 0.8,
            forkSpacingN = 3,
            forkLimitPerDepth = 2,
        },
        profileDefaults = {
            kind = "curved",
            amplitudeDeg = 28,
            frequency = 1,
            curvature = 1,
            rollBias = 0,
            zigzagEvery = 1,
            sigmoidK = 6,
            sigmoidMid = 0.5,
            chaoticR = 3.9,
            randomChaos = 10,
            continuity = "accumulate",
            childInherit = 0.8,
        },
        models = {
            byDepth = {
                [0] = { "model_trunk_A", "model_trunk_B" },
                [1] = { "model_branch_A", "model_branch_B" },
                [2] = { "model_twig_A" },
                terminal = { "model_leafCluster_A", "model_leafCluster_B" },
            },
            decorations = {
                {
                    models = { "leaf_small_A", "leaf_small_B" },
                    placement = "tip",
                    rotation = "upright",
                    density = 0.6,
                    minDepth = 2,
                    maxDepth = 3,
                    maxPerChain = 6,
                },
                {
                    models = { "thorn_A" },
                    placement = "spiral",
                    rotation = "inherit",
                    density = 0.25,
                    minDepth = 1,
                    maxDepth = 2,
                },
            },
        },
        nodes = {
            mode = "rules",
            tipsOnly = true,
            minDepth = 1,
            excludeDepths = {0},
            undersideOnly = false,
            spacingN = 0,
            chancePerEligible = 0.35,
            serverAuthoritative = true,
        },
    },

    -- Simple cactus/vine style plant for testing variety.
    cactus_vine = {
        id = "cactus_vine",
        uiName = "Cactus Vine",
        growthDefaults = {
            segmentCount = 12,
            branchDepthMax = 1,
            branchSpawnChance = 0.1,
            segmentScaleJitter = { length = 0.05, thickness = 0.05 },
            relativeScaleTie = 0.9,
            forkSpacingN = 0,
            forkLimitPerDepth = 1,
        },
        profileDefaults = {
            kind = "straight",
            amplitudeDeg = 10,
            rollBias = 0,
            zigzagEvery = 1,
            sigmoidK = 6,
            sigmoidMid = 0.5,
            chaoticR = 3.9,
            randomChaos = 2,
            continuity = "accumulate",
            childInherit = 0.9,
        },
        models = {
            byDepth = {
                [0] = { "model_cactusStem_A" },
                terminal = { "model_cactusFlower_A" },
            },
            decorations = {
                {
                    models = { "spike_A" },
                    placement = "radial",
                    rotation = "inherit",
                    density = 0.4,
                    minDepth = 0,
                    maxDepth = 0,
                },
            },
        },
        nodes = {
            mode = "rules",
            tipsOnly = true,
            minDepth = 0,
            excludeDepths = {},
            undersideOnly = false,
            spacingN = 0,
            chancePerEligible = 0.2,
            serverAuthoritative = true,
        },
    },

    branch_demo = {
        id = "branch_demo",
        uiName = "Branch Demo",
        growthDefaults = {
            branchDepthMax = 2,
            segmentScaleJitter = { length = 0.1, thickness = 0.1 },
        },
        profiles = {
            trunk = {
                kind = "curved",
                amplitudeDeg = 28,
                frequency = 1,
                curvature = 1,
                childInherit = 0.8,
                segmentCountMode = "normal",
                segmentCountMean = 24,
                segmentCountSd = 2,
                segmentCountMin = 20,
                segmentCountMax = 28,
            },
            branchA = {
                kind = "zigzag",
                amplitudeDeg = 14,
                zigzagEvery = 1,
                childInherit = 0.7,
                segmentCountMode = "triangular",
                segmentCountModeN = 10,
                segmentCountMin = 8,
                segmentCountMax = 14,
            },
            branchB = {
                kind = "sigmoid",
                amplitudeDeg = 16,
                sigmoidK = 7,
                childInherit = 0.6,
                segmentCountMode = "biased",
                segmentCountBias = 1.25,
                segmentCountMin = 8,
                segmentCountMax = 16,
            },
        },
        branchAssignments = {
            trunkProfile = "trunk",
            perDepth = {
                [0] = { {name="branchA", chance=0.6}, {name="branchB", chance=0.4} },
                [1] = { {name="branchA", chance=1.0} },
            },
            spacingN    = { [0] = 3, [1] = 2 },
            maxPerDepth = { [0] = 2, [1] = 2, [2] = 3 },
        },
    },
}

-- Utility for plugin authoring: shallow function to clone tables
local function deepCopy(v)
    if type(v) ~= "table" then return v end
    local c = {}
    for k, val in pairs(v) do
        c[k] = deepCopy(val)
    end
    return c
end

configs._deepCopy = deepCopy

return configs
