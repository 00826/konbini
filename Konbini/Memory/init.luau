--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local JobId = game.JobId
local Users = buffer.create(1)

local UnitReceipts = table.create(1000);
local UnitsExpended = 0;
local FramerateMs = 10000;
local PullSize = 24;

local Partitions = 6;
local PartitionString = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ_";

local MapKeys = {};
local SortedMaps = {};

export type Entry = {
	--- u8[0] number of players present in this server
	Users: buffer;
	--- typeof(Memory.Local)
	Data: {[string]: any};
}

local Hook = require(script.Parent:WaitForChild("Hook"))

--- ### Memory.luau
---
--- memorystoreservice wrapper for the rate limit lovers \
--- `Local` is read-write, `Global` is read \
--- async functions yield until they can be safely called with respect to rate limits
local Memory = {
	--- local "memory"
	Local = {} :: {[any]: any};
	--- global "memory"
	Global = {} :: {[string]: {[any]: any}};
	--- concurrent players
	Concurrent = {};
}

--- returns would-be memory store should this key be stored in global memory
local function storeof(key: string)
	key = string.upper(string.sub(key, 1, 1))

	for i, mapkey in ipairs(MapKeys) do
		if string.find(mapkey, key) then
			return SortedMaps[mapkey]
		end
	end

	return SortedMaps[MapKeys[#MapKeys]]
end

--- returns an empty memory store entry
local function createentry(now: number)
	local e: Entry = {
		Users = Users;
		Data = Memory.Local;
	}

	buffer.writeu8(e.Users, 0, #Players:GetPlayers())

	return e
end

--- returns quota of available memory store units with respect to concurrent player count \
--- will always return at least 100
local function quota()
	local base = 0

	if #Players:GetPlayers() == 0 then
		base += 100
	end

	for _, count in Memory.Concurrent::any do
		base += count * 100
	end

	return math.max(100, base)
end

--- expends memory store unit
local function addunit(cost: number)
	table.insert(UnitReceipts, {
		Remove = DateTime.now().UnixTimestampMillis + 60000;
		Cost = cost
	})
	UnitsExpended += cost
end

--- pops all expired receipts, returning the number of now-available memory store units
local function collapseunits(now: number)
	local units = 0

	if #UnitReceipts == 0 then
		return units
	else
		if UnitReceipts[1].Remove > now then
			return units
		end

		local receipt = table.remove(UnitReceipts, 1)
		assert(receipt, "this should not happen (case covered by #UnitReceipts == 0)")

		return units + receipt.Cost + collapseunits(now)
	end
end

--- yields until enough memory store units are available
local function waitforalloc(size: number)
	if quota() - UnitsExpended > size then
		return true
	else
		repeat
			task.wait()
			local units = collapseunits(DateTime.now().UnixTimestampMillis)
			if units > 0 then
				UnitsExpended -= units
			end
		until quota() - UnitsExpended > size

		return true
	end
end

--- unwraps memorystore
local function unwrap(store: MemoryStoreSortedMap, lowerbounds: {key: string; sortkey: string?}?)
	local u = table.create(1000)

	waitforalloc(PullSize)

	local s, result = pcall(store.GetRangeAsync, store, Enum.SortDirection.Ascending, PullSize, lowerbounds)
	if s then
		local resultlen = #result
		addunit(math.max(1, resultlen))

		table.move(result, 1, resultlen, #u + 1, u)

		if resultlen < PullSize then
			return u
		end

		local reentry = unwrap(store, {key = result[resultlen].key;})
		local reentrylen = #reentry

		return table.move(reentry, 1, reentrylen, #u + 1, u)
	else
		warn(result)
		return u
	end
end

--- calls removeasync with respect to key, writing relevant data to the global table \
--- `memory store units:` `1` \
--- `expiry (?=300)` expiry time of entry associated with the key
function Memory.setasync(key: string, data: any, expiry: number?)
	waitforalloc(1)

	local store = storeof(key)
	local s, result = pcall(store.SetAsync, store, key, data, expiry or 300)
	if s then
		addunit(1)
	else
		warn(result)
	end
end

--- calls updateasync with respect to key, writing relevant data to the global table \
--- `memory store units:` `2` \
--- `expiry (?=300)` expiry time of entry associated with the key
function Memory.updateasync(key: string, data: any, expiry: number?)
	waitforalloc(2)

	local store = storeof(key)
	local ref = nil
	local s, result = pcall(store.UpdateAsync, store, key, function(entry: Entry)
		if not entry then
			ref = {
				Users = buffer.create(1);
				Data = data;
			}
			return ref
		end

		entry.Data = data
		ref = entry

		return entry
	end, expiry or 300)
	if s then
		addunit(2)
	else
		warn(result)
	end

	return ref
end

--- calls removeasync with respect to key, writing relevant data to the global table \
--- `memory store units:` `1`
function Memory.removeasync(key: string)
	waitforalloc(1)

	local store = storeof(key)
	local s, result = pcall(store.RemoveAsync, store, key)
	if s then
		addunit(1)
	else
		warn(result)
	end
end

--- returns first `data` and its associated `key` that satisfies `data[scope] == value`
function Memory.fromscope(scope: string, value: any, includelocal: boolean?): ({[any]: any}?, string?)
	if includelocal then
		local v = Memory.Local[scope]
		if v == value then
			return Memory.Local, JobId
		end
	end

	for k, entry in Memory.Global do
		local v = entry[scope]
		if v == value then
			return entry, k
		end
	end

	return nil, nil
end

--- returns concurrent player count based on cached global memory store
function Memory.concurrentplayers()
	local x = 0
	for _, count in Memory.Concurrent::any do
		x += count
	end

	return x
end

--- connects function to whenever the global memory store is updated
function Memory.globalmemoryupdated(f: (global: typeof(Memory.Global)) -> ())
	return Hook("k_GlobalMemoryUpdate").Connect(f)
end

if RunService:IsServer() then
	local MemoryStoreService = game:GetService("MemoryStoreService")

	local fdiv = #PartitionString // Partitions
	for i = 1, Partitions do
		local lower = 1 + ((i - 1) * fdiv)
		local upper = i * fdiv
		if i == Partitions then
			upper = -1
		end

		local mapkey = string.sub(PartitionString, lower, upper)

		table.insert(MapKeys, mapkey)
		SortedMaps[mapkey] = MemoryStoreService:GetSortedMap("k_Memory_" .. mapkey)
	end

	local later = 0
	local ispulling = false
	local orderedmaps = {}

	for k in SortedMaps do
		table.insert(orderedmaps, k)
	end
	table.sort(orderedmaps)

	local function frame()
		if ispulling then return end
	
		local now = DateTime.now().UnixTimestampMillis
		if later > now then return end
		later = now + FramerateMs
	
		do
			local units = collapseunits(now)
			if units > 0 then
				UnitsExpended -= units
			end
		end
	
		local unitquota = quota()
		if unitquota - UnitsExpended < 1 then return end
	
		ispulling = true
	
		do
			waitforalloc(1)

			if JobId ~= "" then --- corny freakazoid case where studio jobids are always an empty string
				local store = storeof(JobId)
				local s, result = pcall(store.SetAsync, store, JobId, createentry(now), 600)
				if s then
					addunit(1)
				else
					warn(result)
				end
			end
		end
	
		do
			table.clear(Memory.Global)
			table.clear(Memory.Concurrent)
	
			for i, range in ipairs(orderedmaps) do
				local u: {{key: string, value: Entry}} = unwrap(SortedMaps[range])
	
				for _, entry in u do
					local key = entry.key
					local value = entry.value
					Memory.Concurrent[key] = buffer.readu8(value.Users, 0)
					Memory.Global[key] = value.Data
				end
			end
	
			Hook("k_GlobalMemoryUpdate").Fire(Memory.Global)
		end
	
		ispulling = false
	end

	RunService.Heartbeat:Connect(frame)
	
	local function onclose()
		if JobId ~= "" then
			local shard = storeof(JobId)
			pcall(shard.RemoveAsync, shard, JobId)
		end
	end
	
	game:BindToClose(onclose)
end

return Memory