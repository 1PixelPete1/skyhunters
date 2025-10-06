--!strict
-- LanternFactory.luau
-- Main assembly module for dynamic lanterns

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = game.ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("LanternTypes"))
local Archetypes = require(Shared:WaitForChild("LanternArchetypes"))
local BitSlicer = require(Shared:WaitForChild("BitSlicer"))
local CurveEval = require(Shared:WaitForChild("CurveEval"))
local FrameTransport = require(Shared:WaitForChild("FrameTransport"))
local BranchBuilder = require(script.Parent:WaitForChild("BranchBuilder"))

local LanternFactory = {}

local POLE_OVERLAP = 0.15  -- Increased overlap to ensure segments connect properly
local SOCKET_POSITIONS = {
	S1 = 0.45,
	S2 = 0.80,
	Tip = 1.0
}

local function getMaxSegments(): number
	if RunService:IsStudio() then
		return 8
	else
		return 6
	end
end

local function hash64(plotId: string, pos: Vector3, version: number, kind: string): number
	local str = plotId .. "_" .. 
		math.floor(pos.X * 2) .. "_" .. 
		math.floor(pos.Y * 2) .. "_" .. 
		math.floor(pos.Z * 2) .. "_" .. 
		tostring(version) .. "_" .. 
		kind
	
	local hash = 5381
	for i = 1, #str do
		local c = string.byte(str, i)
		hash = bit32.bxor(bit32.lshift(hash, 5) + hash, c)
		hash = hash % 2147483647
	end
	
	return hash * 2654435761 % 4294967296
end

local function resolveParam(spec: Types.ParamSpec, slicer: BitSlicer.BitSlicer): number
	local value: number
	if spec.value ~= nil then
		value = spec.value
	elseif spec.rng then
		value = slicer:sampleCurve(spec.curve)
	else
		value = spec.curve.mu
	end

	if value ~= value or value == math.huge or value == -math.huge then
		value = spec.curve.mu
	end

	local lo = (spec.curve and spec.curve.lo) or value
	local hi = (spec.curve and spec.curve.hi) or value
	if hi < lo then
		hi = lo
	end

	return math.clamp(value, lo, hi)
end

local function createPoleSegment(
	startPos: Vector3,
	endPos: Vector3,
	startFrame: FrameTransport.Frame,
	endFrame: FrameTransport.Frame,
	radius: number,
	color: Color3?,
	orientationMode: string?
): Part
	local segment = Instance.new("Part")
	segment.Name = "PoleSegment"
	segment.Anchored = true
	segment.CanCollide = false
	segment.Material = Enum.Material.Wood
	segment.Color = color or Color3.fromRGB(92, 64, 51)

	local chord = endPos - startPos
	local chordLength = chord.Magnitude
	local length = chordLength + POLE_OVERLAP
	local midpoint = (startPos + endPos) * 0.5

	local tangentBlend = startFrame.forward + endFrame.forward
	local direction: Vector3

	if orientationMode == "tangent" and tangentBlend.Magnitude > 1e-5 then
		direction = tangentBlend.Unit
	else
		if chordLength > 1e-5 then
			direction = chord.Unit
		elseif tangentBlend.Magnitude > 1e-5 then
			direction = tangentBlend.Unit
		else
			direction = startFrame.forward.Unit
		end
	end

	segment.Shape = Enum.PartType.Cylinder
	-- FIXED: Cylinder Y-axis is the length
	segment.Size = Vector3.new(radius * 2, length, radius * 2)

	local upHint = startFrame.up + endFrame.up
	if upHint.Magnitude < 1e-5 then
		upHint = Vector3.yAxis
	else
		upHint = upHint.Unit
	end

	if math.abs(direction:Dot(upHint)) > 0.98 then
		upHint = math.abs(direction:Dot(Vector3.yAxis)) < 0.98 and Vector3.yAxis or Vector3.xAxis
	end

	local right = upHint:Cross(direction)
	if right.Magnitude < 1e-5 then
		right = (math.abs(direction:Dot(Vector3.xAxis)) < 0.98 and Vector3.xAxis or Vector3.zAxis):Cross(direction)
	end
	right = right.Unit

	local back = right:Cross(direction).Unit
	-- FIXED: Y-axis = direction (length of cylinder)
	segment.CFrame = CFrame.fromMatrix(midpoint, right, direction, back)

	return segment
end

local function buildPole(
	samples: {CurveEval.Sample},
	frames: {FrameTransport.Frame},
	radius: number,
	orientationMode: string?
): (Model, {[string]: FrameTransport.Frame})
	local poleModel = Instance.new("Model")
	poleModel.Name = "Pole"
	
	for i = 2, #samples do
		local startPos = samples[i-1].p
		local endPos = samples[i].p
		local startFrame = frames[i-1]
		local endFrame = frames[i]
		
		local segment = createPoleSegment(startPos, endPos, startFrame, endFrame, radius, nil, orientationMode)
		segment.Parent = poleModel
	end
	
	-- Return socket frames to be applied AFTER pivoting
	local sockets = FrameTransport.getSocketFrames(frames, SOCKET_POSITIONS)
	
	return poleModel, sockets
end

local function loadPrefab(kitPath: string, prefabName: string): Model?
	local kit = ReplicatedStorage:FindFirstChild("LanternKit")
	if not kit then
		warn("LanternKit not found in ReplicatedStorage")
		return nil
	end
	
	local category = kit:FindFirstChild(kitPath)
	if not category then
		warn("Kit category not found:", kitPath)
		return nil
	end
	
	local prefab = category:FindFirstChild(prefabName)
	if not prefab then
		warn("Prefab not found:", prefabName, "in", kitPath)
		return nil
	end
	
	return prefab:Clone()
end

export type AssembleOptions = {
	seed: number?,
	style: string?,
	paramOverrides: {[string]: number}?,
	curveOverrides: {[string]: number}?,
	designMode: boolean?,
	branchMode: string?,
	orientationMode: string?,
	branchProfile: {
		mode: string?,
		radiusStart: number?,
		radiusEnd: number?,
		midScale: number?,
		segmentModel: string?,
	}?,
}

local function assembleFromArchetype(
	archetypeName: string?,
	archetype: Types.Archetype?,
	plotId: string,
	position: Vector3,
	options: AssembleOptions?
): Model?
	if not archetype then
		warn("[LanternFactory] Missing archetype for designer build")
		return nil
	end

	options = options and table.clone(options) or {}
	local seed = options.seed or hash64(plotId, position, archetype.version, archetypeName or "Designer")
	options.seed = seed
	local slicer = BitSlicer.fromU64(seed)

	local params = {
		height = resolveParam(archetype.height, slicer),
		bend_deg = resolveParam(archetype.bend_deg, slicer),
		twist_deg = resolveParam(archetype.twist_deg, slicer),
		tip_drop = resolveParam(archetype.tip_drop, slicer),
		arm_len = resolveParam(archetype.arm_len, slicer),
		lantern_tilt = resolveParam(archetype.lantern_tilt, slicer),
		lantern_yaw = resolveParam(archetype.lantern_yaw, slicer),
		head_scale = resolveParam(archetype.head_scale, slicer),
		base_scale = resolveParam(archetype.base_scale, slicer),
		paint_wear = resolveParam(archetype.paint_wear, slicer),
	}
	
	params.height = math.max(params.height, 0.25)
	params.arm_len = math.max(params.arm_len, 0.05)
	params.head_scale = math.max(params.head_scale, 0.01)
	params.base_scale = math.max(params.base_scale, 0.01)
	params.paint_wear = math.clamp(params.paint_wear, 0, 1)
	
	if options.paramOverrides then
		for key, value in pairs(options.paramOverrides) do
			if params[key] ~= nil then
				params[key] = value
			end
		end
	end

	local style = options.style or slicer:weightedChoice(archetype.style_weights) or "straight"
	local orientationMode = options.orientationMode or "tangent"

	local lanternModel = Instance.new("Model")
	lanternModel.Name = "DynamicLantern"
	lanternModel:SetAttribute("Seed", seed)
	lanternModel:SetAttribute("Archetype", archetypeName or "Designer")
	lanternModel:SetAttribute("Style", style)
	lanternModel:SetAttribute("Height", params.height)
	lanternModel:SetAttribute("BendDeg", params.bend_deg)
	lanternModel:SetAttribute("TwistDeg", params.twist_deg)
	lanternModel:SetAttribute("TipDrop", params.tip_drop)
	lanternModel:SetAttribute("OrientationMode", orientationMode)
	if options.branchProfile and options.branchProfile.mode then
		lanternModel:SetAttribute("BranchProfileMode", options.branchProfile.mode)
	end

	local curveFn = CurveEval.getCurveFunction(style)
	if not curveFn then
		warn("[LanternFactory] Unknown curve style:", style)
		curveFn = CurveEval.straight
	end

	local curveOpts = table.clone(options.curveOverrides or {})
	curveOpts.bend_deg = params.bend_deg
	curveOpts.twist_deg = params.twist_deg
	curveOpts.tip_drop = params.tip_drop
	curveOpts.height = params.height
	curveOpts.min_lateral = curveOpts.min_lateral or math.max(params.height * 0.25, 1.25)
	curveOpts.radius_min = curveOpts.radius_min or math.max(params.height * 0.12, 1.25)
	if style == "helix" then
		curveOpts.radius = curveOpts.radius or math.max(params.height * 0.1, curveOpts.radius_min)
	end

	local maxSegments = getMaxSegments()
	local samples = CurveEval.evalAdaptive(curveFn, params.height, curveOpts, 0.08, 3, maxSegments)
	local frames = FrameTransport.buildFrames(samples)

	-- Position base at spawn location
	print("[FACTORY] Received spawn position:", position)
	local baseName = slicer:weightedChoice(archetype.base_set)
	local baseOffset = Vector3.new(0, 0, 0)
	
	if baseName then
		local base = loadPrefab("Base", baseName)
		if base then
			base.Name = "Base"
			base:ScaleTo(params.base_scale)
			-- Keep base at origin for now, will pivot entire lantern later
			base.Parent = lanternModel
			
			local baseTop = base:FindFirstChild("TopSocket", true)
			if baseTop and baseTop:IsA("Attachment") then
				-- Get the local offset of base top
				baseOffset = baseTop.Position
				print("[FACTORY] Base top local offset:", baseOffset)
				-- Shift all frames by this offset so pole starts at base top
				for i = 1, #frames do
					frames[i].origin = frames[i].origin + baseOffset
				end
				-- Update samples too
				for i = 1, #samples do
					samples[i].p = samples[i].p + baseOffset
				end
			end
		end
	end

	-- Rebuild pole starting from base top
	local pole, poleSockets = buildPole(samples, frames, 0.15, orientationMode)
	pole.Parent = lanternModel

	-- Position the lantern FIRST
	lanternModel:PivotTo(CFrame.new(position))
	print("[FACTORY] Final pivot to position:", position)
	print("[FACTORY] Lantern final position:", lanternModel:GetPivot().Position)

	-- NOW create socket attachments in local space
	for name, frame in pairs(poleSockets) do
		local attachment = Instance.new("Attachment")
		attachment.Name = name
		-- Use local CFrame - they're already in local space relative to pole origin
		attachment.CFrame = FrameTransport.cframeFrom(frame)
		attachment.Parent = pole
	end

	-- After pivoting, get socket frames in WORLD space for branch building
	local sockets = {}
	for name in pairs(poleSockets) do
		local attachment = pole:FindFirstChild(name)
		if attachment and attachment:IsA("Attachment") then
			local worldCF = attachment.WorldCFrame
			sockets[name] = {
				origin = worldCF.Position,
				right = worldCF.RightVector,
				up = worldCF.UpVector,
				forward = -worldCF.LookVector  -- Frame uses forward, CFrame uses -LookVector
			}
			print("[SOCKET]", name, "at:", worldCF.Position)
		end
	end

	-- Add BaseTop socket frame for branch building
	local baseModel = lanternModel:FindFirstChild("Base")
	if baseModel then
		local baseTop = baseModel:FindFirstChild("TopSocket", true)
		if baseTop and baseTop:IsA("Attachment") then
			sockets["BaseTop"] = FrameTransport.frameFromLook(baseTop.WorldPosition, Vector3.yAxis)
			print("[SOCKET] BaseTop at:", baseTop.WorldPosition)
		end
	end

	if archetype.branches then
		local kit = ReplicatedStorage:FindFirstChild("LanternKit")
		local poleKit = kit and kit:FindFirstChild("Pole")
		local headKit = kit and kit:FindFirstChild("Head")
		local decorKit = kit and kit:FindFirstChild("Decor")
		local limits = archetype.branches.limits
		if options.designMode and options.branchMode == "single" then
			limits = table.clone(limits)
			limits.max_total_children = math.min(limits.max_total_children, 1)
		end
		local parentSegmentLength = (#samples > 0) and (params.height / #samples) or params.height
		local ctx = {
			take = function(bits: number) return slicer:take(bits) end,
			frames = frames,
			sockets = sockets,
			limits = limits,
			poleKit = poleKit,
			headKit = headKit,
			decorKit = decorKit,
			parentSegmentLength = parentSegmentLength,
			branchMode = options.branchMode,
			designMode = options.designMode or false,
			branchProfile = options.branchProfile,
			orientationMode = orientationMode,
		}
		BranchBuilder.buildBranches(lanternModel, archetype.branches, ctx)
	end

	local headName = slicer:weightedChoice(archetype.head_set)
	if headName then
		local head = loadPrefab("Head", headName)
		if head then
			head.Name = "Head"
			head:ScaleTo(params.head_scale)
			local tipFrame = frames[#frames]
			if tipFrame then
				local tipCFrame = FrameTransport.cframeFrom(tipFrame)
				local tiltRad = math.rad(params.lantern_tilt)
				local yawRad = math.rad(params.lantern_yaw)
				tipCFrame = tipCFrame * CFrame.Angles(tiltRad, yawRad, 0)
				local hangSocket = head:FindFirstChild("HangSocket", true)
				if hangSocket and hangSocket:IsA("Attachment") then
					local offset = hangSocket.Position
					head:PivotTo(tipCFrame * CFrame.new(-offset))
				else
					head:PivotTo(tipCFrame)
				end
			end
			head.Parent = lanternModel
		end
	end

	return lanternModel
end

function LanternFactory.assembleLantern(
	plotId: string,
	position: Vector3,
	archetypeName: string,
	options: AssembleOptions?
): Model?
	local archetype = Archetypes[archetypeName]
	if not archetype then
		warn("Unknown archetype:", archetypeName)
		return nil
	end
	return assembleFromArchetype(archetypeName, archetype, plotId, position, options)
end

function LanternFactory.assembleDesigner(
	plotId: string,
	position: Vector3,
	archetype: Types.Archetype,
	options: AssembleOptions?
): Model?
	return assembleFromArchetype(nil, archetype, plotId, position, options)
end

return LanternFactory
