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
function CurveEval.scurve(s: number, H: number, opts: {bend_deg: number, twist_deg: number, tip_drop: number}): Vector3
	local bend_rad = math.rad(opts.bend_deg or 15)
	local twist_rad = math.rad(opts.twist_deg or 0)
	local tip_drop = opts.tip_drop or 0.2
	
	-- S-curve profile (smooth transition)
	local bend_profile = math.sin(s * math.pi) * bend_rad
	local twist_angle = s * twist_rad
	
	-- Apply bend in XZ plane
	local x = math.sin(bend_profile) * H * 0.15  -- scale bend amplitude
	local z = math.cos(twist_angle) * x
	x = math.sin(twist_angle) * x
	
	-- Vertical with tip drop
	local y = s * H * (1 - tip_drop * s * s)
	
	return Vector3.new(x, y, z)
end

-- Planar spiral
function CurveEval.planar_spiral(s: number, H: number, opts: {twist_deg: number, radius_factor: number?}): Vector3
	local twist_rad = math.rad(opts.twist_deg or 180)
	local radius_factor = opts.radius_factor or 0.1
	
	-- Spiral outward as we go up
	local angle = s * twist_rad
	local radius = s * H * radius_factor
	
	local x = math.cos(angle) * radius
	local z = math.sin(angle) * radius
	local y = s * H
	
	return Vector3.new(x, y, z)
end

-- 3D helix
function CurveEval.helix(s: number, H: number, opts: {twist_deg: number, radius: number?, pitch: number?}): Vector3
	local twist_rad = math.rad(opts.twist_deg or 360)
	local radius = opts.radius or (H * 0.08)
	local pitch = opts.pitch or 1.0
	
	local angle = s * twist_rad
	local x = math.cos(angle) * radius
	local z = math.sin(angle) * radius
	local y = s * H * pitch
	
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
	
	-- Helper to add a sample
	local function addSample(s: number)
		local p = curve(s, H, opts)
		local t = computeTangent(curve, s, H, opts, 0.001)
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
