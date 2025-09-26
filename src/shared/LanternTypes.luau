--!strict
-- LanternTypes.luau
-- Type definitions for the dynamic lantern system

export type Curve = {
	mu: number,
	sigma: number,
	lo: number,
	hi: number
}

export type ParamSpec = {
	curve: Curve,
	rng: boolean,
	value: number?,
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

export type Archetype = {
	version: number,
	-- core params (size/pose/look)
	height: ParamSpec,
	bend_deg: ParamSpec,
	twist_deg: ParamSpec,
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

return nil
