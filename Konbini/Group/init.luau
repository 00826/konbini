--!strict

local Cache						= {} :: {[string]: {any}}

--- ### Group.luau
---
--- value grouper
local Group = {}

--- creates empty group, optionally populated by vararg
function Group.create<T>(name: string, size: number, ...: T?): {T}
	if not Cache[name] then
		Cache[name] = table.create(64)
	else
		warn(`group "{name}" already exists`)
	end
	Group.add(name, ...)

	return Cache[name]
end

--- adds values to group
function Group.add<T>(name: string, ...: T)
	local t = Cache[name]
	assert(t)

	for _, v in {...} do
		if table.find(t, v) then continue end
		table.insert(t, v)
	end
end

--- returns group
function Group.get(name: string): {any}?
	local t = Cache[name]
	assert(t)

	return Cache[name]
end

--- returns a copy of group
function Group.copy(name: string): {any}
	local t = Cache[name]
	assert(t)

	return table.clone(t)
end

--- clears group
function Group.clear(name: string): ()
	local t = Cache[name]
	assert(t)

	table.clear(t)
end

--- clears and destroys group
function Group.remove(name: string): ()
	local t = Cache[name]
	assert(t)

	table.clear(t)
	Cache[name] = nil
end

return Group