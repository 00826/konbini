--!strict

local types						= require(script.Parent.types)

local Time						= require(script.Parent.Time)

local Prefix					= "k_Status_"

--- ### Status.luau
---
--- stores status-esque values compressed as a `Vector3`: \
--- `Vector3(expiry, stacks, indefinite)`
local Status = {}

--- adds status to instance
function Status.add(thing: Instance, name: string, duration: number?, stacks: number?, indefinite: boolean?): ()
	local statusvalue = (thing:GetAttribute(Prefix .. name) or Vector3.new(0, stacks or 0, 0)) :: Vector3
	assert(typeof(statusvalue) == "Vector3")

	local z = 0
	if indefinite == true then
		z = 1
	elseif indefinite == false then
		z = 0
	else
		z = statusvalue.Z
	end

	thing:SetAttribute(Prefix .. name, Vector3.new(
		math.max(statusvalue.X, Time.now()) + (duration or 0),
		statusvalue.Y + (stacks or 0),
		z
	))
end

--- removes status from instance
function Status.remove(thing: Instance, name: string): ()
	thing:SetAttribute(Prefix .. name, nil)
end

--- directly writes to status axes
function Status.writeaxes(thing: Instance, name: string, axes: types.Axes): ()
	local statusvalue = thing:GetAttribute(Prefix .. name)
	assert(typeof(statusvalue) == "Vector3")

	thing:SetAttribute(Prefix .. name, Vector3.new(
		axes.X or statusvalue.X,
		axes.Y or statusvalue.Y,
		axes.Z or statusvalue.Z
	))
end

--- returns true if status is active
function Status.active(thing: Instance, name: string): boolean
	local statusvalue = thing:GetAttribute(Prefix .. name)
	if typeof(statusvalue) ~= "Vector3" then
		return false
	end

	return statusvalue.X >= Time.now()
end

--- returns status: `active, stacks, indefinite`
function Status.read(thing: Instance, name: string): (boolean, number, boolean)
	local statusvalue = thing:GetAttribute(Prefix .. name)
	if typeof(statusvalue) ~= "Vector3" then
		return false, 0, false
	end

	return statusvalue.X >= Time.now(), statusvalue.Y, statusvalue.Z == 1
end

--- returns raw status vector
function Status.readraw(thing: Instance, name: string): Vector3
	local statusvalue = thing:GetAttribute(Prefix .. name)
	assert(typeof(statusvalue) == "Vector3")

	return statusvalue
end

--- formats statusvalue
function Status.format(statusvalue: Vector3): string
	local Expiry, Stacks, Indefinite = statusvalue.X, statusvalue.Y, statusvalue.Z
	local ExpiryString = Status.formatexpiry(Time.now() - Expiry)
	local StacksString = Status.formatstacks(Stacks)

	if Indefinite == 1 then
		return Stacks == 0 and ("") or (StacksString .. "	") .. "∞"
	else
		return Stacks == 0 and ("") or (StacksString .. "	") .. ExpiryString
	end
end

--- formats expiry
function Status.formatexpiry(x: number): string
	local d = string.gsub(string.sub(os.date("!%X", x), 4, 8), "^0", "")
	return d
end

--- formats stacks
function Status.formatstacks(x: number): string
	if x == 0 then
		return ""
	end
	return "x" .. x
end

return Status