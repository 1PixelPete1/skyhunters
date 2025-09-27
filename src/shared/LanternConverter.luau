--!strict
-- LanternConverter.luau
-- Converts between Designer and Runtime archetype formats

local Types = require(script.Parent.LanternTypes)

local LanternConverter = {}

-- Convert Designer archetype to Runtime archetype
function LanternConverter.designerToRuntime(designer: Types.DesignerArchetype): Types.Archetype
	-- Helper to convert DesignerParamSpec to ParamSpec
	local function convertParam(designerParam: Types.DesignerParamSpec): Types.ParamSpec
		if designerParam.locked then
			-- Locked param: Use exact value
			return {
				curve = {
					mu = designerParam.value,
					sigma = 0,
					lo = designerParam.value,
					hi = designerParam.value
				},
				rng = false,
				value = designerParam.value,
				channel = designerParam.channel
			}
		else
			-- Unlocked param: Create a curve with reasonable variance
			local sigma = math.abs(designerParam.value) * 0.1  -- 10% variance
			return {
				curve = {
					mu = designerParam.value,
					sigma = sigma,
					lo = designerParam.value - sigma * 3,
					hi = designerParam.value + sigma * 3
				},
				rng = true,
				value = nil,
				channel = designerParam.channel
			}
		end
	end
	
	-- Convert all params
	local runtime: Types.Archetype = {
		version = designer.version,
		
		-- Core params
		height = convertParam(designer.height),
		bend_deg = convertParam(designer.bend_deg),
		twist_deg = convertParam(designer.twist_deg),
		tip_drop = convertParam(designer.tip_drop),
		arm_len = convertParam(designer.arm_len),
		lantern_tilt = convertParam(designer.lantern_tilt),
		lantern_yaw = convertParam(designer.lantern_yaw),
		head_scale = convertParam(designer.head_scale),
		base_scale = convertParam(designer.base_scale),
		paint_wear = convertParam(designer.paint_wear),
		
		-- Convert explicit choices to weighted sets
		base_set = {[designer.base_model] = 1.0},
		head_set = {[designer.head_model] = 1.0},
		
		-- Convert explicit style to weights (100% chosen style)
		style_weights = {[designer.style] = 1.0},
		
		-- Copy branches as-is
		branches = designer.branches
	}
	
	return runtime
end

-- Convert Runtime archetype to Designer archetype (for editing)
function LanternConverter.runtimeToDesigner(runtime: Types.Archetype, chosenStyle: string?): Types.DesignerArchetype
	-- Helper to convert ParamSpec to DesignerParamSpec
	local function convertParam(runtimeParam: Types.ParamSpec): Types.DesignerParamSpec
		local value = runtimeParam.value or runtimeParam.curve.mu
		local locked = runtimeParam.value ~= nil or not runtimeParam.rng
		
		return {
			value = value,
			locked = locked,
			channel = runtimeParam.channel
		}
	end
	
	-- Pick style (use first weighted or provided)
	local style = chosenStyle or "straight"
	if not chosenStyle then
		for styleName, weight in pairs(runtime.style_weights) do
			if weight > 0 then
				style = styleName
				break
			end
		end
	end
	
	-- Pick base/head models (use first weighted)
	local baseModel = "StoneDisk"
	for name, weight in pairs(runtime.base_set) do
		if weight > 0 then
			baseModel = name
			break
		end
	end
	
	local headModel = "HeadA"
	for name, weight in pairs(runtime.head_set) do
		if weight > 0 then
			headModel = name
			break
		end
	end
	
	-- Convert to designer format
	local designer: Types.DesignerArchetype = {
		version = runtime.version,
		style = style,
		
		-- Core params
		height = convertParam(runtime.height),
		bend_deg = convertParam(runtime.bend_deg),
		twist_deg = convertParam(runtime.twist_deg),
		tip_drop = convertParam(runtime.tip_drop),
		arm_len = convertParam(runtime.arm_len),
		lantern_tilt = convertParam(runtime.lantern_tilt),
		lantern_yaw = convertParam(runtime.lantern_yaw),
		head_scale = convertParam(runtime.head_scale),
		base_scale = convertParam(runtime.base_scale),
		paint_wear = convertParam(runtime.paint_wear),
		
		-- Explicit model choices
		base_model = baseModel,
		head_model = headModel,
		
		-- Style-specific params (extract from archetype if needed)
		style_params = nil,  -- TODO: Extract from specific archetypes
		
		-- Copy branches as-is
		branches = runtime.branches
	}
	
	return designer
end

-- Validate archetype structure
function LanternConverter.validate(archetype: Types.Archetype | Types.DesignerArchetype): (boolean, string?)
	-- Check version
	if not archetype.version or archetype.version < 1 then
		return false, "Invalid or missing version"
	end
	
	-- Check required params exist
	local requiredParams = {
		"height", "bend_deg", "twist_deg", "tip_drop", "arm_len",
		"lantern_tilt", "lantern_yaw", "head_scale", "base_scale", "paint_wear"
	}
	
	for _, param in ipairs(requiredParams) do
		if not archetype[param] then
			return false, "Missing required param: " .. param
		end
	end
	
	-- Type-specific validation
	if archetype.style then
		-- Designer archetype
		local validStyles = {straight = true, scurve = true, planar_spiral = true, helix = true}
		if not validStyles[archetype.style] then
			return false, "Invalid style: " .. tostring(archetype.style)
		end
	elseif archetype.style_weights then
		-- Runtime archetype
		local totalWeight = 0
		for _, weight in pairs(archetype.style_weights) do
			totalWeight = totalWeight + weight
		end
		if totalWeight <= 0 then
			return false, "style_weights sum to zero or negative"
		end
	else
		return false, "Archetype must have either 'style' or 'style_weights'"
	end
	
	return true, nil
end

-- Create a mutation of an archetype (for procedural variation)
function LanternConverter.mutate(
	archetype: Types.Archetype, 
	mutationStrength: number,
	seed: number
): Types.Archetype
	-- Clone archetype
	local mutated = table.clone(archetype)
	
	-- Simple mutation: Adjust curve parameters
	local rng = Random.new(seed)
	
	local function mutateParam(param: Types.ParamSpec, strength: number): Types.ParamSpec
		if param.rng and not param.value then
			local sigmaMult = 1 + (rng:NextNumber() - 0.5) * strength
			local muShift = param.curve.sigma * (rng:NextNumber() - 0.5) * strength
			
			return {
				curve = {
					mu = param.curve.mu + muShift,
					sigma = param.curve.sigma * sigmaMult,
					lo = param.curve.lo,
					hi = param.curve.hi
				},
				rng = param.rng,
				value = param.value,
				channel = param.channel
			}
		end
		return param
	end
	
	-- Mutate parameters
	mutated.height = mutateParam(archetype.height, mutationStrength)
	mutated.bend_deg = mutateParam(archetype.bend_deg, mutationStrength)
	mutated.twist_deg = mutateParam(archetype.twist_deg, mutationStrength)
	-- ... etc for other params
	
	return mutated
end

return LanternConverter
