--!strict
-- BranchBuilderFixed.luau
-- Fixed branch builder that properly uses angle ranges from tree configuration

local Shared = game.ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("LanternTypes"))
local FrameTransport = require(Shared:WaitForChild("FrameTransport"))
local BitSlicer = require(Shared:WaitForChild("BitSlicer"))


type BranchProfileConfig = {
	mode: string?,
	radiusStart: number?,
	radiusEnd: number?,
	midScale: number?,
	segments: number?,
}

local BRANCH_OVERLAP = 0.02

local function buildSegmentCFrame(startPos: Vector3, endPos: Vector3, upHint: Vector3?): CFrame
	local midpoint = (startPos + endPos) * 0.5
	local direction = endPos - startPos
	if direction.Magnitude < 1e-5 then
		direction = upHint or Vector3.yAxis
	else
		direction = direction.Unit
	end

	local up = direction
	local reference = upHint or Vector3.yAxis
	if math.abs(up:Dot(reference)) > 0.98 then
		reference = Vector3.xAxis
	end

	local right = reference:Cross(up)
	if right.Magnitude < 1e-5 then
		right = Vector3.zAxis:Cross(up)
	end
	right = right.Unit

	local back = right:Cross(up)
	return CFrame.fromMatrix(midpoint, right, up, back)
end

local function computeProfileRadius(profile: BranchProfileConfig?, t: number, fallback: number): number
	if not profile then
		return fallback
	end
	local startR = profile.radiusStart or fallback
	local endR = profile.radiusEnd or startR
	local mode = profile.mode or "uniform"
	local base = startR + (endR - startR) * t
	if mode == "uniform" then
		return base
	elseif mode == "taper" then
		return base
	elseif mode == "bell" then
		local peak = profile.midScale or 1.0
		local bell = math.sin(math.pi * t)
		return base * (1 + (peak - 1) * bell)
	else
		return base
	end
end

local BranchBuilder = {}

export type BuildCtx = {
	take: (bits: number) -> number,
	frames: {FrameTransport.Frame},
	sockets: {[string]: FrameTransport.Frame},
	limits: {max_total_children: number, max_depth: number},
	poleKit: Folder?,
	headKit: Folder?,
	decorKit: Folder?,
	parentSegmentLength: number?,
	branchMode: string?,
	designMode: boolean?,
	orientationMode: string?,
	branchProfile: BranchProfileConfig?,
	-- NEW: Tree configuration from designer
	treeConfig: {
		branchAngles: {
			pitchMin: number,
			pitchMax: number,
			yawMin: number,
			yawMax: number,
			inheritRotation: boolean
		}?
	}?
}

-- Track total branches spawned
local totalBranches = 0

-- Create a branch arm (tangent-aligned)
local function createBranchArm(
	startFrame: FrameTransport.Frame,
	length: number,
	radius: number,
	profile: BranchProfileConfig?
): Model
	local container = Instance.new("Model")
	container.Name = "BranchArm"

	local segments = math.max(1, math.floor((profile and profile.segments) or 1))
	local origin = startFrame.origin
	local direction = startFrame.forward.Unit

	for i = 1, segments do
		local t0 = (i - 1) / segments
		local t1 = i / segments
		local segStart = origin + direction * (length * t0)
		local segEnd = origin + direction * (length * t1)
		local tMid = (t0 + t1) * 0.5
		local segRadius = math.max(0.005, computeProfileRadius(profile, tMid, radius))

		local segment = Instance.new("Part")
		segment.Name = string.format("ArmSegment_%d", i)
		segment.Shape = Enum.PartType.Cylinder
		segment.Anchored = true
		segment.CanCollide = false
		segment.Material = Enum.Material.Wood
		segment.Color = Color3.fromRGB(92, 64, 51)

		local segLength = (segEnd - segStart).Magnitude + BRANCH_OVERLAP
		segment.Size = Vector3.new(segRadius * 2, segLength, segRadius * 2)
		segment.CFrame = buildSegmentCFrame(segStart, segEnd, startFrame.up)

		segment.Parent = container
	end

	return container
end

-- Apply decoration orientation mode
local function applyDecorationMode(
	decoration: Model,
	mountPoint: Vector3,
	branchFrame: FrameTransport.Frame,
	mode: Types.DecorationMode,
	jitter_deg: Types.Curve?,
	take: (bits: number) -> number
): ()
	local cf: CFrame
	
	if mode == "Perpendicular" then
		-- Perpendicular to branch, Y = branch right
		cf = CFrame.fromMatrix(
			mountPoint,
			branchFrame.forward,   -- X = branch forward
			branchFrame.right,     -- Y = branch right (perpendicular)
			branchFrame.up         -- Z = branch up
		)
		
	elseif mode == "LocalUpright" then
		-- Y = branch up vector
		cf = CFrame.fromMatrix(
			mountPoint,
			branchFrame.right,
			branchFrame.up,
			-branchFrame.forward
		)
		
	elseif mode == "WorldUpright" then
		-- Y = world up
		local worldUp = Vector3.yAxis
		local forward = branchFrame.forward
		-- Project forward to horizontal plane
		forward = Vector3.new(forward.X, 0, forward.Z)
		if forward.Magnitude < 0.001 then
			forward = Vector3.zAxis
		end
		forward = forward.Unit
		
		local right = forward:Cross(worldUp).Unit
		cf = CFrame.fromMatrix(mountPoint, right, worldUp, -forward)
		
	elseif mode == "TangentAligned" then
		-- Y = branch tangent (along the branch)
		cf = CFrame.fromMatrix(
			mountPoint,
			branchFrame.right,
			branchFrame.forward,   -- Y = tangent
			-branchFrame.up
		)
		
	else
		-- Default to perpendicular
		cf = CFrame.fromMatrix(
			mountPoint,
			branchFrame.forward,
			branchFrame.right,
			branchFrame.up
		)
	end
	
	-- Apply jitter if specified
	if jitter_deg then
		local miniSlicer = {
			take = take,
			sampleCurve = function(_, curve: Types.Curve)
				local u = take(16) / 65536
				local value = curve.mu + (u - 0.5) * 2 * curve.sigma
				return math.clamp(value, curve.lo, curve.hi)
			end
		}
		
		local jitterAngle = miniSlicer:sampleCurve(jitter_deg)
		local jitterRad = math.rad(jitterAngle)
		
		-- Apply random rotation around local Y axis
		cf = cf * CFrame.Angles(
			jitterRad * 0.3 * (take(8) / 256 - 0.5),
			jitterRad,
			jitterRad * 0.3 * (take(8) / 256 - 0.5)
		)
	end
	
	decoration:PivotTo(cf)
end

-- Place decorations on a branch
local function placeDecorations(
	branch: Model,
	branchFrame: FrameTransport.Frame,
	length: number,
	rules: {Types.DecorationRule},
	ctx: BuildCtx
): ()
	if not ctx.decorKit then
		return
	end
	
	for _, rule in ipairs(rules) do
		local prefab = ctx.decorKit:FindFirstChild(rule.modelId)
		if not prefab then
			warn("Decoration prefab not found:", rule.modelId)
			continue
		end
		
		if rule.where == "Along" then
			-- Normalized Along placement - Bernoulli trial per segment
			local density = rule.density or 0.5
			local segmentLength = 0.5  -- Standard segment length
			local numSegments = math.max(1, math.floor(length / segmentLength))
			
			for i = 1, numSegments do
				-- Bernoulli trial for placement
				local roll = ctx.take(16) / 65536
				if roll < density then
					local t = i / (numSegments + 1)
					local mountPoint = branchFrame.origin + branchFrame.forward * (t * length)
					
					local decor = prefab:Clone()
					decor.Name = "Decoration_" .. rule.modelId .. "_" .. i
					applyDecorationMode(decor, mountPoint, branchFrame, rule.mode, rule.jitter_deg, ctx.take)
					decor.Parent = branch
				end
			end
			
		elseif rule.where == "Ends" then
			-- Place at tip socket only
			local mountPoint = branchFrame.origin + branchFrame.forward * length
			
			local decor = prefab:Clone()
			decor.Name = "Decoration_" .. rule.modelId
			applyDecorationMode(decor, mountPoint, branchFrame, rule.mode, rule.jitter_deg, ctx.take)
			decor.Parent = branch
			
		elseif rule.where == "Center" then
			-- Midpoint placement
			local mountPoint = branchFrame.origin + branchFrame.forward * (length * 0.5)
			
			local decor = prefab:Clone()
			decor.Name = "Decoration_" .. rule.modelId
			applyDecorationMode(decor, mountPoint, branchFrame, rule.mode, rule.jitter_deg, ctx.take)
			decor.Parent = branch
		end
	end
end

-- FIXED: Spawn a single branch using tree configuration angle ranges
local function spawnBranch(
	parent: Instance,
	originFrame: FrameTransport.Frame,
	profile: Types.BranchProfile,
	parentSegmentLength: number,
	ctx: BuildCtx,
	debugInfo: {socketName: string}
): Model?
	-- Check global limit
	if totalBranches >= ctx.limits.max_total_children then
		return nil
	end
	
	local branchModel = Instance.new("Model")
	branchModel.Name = "Branch_" .. profile.id
	
	-- Add debug attributes
	branchModel:SetAttribute("ProfileId", profile.id)
	branchModel:SetAttribute("SocketOrigin", debugInfo.socketName)
	
	-- Create mini slicer for curve sampling
	local miniSlicer = {
		take = ctx.take,
		sampleCurve = function(_, curve: Types.Curve)
			local u = ctx.take(16) / 65536
			local value = curve.mu + (u - 0.5) * 2 * curve.sigma
			return math.clamp(value, curve.lo, curve.hi)
		end
	}
	
	-- Calculate branch length
	local lenFrac = miniSlicer:sampleCurve(profile.len_frac)
	local length = math.clamp(parentSegmentLength * lenFrac, 0.5, 5)
	
	-- FIXED: Use tree configuration angles if in design mode
	local pitch, yaw
	
	if ctx.designMode and ctx.treeConfig and ctx.treeConfig.branchAngles then
		-- Use explicit angle ranges from tree tab
		local angles = ctx.treeConfig.branchAngles
		
		-- Generate angles within the specified ranges
		local pitchRange = angles.pitchMax - angles.pitchMin
		local yawRange = angles.yawMax - angles.yawMin
		
		local pitchU = ctx.take(16) / 65536
		local yawU = ctx.take(16) / 65536
		
		pitch = math.rad(angles.pitchMin + pitchU * pitchRange)
		yaw = math.rad(angles.yawMin + yawU * yawRange)
		
		-- Debug output
		print(string.format("  Branch angle: pitch=%.1f° yaw=%.1f° (from ranges [%.1f,%.1f] [%.1f,%.1f])",
			math.deg(pitch), math.deg(yaw),
			angles.pitchMin, angles.pitchMax,
			angles.yawMin, angles.yawMax))
	else
		-- Use profile curves (original behavior)
		pitch = math.rad(miniSlicer:sampleCurve(profile.pitch_deg))
		yaw = math.rad(miniSlicer:sampleCurve(profile.yaw_deg))
	end
	
	-- Handle rotation inheritance
	local startFrame = originFrame
	local inheritRotation = profile.inherit_rotation
	
	-- Check tree config override
	if ctx.treeConfig and ctx.treeConfig.branchAngles then
		inheritRotation = ctx.treeConfig.branchAngles.inheritRotation
	end
	
	if inheritRotation then
		-- Inherit parent frame rotation directly
		startFrame = originFrame
	end
	
	-- Apply rotations relative to parent tangent
	local cf = FrameTransport.cframeFrom(startFrame)
	cf = cf * CFrame.Angles(pitch, yaw, 0)
	
	-- Apply jitter if specified
	if profile.jitter_deg then
		local jitter = math.rad(miniSlicer:sampleCurve(profile.jitter_deg))
		cf = cf * CFrame.Angles(
			jitter * (ctx.take(8) / 256 - 0.5),
			jitter * (ctx.take(8) / 256 - 0.5),
			jitter * (ctx.take(8) / 256 - 0.5)
		)
	end
	
	-- Extract new frame
	local newFrame: FrameTransport.Frame = {
		origin = cf.Position,
		right = cf.RightVector,
		up = cf.UpVector,
		forward = -cf.LookVector  -- CFrame uses -Z as forward
	}
	
	-- Create branch arm with profile shaping
	local armModel = createBranchArm(newFrame, length, 0.08, ctx.branchProfile)
	armModel.Parent = branchModel
	
	-- Place decorations
	if profile.decorations then
		placeDecorations(branchModel, newFrame, length, profile.decorations, ctx)
	end
	
	branchModel.Parent = parent
	totalBranches = totalBranches + 1
	
	-- Add debug attributes for angle verification
	if ctx.designMode then
		branchModel:SetAttribute("ActualPitch", math.deg(pitch))
		branchModel:SetAttribute("ActualYaw", math.deg(yaw))
	end
	
	return branchModel
end

-- Process branches from a specific origin
local function processBranchOrigin(
	parent: Instance,
	socketName: string,
	socketFrame: FrameTransport.Frame,
	profiles: {Types.BranchProfile},
	maxChildren: number,
	density: number?,
	ctx: BuildCtx
): number
	local spawnedCount = 0
	
	-- Determine how many to spawn
	local numToSpawn = 0
	if density then
		-- Use density for probability
		if ctx.take(10) / 1024 < density then
			numToSpawn = math.min(maxChildren, #profiles)
		end
	else
		-- Spawn up to maxChildren
		numToSpawn = math.min(maxChildren, #profiles)
	end
	
	-- Get parent segment length
	local parentSegmentLength = ctx.parentSegmentLength or 2.0
	
	-- Spawn branches
	for i = 1, numToSpawn do
		if totalBranches >= ctx.limits.max_total_children then
			break
		end
		
		local profileIndex = ((i - 1) % #profiles) + 1
		local profile = profiles[profileIndex]
		
		if profile.max_children > 0 then
			local branch = spawnBranch(
				parent, 
				socketFrame, 
				profile, 
				parentSegmentLength, 
				ctx,
				{socketName = socketName}
			)
			if branch then
				spawnedCount = spawnedCount + 1
			end
		end
	end
	
	return spawnedCount
end

function BranchBuilder.buildBranches(root: Instance, spec: Types.BranchSpec, ctx: BuildCtx): ()
	-- Reset counter
	totalBranches = 0
	
	local branchMode = ctx.branchMode or "default"
	local singleBranchMode = branchMode == "single"
	
	-- Debug output for design mode
	if ctx.designMode and ctx.treeConfig and ctx.treeConfig.branchAngles then
		print("🌳 Building branches with tree configuration:")
		print(string.format("   Pitch range: [%.1f°, %.1f°]", 
			ctx.treeConfig.branchAngles.pitchMin,
			ctx.treeConfig.branchAngles.pitchMax))
		print(string.format("   Yaw range: [%.1f°, %.1f°]",
			ctx.treeConfig.branchAngles.yawMin,
			ctx.treeConfig.branchAngles.yawMax))
		print("   Inherit rotation:", ctx.treeConfig.branchAngles.inheritRotation)
	end
	
	local function shouldStop(): boolean
		return singleBranchMode and totalBranches >= 1
	end
	
	-- Process tip first if required
	if spec.origins.trunk_tip.require_one then
		local tipSocket = ctx.sockets["Tip"]
		if tipSocket and #spec.origins.trunk_tip.profiles > 0 then
			local profile = spec.origins.trunk_tip.profiles[1]
			local parentSegmentLength = ctx.parentSegmentLength or 2.0
			spawnBranch(
				root,
				tipSocket,
				profile,
				parentSegmentLength,
				ctx,
				{ socketName = "Tip" }
			)
			if shouldStop() then
				return
			end
		else
			warn("⚠️ Tip branch required but no profiles or socket available!")
		end
	end
	
	-- Process base origins
	for _, socketName in ipairs(spec.origins.base.sockets) do
		if shouldStop() then break end
		local socket = ctx.sockets[socketName]
		if socket then
			processBranchOrigin(
				root,
				socketName,
				socket,
				spec.origins.base.profiles,
				spec.limits.max_total_children - totalBranches,
				nil,
				ctx
			)
			if shouldStop() then break end
		end
	end
	
	-- Process mid-trunk origins
	for _, socketName in ipairs(spec.origins.trunk_mid.sockets) do
		if shouldStop() then break end
		local socket = ctx.sockets[socketName]
		if socket and totalBranches < ctx.limits.max_total_children then
			processBranchOrigin(
				root,
				socketName,
				socket,
				spec.origins.trunk_mid.profiles,
				ctx.limits.max_total_children - totalBranches,
				spec.origins.trunk_mid.density,
				ctx
			)
		end
	end
	
	-- Process tip if not already done
	if not spec.origins.trunk_tip.require_one and not shouldStop() then
		local tipSocket = ctx.sockets["Tip"]
		if tipSocket and totalBranches < ctx.limits.max_total_children then
			processBranchOrigin(
				root,
				"Tip",
				tipSocket,
				spec.origins.trunk_tip.profiles,
				ctx.limits.max_total_children - totalBranches,
				nil,
				ctx
			)
		end
	end
	
	print("✅ Built", totalBranches, "branches")
end

return BranchBuilder
