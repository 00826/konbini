--!strict

local types						= require(script.Parent.types)

local Vector3_yzAxis			= Vector3.new(0, 1, 1)

--- ### Bar.luau
---
--- stores bar-esque values (such as health bars) compressed as a `Vector3`: \
--- `Vector3(value, maxvalue, regenrate)`
local Bar = {}

--- adds barvalue to instance
function Bar.add(thing: Instance, name: string, maxvalue: number, regenrate: number?): ()
	thing:SetAttribute(name, Vector3.new(maxvalue, maxvalue, regenrate))
end

--- removes barvalue from instance
function Bar.remove(thing: Instance, name: string): ()
	thing:SetAttribute(name, nil)
end

--- adds delta to barvalue
function Bar.delta(thing: Instance, name: string, delta: number): ()
	local barvalue = thing:GetAttribute(name)
	assert(typeof(barvalue) == "Vector3")

	local max = barvalue.Y
	thing:SetAttribute(name, Vector3.new(
		math.clamp(barvalue.X + delta, 0, max),
		max,
		barvalue.Z
	))
end

--- directly writes to barvalue axes
function Bar.writeaxes(thing: Instance, name: string, axes: types.BarAxes): ()
	local barvalue = thing:GetAttribute(name)
	assert(typeof(barvalue) == "Vector3")

	thing:SetAttribute(name, Vector3.new(
		axes.X or barvalue.X,
		axes.Y or barvalue.Y,
		axes.Z or barvalue.Z
	))
end

--- sets x-axis (`value`) of barvalue to 0
function Bar.min(thing: Instance, name: string): ()
	local barvalue = thing:GetAttribute(name)
	assert(typeof(barvalue) == "Vector3")

	thing:SetAttribute(name, barvalue * Vector3_yzAxis)
end

--- sets x-axis (`value`) of barvalue to its y-axis (`maxvalue`)
function Bar.max(thing: Instance, name: string): ()
	local barvalue = thing:GetAttribute(name)
	assert(typeof(barvalue) == "Vector3")

	thing:SetAttribute(name, Vector3.new(barvalue.Y, barvalue.Y, barvalue.Z))
end

--- returns quotient of `value / maxvalue`
function Bar.alpha(thing: Instance, name: string): number
	local barvalue = thing:GetAttribute(name)
	if typeof(barvalue) ~= "Vector3" then return 0 end
	return barvalue.X / barvalue.Y
end

--- returns tuple `value, maxvalue, regenrate` of barvalue
function Bar.read(thing: Instance, name: string): (number, number, number)
	local barvalue = thing:GetAttribute(name)
	if typeof(barvalue) ~= "Vector3" then return 0, 0, 0 end
	return barvalue.X, barvalue.Y, barvalue.Z
end

--- returns true if x-axis (`value`) is less-than or equal-to 0
function Bar.ismin(thing: Instance, name: string): boolean
	local barvalue = thing:GetAttribute(name)
	assert(typeof(barvalue) == "Vector3")

	return barvalue.X <= 0
end

--- returns true if x-axis (`value`) is greater-than or equal-to y-axis (`maxvalue`)
function Bar.ismax(thing: Instance, name: string): boolean
	local barvalue = thing:GetAttribute(name)
	assert(typeof(barvalue) == "Vector3")

	return barvalue.X >= barvalue.Y
end

--- returns `value == x`
function Bar.eq(thing: Instance, name: string, x: number): boolean
	local barvalue = thing:GetAttribute(name)
	assert(typeof(barvalue) == "Vector3")

	return barvalue.X == x
end

--- returns `value < x`
function Bar.lt(thing: Instance, name: string, x: number): boolean
	local barvalue = thing:GetAttribute(name)
	assert(typeof(barvalue) == "Vector3")

	return barvalue.X < x
end

--- returns `value <= x`
function Bar.le(thing: Instance, name: string, x: number): boolean
	local barvalue = thing:GetAttribute(name)
	assert(typeof(barvalue) == "Vector3")

	return barvalue.X <= x
end

--- regenerates `regenrate * dt`
function Bar.regen(thing: Instance, name: string, dt: number): ()
	local barvalue = thing:GetAttribute(name)
	assert(typeof(barvalue) == "Vector3")

	local value, maxvalue, regenrate = barvalue.X, barvalue.Y, barvalue.Z
	thing:SetAttribute(name, Vector3.new(
		math.clamp(value + (dt * regenrate), 0, maxvalue),
		maxvalue,
		regenrate
	))
end

return Bar