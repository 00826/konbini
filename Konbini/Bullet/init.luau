--!strict
--!native

local types = require(script.Parent.types)

local Encoder = require(script.Parent.Encoder)
local Time = require(script.Parent.Time)

--- ### Bullet.luau
---
--- projectile-type solver \
--- \
--- `0`: (dead) \
--- `1`: hitscan \
--- `2`: ballistic \
--- `3`: beam \
--- `4`: bezier \
--- `5`: track
local Bullet = {
	Gravity = 196;
	Framerate = 1/30;

	--- base width 34 + typewidth x
	Widths = table.freeze{
		Hitscan = 34 + 0;
		Ballistic = 34 + 3;
		Beam = 34 + 2;
		Bezier = 34 + 14;
		Track = 34 + 6;
	};
	Types = table.freeze{
		"Hitscan";
		"Ballistic";
		"Beam";
		"Bezier";
		"Track";
	};

	Coefficient = 0.5 * Vector3.yAxis; --- the 0.5 of 0.5*g*t*t
}

--- returns a type-wide bullet \
--- `Time (?=Konbini.Time.now())` bullet spawn time
function Bullet.create(type: types.Bullet, time: number?)
	local length = Bullet.Widths[type]
	local index = table.find(Bullet.Types, type)
	assert(index, `{type} is not a bullet type`)

	local b = buffer.create(length)
	buffer.writestring(b, 0, Encoder.string(4))
	buffer.writeu8(b, 4, 1)
	buffer.writeu8(b, 5, index)
	buffer.writef32(b, 6, time or Time.now())

	return b
end

--- writes properties to base bullet range
function Bullet.write(b: buffer, type: types.Bullet, options: types.BaseOptions & types.TypeOptions)
	if options.Id then
		buffer.writestring(b, 0, string.sub(options.Id, 1, 4))
	end
	if options.Cycle then
		buffer.writeu8(b, 4, options.Cycle)
	end
	if options.Time then
		buffer.writef32(b, 6, options.Time)
	end
	if options.Position then
		Encoder.writevector3(b, 10, options.Position)
	end
	if options.Vector then
		Encoder.writevector3(b, 22, options.Vector)
	end

	if type == "Ballistic" then
		if options.Gravity then
			buffer.writei16(b, 34, options.Gravity)
		end
		if options.Ylimit then
			buffer.writei8(b, 36, options.Ylimit)
		end
	elseif type == "Beam" then
		if options.Speed then
			buffer.writeu16(b, 34, options.Speed)
		end
	elseif type == "Bezier" then
		if options.Speed then
			buffer.writeu16(b, 46, options.Speed)
		end
		if options.Goal then
			Encoder.writevector3(b, 22, options.Goal)
		end
		if options.Control then
			Encoder.writevector3(b, 34, options.Control)
		end
	elseif type == "Track" then
		if options.Target then
			buffer.writestring(b, 34, options.Target, 4)
		end
		if options.Speed then
			buffer.writeu16(b, 38, options.Speed)
		end
	end
end

--- returns base components of bullet
function Bullet.unpack(b: buffer): types.BaseOptions
	return {
		Id = buffer.readstring(b, 0, 4);
		Cycle = buffer.readu8(b, 4);
		Type = buffer.readu8(b, 5);
		Time = buffer.readf32(b, 6);
		Position = Encoder.readvector3(b, 10);
		Vector = Encoder.readvector3(b, 22);
	}
end

--- solves hitscan bullet
function Bullet.hitscansolve(b: buffer)
	local type = buffer.readu8(b, 5)
	assert(type == 1, string.format("mismatching bullet (%d) and solve function (1)", type))

	local position = Encoder.readvector3(b, 10)
	local direction = Encoder.readvector3(b, 22)
	local sumvector = position + direction

	return {
		Position = position;
		EndPosition = sumvector;
		Delta = sumvector - position;
	}
end

--- solves ballistic bullet
function Bullet.ballisticsolve(b: buffer, dt: number?)
	local type = buffer.readu8(b, 5)
	assert(type == 2, string.format("mismatching bullet (%d) and solve function (2)", type))

	local position = Encoder.readvector3(b, 10)
	local direction = Encoder.readvector3(b, 22)
	local gravity = buffer.readi16(b, 34)
	local ylimit = buffer.readi8(b, 36)

	local unitvector = direction.Unit
	local velocity = direction.Magnitude

	local start = buffer.readf32(b, 6)
	local now = Time.now()
	local elapsed = now - start

	local thisframe = position + Bullet.solveballistic(unitvector, velocity, elapsed, gravity)
	local stepframe = position + Bullet.solveballistic(unitvector, velocity, elapsed + (dt or Bullet.Framerate), gravity)

	return {
		Position = thisframe;
		StepPosition = stepframe;
		Delta = stepframe - thisframe;
		Elapsed = elapsed;
		Height = ylimit - thisframe.Y;
	}
end

--- solves beam bullet
function Bullet.beamsolve(b: buffer)
	local type = buffer.readu8(b, 5)
	assert(type == 3, string.format("mismatching bullet (%d) and solve function (3)", type))

	local position = Encoder.readvector3(b, 10)
	local direction = Encoder.readvector3(b, 22)

	local unitvector = direction.Unit
	local distance = direction.Magnitude

	local velocity = buffer.readu16(b, 34)

	local start = buffer.readf32(b, 6)
	local now = Time.now()
	local elapsed = now - start

	return {
		Position = position;
		LookVector = unitvector;
		Length = math.clamp(velocity * elapsed, 0, distance);
		Elapsed = elapsed;
	}
end

--- solves bezier bullet
function Bullet.beziersolve(b: buffer, dt: number?)
	local type = buffer.readu8(b, 5)
	assert(type == 4, string.format("mismatching bullet (%d) and solve function (4)", type))

	local startpoint = Encoder.readvector3(b, 10)
	local goalpoint = Encoder.readvector3(b, 22)
	local controlpoint = Encoder.readvector3(b, 34)
	local speed = buffer.readu16(b, 46)

	local start = buffer.readf32(b, 6)
	local now = Time.now()
	local elapsed = now - start

	local thisframe, a = Bullet.solvebezier(startpoint, controlpoint, goalpoint, speed, elapsed)
	local stepframe = Bullet.solvebezier(startpoint, controlpoint, goalpoint, speed, elapsed + (dt or Bullet.Framerate))

	return {
		Position = thisframe;
		StepPosition = stepframe;
		Delta = stepframe - thisframe;
		Interpolant = a;
		Elapsed = elapsed;
	}
end

--- solves track bullet \
--- interpolant is clamped within bounds of `[0, 1]` such that this bullet will never overshoot its target
function Bullet.tracksolve(b: buffer, solve: (target: string, relativeposition: Vector3) -> Vector3, dt: number?)
	local type = buffer.readu8(b, 5)
	assert(type == 5, string.format("mismatching bullet (%d) and solve function (5)", type))

	local position = Encoder.readvector3(b, 10)
	local targetposition = solve(buffer.readstring(b, 34, 4), Encoder.readvector3(b, 22))
	local speed = buffer.readu16(b, 38)

	local start = buffer.readf32(b, 6)
	local now = Time.now()
	local elapsed = now - start

	local delta = targetposition - position
	local distance = speed * elapsed
	local stepdistance = speed * (elapsed + (dt or Bullet.Framerate))

	local a = math.clamp(distance / delta.Magnitude, 0, 1)
	local thisframe = position:Lerp(targetposition, a)

	return {
		Position = thisframe;
		StepPosition = position:Lerp(targetposition, math.clamp(stepdistance / delta.Magnitude, 0, 1));
		Delta = thisframe - targetposition;
		Interpolant = a;
		Elapsed = elapsed;
	}
end

--- returns, with respect to time elapsed: \
--- `Vector3`: size of transform as `Vector3(diameter, diameter, length)` \
--- `Vector3`: offset of transform as `Vector3(0, 0, length / 2)`
function Bullet.solvetransform(size: Vector3, velocity: number, time: number)
	local distance = velocity * time
	return Vector3.new(size.X, size.Y, distance), Vector3.new(0, 0, -0.5 * distance)
end

--- returns, with respect to time elapsed: \
--- `Vector3`: offset of ballistic projectile \
--- *in contexts where `gravity == 0`, ballistic projectile will behave like a linear projectile*
function Bullet.solveballistic(direction: Vector3, velocity: number, time: number, gravity: number?)
	return (direction * (velocity * time)) - (Bullet.Coefficient * (gravity or Bullet.Gravity) * (time * time))
end

--- returns, with respect to time elapsed, \
--- where `a`/`c` are the start/end points, \
--- and `b` is a control point: \
--- `Vector3`: position of bezier-curve projectile \
--- `A`: interpolant used to solve the position \
--- *distance is approximated by adding the distances from `a` to `b` and `b` to `c`*
function Bullet.solvebezier(a: Vector3, b: Vector3, c: Vector3, velocity: number, time: number)
	local i = (time * velocity) / (vector.magnitude(a::any - b::any) + vector.magnitude(b::any - c::any))
	local P0 = a:Lerp(b, i)
	local P1 = b:Lerp(c, i)
	return P0:Lerp(P1, i), i
end

return Bullet