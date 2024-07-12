--!strict
--!native
--!optimize 2

local types						= require(script.Parent.types)

--- ### Math.luau
---
--- extension of math library
local K_Math = {
	tau							= math.pi * 2;
	radian						= math.rad(1);

	NumberSequenceZero			= NumberSequence.new(0);
	NumberSequenceOne			= NumberSequence.new(1);
}

--- returns cooldown value of x with respect to deltatime \
--- solves `"%x per second"`, where `x ∈ [0, 100]`
function K_Math.cooldownrate(x: number, deltatime: number): number
	return deltatime * (100 / x)
end

--- returns regen value of x with respect to deltatime \
--- solves `"x per second"`, where `x ∈ ℝ`
function K_Math.regenrate(x: number, deltatime: number): number
	return deltatime * x
end

--- returns `x ^ y` \
--- *in contexts where `y == 2`, returns `x * x`*
function K_Math.pow(x: number, y: number): number
	return y == 2 and x * x or x ^ y
end

--- returns `x ^ 0.5`
function K_Math.sqrt(x: number): number
	return x ^ 0.5
end

--- linearly interpolates `x` towards `y` with respect to interpolant `a`
function K_Math.lerp(x: number, y: number, a: number): number
	return (1 - a) * x + a * y;
end

--- returns `b` as an interpolant between `x` and `y`, where `b ∈ [x, y]`
function K_Math.alpha(x: number, y: number, b: number): number
	if b >= y then
		return 1
	elseif b <= x then
		return 0
	end

	return (b - x) / (y - x)
end

--- maps `x` such that `x ∈ [a, b] ⟶ [c, d]`
function K_Math.map(x: number, a: number, b: number, c: number, d: number): number
	return (x - a) * (d - c) / (b - a) + c;
end

--- returns true if `x ∈ [a, b]`
function K_Math.inrange(x: number, a: number, b: number): boolean
	if x >= a and x <= b then
		return true
	end

	return false
end

--- shifts `x` `a` times around limit `b` \
--- `Shift(5, 1, 6) -> 6` \
--- `Shift(5, 2, 6) -> 1` \
--- `Shift(1, -3, 6) -> 4`
function K_Math.shift(x: number, a: number, b: number): number
	local s = x + (math.sign(a) * (a % b))

	if a == 0 then
		return x
	elseif s > b then
		return s - b
	elseif s < 1 then
		return s + b
	end

	return s
end

--- returns winner of rally point game with minimum `score` given team 1 points `k` and team 2 points `k` \
--- `RallyPoint(25, 24, 25) -> 0` \
--- `RallyPoint(25, 25, 27) -> 2` \
--- `RallyPoint(25, 25, 0) -> 1`
function K_Math.rallypoint(score: number, h: number, k: number): number
	if (h >= score) and (h - k >= 2) then
		return 1
	elseif (k >= score) and (k - h >= 2) then
		return 2
	end

	return 0
end

--- returns winner of best-of `series` given team 1 wins `h` and team 2 wins `k` \
--- `BestOf(3, 1, 2) -> 2` \
--- `BestOf(5, 2, 2) -> 0` \
--- `BestOf(7, 4, 3) -> 1`
function K_Math.bestof(series: number, h: number, k: number): number
	local wins = 1 + (series // 2)

	if h == wins then
		return 1
	elseif k == wins then
		return 2
	end

	return 0
end

--- returns `x` scaled against limit `a ∈ [0, inf]` with slope scalar `k ∈ [steep, flat]` \
--- `y=\frac{ax}{k+x}`
function K_Math.limit(x: number, a: number, k: number): number
	return (a * x) / (k + x)
end

--- returns cartesian coordinates of point `p` with respect to grid width `w` \
--- assumes a zero-indexed cartesian plane, read from `left -> right`, `top -> bottom` \
--- `cartesian(3, 2)`: `"point #3 on a 2-width grid" -> (0, 1)` \
--- `cartesian(7, 3)`: `"point #7 on a 3-width grid" -> (2, 0)`
function K_Math.cartesian(p: number, w: number): (number, number)
	p -= 1
	return p % w, p // w
end

--- scales numbersequence by x
function K_Math.scalenumbersequence(numbersequence: NumberSequence, x: number): NumberSequence
	local NewSequence = {}
	for _,Keypoint in ipairs(numbersequence.Keypoints) do
		local NewValue = Keypoint.Value * x
		table.insert(NewSequence,NumberSequenceKeypoint.new(Keypoint.Time,NewValue))
	end
	return NumberSequence.new(NewSequence)
end

--- converts `x`, where `x ∈ [0, 1]`, to a numbersequence
function K_Math.alphatonumbersequence(x: number): NumberSequence
	if x <= 0.01 then
		return K_Math.NumberSequenceZero
	elseif x == 1 then
		return K_Math.NumberSequenceOne
	elseif x >= 0.99 then
		return K_Math.NumberSequenceOne
	end
	x = math.clamp(x, 0, 1)
	return NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0);
		NumberSequenceKeypoint.new(x, 0);
		NumberSequenceKeypoint.new(math.clamp(x + 0.001, 0, 1), 1);
		NumberSequenceKeypoint.new(1, 1);
	})
end

--- returns a unit circle \
--- *in contexts where `vertices == 1`, the vertex is placed at `x = -r`* \
--- *in contexts where `vertices == 2`, the vertices are placed at `x = ±r`*
function K_Math.unitcircle(vertices: number, radius: number): { types.UnitCircleVertex }
	if vertices == 1 then
		return { {X = -radius; Z = 0;} }
	elseif vertices == 2 then
		return { {X = -radius; Z = 0;}, {X = radius; Z = 0;} }
	end

	local Step = K_Math.tau / vertices
	local Tilt = math.pi / vertices
	local V = table.create(vertices)
	for i = 1, vertices do
		local a = (i * Step) - Tilt
		table.insert(V, { X = radius * math.cos(a); Z = radius * math.sin(a); })
	end

	return V
end

return table.freeze(K_Math)