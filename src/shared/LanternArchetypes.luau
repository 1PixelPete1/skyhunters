--!strict
-- LanternArchetypes.luau
-- Example archetype definitions for the dynamic lantern system

local Types = require(script.Parent.LanternTypes)

local function makeCurve(mu: number, sigma: number, lo: number?, hi: number?): Types.Curve
	return {
		mu = mu,
		sigma = sigma,
		lo = lo or mu - 3 * sigma,
		hi = hi or mu + 3 * sigma
	}
end

local function makeParam(mu: number, sigma: number, channel: ("shape"|"pose"|"look")?, locked: boolean?): Types.ParamSpec
	return {
		curve = makeCurve(mu, sigma),
		rng = not locked,
		value = locked and mu or nil,
		channel = channel
	}
end

-- Common decoration rules
local DECORATION_FLAG_TIP: Types.DecorationRule = {
	modelId = "FlagSmall",
	where = "Ends",
	mode = "WorldUpright",
	density = nil,
	jitter_deg = makeCurve(0, 5, -15, 15)
}

local DECORATION_CHIME_ALONG: Types.DecorationRule = {
	modelId = "ChimeSmall",
	where = "Along",
	mode = "Perpendicular",
	density = 0.3,
	jitter_deg = makeCurve(0, 3, -10, 10)
}

local DECORATION_CHARM_CENTER: Types.DecorationRule = {
	modelId = "CharmLeaf",
	where = "Center",
	mode = "LocalUpright",
	density = nil,
	jitter_deg = makeCurve(0, 2, -5, 5)
}

-- Branch profiles
local BRANCH_SIMPLE: Types.BranchProfile = {
	id = "simple_arm",
	max_children = 1,
	len_frac = makeCurve(0.4, 0.05, 0.3, 0.5),
	pitch_deg = makeCurve(-20, 10, -45, 0),
	yaw_deg = makeCurve(0, 30, -60, 60),
	inherit_rotation = false,
	jitter_deg = makeCurve(0, 2, -5, 5),
	decorations = {DECORATION_FLAG_TIP}
}

local BRANCH_ORNATE: Types.BranchProfile = {
	id = "ornate_arm",
	max_children = 2,
	len_frac = makeCurve(0.35, 0.08, 0.25, 0.45),
	pitch_deg = makeCurve(-30, 15, -60, 15),
	yaw_deg = makeCurve(0, 45, -90, 90),
	inherit_rotation = true,
	jitter_deg = makeCurve(0, 3, -8, 8),
	decorations = {DECORATION_FLAG_TIP, DECORATION_CHIME_ALONG}
}

-- Archetype: CommonA - simple lantern with minimal branches
local CommonA: Types.Archetype = {
	version = 1,
	-- Core params
	height = makeParam(12, 1.5, "shape"),
	bend_deg = makeParam(15, 5, "pose"),
	twist_deg = makeParam(0, 10, "pose"),
	tip_drop = makeParam(0.2, 0.05, "pose"),
	arm_len = makeParam(1.8, 0.3, "shape"),
	lantern_tilt = makeParam(5, 3, "pose"),
	lantern_yaw = makeParam(0, 15, "pose"),
	head_scale = makeParam(1.0, 0.1, "shape"),
	base_scale = makeParam(1.0, 0.1, "shape"),
	paint_wear = makeParam(0.3, 0.1, "look"),
	-- Weighted picks
	base_set = {["StoneDisk"] = 0.7, ["SquareBlock"] = 0.3},
	head_set = {["HeadA"] = 1.0},
	style_weights = {["straight"] = 0.5, ["scurve"] = 0.4, ["planar_spiral"] = 0.1},
	-- Branches
	branches = {
		origins = {
			base = {
				sockets = {"BaseTop"},
				profiles = {}
			},
			trunk_mid = {
				sockets = {"S1", "S2"},
				density = 0.3,
				profiles = {BRANCH_SIMPLE}
			},
			trunk_tip = {
				sockets = {"Tip"},
				profiles = {BRANCH_SIMPLE},
				require_one = true
			}
		},
		limits = {
			max_total_children = 3,
			max_depth = 1
		}
	}
}

-- Archetype: OrnateB - more decorative with multiple branches
local OrnateB: Types.Archetype = {
	version = 1,
	-- Core params
	height = makeParam(14, 2, "shape"),
	bend_deg = makeParam(20, 8, "pose"),
	twist_deg = makeParam(15, 10, "pose"),
	tip_drop = makeParam(0.25, 0.08, "pose"),
	arm_len = makeParam(2.2, 0.4, "shape"),
	lantern_tilt = makeParam(8, 5, "pose"),
	lantern_yaw = makeParam(0, 20, "pose"),
	head_scale = makeParam(1.1, 0.15, "shape"),
	base_scale = makeParam(1.2, 0.15, "shape"),
	paint_wear = makeParam(0.5, 0.15, "look"),
	-- Weighted picks
	base_set = {["StoneDisk"] = 0.4, ["SquareBlock"] = 0.4, ["Tripod"] = 0.2},
	head_set = {["HeadA"] = 1.0},
	style_weights = {["straight"] = 0.3, ["scurve"] = 0.5, ["planar_spiral"] = 0.15, ["helix"] = 0.05},
	-- Branches
	branches = {
		origins = {
			base = {
				sockets = {"BaseTop"},
				profiles = {BRANCH_SIMPLE}
			},
			trunk_mid = {
				sockets = {"S1", "S2"},
				density = 0.5,
				profiles = {BRANCH_ORNATE}
			},
			trunk_tip = {
				sockets = {"Tip"},
				profiles = {BRANCH_ORNATE},
				require_one = true
			}
		},
		limits = {
			max_total_children = 5,
			max_depth = 1
		}
	}
}

-- Archetype: TestSpiral - for testing spiral styles
local TestSpiral: Types.Archetype = {
	version = 1,
	-- Core params (some locked for testing)
	height = makeParam(10, 0, "shape", true), -- locked at 10
	bend_deg = makeParam(30, 10, "pose"),
	twist_deg = makeParam(180, 30, "pose"),
	tip_drop = makeParam(0.3, 0.1, "pose"),
	arm_len = makeParam(1.5, 0, "shape", true), -- locked at 1.5
	lantern_tilt = makeParam(0, 0, "pose", true), -- locked at 0
	lantern_yaw = makeParam(0, 0, "pose", true), -- locked at 0
	head_scale = makeParam(0.9, 0.05, "shape"),
	base_scale = makeParam(1.0, 0.05, "shape"),
	paint_wear = makeParam(0.2, 0.05, "look"),
	-- Weighted picks
	base_set = {["StoneDisk"] = 1.0},
	head_set = {["HeadA"] = 1.0},
	style_weights = {["planar_spiral"] = 0.7, ["helix"] = 0.3},
	-- Branches
	branches = {
		origins = {
			base = {
				sockets = {"BaseTop"},
				profiles = {}
			},
			trunk_mid = {
				sockets = {"S1", "S2"},
				density = 0.2,
				profiles = {BRANCH_SIMPLE}
			},
			trunk_tip = {
				sockets = {"Tip"},
				profiles = {BRANCH_SIMPLE},
				require_one = false
			}
		},
		limits = {
			max_total_children = 2,
			max_depth = 1
		}
	}
}

-- Export module
local Archetypes = {
	CommonA = CommonA,
	OrnateB = OrnateB,
	TestSpiral = TestSpiral
}

return Archetypes
