--!strict
--!native

local Rand = Random.new()

local function rstring(len: number)
	local str = ""
	for i = 1, len do
		local value = Rand:NextInteger(1, 36)
		if value <= 26 then
			if Rand:NextInteger(0, 1) == 0 then
				str ..= string.char(value + 64) --- [A-Z]
			else
				str ..= string.char(value + 96) --- [a-z]
			end
		else
			str ..= tostring(36 - value) --- [0-9]
		end
	end

	return str
end

--- reads Vector3 from buffer
local function readvector3(b: buffer, offset: number)
	return Vector3.new(
		buffer.readf32(b, offset),
		buffer.readf32(b, offset + 4),
		buffer.readf32(b, offset + 8)
	)
end

--- writes Vector3 to buffer
local function writevector3(b: buffer, offset: number, value: Vector3)
	buffer.writef32(b, offset, value.X)
	buffer.writef32(b, offset + 4, value.Y)
	buffer.writef32(b, offset + 8, value.Z)
end

export type BaseOptions = {
	--- [*Bullet*] \
	--- bullet id
	Id: string?;
	--- [*Bullet*] \
	--- bullet update every nth frame
	Cycle: number?;
	--- [*Bullet*] \
	--- bullet time
	Time: number?;
	--- [*Bullet*] \
	--- bullet position
	Position: Vector3?;
	--- [*Bullet*] \
	--- bullet vector
	Vector: Vector3?;
}

export type TypeOptions = {
	--- [*Ballistic*] \
	--- gravity acting upon a ballistic bullet
	Gravity: number?;
	--- [*Ballistic*] \
	--- y-limit of a ballistic bullet
	Ylimit: number?;
	--- [*Ballistic, Beam, Bezier*] \
	--- speed of any non-hitscan bullet
	Speed: number?;
	--- [*Bezier*] \
	--- control point of a bezier bullet
	Start: Vector3?;
	--- [*Bezier*] \
	--- control point of a bezier bullet
	Control: Vector3?;
	--- [*Bezier*] \
	--- goal point of a bezier bullet
	Goal: Vector3?;
}

export type Bullet =
	| "Hitscan" --- 1
	| "Ballistic" --- 2
	| "Beam" --- 3
	| "Bezier" --- 4

--- ### Bullet.luau
---
--- projectile-type solver \
--- \
--- `0`: (dead) \
--- `1`: hitscan \
--- `2`: ballistic \
--- `3`: beam \
--- `4`: bezier
local Bullet = {
	Gravity = 196;
	Framerate = 1/30;

	--- base width 34 + typewidth x
	Widths = {
		Hitscan = 34 + 0;
		Ballistic = 34 + 3;
		Beam = 34 + 2;
		Bezier = 34 + 14;
	};
	Types = {
		"Hitscan";
		"Ballistic";
		"Beam";
		"Bezier";
	};

	Coefficient = 0.5 * Vector3.yAxis; --- the 0.5 of 0.5*g*t*t
}

--- returns a type-wide bullet
function Bullet.create(type: Bullet, time: number)
	local length = Bullet.Widths[type]
	local index = table.find(Bullet.Types, type)
	assert(index, `{type} is not a bullet type`)

	local b = buffer.create(length)
	buffer.writestring(b, 0, rstring(4))
	buffer.writeu8(b, 4, 1)
	buffer.writeu8(b, 5, index)
	buffer.writef32(b, 6, time)

	return b
end

--- writes properties to base bullet range
function Bullet.write(b: buffer, type: Bullet, options: BaseOptions & TypeOptions)
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
		writevector3(b, 10, options.Position)
	end
	if options.Vector then
		writevector3(b, 22, options.Vector)
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
			writevector3(b, 22, options.Goal)
		end
		if options.Control then
			writevector3(b, 34, options.Control)
		end
	end
end

--- returns base components of bullet
function Bullet.unpack(b: buffer): BaseOptions
	return {
		Id = buffer.readstring(b, 0, 4);
		Cycle = buffer.readu8(b, 4);
		Type = buffer.readu8(b, 5);
		Time = buffer.readf32(b, 6);
		Position = readvector3(b, 10);
		Vector = readvector3(b, 22);
	}
end

--- solves hitscan bullet
function Bullet.hitscansolve(b: buffer)
	local type = buffer.readu8(b, 5)
	assert(type == 1, string.format("mismatching bullet (%d) and solve function (1)", type))

	local position = readvector3(b, 10)
	local direction = readvector3(b, 22)
	local sumvector = position + direction

	return {
		Position = position;
		EndPosition = sumvector;
		Delta = sumvector - position;
	}
end

--- solves ballistic bullet
function Bullet.ballisticsolve(b: buffer, now: number, dt: number?)
	local type = buffer.readu8(b, 5)
	assert(type == 2, string.format("mismatching bullet (%d) and solve function (2)", type))

	local position = readvector3(b, 10)
	local direction = readvector3(b, 22)
	local gravity = buffer.readi16(b, 34)
	local ylimit = buffer.readi8(b, 36)

	local unitvector = direction.Unit
	local velocity = direction.Magnitude

	local start = buffer.readf32(b, 6)
	local elapsed = now - start

	local thisframe = position + Bullet._solveballistic(unitvector, velocity, elapsed, gravity)
	local stepframe = position + Bullet._solveballistic(unitvector, velocity, elapsed + (dt or Bullet.Framerate), gravity)

	return {
		Position = thisframe;
		StepPosition = stepframe;
		Delta = stepframe - thisframe;
		Elapsed = elapsed;
		Height = ylimit - thisframe.Y;
	}
end

--- solves beam bullet
function Bullet.beamsolve(b: buffer, now: number)
	local type = buffer.readu8(b, 5)
	assert(type == 3, string.format("mismatching bullet (%d) and solve function (3)", type))

	local position = readvector3(b, 10)
	local direction = readvector3(b, 22)

	local unitvector = direction.Unit
	local distance = direction.Magnitude

	local velocity = buffer.readu16(b, 34)

	local start = buffer.readf32(b, 6)
	local elapsed = now - start

	return {
		Position = position;
		LookVector = unitvector;
		Length = math.clamp(velocity * elapsed, 0, distance);
		Elapsed = elapsed;
	}
end

--- solves bezier bullet
function Bullet.beziersolve(b: buffer, now: number, dt: number?)
	local type = buffer.readu8(b, 5)
	assert(type == 4, string.format("mismatching bullet (%d) and solve function (4)", type))

	local startpoint = readvector3(b, 10)
	local goalpoint = readvector3(b, 22)
	local controlpoint = readvector3(b, 34)
	local speed = buffer.readu16(b, 46)

	local start = buffer.readf32(b, 6)
	local elapsed = now - start

	local thisframe, a = Bullet._solvebezier(startpoint, controlpoint, goalpoint, speed, elapsed)
	local stepframe = Bullet._solvebezier(startpoint, controlpoint, goalpoint, speed, elapsed + (dt or Bullet.Framerate))

	return {
		Position = thisframe;
		StepPosition = stepframe;
		Delta = stepframe - thisframe;
		Interpolant = a;
		Elapsed = elapsed;
	}
end

--- returns, with respect to time elapsed: \
--- `Vector3`: offset of ballistic projectile \
--- *in contexts where `gravity == 0`, ballistic projectile will behave like a linear projectile*
function Bullet._solveballistic(direction: Vector3, velocity: number, time: number, gravity: number?)
	return (direction * (velocity * time)) - (Bullet.Coefficient * (gravity or Bullet.Gravity) * (time * time))
end

--- returns, with respect to time elapsed, \
--- where `a`/`c` are the start/end points, \
--- and `b` is a control point: \
--- `Vector3`: position of bezier-curve projectile \
--- `A`: interpolant used to solve the position \
--- *distance is approximated by adding the distances from `a` to `b` and `b` to `c`*
function Bullet._solvebezier(a: Vector3, b: Vector3, c: Vector3, velocity: number, time: number)
	local i = (time * velocity) / (vector.magnitude(a::any - b::any) + vector.magnitude(b::any - c::any))
	return a:Lerp(b, i):Lerp(b:Lerp(c, i), i), i
end

return Bullet