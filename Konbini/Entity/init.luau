--!strict

local RunService = game:GetService("RunService")

local IsServer = RunService:IsServer()

local EntityRemote = script:WaitForChild("EntityRemote")

local Rand = Random.new()

local function rstring(len: number)
	local str = string.rep("0", len)
	for i = 1, len do
		local value = Rand:NextInteger(1, 36)
		if value <= 26 then
			local coinflip = Rand:NextInteger(0, 1) == 0
			if coinflip then
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

local function insertkey(t: {[string]: any}, value: any)
	local key = string.rep("0", 4)
	repeat key = rstring(4)
	until t[key] == nil

	t[key] = value

	return key
end

--- ### Entity.luau
---
--- entity handler, belongs as a standalone
local Entity = {
	Cache = {} :: {[string]: any};
	ListeningTo = {};
	
	Rate = 1/40;
	Bucket = {} :: {[string]: {string}|boolean};
}

--- inserts entity `e` stored at `Cache[id]` \
--- does not automatically queue after insertion
function Entity.insert(e: any): string
	assert(IsServer)
	
	local key = insertkey(Entity.Cache, e)
	task.defer(Entity.added, e, key)

	return key
end

--- removes entity `e` stored at `Cache[id]` \
--- disconnects, if connected, `Entity.listento(id)` \
--- fires bind `k_EntityRemoved` *prior* to removal \
--- does not automatically queue after removal
function Entity.remove(id: string)
	task.defer(Entity.removed, Entity.Cache[id], id)

	--[[if Entity.Cache[id] then
		table.clear(Entity.Cache[id])
	end]]

	Entity.Cache[id] = nil
	table.remove(Entity.ListeningTo, table.find(Entity.ListeningTo, id) or 0)
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
			if not table.find(ref, key) then
				table.insert(ref, key)
			end
		end
	else
		for key in e do
			if not table.find(ref, key) then
				table.insert(ref, key)
			end
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
function Entity.fromstring(id: string): any?
	return Entity.Cache[id]
end

--- returns `#Entity.Cache`
function Entity.len()
	local len = 0
	for _ in Entity.Cache do
		len += 1
	end

	return len
end

--- returns array of `e` from `4*n`-width string buffer of `id`'s \
--- assumes that `len(b) % 4 == 0`
@native
function Entity.frombuffer(b: buffer): any
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

--- returns first `e` and its associated `key` that satisfies `e[scope] == value`
function Entity.fromscope(scope: string, value: any): (any?, string?)
	assert(value ~= nil, "cannot scope a nil value")

	for id, thisentity in Entity.Cache do
		if thisentity[scope] == value then
			return thisentity, id
		end
	end
	return
end

--- yields thread until entity that satisfies `e[scope] == value` is added
function Entity.waitfromscope(scope: string, value: any): (any, string)
	assert(value ~= nil, "cannot scope a nil value")
	local a, b

	repeat
		for id, thisentity in Entity.Cache do
			if thisentity[scope] == value then
				a = thisentity
				b = id
			end
		end
		task.wait()
	until a and b

	return a, b
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

--- listens to key changes for this entity
function Entity.listento(id: string)
	if not table.find(Entity.ListeningTo, id) then
		table.insert(Entity.ListeningTo, id)
	end
end

--- deferred when an entity is added \
--- left blank to be overwritten externally
function Entity.added(e: any, id: string)
	
end

--- deferred when an entity, added by `Entity.listento`, has any of its keys changed \
--- left blank to be overwritten externally
function Entity.changed(e: any, id: string, changes: {unknown})
	
end

--- deferred when an entity is removed \
--- left blank to be overwritten externally
function Entity.removed(e: any, id: string)
	
end

--- sends full entity cache to player(kbps disaster)
function Entity.all(player: Player)
	EntityRemote:FireClient(player, Entity.Cache)
end

--- writes key-values of update `u` into `e`, such that `e` inherits all non-nil key-values of `u` \
--- when possible, mutable data types (same-width buffers, same-type tables) have their references preserved
function Entity.update(e: any, u: any)
	local changes = table.create(32)

	for k, updatevalue in u do
		local thisvalue = e[k]
		if thisvalue == nil then
			e[k] = updatevalue
			table.insert(changes, k)
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
			table.insert(changes, k)
		end
	end

	return changes
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
				--- update keys
				packet[id] = {}
				local e = Entity.Cache[id]
				if not e then continue end
				for _, key in keys do
					(packet[id]::{})[key] = e[key]
				end
			elseif keys == false then
				--- entity destroyed
				packet[id] = false
			else
				warn(`fringe case this should not happen {id} {type(keys)} {keys}`)
			end

			Entity.Bucket[id] = nil --- does this leak?
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
					local changes = Entity.update(Entity.Cache[id], update)
					if (#changes > 0) and (table.find(Entity.ListeningTo, id)) then
						task.defer(Entity.changed, Entity.Cache[id], id, changes)
					end
				end
			elseif type(update) == "boolean" then
				if Entity.Cache[id] then
					removed[id] = Entity.Cache[id]
					Entity.Cache[id] = nil
					table.remove(Entity.ListeningTo, table.find(Entity.ListeningTo, id) or 0)
				end
			end
		end

		for k, v in added do
			task.defer(Entity.added, v, k)
		end

		for k, v in removed do
			task.defer(Entity.removed, v, k)
		end
	end)
end

return Entity