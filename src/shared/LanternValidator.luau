--!strict
-- LanternValidator.luau
-- Validation and warning system for lantern configurations

local Types = require(script.Parent.LanternTypes)

local LanternValidator = {}

export type ValidationResult = {
	valid: boolean,
	errors: {string},
	warnings: {string}
}

-- Validate an archetype and return issues
function LanternValidator.validateArchetype(archetype: Types.Archetype | Types.DesignerArchetype): ValidationResult
	local result: ValidationResult = {
		valid = true,
		errors = {},
		warnings = {}
	}
	
	-- Check version
	if not archetype.version or archetype.version < 1 then
		table.insert(result.errors, "Invalid or missing version")
		result.valid = false
	end
	
	-- Check required params
	local requiredParams = {
		"height", "bend_deg", "twist_deg", "tip_drop", "arm_len",
		"lantern_tilt", "lantern_yaw", "head_scale", "base_scale", "paint_wear"
	}
	
	for _, param in ipairs(requiredParams) do
		if not archetype[param] then
			table.insert(result.errors, "Missing required param: " .. param)
			result.valid = false
		end
	end
	
	-- Get style (Designer vs Runtime)
	local styles = {}
	if archetype.style then
		-- Designer archetype - single style
		table.insert(styles, archetype.style)
	elseif archetype.style_weights then
		-- Runtime archetype - multiple weighted styles
		for style, weight in pairs(archetype.style_weights) do
			if weight > 0 then
				table.insert(styles, style)
			end
		end
	end
	
	-- Check for WorldUpright decorations in spiral/helix styles
	if archetype.branches then
		for _, style in ipairs(styles) do
			if style == "planar_spiral" or style == "helix" then
				-- Check all branch profiles
				local function checkProfiles(profiles: {Types.BranchProfile})
					for _, profile in ipairs(profiles) do
						if profile.decorations then
							for _, decor in ipairs(profile.decorations) do
								if decor.mode == "WorldUpright" then
									table.insert(result.warnings, 
										string.format("⚠️ WorldUpright decoration '%s' in style '%s' may look odd. Consider using TangentAligned or LocalUpright instead.",
											decor.modelId, style))
								end
							end
						end
					end
				end
				
				if archetype.branches.origins.base then
					checkProfiles(archetype.branches.origins.base.profiles)
				end
				if archetype.branches.origins.trunk_mid then
					checkProfiles(archetype.branches.origins.trunk_mid.profiles)
				end
				if archetype.branches.origins.trunk_tip then
					checkProfiles(archetype.branches.origins.trunk_tip.profiles)
				end
			end
		end
	end
	
	-- Check twist_deg usage
	for _, style in ipairs(styles) do
		if style == "straight" then
			-- Check if twist_deg is non-zero (probably a mistake)
			local twistParam = archetype.twist_deg
			local twistValue = 0
			
			if twistParam.value then
				twistValue = twistParam.value
			else
				twistValue = twistParam.curve.mu
			end
			
			if math.abs(twistValue) > 5 then
				table.insert(result.warnings,
					string.format("⚠️ twist_deg=%.1f° in 'straight' style has no effect (straight poles don't twist). Did you mean a different style?",
						twistValue))
			end
		end
	end
	
	-- Check branch limits
	if archetype.branches then
		local limits = archetype.branches.limits
		
		if limits.max_total_children < 1 then
			table.insert(result.warnings, "⚠️ max_total_children < 1 means no branches will spawn")
		end
		
		if limits.max_depth < 1 then
			table.insert(result.warnings, "⚠️ max_depth < 1 means no branches will spawn")
		end
		
		-- Check tip requirement
		if archetype.branches.origins.trunk_tip.require_one then
			if #archetype.branches.origins.trunk_tip.profiles == 0 then
				table.insert(result.errors, "❌ trunk_tip.require_one=true but no profiles defined")
				result.valid = false
			end
		end
	end
	
	-- Check scale parameters
	local function checkScale(param: Types.ParamSpec, name: string)
		local value = param.value or param.curve.mu
		if value < 0.1 then
			table.insert(result.warnings, string.format("⚠️ %s=%.2f is very small, lantern may be invisible", name, value))
		elseif value > 5 then
			table.insert(result.warnings, string.format("⚠️ %s=%.2f is very large, may cause rendering issues", name, value))
		end
	end
	
	checkScale(archetype.head_scale, "head_scale")
	checkScale(archetype.base_scale, "base_scale")
	
	return result
end

-- Quick validation - returns true if valid, logs warnings
function LanternValidator.quickValidate(archetype: Types.Archetype | Types.DesignerArchetype, archetypeName: string?): boolean
	local result = LanternValidator.validateArchetype(archetype)
	
	local name = archetypeName or "Archetype"
	
	if #result.errors > 0 then
		warn(string.format("❌ %s validation FAILED:", name))
		for _, err in ipairs(result.errors) do
			warn("  ", err)
		end
	end
	
	if #result.warnings > 0 then
		print(string.format("⚠️ %s has warnings:", name))
		for _, warning in ipairs(result.warnings) do
			print("  ", warning)
		end
	end
	
	if result.valid and #result.warnings == 0 then
		print(string.format("✅ %s is valid", name))
	end
	
	return result.valid
end

-- Validate all archetypes in a table
function LanternValidator.validateAll(archetypes: {[string]: Types.Archetype}): {[string]: ValidationResult}
	local results = {}
	
	for name, archetype in pairs(archetypes) do
		results[name] = LanternValidator.validateArchetype(archetype)
	end
	
	return results
end

-- Print a validation report
function LanternValidator.printReport(results: {[string]: ValidationResult})
	local totalErrors = 0
	local totalWarnings = 0
	
	print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("📋 LANTERN ARCHETYPE VALIDATION REPORT")
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
	
	for name, result in pairs(results) do
		local icon = result.valid and "✅" or "❌"
		print(string.format("%s %s", icon, name))
		
		if #result.errors > 0 then
			totalErrors = totalErrors + #result.errors
			for _, err in ipairs(result.errors) do
				print("  ❌", err)
			end
		end
		
		if #result.warnings > 0 then
			totalWarnings = totalWarnings + #result.warnings
			for _, warning in ipairs(result.warnings) do
				print("  ⚠️ ", warning)
			end
		end
		
		if result.valid and #result.warnings == 0 then
			print("  ✅ No issues")
		end
		
		print()
	end
	
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print(string.format("Total: %d errors, %d warnings", totalErrors, totalWarnings))
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
end

return LanternValidator
