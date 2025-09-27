--!strict
-- LanternTypes.luau (FIXED)
-- Type definitions for the dynamic lantern system

export type Curve = {
	mu: number,
	sigma: number,
	lo: number,
	hi: number
}

-- FIXED: Separate ParamSpec for designer vs runtime
export type ParamSpec = {
	curve: Curve,
	rng: boolean,
	value: number?,
	channel: ("shape" | "pose" | "look")?
}

-- FIXED: Designer param spec (explicit values, no weights)
export type DesignerParamSpec = {
	value: number,
	locked: boolean,
	channel: ("shape" | "pose" | "look")?
}

export type DecorationMode = "Perpendicular" | "LocalUpright" | "WorldUpright" | "TangentAligned"

export type DecorationRule = {
	modelId: string,                     -- e.g. "FlagSmall"
	where: "Along" | "Ends" | "Center",  -- placement class
	mode: DecorationMode,
	density: number?,                     -- for Along (0..1 probability per segment)
	jitter_deg: Curve?,                   -- small random tilt
}

export type BranchProfile = {
	id: string,
	max_children: number,                 -- cap children branching off THIS branch
	len_frac: Curve,                      -- child length vs parent last segment
	pitch_deg: Curve,                     -- local pitch from parent tangent
	yaw_deg: Curve,                       -- local yaw around parent tangent
	inherit_rotation: boolean,            -- adopt parent last segment frame first
	jitter_deg: Curve?,                   -- extra small random rotation
	decorations: {DecorationRule}?,       -- per-branch decor
}

export type BranchSpec = {
	origins: {
		base: { sockets: {string}, profiles: {BranchProfile} },
		trunk_mid: { sockets: {string}, density: number, profiles: {BranchProfile} },
		trunk_tip: { sockets: {string}, profiles: {BranchProfile}, require_one: boolean },
	},
	limits: { max_total_children: number, max_depth: number },
}

-- FIXED: Runtime archetype (with style_weights for probabilistic choices)
export type Archetype = {
	version: number,
	-- core params (size/pose/look)
	height: ParamSpec,
	bend_deg: ParamSpec,
	twist_deg: ParamSpec,        -- FIXED: Only for curve plane yaw (initial rotation)
	tip_drop: ParamSpec,
	arm_len: ParamSpec,
	lantern_tilt: ParamSpec,
	lantern_yaw: ParamSpec,
	head_scale: ParamSpec,
	base_scale: ParamSpec,
	paint_wear: ParamSpec,
	-- weighted picks
	base_set: {[string]: number},  -- "StoneDisk"=0.6, "SquareBlock"=0.3 ...
	head_set: {[string]: number},  -- "HeadA"=1.0 for now
	-- style picks (straight/scurve/spiral/helix)
	style_weights: {[string]: number},
	branches: BranchSpec,
}

-- FIXED: Designer archetype (explicit style choice, no weights)
export type DesignerArchetype = {
	version: number,
	style: "straight" | "scurve" | "planar_spiral" | "helix",  -- Explicit choice
	-- core params (explicit values)
	height: DesignerParamSpec,
	bend_deg: DesignerParamSpec,
	twist_deg: DesignerParamSpec,
	tip_drop: DesignerParamSpec,
	arm_len: DesignerParamSpec,
	lantern_tilt: DesignerParamSpec,
	lantern_yaw: DesignerParamSpec,
	head_scale: DesignerParamSpec,
	base_scale: DesignerParamSpec,
	paint_wear: DesignerParamSpec,
	-- explicit picks
	base_model: string,
	head_model: string,
	-- style-specific params (conditionally visible)
	style_params: {
		spiral_radius_factor: number?,
		helix_radius: number?,
		helix_pitch: number?,
	}?,
	branches: BranchSpec,
}

-- FIXED: UI dependency rules for conditional visibility
export type UIVisibilityRule = {
	param: string,
	visibleIf: {
		style: {"straight" | "scurve" | "planar_spiral" | "helix"}?,
		anyCondition: boolean?,
	}
}

-- FIXED: RNG control state per parameter
export type RNGControlState = {
	locked: boolean,
	channel: "shape" | "pose" | "look",
	currentValue: number
}

return nil
