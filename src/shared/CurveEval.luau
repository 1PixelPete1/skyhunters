--!strict
-- CurveEval.luau
-- Centerline generators and adaptive sampling for lantern poles

export type CurveFn = (s: number, H: number, opts: any) -> Vector3
export type Sample = { p: Vector3, t: Vector3 } -- position + tangent

local CurveEval = {}

-- Curve functions (parameterized by s in [0,1], total height H)

-- Straight vertical pole
function CurveEval.straight(s: number, H: number, opts: any): Vector3
	return Vector3.new(0, s * H, 0)
end

-- S-curve with bend
function CurveEval.scurve(s: number, H: number, opts: {bend_deg: number, twist_deg: number, tip_drop: number, min_lateral: number?, height: number?}): Vector3
	local bend_deg = opts.bend_deg or 15
	local bend_rad = math.rad(bend_deg)
	local twist_total = math.rad(opts.twist_deg or 0)
	local tip_drop = opts.tip_drop or 0.2
	local referenceHeight = opts.height or H
	
	-- Ensure the lateral swing remains visible even on short poles
	local baseAmplitude = referenceHeight * math.sin(math.clamp(bend_rad, 0, math.rad(80))) * 0.5
	local minAmplitude = opts.min_lateral or 1.25
	local amplitude = math.max(baseAmplitude, minAmplitude)
	
	-- Smooth S-curve profile
	local bend_profile = math.sin(s * math.pi) * bend_rad
	local lateral = math.sin(bend_profile) * amplitude
	
	-- Apply progressive twist about the vertical axis
	local twist_angle = s * twist_total
	local cosTwist = math.cos(twist_angle)
	local sinTwist = math.sin(twist_angle)

	local x = cosTwist * lateral
	local z = sinTwist * lateral

	-- Vertical progression with optional tip drop
	local y = s * H * (1 - tip_drop * s * s)

	return Vector3.new(x, y, z)
end

-- Planar spiral
function CurveEval.planar_spiral(s: number, H: number, opts: {twist_deg: number, radius_factor: number?, radius_min: number?, height: number?}): Vector3
	local twist_rad = math.rad(opts.twist_deg or 180)
	local referenceHeight = opts.height or H
	local radius_factor = opts.radius_factor or 0.12
	local min_radius = opts.radius_min or 1.5

	-- Grow radius in relation to height so the silhouette reads even on short poles
	local targetRadius = math.max(referenceHeight * radius_factor, min_radius)
	local angle = s * twist_rad
	local radius = targetRadius * (s ^ 0.85)

	local x = math.cos(angle) * radius
	local z = math.sin(angle) * radius
	local y = s * H

	return Vector3.new(x, y, z)
end

-- 3D helix
function CurveEval.helix(s: number, H: number, opts: {twist_deg: number, radius: number?, pitch: number?, radius_min: number?, height: number?}): Vector3
	local twist_rad = math.rad(opts.twist_deg or 360)
	local referenceHeight = opts.height or H
	local min_radius = opts.radius_min or 1.5
	local radius = opts.radius or (referenceHeight * 0.1)
	radius = math.max(radius, min_radius)

	-- Maintain overall height while allowing optional pitch scaling
	local pitch_scale = opts.pitch or 1.0
	local angle = s * twist_rad
	local x = math.cos(angle) * radius
	local z = math.sin(angle) * radius
	local y = s * H * pitch_scale

	return Vector3.new(x, y, z)
end

-- Map of style names to curve functions
local CURVE_STYLES = {
	["straight"] = CurveEval.straight,
	["scurve"] = CurveEval.scurve,
	["planar_spiral"] = CurveEval.planar_spiral,
	["helix"] = CurveEval.helix
}

-- Get curve function by style name
function CurveEval.getCurveFunction(style: string): CurveFn?
	return CURVE_STYLES[style]
end

-- Compute tangent via finite difference
local function computeTangent(curve: CurveFn, s: number, H: number, opts: any, ds: number): Vector3
	ds = ds or 0.001
	local s1 = math.max(0, s - ds)
	local s2 = math.min(1, s + ds)
	
	local p1 = curve(s1, H, opts)
	local p2 = curve(s2, H, opts)
	
	local tangent = (p2 - p1) / (s2 - s1)
	return tangent.Unit
end

-- Adaptive sampling based on curvature
function CurveEval.evalAdaptive(
	curve: CurveFn, 
	H: number, 
	opts: any, 
	tau: number,     -- tolerance in studs (default 0.08)
	kMin: number,    -- minimum segments
	kMax: number     -- maximum segments
): {Sample}
	tau = tau or 0.08
	kMin = kMin or 3
	kMax = kMax or 8
	
	local samples = {}
	local lastY: number? = nil
	
	-- Helper to add a sample
	local function addSample(s: number)
		local p = curve(s, H, opts)
		if lastY and p.Y < lastY then
			p = Vector3.new(p.X, lastY + 0.0005, p.Z)
		end
		local t = computeTangent(curve, s, H, opts, 0.001)
		if t.Y <= 0 then
			t = Vector3.new(t.X, math.abs(t.Y) + 0.0005, t.Z)
			t = if t.Magnitude > 0 then t.Unit else Vector3.new(0, 1, 0)
		end
		lastY = p.Y
		table.insert(samples, { p = p, t = t })
	end
	
	-- Start with uniform sampling at minimum resolution
	local initialSamples = {}
	for i = 0, kMin do
		local s = i / kMin
		table.insert(initialSamples, s)
	end
	
	-- Adaptive refinement
	local function refine(samples: {number}, depth: number): {number}
		if depth <= 0 or #samples >= kMax then
			return samples
		end
		
		local refined = {}
		table.insert(refined, samples[1])
		
		for i = 2, #samples do
			local s0 = samples[i - 1]
			local s1 = samples[i]
			local sMid = (s0 + s1) / 2
			
			-- Compute points
			local p0 = curve(s0, H, opts)
			local p1 = curve(s1, H, opts)
			local pMid = curve(sMid, H, opts)
			
			-- Check deviation from straight line
			local straight = p0 + (p1 - p0) * 0.5
			local deviation = (pMid - straight).Magnitude
			
			-- Add midpoint if deviation exceeds tolerance
			if deviation > tau and #refined < kMax - (#samples - i) then
				table.insert(refined, sMid)
			end
			
			table.insert(refined, s1)
		end
		
		-- Recursively refine if we added points
		if #refined > #samples then
			return refine(refined, depth - 1)
		else
			return refined
		end
	end
	
	-- Perform adaptive refinement
	local maxDepth = 3
	local refinedParams = refine(initialSamples, maxDepth)
	
	-- Ensure we don't exceed kMax
	if #refinedParams > kMax + 1 then
		-- Resample to kMax segments
		refinedParams = {}
		for i = 0, kMax do
			table.insert(refinedParams, i / kMax)
		end
	end
	
	-- Generate final samples
	for _, s in ipairs(refinedParams) do
		addSample(s)
	end
	
	return samples
end

-- Utility: compute total arc length of sampled curve
function CurveEval.computeArcLength(samples: {Sample}): number
	local length = 0
	for i = 2, #samples do
		local dist = (samples[i].p - samples[i-1].p).Magnitude
		length = length + dist
	end
	return length
end

-- Utility: get interpolated point along samples at normalized parameter t
function CurveEval.interpolate(samples: {Sample}, t: number): Sample
	t = math.clamp(t, 0, 1)
	
	if #samples < 2 then
		return samples[1] or { p = Vector3.zero, t = Vector3.yAxis }
	end
	
	-- Handle edge cases
	if t <= 0 then return samples[1] end
	if t >= 1 then return samples[#samples] end
	
	-- Find segment
	local totalSegments = #samples - 1
	local scaledT = t * totalSegments
	local segmentIndex = math.floor(scaledT) + 1
	local localT = scaledT - math.floor(scaledT)
	
	-- Clamp segment index
	segmentIndex = math.clamp(segmentIndex, 1, #samples - 1)
	
	local s0 = samples[segmentIndex]
	local s1 = samples[segmentIndex + 1]
	
	-- Linear interpolation
	local p = s0.p:Lerp(s1.p, localT)
	local tangent = s0.t:Lerp(s1.t, localT).Unit
	
	return { p = p, t = tangent }
end

return CurveEval
