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
            kind = "spiral",
            yawStep = 28,
            yawVar = 6,
            pitchBias = 6,
            pitchVar = 2,
            rollBias = 0,
            rollVar = 2,
            zigzagStep = 30,
            curveRate = 10,
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
            kind = "curved",
            yawStep = 0,
            yawVar = 4,
            pitchBias = 10,
            pitchVar = 3,
            rollBias = 0,
            rollVar = 1,
            curveRate = 8,
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
}

return configs
