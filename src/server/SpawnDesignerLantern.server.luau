--!strict
-- SpawnDesignerLantern.server.luau
-- FIXED: Print exact spawn location

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

if not RunService:IsStudio() then
	return
end

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Server = game.ServerScriptService:WaitForChild("Server")
local FeatureFlags = require(Shared:WaitForChild("FeatureFlags"))
local Types = require(Shared:WaitForChild("LanternTypes"))
local LanternFactory = require(Server:WaitForChild("LanternFactory"))

local spawnRemote = ReplicatedStorage:FindFirstChild("SpawnDesignerLantern")
if not spawnRemote then
	spawnRemote = Instance.new("RemoteEvent")
	spawnRemote.Name = "SpawnDesignerLantern"
	spawnRemote.Parent = ReplicatedStorage
end

local function sanitizeNumber(value: any, default: number, min: number?, max: number?): number
	local num = tonumber(value) or default
	if num ~= num then
		num = default
	end
	if min then
		num = math.max(num, min)
	end
	if max then
		num = math.min(num, max)
	end
	return num
end

local function convertDesignerToArchetype(payload: {[string]: any}): (Types.Archetype, {[string]: any})
	local tree = payload.tree or {}
	local lantern = payload.lantern or {}

	local function cloneArray(src: {string}?): {string}
		local result = {}
		if src then
			for _, value in ipairs(src) do
				table.insert(result, value)
			end
		end
		return result
	end

	local function sanitizeCurve(def: {mu: number?, sigma: number?, lo: number?, hi: number?, multiplier: number?}?): Types.Curve
		if not def then
			return {mu = 0, sigma = 0, lo = 0, hi = 0}
		end
		local lo = sanitizeNumber(def.lo, 0)
		local hi = sanitizeNumber(def.hi, lo)
		if hi < lo then
			lo, hi = hi, lo
		end
		local mu = sanitizeNumber(def.mu, (lo + hi) / 2)
		mu = math.clamp(mu, lo, hi)
		local sigma = math.abs(sanitizeNumber(def.sigma, 0))
		local multiplier = sanitizeNumber(def.multiplier, 1)
		sigma = sigma * math.max(multiplier, 0)
		return {
			mu = mu,
			sigma = sigma,
			lo = lo,
			hi = hi
		}
	end

	local angles = tree.angles or {}
	local lengthCfg = tree.branchLength or {}

	local branchProfiles = {}
	local defaultProfile: Types.BranchProfile = {
		id = "designer_branch",
		max_children = (tree.distribution and tree.distribution.maxPerSocket) or 2,
		len_frac = sanitizeCurve(lengthCfg.fraction),
		pitch_deg = sanitizeCurve(angles.pitch),
		yaw_deg = sanitizeCurve(angles.yaw),
		inherit_rotation = true,
		jitter_deg = (tree.jitter and tree.jitter.enabled) and {
			mu = 0,
			sigma = (tree.jitter.range or 0) / 3,
			lo = -(tree.jitter.range or 0),
			hi = (tree.jitter.range or 0)
		} or nil,
		decorations = {}
	}
	
	defaultProfile.pitch_deg.lo = math.max(-90, defaultProfile.pitch_deg.lo)
	defaultProfile.pitch_deg.hi = math.min(90, defaultProfile.pitch_deg.hi)
	defaultProfile.yaw_deg.lo = math.clamp(defaultProfile.yaw_deg.lo, 0, 360)
	defaultProfile.yaw_deg.hi = math.clamp(defaultProfile.yaw_deg.hi, defaultProfile.yaw_deg.lo, 360)

	table.insert(branchProfiles, defaultProfile)

	local branchSpec: Types.BranchSpec = {
		origins = {
			base = {
				sockets = {"BaseTop"},
				profiles = branchProfiles
			},
			trunk_mid = {
				sockets = {"S1", "S2"},
				density = 0.5,
				profiles = branchProfiles
			},
			trunk_tip = {
				sockets = {"Tip"},
				profiles = branchProfiles,
				require_one = false
			}
		},
		limits = {
			max_total_children = (tree.distribution and tree.distribution.maxTotal) or 5,
			max_depth = 1
		}
	}

	local function createParamSpec(
		param: {value: number?, rngEnabled: boolean?, min: number?, max: number?}?,
		channel: string?,
		defaultValue: number?
	): Types.ParamSpec
		local fallback = defaultValue or 1
		if not param then
			return {
				curve = {mu = fallback, sigma = 0, lo = fallback, hi = fallback},
				rng = false,
				value = fallback,
				channel = channel
			}
		end

		local minValue = param.min
		local maxValue = param.max
		local requiresPositive = channel == "shape" or (channel and string.find(channel, "scale") ~= nil)
		local safeMin = requiresPositive and 0.01 or nil

		if requiresPositive then
			if minValue ~= nil then
				minValue = math.max(minValue, safeMin :: number)
			else
				minValue = safeMin
			end
			if maxValue ~= nil and minValue ~= nil then
				maxValue = math.max(maxValue, minValue)
			end
		end

		if param.rngEnabled and minValue ~= nil and maxValue ~= nil then
			local min = sanitizeNumber(param.min, minValue, minValue)
			local max = sanitizeNumber(param.max, maxValue, min)
			if max < min then
				max = min
			end
			return {
				curve = {
					mu = (min + max) * 0.5,
					sigma = math.abs(max - min) / 4,
					lo = min,
					hi = max
				},
				rng = true,
				channel = channel
			}
		end

		local value = param.value
		if value == nil then
			value = minValue or maxValue or fallback
		end
		local clamped = sanitizeNumber(value, fallback, minValue, maxValue)
		local lo = minValue or clamped
		local hi = maxValue or clamped
		if hi < lo then
			hi = lo
		end

		return {
			curve = {
				mu = clamped,
				sigma = 0,
				lo = lo,
				hi = hi
			},
			rng = false,
			value = clamped,
			channel = channel
		}
	end

	local archetype: Types.Archetype = {
		height = createParamSpec(lantern.params and lantern.params.height, "shape", 12),
		bend_deg = createParamSpec(lantern.params and lantern.params.bend, "pose", 15),
		twist_deg = createParamSpec(lantern.params and lantern.params.twist, "pose", 0),
		tip_drop = {
			curve = {mu = 0.2, sigma = 0.05, lo = 0, hi = 0.5},
			rng = false,
			value = 0.2
		},
		arm_len = createParamSpec(lantern.params and lantern.params.armLength, "shape", 1.8),
		lantern_tilt = createParamSpec(lantern.params and lantern.params.lanternTilt, "look", 5),
		lantern_yaw = createParamSpec(lantern.params and lantern.params.lanternYaw, "look", 0),
		head_scale = createParamSpec(lantern.models and lantern.models.headScale, "shape", 1.0),
		base_scale = createParamSpec(lantern.models and lantern.models.baseScale, "shape", 1.0),
		paint_wear = {curve = {mu = 0, sigma = 0, lo = 0, hi = 0}, rng = false, value = 0},
		base_set = {[lantern.models and lantern.models.base and lantern.models.base.selection or "StoneDisk"] = 1.0},
		head_set = {[lantern.models and lantern.models.head and lantern.models.head.selection or "HeadA"] = 1.0},
		style_weights = {[lantern.style or "scurve"] = 1.0},
		branches = branchSpec
	}

	local style = lantern.style or "scurve"
	local curveOverrides = {}
	local styleOptions = lantern.styleOptions and lantern.styleOptions[style]
	if style == "scurve" then
		curveOverrides.min_lateral = styleOptions and styleOptions.minLateral or 1.25
		curveOverrides.tip_drop = styleOptions and styleOptions.tipDrop or 0.2
	elseif style == "planar_spiral" then
		curveOverrides.radius_factor = styleOptions and styleOptions.radiusFactor or 0.12
		curveOverrides.radius_min = styleOptions and styleOptions.minRadius or 1.5
	elseif style == "helix" then
		curveOverrides.radius = styleOptions and styleOptions.radius or 2.0
		curveOverrides.pitch = styleOptions and styleOptions.pitch or 1.0
	end

	local branchProfile = {}
	local srcProfile = lantern.branchProfile
	if srcProfile then
		for key, value in pairs(srcProfile) do
			branchProfile[key] = value
		end
		branchProfile.radiusStart = math.max(0.005, branchProfile.radiusStart or 0.08)
		branchProfile.radiusEnd = math.max(0.005, branchProfile.radiusEnd or branchProfile.radiusStart)
		branchProfile.mode = branchProfile.mode or "uniform"
		branchProfile.midScale = branchProfile.midScale or 1.0
		branchProfile.segmentModel = lantern.models and lantern.models.segment and lantern.models.segment.selection
		if branchProfile.segmentModel == "" then
			branchProfile.segmentModel = nil
		end
	else
		branchProfile = nil
	end

	local factoryOptions = {
		designMode = true,
		branchMode = tree.distribution and tree.distribution.pattern or "uniform",
		style = style,
		curveOverrides = curveOverrides,
		orientationMode = lantern.orientation and lantern.orientation.mode or "tangent",
		branchProfile = branchProfile,
	}

	return archetype, factoryOptions
end

spawnRemote.OnServerEvent:Connect(function(player: Player, payload: {[string]: any})
	if not RunService:IsStudio() then
		return
	end
	
	if not FeatureFlags.get("Lanterns.DesignerEnabled") then
		warn("Designer is not enabled")
		return
	end
	
	local mode = payload.mode or "spawn"
	
	-- Get player position
	local position = nil
	local character = player.Character
	if character then
		local root = character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			position = root.Position
			print("============ SPAWN LOCATION ============")
			print("[SPAWN] Player position:", position)
			print("[SPAWN] Root CFrame:", root.CFrame)
		end
	end
	
	if not position then
		position = Vector3.new(0, 10, 0)
		warn("[SPAWN] No player found, using fallback:", position)
	end
	
	local archetype, factoryOptions = convertDesignerToArchetype(payload)
	local seed = payload.tree and payload.tree.masterSeed or math.random(1, 1000000)
	local plotId = "designer_" .. player.Name .. "_" .. os.time()
	
	print("[SPAWN] Calling LanternFactory with position:", position)
	
	local success, lanternModel = pcall(function()
		factoryOptions = factoryOptions or {}
		factoryOptions.seed = seed
		return LanternFactory.assembleDesigner(plotId, position, archetype, factoryOptions)
	end)
	
	if success and lanternModel then
		lanternModel:SetAttribute("SpawnedByDesigner", true)
		lanternModel:SetAttribute("DesignerPlayer", player.Name)
		lanternModel:SetAttribute("DesignerSeed", seed)
		
		-- CRITICAL: Parent the lantern to workspace so it actually appears!
		lanternModel.Parent = workspace
		
		if mode == "preview" then
			lanternModel:SetAttribute("IsPreview", true)
			for _, model in ipairs(workspace:GetChildren()) do
				if model:IsA("Model") and 
				   model:GetAttribute("SpawnedByDesigner") and
				   model:GetAttribute("DesignerPlayer") == player.Name and
				   model:GetAttribute("IsPreview") and
				   model ~= lanternModel then
					model:Destroy()
				end
			end
		end
		
		print("[SPAWN] Final lantern position:", lanternModel:GetPivot().Position)
		print("[SPAWN] ✓ Spawned successfully")
		print("========================================")
	else
		warn("Failed to spawn:", lanternModel)
	end
end)

print("[Designer] Server handler loaded")
