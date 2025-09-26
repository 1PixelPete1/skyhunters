--!strict
-- BranchBuilder.luau
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
	decorKit: Folder?
}

-- Track total branches spawned
local totalBranches = 0

-- Create a branch arm (block part)
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
	arm.Size = Vector3.new(radius * 2, radius * 2, length)
	
	-- Position and orient the block along the branch direction
	local endPos = startFrame.origin + startFrame.forward * length
	local midpoint = (startFrame.origin + endPos) / 2
	
	-- CFrame looking from midpoint towards end, with -Z axis along the branch
	arm.CFrame = CFrame.lookAt(midpoint, endPos)
	
	return arm
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
		-- X axis = branch right, Y = up, Z = forward
		cf = CFrame.fromMatrix(
			mountPoint,
			branchFrame.right,
			branchFrame.up,
			branchFrame.forward
		)
		
	elseif mode == "LocalUpright" then
		-- Y = branch up, Z = branch forward
		cf = CFrame.fromMatrix(
			mountPoint,
			branchFrame.right,
			branchFrame.up,
			-branchFrame.forward
		)
		
	elseif mode == "WorldUpright" then
		-- Y = world up, align Z to branch forward projection
		local worldUp = Vector3.yAxis
		local forward = branchFrame.forward
		forward = Vector3.new(forward.X, 0, forward.Z).Unit
		if forward.Magnitude < 0.001 then
			forward = Vector3.zAxis
		end
		
		local right = forward:Cross(worldUp).Unit
		cf = CFrame.fromMatrix(mountPoint, right, worldUp, -forward)
		
	elseif mode == "TangentAligned" then
		-- Y = branch forward (along the branch)
		cf = CFrame.fromMatrix(
			mountPoint,
			branchFrame.right,
			branchFrame.forward,
			-branchFrame.up
		)
		
	else
		-- Default to perpendicular
		cf = CFrame.fromMatrix(
			mountPoint,
			branchFrame.right,
			branchFrame.up,
			branchFrame.forward
		)
	end
	
	-- Apply jitter if specified
	if jitter_deg then
		-- Create a mini slicer for jitter sampling
		local miniSlicer = {
			take = take,
			sampleCurve = function(_, curve: Types.Curve)
				local u = take(10)
				local value = curve.mu + (u - 0.5) * 2 * curve.sigma
				return math.clamp(value, curve.lo, curve.hi)
			end
		}
		
		local jitterAngle = miniSlicer:sampleCurve(jitter_deg)
		local jitterRad = math.rad(jitterAngle)
		
		-- Apply random rotation around local Y axis
		cf = cf * CFrame.Angles(0, jitterRad, 0)
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
		-- Load decoration prefab
		local prefab = ctx.decorKit:FindFirstChild(rule.modelId)
		if not prefab then
			warn("Decoration prefab not found:", rule.modelId)
			continue
		end
		
		if rule.where == "Along" then
			-- Place along the branch with density probability
			local density = rule.density or 0.5
			local numPositions = math.floor(length / 0.5)  -- Every 0.5 studs
			
			for i = 1, numPositions do
				-- Bernoulli trial for placement
				if ctx.take(10) / 1024 < density then
					local t = i / (numPositions + 1)
					local mountPoint = branchFrame.origin + branchFrame.forward * (t * length)
					
					local decor = prefab:Clone()
					decor.Name = "Decoration_" .. rule.modelId
					applyDecorationMode(decor, mountPoint, branchFrame, rule.mode, rule.jitter_deg, ctx.take)
					decor.Parent = branch
				end
			end
			
		elseif rule.where == "Ends" then
			-- Place at the tip of the branch
			local mountPoint = branchFrame.origin + branchFrame.forward * length
			
			local decor = prefab:Clone()
			decor.Name = "Decoration_" .. rule.modelId
			applyDecorationMode(decor, mountPoint, branchFrame, rule.mode, rule.jitter_deg, ctx.take)
			decor.Parent = branch
			
		elseif rule.where == "Center" then
			-- Place at the geometric center
			local mountPoint = branchFrame.origin + branchFrame.forward * (length * 0.5)
			
			local decor = prefab:Clone()
			decor.Name = "Decoration_" .. rule.modelId
			applyDecorationMode(decor, mountPoint, branchFrame, rule.mode, rule.jitter_deg, ctx.take)
			decor.Parent = branch
		end
	end
end

-- Spawn a single branch
local function spawnBranch(
	parent: Instance,
	originFrame: FrameTransport.Frame,
	profile: Types.BranchProfile,
	parentSegmentLength: number,
	ctx: BuildCtx
): Model?
	-- Check global limit
	if totalBranches >= ctx.limits.max_total_children then
		return nil
	end
	
	local branchModel = Instance.new("Model")
	branchModel.Name = "Branch_" .. profile.id
	
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
	
	-- Start with origin frame or inherit parent rotation
	local startFrame = originFrame
	
	-- Apply rotations
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
	
	-- Create branch arm
	local arm = createBranchArm(newFrame, length, 0.08)
	arm.Parent = branchModel
	
	-- Place decorations
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
	
	-- Get parent segment length (estimate from pole height)
	local parentSegmentLength = 2.0  -- Default estimate
	
	-- Spawn branches
	for i = 1, numToSpawn do
		if totalBranches >= ctx.limits.max_total_children then
			break
		end
		
		local profileIndex = math.min(i, #profiles)
		local profile = profiles[profileIndex]
		
		if profile.max_children > 0 then
			local branch = spawnBranch(parent, socketFrame, profile, parentSegmentLength, ctx)
			if branch then
				spawnedCount = spawnedCount + 1
			end
		end
	end
	
	return spawnedCount
end

-- Main branch building function
function BranchBuilder.buildBranches(root: Instance, spec: Types.BranchSpec, ctx: BuildCtx): ()
	-- Reset counter
	totalBranches = 0
	
	-- Process tip first if required
	if spec.origins.trunk_tip.require_one then
		local tipSocket = ctx.sockets["Tip"]
		if tipSocket and #spec.origins.trunk_tip.profiles > 0 then
			-- Must spawn at least one at tip
			local profile = spec.origins.trunk_tip.profiles[1]
			spawnBranch(root, tipSocket, profile, 2.0, ctx)
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
				spec.limits.max_total_children,
				nil,  -- No density for base
				ctx
			)
		end
	end
	
	-- Process mid-trunk origins
	for _, socketName in ipairs(spec.origins.trunk_mid.sockets) do
		local socket = ctx.sockets[socketName]
		if socket then
			processBranchOrigin(
				root,
				socketName,
				socket,
				spec.origins.trunk_mid.profiles,
				spec.limits.max_total_children,
				spec.origins.trunk_mid.density,
				ctx
			)
		end
	end
	
	-- Process tip if not already done
	if not spec.origins.trunk_tip.require_one then
		local tipSocket = ctx.sockets["Tip"]
		if tipSocket then
			processBranchOrigin(
				root,
				"Tip",
				tipSocket,
				spec.origins.trunk_tip.profiles,
				spec.limits.max_total_children,
				nil,
				ctx
			)
		end
	end
end

return BranchBuilder
