--!strict
--!native

local Rand = Random.new()

--- ### Vector3.luau
---
--- Vector3 library extension
local Vector3K = {
	yzaxis = Vector3.one - Vector3.xAxis;
	xzaxis = Vector3.one - Vector3.yAxis;
	xyaxis = Vector3.one - Vector3.zAxis;
}

--- returns vector3-typecasted `vector.lerp(v, w a)`
function Vector3K.lerp(v: Vector3, w: Vector3, a: number)
	return (vector.lerp(v::any, w::any, a)::any)::Vector3
end

--- returns vector3-typecasted `vector.normalize(v)`
function Vector3K.normalize(v: Vector3)
	return (vector.normalize(v::any)::any)::Vector3
end

--- returns vector3-typecasted `vector.magnitude(v)`
function Vector3K.magnitude(v: Vector3)
	return vector.magnitude(v::any)
end

--- returns whether or not `v` is finite
function Vector3K.isfinite(v: Vector3)
	local x, y, z = v.X, v.Y, v.Z
	return (x == x and x ~= 1/0 and x ~= -1/0)
		and (y == y and y ~= 1/0 and y ~= -1/0)
		and (z == z and z ~= 1/0 and z ~= -1/0)
end

--- returns `vector.normalize(v)`, or, if `NaN`, `Vector3.zero`
function Vector3K.unitorzero(v: Vector3)
	if vector.magnitude(v::any) > 0 then
		return (vector.normalize(v::any)::any)::Vector3
	else
		return Vector3.zero
	end
end

--- returns `v` projected onto `w`
function Vector3K.project(v: Vector3, w: Vector3)
	w = Vector3K.unitorzero(w)

	return vector.dot(v::any, w::any) * w
end

--- returns `v` rejected from `w`
function Vector3K.reject(v: Vector3, w: Vector3)
	return v - Vector3K.project(v, w)
end

--- writes non-zero components of `w` onto `v`
--- ```luau
--- Vector3K.write(vector[1, 2, 3], vector[5, 0, -10]) -> vector[5, 2, -10]
--- ```
function Vector3K.write(v: Vector3, w: Vector3)
	local x, y, z = w.X, w.Y, w.Z

	return Vector3.new(
		x == 0 and v.X or x,
		y == 0 and v.Y or y,
		z == 0 and v.Z or z
	)
end

--- returns point on bezier curve at interpolant `a`
function Vector3K.bezier(vectors: {Vector3}, a: number)
	local len = #vectors
	if len > 1 then
		local result = table.create(len)
		for i, v in ipairs(vectors) do
			local w = vectors[i + 1]
			if not w then break end

			table.insert(result, (vector.lerp(v::any, w::any, a)::any)::Vector3)
		end

		return Vector3K.bezier(result, a)
	else
		return vectors[1]
	end
end

--- returns vectors between `v` and `w` such that `u` and `w` are split into `u` equal segments \
--- `split[1]` guarantees equivalence to `v` \
--- `split[#split]` guarantees equivalence to `w`
function Vector3K.split(v: Vector3, w: Vector3, u: number)
	if u < 3 then
		return {v, w}
	else
		local result = table.create(u)
		table.insert(result, v)
		
		for i = 1, u - 1 do
			table.insert(result, (vector.lerp(v::any, w::any, i / u)::any)::Vector3)
		end

		table.insert(result, w)

		return result
	end
end

--- returns random unit vector
function Vector3K.nextunitvector(R: Random?)
	return (R or Rand):NextUnitVector()
end

--- returns random unit vector within bounds of cone \
--- quasiduck is the goat
function Vector3K.nextunitspread(v: Vector3, radians: number, R: Random?)
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
	local cosTheta = (R or Rand):NextNumber(math.cos(radians), 1)
	local sinTheta = (1 - cosTheta * cosTheta)^0.5
	local phi = (R or Rand):NextNumber(0, 2*math.pi)

	local x = sinTheta * math.cos(phi)
	local y = sinTheta * math.sin(phi)
	local z = cosTheta

	--- construct the random vector in the original coordinate system
	return (((x*u)::any + (y*w)::any + (z*v)::any)::any)::Vector3
end

--- returns random point within bounds of `[v, w]`
function Vector3K.nextpointinbounds(v: Vector3, w: Vector3, R: Random?)
	return
		  (Vector3.xAxis * (R or Rand):NextNumber(v.X, w.X))
		+ (Vector3.yAxis * (R or Rand):NextNumber(v.Y, w.Y))
		+ (Vector3.zAxis * (R or Rand):NextNumber(v.Z, w.Z))
end

--- returns random point in `x,z` radius
function Vector3K.nextpointinradius(radius: number, R: Random?)
	local r = radius * ((R or Rand):NextNumber()^0.5)
	local theta = (R or Rand):NextNumber() * 2 * math.pi

	return (Vector3.xAxis * r * math.cos(theta)) + (Vector3.zAxis * r * math.sin(theta))
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

--- returns unit vector from input vector `i`, relative to viewport `lookvector, -upvector`
function Vector3K.movevector(i: Vector3, lookvector: Vector3, upvector: Vector3)
	local rightvector = (vector.cross(lookvector::any, upvector::any)::any)::Vector3
	local cos, sin

	--[[
	local R00, R01, R02 = rightvector.X, upvector.X, lookvector.X
	local   _,   _, R12 = rightvector.Y, upvector.Y, lookvector.Y
	local   _,   _, R22 = rightvector.Z, upvector.Z, lookvector.Z]]

	local R12 = lookvector.Y

	if R12 < 1 and R12 > -1 then
		cos = lookvector.Z
		sin = lookvector.X
	else
		cos = rightvector.X
		sin = -upvector.X*math.sign(lookvector.Y)
	end

	local length = (cos*cos + sin*sin)^0.5
	return Vector3.new(cos*i.X + sin*i.Z, 0, cos*i.Z - sin*i.X) / length
end

--- interpolates between unit vector `v` and unit vector `w` with respect to interpolant `t` \
--- axisangle is the goat
function Vector3K.slerp(v: Vector3, w: Vector3, t: number)
	local magA = vector.magnitude(v::any)
	local magB = vector.magnitude(w::any)

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
	local cosine = vector.dot(v::any, w::any)
	local sine = vector.magnitude(vector.cross(v::any, w::any))

	local unitA = (vector.normalize(v::any)::any)::Vector3
	local unitB = (vector.normalize(w::any)::any)::Vector3

	-- more degenerate cases
	if cosine < 0 and sine < -1e-16*cosine then --- this test sees, in a stable way, if they are opposite and abs(tan(angle)) < 1e-16
		if t%2 < 1/2 or t%2 >= 3/2 then
			return magC*unitA
		else
			return magC*unitB
		end
	elseif cosine > 0 and sine < 1e-16*cosine then --- this test sees, in a stable way, if they are in the same direction and abs(tan(angle)) < 1e-16
		return magC*(vector.normalize((1 - t)*unitA + t*unitB::any)::any)
	end
	local angle = math.atan2(sine, cosine)

	local unitC = (vector.normalize(math.sin((1 - t)*angle)*unitA + math.sin(t*angle)*unitB::any)::any)::Vector3

	return magC*unitC
end

--- returns `point` transformed to objectspace of `position, lookvector, upvector(?=Vector3.yAxis)` \
--- eev is the goat
function Vector3K.pointtoobjectspace(point: Vector3, position: Vector3, lookvector: Vector3, upvector: Vector3?)
	local delta = point - position

	--[[
	--- case for non-orthonormal input
	local ub = vector.cross(upvector::any, backvector::any)

	upvector = upvector or Vector3.yAxis
	return Vector3.new(
		vector.dot(delta::any, ub),
		vector.dot(delta::any, vector.cross(backvector::any, rightvector::any)),
		vector.dot(delta::any, vector.cross(rightvector::any, upvector::any))
	) / vector.dot(rightvector::any, ub)
	]]

	--- fast case for orthonormal input
	upvector = upvector or Vector3.yAxis
	return Vector3.new(
		vector.dot(delta::any, vector.cross(lookvector::any, upvector::any)::any),
		vector.dot(delta::any, upvector::any),
		-vector.dot(delta::any, lookvector::any)
	)
end

--- returns: \
--- `if point is within or lies on edge of box`: `0` \
--- `if point is outside of box`: `distance between point and nearest edge on box`
function Vector3K.distancefrombox(point: Vector3, size: Vector3, position: Vector3, lookvector: Vector3, upvector: Vector3?)
	local absoluteobjectspace: Vector3 = vector.abs(Vector3K.pointtoobjectspace(point, position, lookvector, upvector)::any)::any
	size *= 0.5

	local distx = absoluteobjectspace.X - size.X
	local disty = absoluteobjectspace.Y - size.Y
	local distz = absoluteobjectspace.Z - size.Z

	if distx <= 0 and disty <= 0 and distz <= 0 then
		return 0
	end

	local realx = distx > 0 and vector.magnitude( absoluteobjectspace::any - (absoluteobjectspace + (Vector3.xAxis * distx)) ) or 0
	local realy = disty > 0 and vector.magnitude( absoluteobjectspace::any - (absoluteobjectspace + (Vector3.yAxis * disty)) ) or 0
	local realz = distz > 0 and vector.magnitude( absoluteobjectspace::any - (absoluteobjectspace + (Vector3.zAxis * distz)) ) or 0
	
	return vector.magnitude(Vector3.new(realx, realy, realz)::any)
end

--- returns a number describing unit distance of point relative to sphere: \
--- `if distance < innerradius(?=0)`: `innerradius - distance` \
--- `if distance > radius`: `distance - radius` \
--- `if distance <= radius AND angle ~= nil`: `distance between point and nearest point on edge of cone formed by angle` \
--- `if distance <= radius`: `0`
function Vector3K.distancefromsphere(point: Vector3, position: Vector3, radius: number, innerradius: number?, angle: number?, lookvector: Vector3?)
	innerradius = innerradius or 0
	local distance = vector.magnitude(position::any - point)

	if distance < innerradius::any then
		return (innerradius::any - distance)::number
	elseif distance > radius then
		return distance - radius
	elseif distance <= radius then
		if angle then
			assert(lookvector, "angle argument expects a lookvector")
			local unit: Vector3 = vector.normalize(point::any - position)::any
			local unitangle = 2 * vector.angle(lookvector::any, unit::any)
			local diff: number = (unitangle - angle::any)

			if diff > 0 then
				local leftangle: number = (angle::any) * -0.5
				local leftunit = Vector3.new(
					(lookvector.X * math.cos(leftangle)) - (lookvector.Z * math.sin(leftangle)),
					lookvector.Y,
					(lookvector.X * math.sin(leftangle)) + (lookvector.Z * math.cos(leftangle))
				)
				local rightangle: number = (angle::any) * 0.5
				local rightunit = Vector3.new(
					(lookvector.X * math.cos(rightangle)) - (lookvector.Z * math.sin(rightangle)),
					lookvector.Y,
					(lookvector.X * math.sin(rightangle)) + (lookvector.Z * math.cos(rightangle))
				)

				return math.min(
					vector.magnitude((position + (leftunit * distance))::any - point),
					vector.magnitude((position + (rightunit * distance))::any - point)
				)
			end
		end

		return 0
	end
	
	return 0
end

--- returns position of a projectile given its initial `velocity`, elapsed `time`, and gravity `?=196`
function Vector3K.projectile(velocity: Vector3, time: number, gravity: number?): Vector3
	return (vector.normalize(velocity::any)::any * (vector.magnitude(velocity::any) * time)) - ((0.5 * Vector3.yAxis) * (gravity or 196) * (time * time))
end

return Vector3K