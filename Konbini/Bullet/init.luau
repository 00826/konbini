--!strict

local types = require(script.Parent.types)

local Encoder = require(script.Parent.Encoder)
local Time = require(script.Parent.Time)

local emptywidth = 34

local hitscanwidth = emptywidth + 0
local ballisticwidth = emptywidth + 5
local beamwidth = emptywidth + 2
local bezierwidth = emptywidth + 14

@native
local function fastdistance(a: Vector3, b: Vector3): number
	b -= a
	local x, y, z = b.X, b.Y, b.Z
	return ((x * x) + (y * y) + (z * z)) ^ 0.5
end

--- ### Bullet.luau
---
--- projectile-type solver \
--- -- \
--- `0`: (dead) \
--- `1`: hitscan \
--- `2`: ballistic \
--- `3`: beam \
--- `4`: bezier
local Bullet = {
	gravity = 196;
	frame = 1/60;

	coefficient = 0.5 * Vector3.yAxis; -- the 0.5 of 0.5*g*t*t
}

--- writes properties to base bullet range
function Bullet.write(b: buffer, options: types.WriteOptions)
	if options.id then
		buffer.writestring(b, 0, string.sub(options.id, 1, 4))
	end
	if options.time then
		buffer.writef32(b, 6, options.time)
	end
	if options.position then
		Encoder.writevector3(b, 10, options.position)
	end
	if options.direction then
		Encoder.writevector3(b, 22, options.direction)
	end
end

--- returns base components of bullet
function Bullet.components(b: buffer)
	return {
		id = buffer.readstring(b, 0, 4);
		type = buffer.readu8(b, 5);
		time = buffer.readf32(b, 6);
		position = Encoder.readvector3(b, 10);
		direction = Encoder.readvector3(b, 22);
	}
end

--- returns an empty hitscan bullet \
--- type `1`
function Bullet.hitscan(): buffer
	local b = buffer.create(hitscanwidth)
	buffer.writestring(b, 0, Encoder.string(4))
	buffer.writeu8(b, 5, 1)
	buffer.writef32(b, 6, Time.now())
	return b
end

--- solves hitscan bullet
function Bullet.hitscansolve(b: buffer)
	local position = Encoder.readvector3(b, 10)
	local direction = Encoder.readvector3(b, 22)
	local sumvector = position + direction

	return {
		position = position;
		endposition = sumvector;
		deltavector = sumvector - position;
	}
end

--- returns an empty ballistic bullet \
--- type `2`
function Bullet.ballistic(): buffer
	local b = buffer.create(ballisticwidth)
	buffer.writestring(b, 0, Encoder.string(4))
	buffer.writeu8(b, 5, 2)
	return b
end

--- writes properties to bezier bullet
function Bullet.ballisticwrite(b: buffer, lifetime: number?, gravity: number?, ylimit: number?)
	if lifetime then
		buffer.writeu16(b, 34, lifetime)
	end
	if gravity then
		buffer.writei16(b, 36, gravity)
	end
	if ylimit then
		buffer.writei8(b, 38, ylimit)
	end
end

--- solves ballistic bullet
function Bullet.ballisticsolve(b: buffer, dt: number?)
	local position = Encoder.readvector3(b, 10)
	local direction = Encoder.readvector3(b, 22)
	local gravity = buffer.readi16(b, 36)

	local unitvector = direction.Unit
	local velocity = direction.Magnitude

	local start = buffer.readf32(b, 6)
	local now = Time.now()
	local elapsed = now - start

	local thisframe = position + Bullet.solveballistic(unitvector, velocity, elapsed, gravity)
	local stepframe = position + Bullet.solveballistic(unitvector, velocity, elapsed + (dt or Bullet.frame), gravity)

	return {
		position = thisframe;
		stepposition = stepframe;
		deltavector = stepframe - thisframe;
	}
end

--- returns an empty beam bullet \
--- type `3`
function Bullet.beam(): buffer
	local b = buffer.create(beamwidth)
	buffer.writestring(b, 0, Encoder.string(4))
	buffer.writeu8(b, 5, 3)
	return b
end

--- writes properties to bezier bullet
function Bullet.beamwrite(b: buffer, speed: number?)
	if speed then
		buffer.writeu16(b, 34, speed)
	end
end

--- solves beam bullet
function Bullet.beamsolve(b: buffer)
	local position = Encoder.readvector3(b, 10)
	local direction = Encoder.readvector3(b, 22)

	local unitvector = direction.Unit
	local distance = direction.Magnitude

	local velocity = buffer.readu16(b, 34)

	local start = buffer.readf32(b, 6)
	local now = Time.now()
	local elapsed = now - start

	return {
		position = position;
		lookvector = unitvector;
		length = math.clamp(velocity * elapsed, 0, distance);
	}
end

--- returns an empty bezier bullet \
--- type `4`
function Bullet.bezier(): buffer
	local b = buffer.create(bezierwidth)
	buffer.writestring(b, 0, Encoder.string(4))
	buffer.writeu8(b, 5, 4)
	return b
end

--- writes properties to bezier bullet
function Bullet.bezierwrite(b: buffer, speed: number?)
	if speed then
		buffer.writeu16(b, 46, speed)
	end
end

--- writes 3 controlpoints to bezier bullet
function Bullet.bezierwritepoints(b: buffer, startpoint: Vector3, controlpoint: Vector3, endpoint: Vector3)
	Encoder.writevector3(b, 10, startpoint)
	Encoder.writevector3(b, 22, endpoint)
	Encoder.writevector3(b, 34, controlpoint)
end

--- reads 3 controlpoints from bezier bullet: \
--- `startpoint` \
--- `endpoint` \
--- `controlpoint`
function Bullet.bezierreadpoints(b: buffer)
	return	Encoder.readvector3(b, 10),
			Encoder.readvector3(b, 22),
			Encoder.readvector3(b, 34)
end

--- solves bezier bullet
function Bullet.beziersolve(b: buffer, dt: number?)
	local startpoint, endpoint, controlpoint = Bullet.bezierreadpoints(b)
	local speed = buffer.readu16(b, 46)

	local start = buffer.readf32(b, 6)
	local now = Time.now()
	local elapsed = now - start

	local thisframe, a = Bullet.solvebezier(startpoint, controlpoint, endpoint, speed, elapsed)
	local stepframe = Bullet.solvebezier(startpoint, controlpoint, endpoint, speed, elapsed + (dt or Bullet.frame))

	return {
		position = thisframe;
		stepposition = stepframe;
		deltavector = stepframe - thisframe;
		interpolant = a;
	}
end

--- returns, with respect to time elapsed: \
--- `Vector3`: size of transform as `Vector3(diameter, diameter, length)` \
--- `Vector3`: offset of transform as `Vector3(0, 0, length / 2)`
@native
function Bullet.solvetransform(size: Vector3, velocity: number, time: number): (Vector3, Vector3)
	local distance = velocity * time
	return Vector3.new(size.X, size.Y, distance), Vector3.new(0, 0, -0.5 * distance)
end

--- returns, with respect to time elapsed: \
--- `Vector3`: offset of ballistic projectile \
--- *in contexts where `gravity == 0`, ballistic projectile will behave like a linear projectile*
@native
function Bullet.solveballistic(direction: Vector3, velocity: number, time: number, gravity: number?): Vector3
	return (direction * (velocity * time)) - (Bullet.coefficient * (gravity or Bullet.gravity) * (time * time))
end

--- returns, with respect to time elapsed, \
--- where `a`/`c` are the start/end points, \
--- and `b` is a control point: \
--- `Vector3`: position of bezier-curve projectile \
--- `A`: interpolant used to solve the position \
--- *distance is approximated by adding the distances from `a` to `b` and `b` to `c`*
@native
function Bullet.solvebezier(a: Vector3, b: Vector3, c: Vector3, velocity: number, time: number): (Vector3, number)
	local i = (time * velocity) / (fastdistance(a, b) + fastdistance(b, c))
	local P0 = a:Lerp(b, i)
	local P1 = b:Lerp(c, i)
	return P0:Lerp(P1, i), i
end

return Bullet