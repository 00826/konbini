--!strict
--!native

--- ### Math.luau
---
--- math library extension
local MathK = {
	NumberSequence = {
		zero = NumberSequence.new(0);
		one = NumberSequence.new(1);

		zeroone = NumberSequence.new(0, 1);
		onezero = NumberSequence.new(1, 0);

		--- returns numbersequence from alpha `a`
		fromalpha = function(a: number)
			if a <= 0.01 then
				return NumberSequence.new(0)
			elseif a >= 0.99 then
				return NumberSequence.new(1)
			else
				a = math.clamp(a, 0, 1)

				return NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0);
					NumberSequenceKeypoint.new(a, 0);
					NumberSequenceKeypoint.new(math.clamp(a + 0.01, 0, 1), 1);
					NumberSequenceKeypoint.new(1, 1);
				})
			end
		end;
		--- scales numbersequence by `x`
		scale = function(numbersequence: NumberSequence, x: number)
			local keypoints = numbersequence.Keypoints
			local newsequence = table.create(#keypoints)

			for _, keypoint in ipairs(keypoints) do
				table.insert(newsequence, NumberSequenceKeypoint.new(keypoint.Time, keypoint.Value * x))
			end

			return NumberSequence.new(newsequence)
		end;
	};
	NumberRange = {
		zero = NumberRange.new(0);
		one = NumberRange.new(1);

		zeroone = NumberRange.new(0, 1);
	};

	phi = (1 + 5^0.5) * 0.5;

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

--- returns `-(a // -b)`
function MathK.cdiv(a: number, b: number)
	return -(a // -b)
end

--- returns `x >= a and x <= b and true or false`
function MathK.inrange(x: number, a: number, b: number)
	return x >= a and x <= b and true or false
end

--- shifts `x` `a` times around limit `b` \
--- `Shift(5, 1, 6) -> 6` \
--- `Shift(5, 2, 6) -> 1` \
--- `Shift(1, -3, 6) -> 4`
function MathK.shift(x: number, a: number, b: number)
	if b == 0 then
		return x
	else
		x = (x + a) % b

		return x == 0 and b or x
	end
end

--- returns `n`-th value of the fibonacci sequence
function MathK.fibonacci(n: number)
	local a = 1 / (5^0.5)
	local b = (( 1 + (5^0.5) ) / 2)^n
	local c = (( 1 - (5^0.5) ) / 2)^n
	
	return math.round(a*b - a*c)
end

--- returns winner of rally point game with minimum `score` given team 1 points `k` and team 2 points `k` \
--- `rallypoint(25, 24, 25) -> 0` \
--- `rallypoint(25, 25, 27) -> 2` \
--- `rallypoint(25, 25, 0) -> 1`
function MathK.rallypoint(score: number, h: number, k: number)
	if (h >= score) and (h - k >= 2) then
		return 1
	elseif (k >= score) and (k - h >= 2) then
		return 2
	end

	return 0
end

--- returns winner of best-of `series` given team 1 wins `h` and team 2 wins `k` \
--- `bestof(3, 1, 2) -> 2` \
--- `bestof(5, 2, 2) -> 0` \
--- `bestof(7, 4, 3) -> 1`
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

--- creates a spring
function MathK.createspring(frequency: number, distance: number, mindistance: number, maxdistance: number)
	distance = math.clamp(distance, mindistance, maxdistance)
	
	return {
		frequency = frequency;
		
		velocity = 0;

		distance = distance;
		goal = distance;

		mindistance = mindistance;
		maxdistance = maxdistance;
	}
end

--- advances spring by `dt`
function MathK.springstep(s: typeof(MathK.createspring(...)), dt: number)
	local freq = s.frequency * 2 * math.pi --- Convert from Hz to rad/s
	local distance = s.distance
	local velocity = s.velocity
	local mindistance = s.mindistance
	local maxdistance = s.maxdistance
	local goal = s.goal

	--- Solve the spring ODE for position x and velocity after time t, assuming critical damping:
	--- 2*f*x'[t] + x''[t] = f^2*(g - x[t])
	--- Knowns are x[0] and x'[0].
	--- Solve for x[t] and x'[t].

	local offset = goal - distance
	local step = freq*dt
	local decay = math.exp(-step)

	local x1 = goal + (velocity*dt - offset*(step + 1))*decay
	local v1 = ((offset*freq - velocity)*step + velocity)*decay

	-- Constrain
	if x1 < mindistance then
		x1 = mindistance
		v1 = 0
	elseif x1 > maxdistance then
		x1 = maxdistance
		v1 = 0
	end

	s.distance = x1
	s.velocity = v1

	return x1
end

return MathK