--!strict
--!native
--!optimize 2

local types						= require(script.Parent.types)

local DefaultR					= Random.new()

--- ### Vector3.luau
---
--- extension of Vector3 library
local K_Vector3 = {
	yzAxis						= Vector3.new(0, 1, 1);			-- `Vector3.new(0, 1, 1)`
	xzAxis						= Vector3.new(1, 0, 1);			-- `Vector3.new(1, 0, 1)`
	xyAxis						= Vector3.new(1, 1, 0);			-- `Vector3.new(1, 1, 0)`

	BallisticCoefficient		= Vector3.new(0, 0.5, 0);		-- Vector3 ballistic coefficient `(0.5*g*t*t)`

	Gravity						= 196;
}

--- returns `b.Y - a.Y`
function K_Vector3.height(a: Vector3, b: Vector3): number
	return b.Y - a.Y
end

--- returns vector3 normalized along axis
function K_Vector3.normalize(a: Vector3, Axis: types.xyzAxis): Vector3
	return (a * (
		Axis == "X" and K_Vector3.yzAxis or
		Axis == "Y" and K_Vector3.xzAxis or
		Axis == "Z" and K_Vector3.xyAxis or
		Vector3.one
	)).Unit
end

--- returns X, Y, Z of vector3 as a tuple
function K_Vector3.components(a: Vector3): (number, number, number)
	return a.X, a.Y, a.Z
end

--- returns vector3 clamped between `[a, b]`
function K_Vector3.clamp(x: Vector3, a: Vector3, b: Vector3): Vector3
	return Vector3.new(
		math.clamp(x.X, math.min(a.X, b.X), math.max(a.X, b.X)),
		math.clamp(x.Y, math.min(a.Y, b.Y), math.max(a.Y, b.Y)),
		math.clamp(x.Z, math.min(a.Z, b.Z), math.max(a.Z, b.Z))
	)
end

--- returns point on bezier curve at interpolant `A`
function K_Vector3.bezier(A: number, points: {Vector3}): Vector3
	if #points > 1 then
		local NewPoints = table.create(#points)
		for i = 1, #points - 1 do
			table.insert(NewPoints, points[i]:Lerp(points[i + 1], A))
		end
		return K_Vector3.bezier(A, NewPoints)
	end
	return points[1]
end

--- returns random unit vector
function K_Vector3.randomdirection(R: Random?): Vector3
	return (R or DefaultR):NextUnitVector()
end

--- returns random unit vector within cone \
--- `theta` is in degrees, dont @ me
function K_Vector3.randomcone(normal: Vector3, theta: number, R: Random?): Vector3
	R = R or DefaultR
	return (
		CFrame.new(Vector3.zero, normal)
		* CFrame.Angles(0, 0, (R :: Random):NextNumber(0, math.pi * 2))
		* CFrame.Angles(math.acos((R :: Random):NextNumber(math.cos(math.rad(theta)), 1)), 0, 0)
	).LookVector
end

--- returns random point within `[a, b]`
function K_Vector3.randompoint(a: Vector3, b: Vector3, R: Random?): Vector3
	R = R or DefaultR
	return Vector3.new(
		(R :: Random):NextNumber(a.X, b.X),
		(R :: Random):NextNumber(a.Y, b.Y),
		(R :: Random):NextNumber(a.Z, b.Z)
	)
end

--- returns value normalized as a vector3
function K_Vector3.tovector(value: types.xyzType?): Vector3
	if typeof(value) == "Vector3" then
		return value
	elseif typeof(value) == "Vector3int16" then
		return Vector3.new(value.X, value.Y, value.Z)
	elseif typeof(value) == "CFrame" then
		return Vector3.new(value.X, value.Y, value.Z)
	elseif typeof(value) == "PVInstance" then
		return value:GetPivot().Position
	end
	return Vector3.zero
end

--- returns `(b - a).Magnitude`
function K_Vector3.distance(a: Vector3, b: Vector3): number
	b -= a
	local x, y, z = b.X, b.Y, b.Z
	return ((x * x) + (y * y) + (z * z)) ^ 0.5
end

--- returns distance between two `XYZtype` values
function K_Vector3.distanceXYZ(a: types.xyzType, b: types.xyzType): number
	return K_Vector3.distance(K_Vector3.tovector(a), K_Vector3.tovector(b))
end

--- returns `(b - a).Unit`
function K_Vector3.direction(a: Vector3, b: Vector3)
	return (b - a).Unit
end

--- returns direction from two `XYZtype` values
function K_Vector3.directionXYZ(a: types.xyzType, b: types.xyzType): Vector3
	return K_Vector3.direction(K_Vector3.tovector(a), K_Vector3.tovector(b))
end

--- returns the midpoint of vararg `XYZtype`
function K_Vector3.midpoint(...: types.xyzType): Vector3
	local Vectors = {...}
	local Count = #Vectors

	local T = Vector3.zero
	for _, V in Vectors do
		T += K_Vector3.tovector(V)
	end
	return T / Count
end

--- returns true if `a` and `b` are coplanar along unit vector
function K_Vector3.iscoplanar(a: Vector3, b: Vector3, unitvector: Vector3): boolean
	return math.round((a - b):Dot(unitvector)) == 0
end

--- returns unit vector `a` reflected against unit vector `b`
function K_Vector3.reflect(a: Vector3, b: Vector3): Vector3
	return 2 * a:Dot(b) * b - a
end

--- interpolates between unit vector `a` and unit vector `b` with respect to interpolant `t` \
--- axisangle is the goat
function K_Vector3.slerp(a: Vector3, b: Vector3, t: number): Vector3
	local magA = a.Magnitude
	local magB = b.Magnitude

	if magA == 0 and magB == 0 then
		return Vector3.zero
	elseif magA == 0 then
		if t < 1 then
			return Vector3.zero
		elseif t == 1 then
			return b
		else
			return math.huge*b
		end
	elseif magB == 0 then
		if t < 0 then
			return math.huge*a
		elseif t == 0 then
			return a
		else
			return Vector3.zero
		end
	end

	local magC = magA^(1 - t)*magB^t -- final magnitude

	-- get k*cosine and k*sine components of the angle between a and b
	local co = a:Dot(b)
	local si = a:Cross(b).Magnitude

	local unitA = a.Unit
	local unitB = b.Unit

	-- more degenerate cases
	if co < 0 and si < -1e-16*co then -- this test sees, in a stable way, if they are opposite and abs(tan(angle)) < 1e-16
		if t%2 < 1/2 or t%2 >= 3/2 then
			return magC*unitA
		else
			return magC*unitB
		end
	elseif co > 0 and si < 1e-16*co then -- this test sees, in a stable way, if they are in the same direction and abs(tan(angle)) < 1e-16
		return magC*((1 - t)*unitA + t*unitB).Unit
	end
	local ang = math.atan2(si, co)

	local unitC = (math.sin((1 - t)*ang)*unitA + math.sin(t*ang)*unitB).Unit

	return magC*unitC
end

--- stretches `a` towards `b`, constrained around radius `r`
function K_Vector3.Stretch(a: Vector3, b: Vector3, r: number): Vector3
	if K_Vector3.distance(a, b) <= r then
		return b
	end
	return a + (K_Vector3.direction(a, b) * r)
end

--- returns degree rotations interpreted as a rotation vector
function K_Vector3.torotationvector(dX: number, dY: number, dZ: number): Vector3
	return Vector3.new(dX, dY, dZ) * math.rad(1)
end

--- returns rotation vector as `CFrame.Angles`
function K_Vector3.rotationvectortoangles(rotationvector: Vector3): CFrame
	return CFrame.Angles(rotationvector.X, rotationvector.Y, rotationvector.Z)
end

--- returns, with respect to time elapsed: \
--- `CFrame`: rotation vector as `CFrame.Angles`
function K_Vector3.solverotate(rotationvector: Vector3, time: number): CFrame
	rotationvector *= time
	return CFrame.Angles(rotationvector.X, rotationvector.Y, rotationvector.Z)
end

--- returns, with respect to time elapsed: \
--- `Vector3`: size of transform as `Vector3(diameter, diameter, length)` \
--- `Vector3`: offset of transform as `Vector3(0, 0, length / 2)`
function K_Vector3.solvetransform(size: Vector3, velocity: number, time: number): (Vector3, Vector3)
	local Distance = velocity * time
	return Vector3.new(size.X, size.Y, Distance), Vector3.new(0, 0, Distance * -0.5)
end

--- returns, with respect to time elapsed: \
--- `Vector3`: offset of ballistic projectile \
--- *in contexts where `gravity == 0`, ballistic projectile will behave like a linear projectile*
function K_Vector3.solveballistic(direction: Vector3, velocity: number, time: number, gravity: number?): Vector3
	return (direction * (velocity * time)) - (K_Vector3.BallisticCoefficient * (gravity or K_Vector3.Gravity) * (time * time))
end

--- returns, with respect to time elapsed, \
--- where `a`/`c` are the start/end points, \
--- and `b` is a control point: \
--- `Vector3`: position of bezier-curve projectile \
--- `A`: interpolant used to solve the position \
--- *distance is approximated by adding the distances from `a` to `b` and `b` to `c`*
function K_Vector3.solvebezier(a: Vector3, b: Vector3, c: Vector3, velocity: number, time: number): (Vector3, number)
	local A = (time * velocity) / (K_Vector3.distance(a, b) + K_Vector3.distance(b, c))
	local P0 = a:Lerp(b, A)
	local P1 = b:Lerp(c, A)
	return P0:Lerp(P1, A), A
end

return table.freeze(K_Vector3)