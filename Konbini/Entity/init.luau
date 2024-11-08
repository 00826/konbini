--!strict

local types = require(script.Parent.types)

local RunService = game:GetService("RunService")

local IsServer = RunService:IsServer()

local EntityRemote = script:WaitForChild("EntityRemote")

local Bind = require(script.Parent.Bind)
local KTable = require(script.Parent.Table)

--- ### Entity.luau
---
--- entity handler, belongs as a standalone
local Entity = {
	Cache = {};
	
	rate = 1/40;
	bucket = table.create(128);
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

--- queues entity at `Cache[id]` for the next replication cycle
function Entity.queue(id: string)
	KTable.queue_ifandonlyif(Entity.bucket, id)
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

--- fires function when an entity is added
function Entity.added(f: (e: {}, id: string) -> ()): types.Disconnect
	return Bind("k_Entity_added"):Connect(f)
end

--- fires function when an entity is removed
function Entity.removed(f: (e: {}, id: string) -> ()): types.Disconnect
	return Bind("k_Entity_removed"):Connect(f)
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
		if elapsed < Entity.rate then return end
		elapsed -= Entity.rate

		local len = #Entity.bucket
		if len < 1 then
			return
		else
			local ids = table.move(Entity.bucket, 1, len, 1, table.create(len))
			table.clear(Entity.bucket)
	
			local packet = {}
			for _, id in ids do
				packet[id] = Entity.Cache[id] or false
			end
	
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
			Bind("k_Entity_added"):Fire(v, k)
		end

		for k, v in removed do
			Bind("k_Entity_removed"):Fire(v, k)
		end
	end)
end

return Entity