--!strict

local types						= require(script.Parent.types)

local RunService				= game:GetService("RunService")

local IsServer					= RunService:IsServer()

local EntityRemote				= script:WaitForChild("EntityRemote") :: RemoteEvent

local Bind						= require(script.Parent.Bind)
local KTable					= require(script.Parent.Table)

--- ### Entity.luau
---
--- entity handler, belongs as a standalone
local Entity = {
	Cache						= {};
}

--- creates entity `e` from template `t (?={})`, creates id `id` \
--- stores `e` at `e = Cache[id]` \
--- buffers and tables in `t` are copied
function Entity.create(t: {[string]: any}?): ({[string]: any}, string)
	assert(IsServer)

	local e = {}
	if t then
		for k, v in t do
			if type(v) == "buffer" then
				e[k] = buffer.create(buffer.len(v))
				buffer.copy(e[k], 0, v, 0)
			elseif type(v) == "table" then
				e[k] = table.clone(v :: any) :: any
			else
				e[k] = v :: any
			end
		end
	end
	return e, KTable.assign(Entity.Cache, e, 4)
end

--- removes entity `e` stored at `Cache[id]` 
function Entity.remove(id: string)
	if Entity.Cache[id] then
		table.clear(Entity.Cache[id])
	end
	Entity.Cache[id] = nil
end

--- returns first `id` that satisfies `e = Cache[id]`
function Entity.tostring(e: {}): string?
	for id, thisentity in Entity.Cache do
		if thisentity == e then
			return id
		end
	end
	return
end

--- returns `e` that satisfies `e = Cache[id]`
function Entity.fromstring(id: string): {}?
	return Entity.Cache[id]
end

--- returns first `e` that satisfies `e[scope] == value`
function Entity.fromscope(scope: string, value: any): ({}?, string?)
	assert(value ~= nil, "cannot scope a nil value")

	for id, thisentity in Entity.Cache do
		if thisentity[scope] == value then
			return thisentity, id
		end
	end
	return
end

--- returns key-value subset of `Cache` where e in subset satisfies `comp(e) -> true`
function Entity.subset(scope: string, comp: (e: {}) -> boolean): {[string]: {}}
	local subset = {}

	for id, thisentity in Entity.Cache do
		if comp(thisentity) then
			subset[id] = thisentity
		end
	end
	return subset
end

--- reflects entity data across the network \
--- if `ids` are omitted, then entire cache is sent \
--- nil-ids are sent as `false`
function Entity.sync(ids: {string}?, player: Player?)
	assert(IsServer)

	local packet = {}
	if ids then
		for _, id in ids do
			packet[id] = Entity.Cache[id] or false
		end
	else
		for id, e in Entity.Cache do
			packet[id] = e or false
		end
	end

	if player then
		EntityRemote:FireClient(player, packet)
	else
		EntityRemote:FireAllClients(packet)
	end
end

--- fires function when an entity is added
function Entity.added(f: (e: {}, id: string) -> ()): types.Disconnect
	return Bind("k_Entity_added"):Connect(f)
end

--- fires function when an entity is removed
function Entity.removed(f: (e: {}, id: string) -> ()): types.Disconnect
	return Bind("k_Entity_removed"):Connect(f)
end

if IsServer then
else
	EntityRemote.OnClientEvent:Connect(function(packet: {[string]: {}|boolean})
		local added = {}
		local removed = {}

		for id, thisentity in packet do
			if type(thisentity) == "table" then
				if not Entity.Cache[id] then
					Entity.Cache[id] = thisentity
					added[id] = thisentity
				else
					local e = Entity.Cache[id]
					for k, v in thisentity do
						e[k] = v
					end
				end
			elseif type(thisentity) == "boolean" then
				if Entity.Cache[id] then
					removed[id] = Entity.Cache[id]
					Entity.Cache[id] = nil
				end
			end
		end

		for k, v in added do
			Bind("k_Entity_added"):Fire(v, k)
		end

		for k, v in added do
			Bind("k_Entity_removed"):Fire(v, k)
		end
	end)
end

return Entity