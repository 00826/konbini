--!strict
--!native
--!optimize 2

--- ### Math.luau
---
--- math library extension
local MathK = {
	NumberSequence = {
		zero = NumberSequence.new(0);
		one = NumberSequence.new(1);

		zeroone = NumberSequence.new(0, 1);
		onezero = NumberSequence.new(1, 0);
	};
	NumberRange = {
		zero = NumberRange.new(0);
		one = NumberRange.new(1);

		zeroone = NumberRange.new(0, 1);
		onezero = NumberRange.new(1, 0);
	};

	random = Random.new();
}

--- returns whether or not `x` is finite
function MathK.isfinite(x: number)
	return x == x and x ~= 1/0 and x ~= -1/0
end

--- returns interpolant with respect to deltatime (`1 - (x ^ dt)`) \
--- `x` is ideally passed in `e-` notation form (such as `10e-11`)
function MathK.interpolant(x: number, dt: number)
	return 1 - (x ^ dt)
end

--- returns: \
--- where `x ∈ [a, b]`: `true` \
--- where `x ∉ [a, b]`: `false`
function MathK.inrange(x: number, a: number, b: number)
	if x >= a and x <= b then
		return true
	end

	return false
end

--- shifts `x` `a` times around limit `b` \
--- `Shift(5, 1, 6) -> 6` \
--- `Shift(5, 2, 6) -> 1` \
--- `Shift(1, -3, 6) -> 4`
function MathK.shift(x: number, a: number, b: number)
	x += a
	local c = x % b

	return c == 0 and b or c
end

--- returns `n`-th value of the fibonacci sequence
function MathK.fibonacci(n: number)
	local a = 1 / (5^0.5)
	local b = (( 1 + (5^0.5) ) / 2)^n
	local c = (( 1 - (5^0.5) ) / 2)^n
	
	return math.round(a*b - a*c)
end

--- returns winner of rally point game with minimum `score` given team 1 points `k` and team 2 points `k` \
--- `RallyPoint(25, 24, 25) -> 0` \
--- `RallyPoint(25, 25, 27) -> 2` \
--- `RallyPoint(25, 25, 0) -> 1`
function MathK.rallypoint(score: number, h: number, k: number)
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
function MathK.bestof(series: number, h: number, k: number)
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
function MathK.limit(x: number, a: number, k: number)
	return (a * x) / (k + x)
end

--- returns cartesian coordinates of point `p` with respect to grid width `w` \
--- assumes a zero-indexed cartesian plane, read from `left -> right`, `top -> bottom` \
function MathK.cartesian(p: number, w: number)
	p -= 1
	return p // w, p % w
end

--- returns center-aligned number-line coordinates given size `x` \
--- `aligncenter(2)`: `[-0.5, 0.5]` \
--- `aligncenter(3, true)`: `[1, 0, -1]` \
--- `aligncenter(5)`: `[-2, -1, 0, 1, 2]`
function MathK.aligncenter(x: number, reverse: boolean?)
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
function MathK.falloff(x: number, a: number, b: number, c: number)
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
function MathK.sinewave(a: number, t: number, b: number, k: number)
	return a * math.sin(t / b) + k
end

--- returns the radius (base) of a cone given height `h` and vertex angle `r`
function MathK.coneradius(h: number, r: number)
	return h * math.tan(r)
end

--- returns the equivalent of `Random.new():NextNumber(-1, 1) > 0 and 1 or -1` \
--- non-zero `math.sign()`
function MathK.rsign(R: Random?)
	return (R or MathK.random):NextNumber(-1, 1) > 0 and 1 or -1
end

--- returns the equivalent of `Random.new():NextNumber(x, y)`
function MathK.nextnumber(x: number, y: number, R: Random?)
	return (R or MathK.random):NextNumber(x, y)
end

--- returns the equivalent of `Random.new():NextInteger(x, y)`
function MathK.nextinteger(x: number, y: number, R: Random?)
	return (R or MathK.random):NextInteger(x, y)
end

--- returns the equivalent of `Random.new():NextInteger(0, y) / y <= odds`
function MathK.nextintegeroutcome(y: number, odds: number, R: Random?)
	return (R or MathK.random):NextInteger(0, y) / y <= odds
end

--- returns the equivalent of `Random.new():NextInteger(0, y) / y <= odds`
function MathK.nextnumberoutcome(y: number, odds: number, R: Random?)
	return (R or MathK.random):NextNumber(0, y) / y <= odds
end

--- scales numbersequence by `x`
function MathK.scalenumbersequence(numbersequence: NumberSequence, x: number)
	local newsequence = {}
	for _, keypoint in ipairs(numbersequence.Keypoints) do
		table.insert(newsequence,NumberSequenceKeypoint.new(keypoint.Time, keypoint.Value * x))
	end

	return NumberSequence.new(newsequence)
end

--- converts `x`, where `x in [0, 1]`, to a numbersequence
function MathK.alphatonumbersequence(x: number)
	if x <= 0.01 then
		return MathK.NumberSequence.zero
	elseif x == 1 then
		return MathK.NumberSequence.one
	elseif x >= 0.99 then
		return MathK.NumberSequence.one
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
function MathK.unitcircle(vertices: number, radius: number)
	if vertices == 1 then
		return { {X = -radius; Z = 0;} }
	elseif vertices == 2 then
		return { {X = -radius; Z = 0;}, {X = radius; Z = 0;} }
	end

	local step = (2*math.pi) / vertices
	local tilt = math.pi / vertices
	local unitcircle = table.create(vertices)

	for i = 1, vertices do
		local a = (i * step) - tilt
		table.insert(unitcircle, { X = radius * math.cos(a); Z = radius * math.sin(a); })
	end

	return unitcircle
end

return (MathK)