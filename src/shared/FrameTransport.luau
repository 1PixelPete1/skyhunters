--!strict
-- FrameTransport.luau
-- Parallel transport frames for smooth orientation along curves

local CurveEval = require(script.Parent.CurveEval)

export type Frame = {
	origin: Vector3,
	right: Vector3,
	up: Vector3,
	forward: Vector3
}

local FrameTransport = {}

-- Build parallel transport frames along a curve
function FrameTransport.buildFrames(samples: {CurveEval.Sample}, up0: Vector3?): {Frame}
	local frames = {}
	
	if #samples == 0 then
		return frames
	end
	
	-- Initial up vector (prefer Y-up if not specified)
	local initialUp = up0 or Vector3.yAxis
	
	-- Handle single sample case
	if #samples == 1 then
		local sample = samples[1]
		local forward = sample.t
		
		-- Build orthonormal basis
		local right = forward:Cross(initialUp)
		if right.Magnitude < 0.001 then
			-- Forward is parallel to up, use alternative
			right = forward:Cross(Vector3.xAxis)
			if right.Magnitude < 0.001 then
				right = forward:Cross(Vector3.zAxis)
			end
		end
		right = right.Unit
		
		local up = right:Cross(forward).Unit
		
		table.insert(frames, {
			origin = sample.p,
			right = right,
			up = up,
			forward = forward
		})
		return frames
	end
	
	-- Initialize first frame
	local firstSample = samples[1]
	local forward = firstSample.t
	
	-- Build initial orthonormal basis
	local right = forward:Cross(initialUp)
	if right.Magnitude < 0.001 then
		-- Forward is parallel to initial up, use alternative
		right = forward:Cross(Vector3.xAxis)
		if right.Magnitude < 0.001 then
			right = forward:Cross(Vector3.zAxis)
		end
	end
	right = right.Unit
	
	local up = right:Cross(forward).Unit
	
	table.insert(frames, {
		origin = firstSample.p,
		right = right,
		up = up,
		forward = forward
	})
	
	-- Parallel transport for remaining frames
	for i = 2, #samples do
		local prevFrame = frames[i - 1]
		local sample = samples[i]
		local newForward = sample.t
		
		-- Compute rotation from previous forward to new forward
		local prevForward = prevFrame.forward
		local axis = prevForward:Cross(newForward)
		
		if axis.Magnitude < 0.001 then
			-- Directions are parallel, keep the same frame
			right = prevFrame.right
			up = prevFrame.up
		else
			-- Rotate the frame
			axis = axis.Unit
			local angle = math.acos(math.clamp(prevForward:Dot(newForward), -1, 1))
			
			-- Rodrigues' rotation formula
			local cosAngle = math.cos(angle)
			local sinAngle = math.sin(angle)
			local oneMinusCos = 1 - cosAngle
			
			-- Rotate right vector
			local r = prevFrame.right
			right = r * cosAngle +
				axis:Cross(r) * sinAngle +
				axis * (axis:Dot(r)) * oneMinusCos
			right = right.Unit
			
			-- Compute up from right and forward
			up = newForward:Cross(right).Unit
		end
		
		table.insert(frames, {
			origin = sample.p,
			right = right,
			up = up,
			forward = newForward
		})
	end
	
	return frames
end

-- Convert a Frame to CFrame
function FrameTransport.cframeFrom(frame: Frame): CFrame
	-- Construct rotation matrix
	-- CFrame expects: rightVector, upVector, -lookVector (backward)
	return CFrame.fromMatrix(
		frame.origin,
		frame.right,
		frame.up,
		-frame.forward  -- CFrame uses -Z as forward
	)
end

-- Get frame at normalized parameter t along the frames
function FrameTransport.interpolateFrame(frames: {Frame}, t: number): Frame
	t = math.clamp(t, 0, 1)
	
	if #frames < 2 then
		return frames[1] or {
			origin = Vector3.zero,
			right = Vector3.xAxis,
			up = Vector3.yAxis,
			forward = Vector3.zAxis
		}
	end
	
	-- Handle edge cases
	if t <= 0 then return frames[1] end
	if t >= 1 then return frames[#frames] end
	
	-- Find segment
	local totalSegments = #frames - 1
	local scaledT = t * totalSegments
	local segmentIndex = math.floor(scaledT) + 1
	local localT = scaledT - math.floor(scaledT)
	
	-- Clamp segment index
	segmentIndex = math.clamp(segmentIndex, 1, #frames - 1)
	
	local f0 = frames[segmentIndex]
	local f1 = frames[segmentIndex + 1]
	
	-- Interpolate position
	local origin = f0.origin:Lerp(f1.origin, localT)
	
	-- Slerp rotation vectors
	local right = f0.right:Lerp(f1.right, localT).Unit
	local up = f0.up:Lerp(f1.up, localT).Unit
	local forward = f0.forward:Lerp(f1.forward, localT).Unit
	
	-- Re-orthogonalize to ensure valid frame
	forward = forward.Unit
	right = forward:Cross(up)
	if right.Magnitude < 0.001 then
		right = f0.right
	end
	right = right.Unit
	up = right:Cross(forward).Unit
	
	return {
		origin = origin,
		right = right,
		up = up,
		forward = forward
	}
end

-- Get socket frames at specific normalized positions
function FrameTransport.getSocketFrames(frames: {Frame}, positions: {[string]: number}): {[string]: Frame}
	local sockets = {}
	
	for name, t in pairs(positions) do
		sockets[name] = FrameTransport.interpolateFrame(frames, t)
	end
	
	return sockets
end

-- Utility: Create a frame from position and look direction
function FrameTransport.frameFromLook(origin: Vector3, lookDir: Vector3, upHint: Vector3?): Frame
	local forward = lookDir.Unit
	local up = upHint or Vector3.yAxis
	
	local right = forward:Cross(up)
	if right.Magnitude < 0.001 then
		-- Look direction is parallel to up, choose alternative
		right = forward:Cross(Vector3.xAxis)
		if right.Magnitude < 0.001 then
			right = forward:Cross(Vector3.zAxis)
		end
	end
	right = right.Unit
	
	up = right:Cross(forward).Unit
	
	return {
		origin = origin,
		right = right,
		up = up,
		forward = forward
	}
end

return FrameTransport
