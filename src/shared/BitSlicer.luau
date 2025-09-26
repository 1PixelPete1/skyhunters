--!strict
-- BitSlicer.luau
-- Single-draw RNG system that derives all uniforms from one 64-bit seed

local BitSlicer = {}
BitSlicer.__index = BitSlicer

export type BitSlicer = {
	seed: number,
	position: number,
	take: (self: BitSlicer, bits: number) -> number
}

-- Create a new BitSlicer from a 64-bit unsigned integer
function BitSlicer.fromU64(u64: number): BitSlicer
	local self = setmetatable({
		seed = u64,
		position = 0
	}, BitSlicer)
	return self
end

-- Extract 'bits' bits and return as a uniform value in [0,1)
function BitSlicer:take(bits: number): number
	if bits <= 0 or bits > 32 then
		error("BitSlicer:take requires bits in range [1,32]")
	end
	
	-- Use rotating bit extraction with mixing
	local mask = bit32.lshift(1, bits) - 1
	
	-- Extract bits from current position
	local shift = self.position % 64
	local value
	
	if shift + bits <= 64 then
		-- Can extract all bits from current position
		value = bit32.band(bit32.rshift(self.seed, shift), mask)
	else
		-- Need to wrap around (extract from both ends)
		local lowBits = 64 - shift
		local highBits = bits - lowBits
		local lowMask = bit32.lshift(1, lowBits) - 1
		local highMask = bit32.lshift(1, highBits) - 1
		
		local lowPart = bit32.band(bit32.rshift(self.seed, shift), lowMask)
		local highPart = bit32.band(self.seed, highMask)
		
		value = bit32.bor(lowPart, bit32.lshift(highPart, lowBits))
	end
	
	-- Mix the extracted value with position for better distribution
	value = bit32.bxor(value, bit32.band(self.position * 0x9E3779B9, mask))
	
	-- Advance position
	self.position = (self.position + bits) % 64
	
	-- Convert to uniform [0,1)
	return value / (2^bits)
end

-- Utility: Sample from a Gaussian distribution using Box-Muller transform
function BitSlicer:gaussian(mean: number, stddev: number): number
	-- Box-Muller requires two uniform samples
	local u1 = self:take(16)
	local u2 = self:take(16)
	
	-- Avoid log(0)
	u1 = math.max(u1, 0.0001)
	
	-- Box-Muller transform
	local z0 = math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2)
	
	return mean + stddev * z0
end

-- Utility: Sample from a curve specification with clamping
function BitSlicer:sampleCurve(curve: {mu: number, sigma: number, lo: number, hi: number}): number
	local value = self:gaussian(curve.mu, curve.sigma)
	return math.clamp(value, curve.lo, curve.hi)
end

-- Utility: Weighted random selection
function BitSlicer:weightedChoice(weights: {[string]: number}): string?
	local total = 0
	for _, weight in pairs(weights) do
		total = total + weight
	end
	
	if total <= 0 then
		return nil
	end
	
	local r = self:take(16) * total
	local cumulative = 0
	
	for key, weight in pairs(weights) do
		cumulative = cumulative + weight
		if r < cumulative then
			return key
		end
	end
	
	-- Fallback (shouldn't reach here)
	for key, _ in pairs(weights) do
		return key
	end
	
	return nil
end

-- Utility: Bernoulli trial (returns true with probability p)
function BitSlicer:bernoulli(p: number): boolean
	return self:take(10) < p
end

-- Utility: Integer in range [min, max] inclusive
function BitSlicer:intRange(min: number, max: number): number
	if min > max then
		min, max = max, min
	end
	local range = max - min + 1
	local bits = math.ceil(math.log(range) / math.log(2))
	
	-- Rejection sampling to ensure uniform distribution
	local mask = bit32.lshift(1, bits) - 1
	local value
	repeat
		value = self:take(bits) * (mask + 1)
		value = math.floor(value)
	until value < range
	
	return min + value
end

return BitSlicer
