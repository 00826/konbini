--!strict
--!native

--- ### Bullet.luau
---
--- projectile solver
local Bullet = {
	--- for external read-write purposes
	Framerate = 1/30;
}

--- returns ballistic bullet \
--- `gravity (?=196)`
function Bullet.ballistic(position: Vector3, velocity: Vector3, gravity: number?)
	return {
		Gravity = gravity or 196;
		Position = position;
		Velocity = velocity;
	}
end

--- returns position of ballistic bullet
function Bullet.ballisticsolve(b: typeof(Bullet.ballistic(...)) & {any}, elapsed: number)
	local velocity = b.Velocity
	local unit = velocity.Unit
	local speed = velocity.Magnitude

	return (unit * (speed * elapsed)) - ((0.5 * Vector3.yAxis) * b.Gravity * (elapsed * elapsed))
end

--- returns bezier bullet
function Bullet.bezier(start: Vector3, finish: Vector3, control: Vector3, speed: number)
	return {
		A = start;
		B = finish;
		C = control;
		Speed = speed;
	}
end

--- returns position of bezier bullet and the interpolant used to solve for the position
function Bullet.beziersolve(b: typeof(Bullet.bezier(...)) & {any}, elapsed: number)
	local start = b.A
	local finish = b.B
	local control = b.C

	local distance = vector.magnitude(start::any - control::any) + vector.magnitude(finish::any - control::any)
	local maxtime = distance / b.Speed

	if elapsed == 0 then
		return start, 0
	elseif elapsed >= maxtime then
		return finish, 1
	else
		local a = math.clamp(elapsed / maxtime, 0, 1)

		return start:Lerp(control, a):Lerp(control:Lerp(finish, a), a), a
	end
end

--- equivalent to `b.Time = value`
function Bullet.timeset(b: {Time: number} & {any}, value: number)
	b.Time = value
end

--- equivalent to `b.Time += dt`
function Bullet.timestep(b: {Time: number} & {any}, dt: number)
	b.Time += dt
end

return Bullet