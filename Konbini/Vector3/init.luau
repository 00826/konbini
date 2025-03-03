--!strict
--!native
--!optimize 2

local types = require(script.Parent.types)

--- ### Vector3.luau
---
--- extension of Vector3 library
local Vector3K = {
	yzAxis = Vector3.one - Vector3.xAxis;
	xzAxis = Vector3.one - Vector3.yAxis;
	xyAxis = Vector3.one - Vector3.zAxis;

	xAxisHalf = Vector3.xAxis * 0.5;
	yAxisHalf = Vector3.yAxis * 0.5;
	zAxisHalf = Vector3.zAxis * 0.5;

	--- returns `Vector3.one * w`
	fromconstant = function(w: number)
		return Vector3.one * w
	end;
}

--- returns `v.Unit`, or, if `NaN`, `Vector3.zero`
function Vector3K.unit_or_zero(v: Vector3)
	--[[
	if vector.magnitude(v) > 0 then
		return vector.normalize(v)
	else
		return vector.zero
	end
	]]
	if v.Magnitude > 0 then
		return v.Unit
	else
		return Vector3.zero
	end
end

--- returns `v` projected onto `w`
function Vector3K.project(v: Vector3, w: Vector3)
	--[[
	w = Vector3K.unit_or_zero(w)
	return vector.dot(v, w) * w
	]]
	w = Vector3K.unit_or_zero(w)
	return vector.dot(v::any, w::any) * w
end

--- returns `v` rejected from `w`
function Vector3K.reject(v: Vector3, w: Vector3)
	return v - Vector3K.project(v, w)
end

--- writes non-zero components of `w` onto `v`
--- ```lua
--- write(vector[1, 2, 3], vector[5, 0, -10]) -> vector[5, 2, -10]
--- ```
function Vector3K.write(v: Vector3, w: Vector3)
	local x, y, z = w.X, w.Y, w.Z

	return Vector3.new(
		x == 0 and v.X or x,
		y == 0 and v.Y or y,
		z == 0 and v.Z or z
	)
end

--- returns `v` as a tuple
function Vector3K.unpack(v: Vector3)
	return v.X, v.Y, v.Z
end

--- stretches `v` towards `w`, within bounds of `radius`
function Vector3K.stretch(v: Vector3, w: Vector3, radius: number)
	--[[
	if vector.magnitude(v, w) <= radius then
		return w
	end

	return v + (vector.normalize(w - v) * radius)
	]]
	if Vector3K.distance(v, w) <= radius then
		return w
	end

	return v + ((vector.normalize(w::any - v::any)::any)::Vector3 * radius)
end

--- returns point on bezier curve at interpolant `a`
function Vector3K.bezier(points: {Vector3}, a: number)
	if #points > 1 then
		local newpoints = table.create(#points)
		for i = 1, #points - 1 do
			table.insert(newpoints, points[i]:Lerp(points[i + 1], a))
		end
		return Vector3K.bezier(newpoints, a)
	end

	return points[1]
end

--- returns random unit vector
function Vector3K.nextunitvector(R: Random?)
	return (R or types.R):NextUnitVector()
end

--- returns random unit vector within bounds of cone \
--- quasiduck is the goat
function Vector3K.nextunitspread(v: Vector3, radians: number, R: Random?)
	--[[
	--- create an orthonormal basis (u, w, v)
	--- equivalent of producing the rightvector (u) and upvector (w) of v
	local u
	if math.abs(v.Y) < 0.999 then
		u = vector.normalize(vector.cross(v, Vector3.yAxis))
	else
		u = vector.normalize(vector.cross(v, Vector3.xAxis))
	end
	local w = vector.cross(v, u)

	--- generate a random point within the spherical cap (from unit sphere)
	--- produces spherical coordinates
	local cosTheta = (R or types.R):NextNumber(math.cos(radians), 1)
	local sinTheta = (1 - cosTheta * cosTheta)^0.5
	local phi = (R or types.R):NextNumber(0, 2*math.pi)

	local x = sinTheta * math.cos(phi)
	local y = sinTheta * math.sin(phi)
	local z = cosTheta

	--- construct the random vector in the original coordinate system
	return (x*u) + (y*w) + (z*v)
	]]
	--- create an orthonormal basis (u, w, v)
	--- equivalent of producing the rightvector (u) and upvector (w) of v
	local u
	if math.abs(v.Y) < 0.999 then
		u = vector.normalize(vector.cross(v::any, Vector3.yAxis::any))
	else
		u = vector.normalize(vector.cross(v::any, Vector3.xAxis::any))
	end
	local w = vector.cross(v::any, u)

	--- generate a random point within the spherical cap (from unit sphere)
	--- produces spherical coordinates
	local cosTheta = (R or types.R):NextNumber(math.cos(radians), 1)
	local sinTheta = (1 - cosTheta * cosTheta)^0.5
	local phi = (R or types.R):NextNumber(0, 2*math.pi)

	local x = sinTheta * math.cos(phi)
	local y = sinTheta * math.sin(phi)
	local z = cosTheta

	--- construct the random vector in the original coordinate system
	return ((x*u) + (y*w) + (z*v))::Vector3
end

--- returns random point within bounds of `[v, w]`
function Vector3K.nextpointinbounds(v: Vector3, w: Vector3, R: Random?)
	return
		  (Vector3.xAxis * (R or types.R):NextNumber(v.X, w.X))
		+ (Vector3.yAxis * (R or types.R):NextNumber(v.Y, w.Y))
		+ (Vector3.zAxis * (R or types.R):NextNumber(v.Z, w.Z))
end

function Vector3K.nextpointinradius(radius: number, R: Random?)
	local r = radius * ((R or types.R):NextNumber()^0.5)
	local theta = (R or types.R):NextNumber() * 2 * math.pi

	return (Vector3.xAxis * r * math.cos(theta)) + (Vector3.zAxis * r * math.sin(theta))
end

--- returns vector3 representation of `variant`
function Vector3K.tovector(variant: types.xyzType?)
	if typeof(variant) == "Vector3" then
		return variant
	elseif typeof(variant) == "Vector3int16" then
		return Vector3.new(variant.X, variant.Y, variant.Z)
	elseif typeof(variant) == "CFrame" then
		return Vector3.new(variant.X, variant.Y, variant.Z)
	elseif typeof(variant) == "PVInstance" then
		return variant:GetPivot().Position
	end

	return Vector3.zero
end

--- returns `vector.magnitude(w - v)`
function Vector3K.distance(v: Vector3, w: Vector3)
	return vector.magnitude(w::any - v::any)
end

--- returns `vector.normalize(w - v)`
function Vector3K.unit(v: Vector3, w: Vector3)
	--- just beat the type solver final boss
	--- whats good
	return (vector.normalize(w::any - v::any)::any)::Vector3
end

--- returns `vector.angle(v, w)`
function Vector3K.angle(v: Vector3, w: Vector3)
	return vector.angle(v::any, w::any)
end

--- returns the midpoint of `vectors`
function Vector3K.midpoint(vectors: { Vector3 | types.xyzType })
	local length = #vectors

	local sum = Vector3.zero
	for _, v in vectors do
		if typeof(v) == "Vector3" then
			sum += v
		else
			sum += Vector3K.tovector(v)
		end
	end

	return sum / length
end

--- returns points along line drawn from `v` towards `w` and the distance from `v` towards `w` including segments
function Vector3K.segment(v: Vector3, w: Vector3, segments: number, transform: ((u: Vector3) -> Vector3)?)
	local partition = table.create(segments)
	partition[1] = v
	partition[segments] = w

	if segments <= 2 then
		return partition, (partition[2] - partition[1]).Magnitude
	else
		local step = segments - 1
		for i = 1, segments - 2, 1 do
			local u = v:Lerp(w, i / step)
			if transform then
				u = transform(u)
			end
			partition[i + 1] = u
		end

		local distance = 0
		for i, seg in partition do
			local ment = partition[i + 1]
			if not ment then break end

			distance += (seg - ment).Magnitude
		end

		return partition, distance
	end
end

--- returns true if `v` and `w` are coplanar along unit vector `u`
function Vector3K.iscoplanar(v: Vector3, w: Vector3, u: Vector3)
	return math.round(vector.dot((v - w)::any, u::any)) == 0
end

--- returns unit vector `v` reflected against unit vector `w`
function Vector3K.reflect(v: Vector3, w: Vector3)
	return 2 * vector.dot(v::any, w::any) * w - v
end

--- returns rotation of unit vector `v` along `axis`
function Vector3K.rotation(v: Vector3, axis: Enum.Axis)
	local y, x = 0, 0

	if axis == Enum.Axis.X then
		y = v.Y
		x = v.Z
	elseif axis == Enum.Axis.Y then
		y = v.X
		x = v.Z
	elseif axis == Enum.Axis.Z then
		y = v.Y
		x = v.X
	end

	if y == 0 and x == 0 then
		return 0
	else
		return -1 * math.atan2(y, x)
	end
end

--- returns unit vector from input vector `i`, relative to (camera) `cframe`
function Vector3K.movevector(i: Vector3, cframe: CFrame)
	local cos, sin
	local _, _, _, R00, R01, R02, _, _, R12, _, _, R22 = cframe:GetComponents()
	if R12 < 1 and R12 > -1 then
		--- cos, sin = lookvector.x, lookvector.z
		cos = R22
		sin = R02
	else
		--- cos, sin = rightvector.x, upvector.x
		cos = R00
		sin = -R01*math.sign(R12)
	end

	local length = (cos*cos + sin*sin)^0.5
	return Vector3.new(cos*i.X + sin*i.Z, 0, cos*i.Z - sin*i.X) / length
end

--- interpolates between unit vector `v` and unit vector `w` with respect to interpolant `t` \
--- axisangle is the goat
function Vector3K.slerp(v: Vector3, w: Vector3, t: number)
	local magA = v.Magnitude
	local magB = w.Magnitude

	if magA == 0 and magB == 0 then
		return Vector3.zero
	elseif magA == 0 then
		if t < 1 then
			return Vector3.zero
		elseif t == 1 then
			return w
		else
			return math.huge*w
		end
	elseif magB == 0 then
		if t < 0 then
			return math.huge*v
		elseif t == 0 then
			return v
		else
			return Vector3.zero
		end
	end

	local magC = magA^(1 - t)*magB^t --- final magnitude

	-- get k*cosine and k*sine components of the angle between v and w
	local co = v:Dot(w)
	local si = v:Cross(w).Magnitude

	local unitA = v.Unit
	local unitB = w.Unit

	-- more degenerate cases
	if co < 0 and si < -1e-16*co then --- this test sees, in a stable way, if they are opposite and abs(tan(angle)) < 1e-16
		if t%2 < 1/2 or t%2 >= 3/2 then
			return magC*unitA
		else
			return magC*unitB
		end
	elseif co > 0 and si < 1e-16*co then --- this test sees, in a stable way, if they are in the same direction and abs(tan(angle)) < 1e-16
		return magC*((1 - t)*unitA + t*unitB).Unit
	end
	local ang = math.atan2(si, co)

	local unitC = (math.sin((1 - t)*ang)*unitA + math.sin(t*ang)*unitB).Unit

	return magC*unitC
end

--- returns `v` as a string
function Vector3K.tostring(v: Vector3, precision: number?)
	return string.sub(string.format(string.rep("%." .. (precision or 2) .. "f ", 3), v.X, v.Y, v.Z), 1, -2)
end

return table.freeze(Vector3K)