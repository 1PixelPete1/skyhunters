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

-- Constants
local POLE_OVERLAP = 0.02  -- Small overlap to hide seams
local SOCKET_POSITIONS = {
	S1 = 0.45,  -- 45% up the pole
	S2 = 0.80,  -- 80% up the pole
	Tip = 1.0   -- At the tip
}

-- Platform-specific LOD settings
local function getMaxSegments(): number
	if RunService:IsStudio() then
		return 8
	else
		-- Could check for mobile platform here
		return 6
	end
end

-- Hash function for deterministic seed generation
local function hash64(plotId: string, pos: Vector3, version: number, kind: string): number
	-- Simple hash combining inputs
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
		hash = hash % 2147483647  -- Keep it positive
	end
	
	-- Extend to 64-bit-ish (Luau number limitations)
	return hash * 2654435761 % 4294967296
end

-- Resolve parameter value from spec
local function resolveParam(spec: Types.ParamSpec, slicer: BitSlicer.BitSlicer): number
	if spec.value then
		-- Parameter is locked
		return spec.value
	elseif spec.rng then
		-- Sample from curve
		return slicer:sampleCurve(spec.curve)
	else
		-- Default to mean
		return spec.curve.mu
	end
end

-- Create a cylinder segment for the pole
local function createPoleSegment(
	startPos: Vector3,
	endPos: Vector3,
	radius: number,
	color: Color3?
): Part
	local segment = Instance.new("Part")
	segment.Name = "PoleSegment"
	segment.Anchored = true
	segment.CanCollide = false
	segment.Material = Enum.Material.Wood
	segment.Color = color or Color3.fromRGB(92, 64, 51)
	
	-- Calculate dimensions
	local length = (endPos - startPos).Magnitude + POLE_OVERLAP
	local midpoint = (startPos + endPos) / 2
	local direction = (endPos - startPos).Unit
	
	-- Set size (cylinder along Y axis)
	segment.Shape = Enum.PartType.Cylinder
	segment.Size = Vector3.new(length, radius * 2, radius * 2)
	
	-- Orient cylinder
	local cf = CFrame.lookAt(midpoint, midpoint + direction)
	-- Rotate 90 degrees to align cylinder axis with direction
	segment.CFrame = cf * CFrame.Angles(0, math.pi/2, 0)
	
	return segment
end

-- Build the pole from curve samples
local function buildPole(
	samples: {CurveEval.Sample},
	frames: {FrameTransport.Frame},
	radius: number
): Model
	local poleModel = Instance.new("Model")
	poleModel.Name = "Pole"
	
	-- Create segments between consecutive samples
	for i = 2, #samples do
		local startPos = samples[i-1].p
		local endPos = samples[i].p
		
		local segment = createPoleSegment(startPos, endPos, radius)
		segment.Parent = poleModel
	end
	
	-- Add socket attachments
	local sockets = FrameTransport.getSocketFrames(frames, SOCKET_POSITIONS)
	
	for name, frame in pairs(sockets) do
		local attachment = Instance.new("Attachment")
		attachment.Name = name
		attachment.CFrame = FrameTransport.cframeFrom(frame)
		attachment.Parent = poleModel
	end
	
	return poleModel
end

-- Load a prefab from the kit
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

-- Main assembly function
function LanternFactory.assembleLantern(
	plotId: string,
	position: Vector3,
	archetypeName: string,
	overrideSeed: number?
): Model?
	-- Get archetype
	local archetype = Archetypes[archetypeName]
	if not archetype then
		warn("Unknown archetype:", archetypeName)
		return nil
	end
	
	-- Generate seed
	local seed = overrideSeed or hash64(plotId, position, archetype.version, archetypeName)
	local slicer = BitSlicer.fromU64(seed)
	
	-- Resolve all parameters
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
	
	-- Pick style
	local style = slicer:weightedChoice(archetype.style_weights) or "straight"
	
	-- Create root model
	local lanternModel = Instance.new("Model")
	lanternModel.Name = "DynamicLantern"
	
	-- Store attributes for debugging
	lanternModel:SetAttribute("Seed", seed)
	lanternModel:SetAttribute("Archetype", archetypeName)
	lanternModel:SetAttribute("Style", style)
	lanternModel:SetAttribute("Height", params.height)
	
	-- Generate curve
	local curveFn = CurveEval.getCurveFunction(style)
	if not curveFn then
		warn("Unknown curve style:", style)
		curveFn = CurveEval.straight
	end
	
	local curveOpts = {
		bend_deg = params.bend_deg,
		twist_deg = params.twist_deg,
		tip_drop = params.tip_drop
	}
	
	-- Adaptive sampling
	local maxSegments = getMaxSegments()
	local samples = CurveEval.evalAdaptive(curveFn, params.height, curveOpts, 0.08, 3, maxSegments)
	
	-- Build frames
	local frames = FrameTransport.buildFrames(samples)
	
	-- Build pole
	local pole = buildPole(samples, frames, 0.15)  -- Default radius
	pole.Parent = lanternModel
	
	-- Pick and place base
	local baseName = slicer:weightedChoice(archetype.base_set)
	if baseName then
		local base = loadPrefab("Base", baseName)
		if base then
			base.Name = "Base"
			base:ScaleTo(params.base_scale)
			
			-- Position at origin
			base:PivotTo(CFrame.new(position))
			base.Parent = lanternModel
			
			-- Add BaseTop socket to our socket list
			local baseTop = base:FindFirstChild("TopSocket", true)
			if baseTop and baseTop:IsA("Attachment") then
				local socketFrame = FrameTransport.frameFromLook(
					baseTop.WorldPosition,
					Vector3.yAxis
				)
				frames[1] = socketFrame  -- Override first frame with base socket
			end
		end
	end
	
	-- Get socket frames for branches
	local sockets = FrameTransport.getSocketFrames(frames, SOCKET_POSITIONS)
	
	-- Add BaseTop to sockets if we have a base
	local base = lanternModel:FindFirstChild("Base")
	if base then
		local baseTop = base:FindFirstChild("TopSocket", true)
		if baseTop and baseTop:IsA("Attachment") then
			sockets["BaseTop"] = FrameTransport.frameFromLook(
				baseTop.WorldPosition,
				Vector3.yAxis
			)
		end
	end
	
	-- Build branches
	if archetype.branches then
		local poleKit = ReplicatedStorage:FindFirstChild("LanternKit"):FindFirstChild("Pole")
		local headKit = ReplicatedStorage:FindFirstChild("LanternKit"):FindFirstChild("Head")
		local decorKit = ReplicatedStorage:FindFirstChild("LanternKit"):FindFirstChild("Decor")
		
		local ctx = {
			take = function(bits: number) return slicer:take(bits) end,
			frames = frames,
			sockets = sockets,
			limits = archetype.branches.limits,
			poleKit = poleKit,
			headKit = headKit,
			decorKit = decorKit
		}
		
		BranchBuilder.buildBranches(lanternModel, archetype.branches, ctx)
	end
	
	-- Pick and place head at tip
	local headName = slicer:weightedChoice(archetype.head_set)
	if headName then
		local head = loadPrefab("Head", headName)
		if head then
			head.Name = "Head"
			head:ScaleTo(params.head_scale)
			
			-- Get tip frame
			local tipFrame = frames[#frames]
			local tipCFrame = FrameTransport.cframeFrom(tipFrame)
			
			-- Apply tilt and yaw
			local tiltRad = math.rad(params.lantern_tilt)
			local yawRad = math.rad(params.lantern_yaw)
			tipCFrame = tipCFrame * CFrame.Angles(tiltRad, yawRad, 0)
			
			-- Position head
			local hangSocket = head:FindFirstChild("HangSocket", true)
			if hangSocket and hangSocket:IsA("Attachment") then
				-- Offset head so HangSocket aligns with tip
				local offset = hangSocket.Position
				head:PivotTo(tipCFrame * CFrame.new(-offset))
			else
				head:PivotTo(tipCFrame)
			end
			
			head.Parent = lanternModel
		end
	end
	
	-- Position entire model
	lanternModel:PivotTo(CFrame.new(position))
	
	return lanternModel
end

return LanternFactory
