--!strict
-- BranchBuilder.luau
-- FIXED: Print coordinates to debug gaps

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
	parentSegmentLength: number?,
	branchMode: string?,
	designMode: boolean?,
	branchProfile: {
		mode: string?,
		radiusStart: number?,
		radiusEnd: number?,
		segmentModel: string?,
	}?,
	orientationMode: string?,
}

local totalBranches = 0
local SEGMENT_OVERLAP = 0.15
local MIN_SEGMENT_LENGTH = 0.05

local function createBranchSegment(
	startPos: Vector3,
	endPos: Vector3,
	radius: number,
	segmentModel: string?,
	poleKit: Folder?,
	branchFrame: FrameTransport.Frame
): BasePart
	local offset = endPos - startPos
	local length = offset.Magnitude
	local midpoint = (startPos + endPos) * 0.5

	-- PRINT SEGMENT COORDINATES
	print("[SEGMENT] Start:", startPos)
	print("[SEGMENT] End:", endPos)
	print("[SEGMENT] Length:", length)
	print("[SEGMENT] Midpoint:", midpoint)

	local diameter = math.max(radius * 2, 0.02)
	local visualLength = math.max(length + SEGMENT_OVERLAP, MIN_SEGMENT_LENGTH)

	local segment: BasePart?
	local usingPrefab = false

	if segmentModel and segmentModel ~= "" and segmentModel ~= "Cylinder" and poleKit then
		local prefab = poleKit:FindFirstChild(segmentModel)
		if prefab and prefab:IsA("BasePart") then
			segment = prefab:Clone()
			usingPrefab = true
		else
			warn("[BranchBuilder] Model not found or unsupported:", segmentModel)
		end
	end

	if not segment then
		local part = Instance.new("Part")
		part.Shape = Enum.PartType.Cylinder
		part.Material = Enum.Material.Wood
		part.Color = Color3.fromRGB(92, 64, 51)
		segment = part
	end

	segment.Name = "BranchSegment"
	segment.Anchored = true
	segment.CanCollide = false

	if segment:IsA("Part") and segment.Shape == Enum.PartType.Cylinder then
		segment.Size = Vector3.new(diameter, visualLength, diameter)
	elseif not usingPrefab then
		segment.Size = Vector3.new(diameter, visualLength, diameter)
	end

	-- Align the cylinder's Y-axis with the branch tangent
	local direction: Vector3
	if length > 1e-5 then
		direction = offset.Unit
	elseif branchFrame.forward.Magnitude > 1e-5 then
		direction = branchFrame.forward.Unit
	else
		direction = Vector3.yAxis
	end

	local rightAxis = branchFrame.right - direction * branchFrame.right:Dot(direction)
	if rightAxis.Magnitude < 1e-5 then
		rightAxis = branchFrame.up:Cross(direction)
	end
	if rightAxis.Magnitude < 1e-5 then
		rightAxis = direction:Cross(Vector3.yAxis)
	end
	if rightAxis.Magnitude < 1e-5 then
		rightAxis = direction:Cross(Vector3.xAxis)
	end
	rightAxis = rightAxis.Unit

	local backAxis = rightAxis:Cross(direction)
	if backAxis.Magnitude < 1e-5 then
		backAxis = branchFrame.up
	end
	backAxis = backAxis.Unit

	segment.CFrame = CFrame.fromMatrix(midpoint, rightAxis, direction, backAxis)

	print("[SEGMENT] Final CFrame Position:", segment.CFrame.Position)
	print("---")

	return segment
end

local function createBranchArm(
	startFrame: FrameTransport.Frame,
	length: number,
	radiusStart: number,
	radiusEnd: number,
	profileMode: string?,
	segmentModel: string?,
	poleKit: Folder?,
	midScale: number?
): {BasePart}
	local segments: {BasePart} = {}
	
	local segmentLength = 0.5
	local numSegments = math.max(1, math.ceil(length / segmentLength))
	
	print("========== CREATING BRANCH ==========")
	print("[BRANCH] Total length:", length)
	print("[BRANCH] Num segments:", numSegments)
	print("[BRANCH] Start origin:", startFrame.origin)
	print("[BRANCH] Forward vector:", startFrame.forward)
	
	for i = 1, numSegments do
		local t0 = (i - 1) / numSegments
		local t1 = i / numSegments
		
		print("[BRANCH] Segment", i, "- t0:", t0, "t1:", t1)
		
		local radius: number
		if profileMode == "uniform" then
			radius = radiusStart
		elseif profileMode == "taper" then
			radius = radiusStart + (radiusEnd - radiusStart) * t0
		elseif profileMode == "bell" then
			local midT = 0.5
			local dist = math.abs(t0 - midT)
			local scaleFactor = 1 + ((midScale or 1.15) - 1) * (1 - dist * 2)
			local baseRadius = radiusStart + (radiusEnd - radiusStart) * t0
			radius = baseRadius * scaleFactor
		else
			radius = radiusStart
		end
		
		local startPos = startFrame.origin + startFrame.forward * (t0 * length)
		local endPos = startFrame.origin + startFrame.forward * (t1 * length)
		
		print("[BRANCH] Calculated Start:", startPos)
		print("[BRANCH] Calculated End:", endPos)
		
		-- Check gap from previous segment
		if i > 1 then
			local prevSegment = segments[i-1]
			local prevEnd = prevSegment:GetAttribute("EndPos")
			if prevEnd then
				local gap = (startPos - prevEnd).Magnitude
				print("[GAP CHECK] Distance from previous segment end to this start:", gap)
			end
		end
		
		local segment = createBranchSegment(startPos, endPos, radius, segmentModel, poleKit, startFrame)
		segment:SetAttribute("EndPos", endPos)
		table.insert(segments, segment)
	end
	
	print("========== BRANCH COMPLETE ==========")
	
	return segments
end

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
		cf = CFrame.fromMatrix(mountPoint, branchFrame.forward, branchFrame.right, branchFrame.up)
	elseif mode == "LocalUpright" then
		cf = CFrame.fromMatrix(mountPoint, branchFrame.right, branchFrame.up, -branchFrame.forward)
	elseif mode == "WorldUpright" then
		local worldUp = Vector3.yAxis
		local forward = branchFrame.forward
		forward = Vector3.new(forward.X, 0, forward.Z)
		if forward.Magnitude < 0.001 then
			forward = Vector3.zAxis
		end
		forward = forward.Unit
		local right = forward:Cross(worldUp).Unit
		cf = CFrame.fromMatrix(mountPoint, right, worldUp, -forward)
	elseif mode == "TangentAligned" then
		cf = CFrame.fromMatrix(mountPoint, branchFrame.right, branchFrame.forward, -branchFrame.up)
	else
		cf = CFrame.fromMatrix(mountPoint, branchFrame.forward, branchFrame.right, branchFrame.up)
	end
	
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
		
		cf = cf * CFrame.Angles(
			jitterRad * 0.3 * (take(8) / 256 - 0.5),
			jitterRad,
			jitterRad * 0.3 * (take(8) / 256 - 0.5)
		)
	end
	
	decoration:PivotTo(cf)
end

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
			continue
		end
		
		if rule.where == "Along" then
			local density = rule.density or 0.5
			local segmentLength = 0.5
			local numSegments = math.max(1, math.floor(length / segmentLength))
			
			for i = 1, numSegments do
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
			local mountPoint = branchFrame.origin + branchFrame.forward * length
			local decor = prefab:Clone()
			decor.Name = "Decoration_" .. rule.modelId
			applyDecorationMode(decor, mountPoint, branchFrame, rule.mode, rule.jitter_deg, ctx.take)
			decor.Parent = branch
		elseif rule.where == "Center" then
			local mountPoint = branchFrame.origin + branchFrame.forward * (length * 0.5)
			local decor = prefab:Clone()
			decor.Name = "Decoration_" .. rule.modelId
			applyDecorationMode(decor, mountPoint, branchFrame, rule.mode, rule.jitter_deg, ctx.take)
			decor.Parent = branch
		end
	end
end

local function spawnBranch(
	parent: Instance,
	originFrame: FrameTransport.Frame,
	profile: Types.BranchProfile,
	parentSegmentLength: number,
	ctx: BuildCtx,
	debugInfo: {socketName: string}
): Model?
	if totalBranches >= ctx.limits.max_total_children then
		return nil
	end
	
	local branchModel = Instance.new("Model")
	branchModel.Name = "Branch_" .. profile.id
	branchModel:SetAttribute("ProfileId", profile.id)
	branchModel:SetAttribute("SocketOrigin", debugInfo.socketName)
	
	local miniSlicer = {
		take = ctx.take,
		sampleCurve = function(_, curve: Types.Curve)
			local u = ctx.take(16) / 65536
			local value = curve.mu + (u - 0.5) * 2 * curve.sigma
			return math.clamp(value, curve.lo, curve.hi)
		end
	}
	
	local lenFrac = miniSlicer:sampleCurve(profile.len_frac)
	local length = math.clamp(parentSegmentLength * lenFrac, 0.5, 5)
	
	local pitch = math.rad(miniSlicer:sampleCurve(profile.pitch_deg))
	local yaw = math.rad(miniSlicer:sampleCurve(profile.yaw_deg))
	
	local startFrame = originFrame
	local cf = FrameTransport.cframeFrom(startFrame)
	cf = cf * CFrame.Angles(pitch, yaw, 0)
	
	if profile.jitter_deg then
		local jitter = math.rad(miniSlicer:sampleCurve(profile.jitter_deg))
		cf = cf * CFrame.Angles(
			jitter * (ctx.take(8) / 256 - 0.5),
			jitter * (ctx.take(8) / 256 - 0.5),
			jitter * (ctx.take(8) / 256 - 0.5)
		)
	end
	
	local newFrame: FrameTransport.Frame = {
		origin = cf.Position,
		right = cf.RightVector,
		up = cf.UpVector,
		forward = -cf.LookVector
	}
	
	local radiusStart = (ctx.branchProfile and ctx.branchProfile.radiusStart) or 0.08
	local radiusEnd = (ctx.branchProfile and ctx.branchProfile.radiusEnd) or radiusStart
	local profileMode = (ctx.branchProfile and ctx.branchProfile.mode) or "uniform"
	local midScale = (ctx.branchProfile and ctx.branchProfile.midScale) or 1.15
	local segmentModel = ctx.branchProfile and ctx.branchProfile.segmentModel
	
	local segments = createBranchArm(
		newFrame, 
		length, 
		radiusStart, 
		radiusEnd, 
		profileMode,
		segmentModel,
		ctx.poleKit,
		midScale
	)
	
	for _, segment in ipairs(segments) do
		segment.Parent = branchModel
	end
	
	if profile.decorations then
		placeDecorations(branchModel, newFrame, length, profile.decorations, ctx)
	end
	
	branchModel.Parent = parent
	totalBranches = totalBranches + 1
	
	return branchModel
end

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
	local numToSpawn = 0
	
	if density then
		if ctx.take(10) / 1024 < density then
			numToSpawn = math.min(maxChildren, #profiles)
		end
	else
		numToSpawn = math.min(maxChildren, #profiles)
	end
	
	local parentSegmentLength = ctx.parentSegmentLength or 2.0
	
	for i = 1, numToSpawn do
		if totalBranches >= ctx.limits.max_total_children then
			break
		end
		
		local profileIndex = ((i - 1) % #profiles) + 1
		local profile = profiles[profileIndex]
		
		if profile.max_children > 0 then
			local branch = spawnBranch(parent, socketFrame, profile, parentSegmentLength, ctx, {socketName = socketName})
			if branch then
				spawnedCount = spawnedCount + 1
			end
		end
	end
	
	return spawnedCount
end

function BranchBuilder.buildBranches(root: Instance, spec: Types.BranchSpec, ctx: BuildCtx): ()
	totalBranches = 0

	local branchMode = ctx.branchMode or "default"
	local singleBranchMode = branchMode == "single"

	local function shouldStop(): boolean
		return singleBranchMode and totalBranches >= 1
	end

	for _, socketName in ipairs(spec.origins.base.sockets) do
		if shouldStop() then break end
		local socket = ctx.sockets[socketName]
		if socket then
			processBranchOrigin(root, socketName, socket, spec.origins.base.profiles, spec.limits.max_total_children - totalBranches, nil, ctx)
			if shouldStop() then break end
		end
	end

	for _, socketName in ipairs(spec.origins.trunk_mid.sockets) do
		if shouldStop() then break end
		local socket = ctx.sockets[socketName]
		if socket and totalBranches < ctx.limits.max_total_children then
			processBranchOrigin(root, socketName, socket, spec.origins.trunk_mid.profiles, ctx.limits.max_total_children - totalBranches, spec.origins.trunk_mid.density, ctx)
		end
	end

	if not shouldStop() then
		local tipSocket = ctx.sockets["Tip"]
		if tipSocket and totalBranches < ctx.limits.max_total_children then
			processBranchOrigin(root, "Tip", tipSocket, spec.origins.trunk_tip.profiles, ctx.limits.max_total_children - totalBranches, nil, ctx)
		end
	end
end

return BranchBuilder
