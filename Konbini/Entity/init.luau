--!strict

local RunService = game:GetService("RunService")

local IsServer = RunService:IsServer()

local EntityRemote = script:WaitForChild("EntityRemote")

local Hook = require(script.Parent.Hook)
local TableK = require(script.Parent.Table)

--- ### Entity.luau
---
--- entity handler, belongs as a standalone
local Entity = {
	Cache = {};
	
	Rate = 1/40;
	Bucket = {} :: {[string]: {string}|boolean};
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

	local key = TableK.assign(Entity.Cache, e, 4)
	Hook("k_EntityAdded").Fire(e, key)

	return e, key
end

--- removes entity `e` stored at `Cache[id]` \
--- fires bind `k_EntityRemoved` *prior* to removal \
--- does not automatically queue after removal
function Entity.remove(id: string)
	Hook("k_EntityRemoved").Fire(Entity.Cache[id], id)

	--[[if Entity.Cache[id] then
		table.clear(Entity.Cache[id])
	end]]

	Entity.Cache[id] = nil
end

--- queues keys of entity at `Cache[id]` for the next replication cycle \
--- if `keys` are omitted, then all keys will be queued
function Entity.queue(id: string, keys: {string}?)
	local e = Entity.Cache[id]
	if not e then
		Entity.Bucket[id] = false
		return
	end

	if Entity.Bucket[id] == nil then
		Entity.Bucket[id] = table.create(16)
	end
	local ref = Entity.Bucket[id]
	assert(type(ref) == "table", "this should not happen")

	if keys then
		for _, key in keys do
			TableK.queue_ifandonlyif(ref, key)
		end
	else
		for key in e do
			TableK.queue_ifandonlyif(ref, key)
		end
	end
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

--- returns array of `e` from `4*n`-width string buffer of `id`'s \
--- assumes that `len(b) % 4 == 0`
@native
function Entity.frombuffer(b: buffer): {}
	local len = buffer.len(b)
	local from = table.create(len // 4)

	for i = 0, len - 4, 4 do
		local e = Entity.Cache[buffer.readstring(b, i, 4)]
		if e and not table.find(from, e) then
			table.insert(from, e)
		end
	end

	return from
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

--- fires function when an entity is added
function Entity.added(f: (e: any, id: string) -> ())
	return Hook("k_EntityAdded").Connect(f)
end

--- fires function when an entity is removed
function Entity.removed(f: (e: any, id: string) -> ())
	return Hook("k_EntityRemoved").Connect(f)
end

--- sends full entity cache to player(kbps disaster)
function Entity.all(player: Player)
	EntityRemote:FireClient(player, Entity.Cache)
end

--- writes key-values of update `u` into `e`, such that `e` inherits all non-nil key-values of `u` \
--- when possible, mutable data types (same-width buffers, same-type tables) have their references preserved
function Entity.update(e: {}, u: {})
	for k, updatevalue in u do
		local thisvalue = e[k]
		if thisvalue == nil then
			e[k] = updatevalue
		elseif thisvalue == updatevalue then
			continue
		else
			if type(updatevalue) ~= type(thisvalue) then
				e[k] = updatevalue
			else
				if type(updatevalue) == "buffer" then
					if buffer.len(updatevalue) == buffer.len(thisvalue) then
						buffer.copy(thisvalue, 0, updatevalue)
					else
						e[k] = updatevalue
					end
				elseif type(updatevalue) == "table" then --- ._. a billion dollars cant narrow a table
					table.clear(thisvalue)

					if #updatevalue::{any} > 0 then
						table.move(updatevalue::{any}, 1, #updatevalue::{any}, 1, thisvalue)
					else
						for a, b in updatevalue::{any} do
							thisvalue[a] = b
						end
					end
				else
					e[k] = updatevalue
				end
			end
		end
	end
end

if IsServer then
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		if elapsed < Entity.Rate then return end
		elapsed -= Entity.Rate

		local packet = {} :: typeof(Entity.Bucket)

		for id, keys in Entity.Bucket do
			if type(keys) == "table" then
				-- update keys
				packet[id] = {}
				local e = Entity.Cache[id]
				if not e then continue end
				for _, key in keys do
					(packet[id]::{})[key] = e[key]
				end
			elseif keys == false then
				-- entity destroyed
				packet[id] = false
			else
				warn(`fringe case this should not happen {id} {type(keys)} {keys}`)
			end

			Entity.Bucket[id] = nil -- does this leak?
		end

		if next(packet) == nil then return end

		EntityRemote:FireAllClients(packet)
	end)
else
	EntityRemote.OnClientEvent:Connect(function(packet: {[string]: {}|boolean})
		local added = {}
		local removed = {}

		for id, update in packet do
			if type(update) == "table" then
				if not Entity.Cache[id] then
					Entity.Cache[id] = update
					added[id] = update
				else
					Entity.update(Entity.Cache[id], update)
				end
			elseif type(update) == "boolean" then
				if Entity.Cache[id] then
					removed[id] = Entity.Cache[id]
					Entity.Cache[id] = nil
				end
			end
		end

		for k, v in added do
			Hook("k_EntityAdded").Fire(v, k)
		end

		for k, v in removed do
			Hook("k_EntityRemoved").Fire(v, k)
		end
	end)
end

return Entity