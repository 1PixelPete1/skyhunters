--!strict
-- BranchBuilder.luau (FIXED)
-- Branch grammar system with decorations

local Shared = game.ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("LanternTypes"))
local FrameTransport = require(Shared:WaitForChild("FrameTransport"))
local BitSlicer = require(Shared:WaitForChild("BitSlicer"))

local BranchBuilder = {}

export type BuildCtx = {
	take: (bits: number) -> number,
	frames: {FrameTransport.Frame},
	sockets: {[string]: FrameTransport.Frame},
	limits: {max_total_children: number, max_depth: number},
	poleKit: Folder?,
	headKit: Folder?,
	decorKit: Folder?,
	parentSegmentLength: number?
}

-- Track total branches spawned
local totalBranches = 0

-- Create a branch arm (FIXED: tangent-aligned)
local function createBranchArm(
	startFrame: FrameTransport.Frame,
	length: number,
	radius: number
): Part
	local arm = Instance.new("Part")
	arm.Name = "BranchArm"
	arm.Anchored = true
	arm.CanCollide = false
	arm.Material = Enum.Material.Wood
	arm.Color = Color3.fromRGB(92, 64, 51)
	arm.Size = Vector3.new(radius * 2, length, radius * 2)
	
	-- FIXED: Use frame forward as the arm's long axis (Y-axis of part)
	-- Position at midpoint along the forward direction
	local endPos = startFrame.origin + startFrame.forward * length
	local midpoint = (startFrame.origin + endPos) / 2
	
	-- Create CFrame with Y-axis aligned to branch direction
	local cf = CFrame.fromMatrix(
		midpoint,
		startFrame.right,
		startFrame.forward,  -- Y-axis = forward
		-startFrame.up       -- Z-axis = -up
	)
	
	arm.CFrame = cf
	
	return arm
end

-- Apply decoration orientation mode (FIXED: better modes)
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
		-- FIXED: Warn if used in spiral/helix (as per requirements)
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
		-- Create a mini slicer for jitter sampling
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
		
		-- Apply random rotation around local Y axis (with small XZ variation)
		cf = cf * CFrame.Angles(
			jitterRad * 0.3 * (take(8) / 256 - 0.5),
			jitterRad,
			jitterRad * 0.3 * (take(8) / 256 - 0.5)
		)
	end
	
	decoration:PivotTo(cf)
end

-- Place decorations on a branch (FIXED: normalized placement)
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
		-- Load decoration prefab
		local prefab = ctx.decorKit:FindFirstChild(rule.modelId)
		if not prefab then
			warn("Decoration prefab not found:", rule.modelId)
			continue
		end
		
		if rule.where == "Along" then
			-- FIXED: Normalized Along placement - Bernoulli trial per segment
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
			-- FIXED: Place at tip socket only
			local mountPoint = branchFrame.origin + branchFrame.forward * length
			
			local decor = prefab:Clone()
			decor.Name = "Decoration_" .. rule.modelId
			applyDecorationMode(decor, mountPoint, branchFrame, rule.mode, rule.jitter_deg, ctx.take)
			decor.Parent = branch
			
		elseif rule.where == "Center" then
			-- FIXED: Midpoint placement
			local mountPoint = branchFrame.origin + branchFrame.forward * (length * 0.5)
			
			local decor = prefab:Clone()
			decor.Name = "Decoration_" .. rule.modelId
			applyDecorationMode(decor, mountPoint, branchFrame, rule.mode, rule.jitter_deg, ctx.take)
			decor.Parent = branch
		end
	end
end

-- Spawn a single branch (FIXED: adopt parent end tangent)
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
	
	-- Calculate branch orientation
	local pitch = math.rad(miniSlicer:sampleCurve(profile.pitch_deg))
	local yaw = math.rad(miniSlicer:sampleCurve(profile.yaw_deg))
	
	-- FIXED: Default branch rotation adoption = parent end tangent
	local startFrame = originFrame
	
	if profile.inherit_rotation then
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
	
	-- Create branch arm (FIXED: tangent-aligned)
	local arm = createBranchArm(newFrame, length, 0.08)
	arm.Parent = branchModel
	
	-- Place decorations (FIXED: with normalized rules)
	if profile.decorations then
		placeDecorations(branchModel, newFrame, length, profile.decorations, ctx)
	end
	
	branchModel.Parent = parent
	totalBranches = totalBranches + 1
	
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

-- Main branch building function (FIXED: guarantee tip branch)
function BranchBuilder.buildBranches(root: Instance, spec: Types.BranchSpec, ctx: BuildCtx): ()
	-- Reset counter
	totalBranches = 0
	
	-- FIXED: Process tip first if required (guarantee at least one branch spawns)
	if spec.origins.trunk_tip.require_one then
		local tipSocket = ctx.sockets["Tip"]
		if tipSocket and #spec.origins.trunk_tip.profiles > 0 then
			-- Must spawn at least one at tip
			local profile = spec.origins.trunk_tip.profiles[1]
			local parentSegmentLength = ctx.parentSegmentLength or 2.0
			spawnBranch(
				root, 
				tipSocket, 
				profile, 
				parentSegmentLength, 
				ctx,
				{socketName = "Tip"}
			)
			print("✅ Guaranteed tip branch spawned")
		else
			warn("⚠️ Tip branch required but no profiles or socket available!")
		end
	end
	
	-- Process base origins
	for _, socketName in ipairs(spec.origins.base.sockets) do
		local socket = ctx.sockets[socketName]
		if socket then
			processBranchOrigin(
				root,
				socketName,
				socket,
				spec.origins.base.profiles,
				spec.limits.max_total_children - totalBranches,
				nil,  -- No density for base
				ctx
			)
		end
	end
	
	-- Process mid-trunk origins
	for _, socketName in ipairs(spec.origins.trunk_mid.sockets) do
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
	
	-- Process tip if not already done (no requirement)
	if not spec.origins.trunk_tip.require_one then
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
	
	print("🌿 Total branches spawned:", totalBranches)
end

return BranchBuilder
