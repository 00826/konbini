--!strict

local RunService = game:GetService("RunService")

local IsServer = RunService:IsServer()

local EntityRemote = script:WaitForChild("Remote")

local Rand = Random.new()

local function rstring(len: number)
	local b = buffer.create(len)
	for i = 0, len - 1, 1 do
		local value = Rand:NextInteger(1, 62)
		if value <= 26 then
			buffer.writeu8(b, i, value + 96)
		elseif value <= 52 then
			buffer.writeu8(b, i, value + 38)
		else
			buffer.writeu8(b, i, value - 5)
		end
	end

	return buffer.tostring(b)
end

--- ### Entity.luau
---
--- entity replication controller
local Entity = {
	Cache = {} :: { [string]: any };
	ListeningTo = {};
	
	Framerate = 1/40;
	Bucket = {} :: { [string]: {string}|boolean };

	NilString = "__nil";
}

--- inserts entity `e` stored at `Cache[id]` \
--- does not automatically queue after insertion
function Entity.insert(e: any): string
	assert(IsServer)
	
	local key = rstring(4)
	if Entity.Cache[key] ~= nil then
		repeat key = rstring(4)
		until Entity.Cache[key] == nil
	end

	Entity.Cache[key] = e

	task.defer(Entity.added, e, key)

	return key
end

--- removes entity `e` stored at `Cache[id]` \
--- disconnects, if connected, `Entity.listento(id)` \
--- fires bind `k_EntityRemoved` *prior* to removal \
--- does not automatically queue after removal
function Entity.remove(id: string)
	task.defer(Entity.removed, Entity.Cache[id], id)

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

--- equivalent to `Entity.Cache[key]`
function Entity.find(key: string): any?
	return Entity.Cache[key]
end

--- returns first `key(id), value(entity)` pair that satisfies `e[scope] == value`
function Entity.scope(scope: string, value: any): (string?, any?)
	assert(value ~= nil, "cannot scope a nil value")

	for id, e in Entity.Cache do
		if e[scope] == value then
			return id, e
		end
	end

	return
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

--- sends full entity cache to player
function Entity.all(player: Player)
	EntityRemote:FireClient(player, Entity.Cache) --- kbps disaster
end

--- writes key-values of update `u` into `e`, such that `e` inherits all non-nil key-values of `u` \
--- when possible, mutable data types (same-width buffers, same-type tables) have their references preserved
function Entity.update(e: any, u: any)
	local changes = table.create(32)

	for k, updatevalue in u do
		local thisvalue = e[k]

		if thisvalue == Entity.NilString then
			e[k] = nil
			if type(thisvalue) ~= type(nil) then
				table.insert(changes, k)
			end
		elseif thisvalue == nil then
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
	local recent = os.clock() - Entity.Framerate
	
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		local dt = now - recent
		if dt > Entity.Framerate then
			recent = now - (dt - Entity.Framerate)

			local packet = {} :: typeof(Entity.Bucket)

			for id, keys in Entity.Bucket do
				if type(keys) == "table" then
					--- update keys
					packet[id] = {}
					local e = Entity.Cache[id]
					if not e then continue end
					for _, key in keys do
						local value = e[key]
						if value == nil then
							value = Entity.NilString
						end
						(packet[id]::{})[key] = value
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
		end
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