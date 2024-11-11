--!strict
--!native
--!optimize 2

local types = require(script.Parent.types)

--- ### Math.luau
---
--- extension of math library
local K_Math = {
	pi4 = math.pi/4;
	pi2 = math.pi/2;

	tau = math.pi*2;
	radian = math.rad(1);

	NumberSequence = table.freeze{
		zero = NumberSequence.new(0);
		one = NumberSequence.new(0);
	};
	NumberRange = table.freeze{
		zero = NumberRange.new(0);
		one = NumberRange.new(0);

		zeroOne = NumberRange.new(0, 1);
		zeroTen = NumberRange.new(0, 10);
		zeroHundred = NumberRange.new(0, 100);
	};

	random = Random.new();
}

--- returns cooldown value of x with respect to deltatime \
--- solves `"%x per second"`, where `x ∈ [0, 100]`
function K_Math.cooldownrate(x: number, dt: number): number
	return dt * (100 / x)
end

--- returns regen value of x with respect to deltatime \
--- solves `"x per second"`, where `x ∈ ℝ`
function K_Math.regenrate(x: number, dt: number): number
	return dt * x
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

--- returns interpolant with respect to deltatime (`1 - (x ^ dt)`) \
--- `x` is ideally passed in `e-` notation form (such as `10e-11`)
function K_Math.interpolant(x: number, dt: number): number
	return 1 - (x ^ dt)
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

--- returns: \
--- where `x ∈ [a, b]`: `true` \
--- where `x ∉ [a, b]`: `false`
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
	x += a
	local c = x % b
	return c == 0 and b or c
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

--- returns `x` scaled against limit where `a ∈ [0, ∞]` and slope scalar where `k ∈ [steep, flat]` \
--- `y=\frac{ax}{k+x}`
function K_Math.limit(x: number, a: number, k: number): number
	return (a * x) / (k + x)
end

--- returns cartesian coordinates of point `p` with respect to grid width `w` \
--- assumes a zero-indexed cartesian plane, read from `left -> right`, `top -> bottom` \
function K_Math.cartesian(p: number, w: number): (number, number)
	p -= 1
	return p // w, p % w
end

--- returns center-aligned number-line coordinates given size `x` \
--- `aligncenter(2)`: `[-0.5, 0.5]` \
--- `aligncenter(3, true)`: `[1, 0, -1]` \
--- `aligncenter(5)`: `[-2, -1, 0, 1, 2]`
function K_Math.aligncenter(x: number, reverse: boolean?): {number}
	if x == 1 then
		return table.create(1, 0)
	else
		local t = table.create(x)
		local shift = 1 + x // 2
		for i = 1, x do
			i -= shift
			if x % 2 == 0 then
				i += 0.5
			end
			
			if reverse then
				i *= -1
			end

			table.insert(t, i)
		end
		return t
	end
end

--- returns a falloff value in `[0, 1]` given `x`, where `x in [a, b]` is the most optimal: \
--- where `x in [0, a)`: `[0, 1)` \
--- where `x in [a, b]`: `{1}` \
--- where `x in (b, c]`: `(1, 0]` \
--- where `x in (c, ∞]`: `{0}`
function K_Math.falloff(x: number, a: number, b: number, c: number): number
	if x < a then
		return x / a
	elseif x > c then
		return 0
	elseif x > b then
		return 1 - (x - b) / (c - b)
	else
		return 1
	end
end

--- returns value of sine wave (`a * math.sin(x / b) + k`) with respect to time `t` \
--- `a`: amplitude \
--- `t`: time \
--- `b`: frequency \
--- `k`: offset of wave from 0
function K_Math.sinewave(a: number, t: number, b: number, k: number): number
	return a * math.sin(t / b) + k
end

--- scales numbersequence by `x`
function K_Math.scalenumbersequence(numbersequence: NumberSequence, x: number): NumberSequence
	local NewSequence = {}
	for _, Keypoint in ipairs(numbersequence.Keypoints) do
		local NewValue = Keypoint.Value * x
		table.insert(NewSequence,NumberSequenceKeypoint.new(Keypoint.Time,NewValue))
	end
	return NumberSequence.new(NewSequence)
end

--- converts `x`, where `x in [0, 1]`, to a numbersequence
function K_Math.alphatonumbersequence(x: number): NumberSequence
	if x <= 0.01 then
		return K_Math.NumberSequence.zero
	elseif x == 1 then
		return K_Math.NumberSequence.one
	elseif x >= 0.99 then
		return K_Math.NumberSequence.one
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