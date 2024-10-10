--!strict
--!native
--!optimize 2

local Encoder					= require(script.Parent.Encoder)

local DefaultR					= Random.new()

--- ### Table.luau
---
--- extension of table library
local K_Table = {
	Remote = script:WaitForChild("SyncRemote");

	SyncCache = {};
	SyncLimit = 1;
	SyncTimes = {};
}

--- removes and returns the first (oldest) element in queue
function K_Table.queue_pop<T>(queue: {T}): T?
	return table.remove(queue, 1)
end

--- returns the first (oldest) element in queue
function K_Table.queue_front<T>(queue: {T}): T?
	return queue[1]
end

--- returns the last (newest) element in queue
function K_Table.queue_back<T>(queue: {T}): T?
	return queue[#queue]
end

--- adds a value to the back of queue
function K_Table.queue_push<T>(queue: {T}, value: T): ()
	table.insert(queue, value)
end

--- pushes a value to queue, if any only if it isn't already an element of the queue
function K_Table.queue_ifandonlyif<T>(queue: {T}, value: T): boolean
	if not table.find(queue, value) then
		table.insert(queue, value)
		return true
	end
	return false
end

--- pushes all values of source into queue
function K_Table.queue_fill<T>(queue: {T}, source: {T}): ()
	for _, v in source do
		table.insert(queue, v)
	end
end

--- pops all values in queue, calling `f(value)` as they are popped
function K_Table.queue_flush<T>(queue: {T}, f: (value: T) -> ()): ()
	local value = table.remove(queue, 1)
	if value then
		f(value)
		K_Table.queue_flush(queue, f)
	else
		return
	end
end

--- encodes string-number table as a string
--- ```
--- encode({str = -2, dex = 10, int = 7}) -> "str:-2/dex:10/int:7"
--- ```
function K_Table.encode(T: {[string]: number}): string
	local StatString = ""
	for k, v in T do
		StatString ..= k ..":".. v .. "/"
	end

	return string.sub(StatString, 1, -2)
end

--- decodes string as a string-number table
--- ```
--- decode("str:-2/dex:10/int:7") -> {str = -2, dex = 10, int = 7}
--- ```
function K_Table.decode(str: string): {[string] : number}
	local T = {}

	for _, kv in string.split(str, "/") do
		local Split = string.split(kv, ":")
		T[Split[1]] = tonumber(Split[2]) or 0
	end

	return T
end

--- reads single value stored in encoded string
--- ```
--- read("str:-2/dex:10/int:7", "dex") -> 10
--- ```
function K_Table.read(str: string, key: string): number
	return tonumber(string.match(str, "%f[A-Za-z]" .. key .. "%f[^A-Za-z]:(%d+)") or 0) or 0
end

--- returns a deep-copy of table
function K_Table.deepcopy(T: {[any]: any}): {[any]: any}
	local Copy = {}

	for k, v in T do
		if type(v) == "table" then
			Copy[k] = K_Table.deepcopy(v)
		else
			Copy[k] = v
		end
	end

	return Copy
end

--- packs vararg into a space-allocated array
function K_Table.pack(...: any): {any}
	local temp = {...}
	return table.move(temp, 1, #temp, 1, table.create(#temp))
end

--- returns average or weighted average of elements in array \
--- assumes a single-type array populated with types that support operators `+`, `*`, `/`
function K_Table.average(A: {any}, weights: {number}?): any
	local n = #A
	local T = table.remove(A, 1)
	for i, V in ipairs(A) do
		local Weight = (weights and weights[i] or 1)
		T += V * Weight
	end
	return T and T / n
end

--- returns a frozen, space-allocated, shallow-copy of array
function K_Table.readonly<T>(A: {T}): {T}
	local t = table.create(#A)
	for _, v in ipairs(A) do
		table.insert(t, v)
	end
	return t
end

--- returns list of elements picked from drop table \
--- assume sum of odds in drop table equate to 100
function K_Table.pickfromdroptable(D: {[string]: number}, n: number, R: Random?): {string}
	if not R then R = DefaultR end
	if not n then n = 1 end

	assert(R)
	assert(n)

	local Items = table.create(n)

	for _ = 1, n do
		local Roll, Passed = 100 * (R:NextNumber()), 0
		for Key, Value in D do
			Passed += Value
			if Roll > Passed then continue end
			table.insert(Items, Key)
			break
		end
	end

	return Items
end

--- returns non-repeating list of elements picked from array
function K_Table.pickfromlist<T>(A: {T}, n: number?, R: Random?): {T}
	if not R then R = DefaultR end
	if not n then n = 1 end

	assert(R)
	assert(n)

	local B = table.clone(A)
	R:Shuffle(B)

	return table.move(B, 1, math.clamp(n, 1, #B), 1, table.create(n))
end

--- returns true if table contains value and its associated key
function K_Table.contains(A: {[any]: any}, value: any): (boolean, string?)
	for k, v in A do
		if value == v then
			return true, k
		end
	end
	return false
end

--- returns shuffled copy of array
function K_Table.shuffle(A: {any}, R: Random?): {any}
	R = R or DefaultR
	assert(R)

	local B = table.clone(A)
	R:Shuffle(B)

	return B
end

--- similar to `table.insert`, where `T[random alphanumeric key] = value` \
--- returns `random alphanumeric key` for convenience \
--- `len (?=4)`: key length
function K_Table.assign(T: {[string]: any}, value: any, len: number?): string
	local key = string.rep("0", len or 4)
	repeat
		key = Encoder.string(len or 4)
	until T[key] == nil
	T[key] = value
	return key
end

--- reflects value such that `destination[i] = source[i]` \
--- equivalent to `table.move(source, i, i, i, destination)`
function K_Table.reflect(source: {any}, destination: {any}, i: number)
	table.move(source, i, i, i, destination)
end

--- performs a binary search on sorted array \
--- `comp` returns: \
--- `0`: value == desired value; return value \
--- `1`: value < desired value; search to the left \
--- `2`: value > desired value; search to the right \
---
--- ```lua
--- --- find x in [1, 100]:
--- local comp = function(value: number): number
--- 	if value == x then
--- 		return 0
--- 	else
--- 		return value < x and 1 or 2
--- 	end
--- end
--- ```
function K_Table.search<T>(A: {T}, comp: (value: T) -> number): T?
	local L = 1
	local R = #A

	if L > R then
		return nil
	else
		local idx = (L + R) // 2
		local value = A[idx]

		local result = comp(value)

		if result == 0 then
			return value
		else
			if result == 1 then
				L = idx + 1
			elseif result == 2 then
				R = idx - 1
			else
				error(`comp {comp} did not return exactly 0, 1, or 2`)
			end
			return K_Table.search(table.move(A, L, R, 1, table.create(L + R)), comp)
		end
	end
end

--- shallow-clones target *exclusively* with keys and/or indices
function K_Table.only(target: {any}, keys: {any}?, indices: {number}?): {}
	local clone = {}

	if keys then
		for _, key in keys do
			clone[key] = target[key]
		end
	end
	if indices then
		for _, idx in indices do
			table.move(target, idx, idx, idx, clone)
		end
	end

	return clone
end

--- shallow-clones target with the *exception* of keys and/or indices
function K_Table.except(target: {any}, keys: {any}?, indices: {number}?): {}
	local clone = {}

	if keys then
		for _, key in target do
			if table.find(keys, key) then
				continue
			else
				clone[key] = target[key]
			end
		end
	end
	if indices then
		for i, v in ipairs(target) do
			if table.find(indices, i) then
				continue
			else
				table.move(target, i, i, i, clone)
			end
		end
	end

	return clone
end

--- merges values from source into target, if they dont already exist
function K_Table.merge<T>(target: {T}, source: {T})
	for _, value in source do
		K_Table.queue_ifandonlyif(target, value)
	end
end

--- patches target table using source as a truth state
function K_Table.patch<T>(target: {[T]: any}, source: {[T]: any})
	for k in target do
		if not source[k] then
			target[k] = nil
		end
	end
	for k, v in source do
		if type(target[k]) ~= type(v) then
			target[k] = v
		end
	end
end

--- returns length of key-value table
function K_Table.len(T: {[any]: any}): number
	local x = 0

	for _ in T do
		x += 1
	end

	return x
end

--- reverse-iterates through array with iterator function `f`: \
--- `f(i, v) -> 0`: `v` is removed from `A` \
--- `f(i, v) -> 1`: loop `continue` \
--- `f(i, v) -> 2`: loop `break`
function K_Table.ipairs_r<T>(A: {T}, f: (i: number, v: T) -> number?)
	for i = #A, 1, -1 do
		local Result = f(i, A[i])
		if Result == 0 then
			table.remove(A, i)
		elseif Result == 1 then
			continue
		elseif Result == 2 then
			break
		end
	end
end

--- limits size of array
function K_Table.limit(A: {any}, size: number)
	if #A > size then
		table.remove(A)
		K_Table.limit(A, size)
	else
		return
	end
end

--- rotates array `A` `x` times such that:
--- ```
--- rotate([1, 2, 3, 4, 5], 1) -> [5, 1, 2, 3, 4]
--- rotate([1, 2, 3, 4, 5], -1) -> [2, 3, 4, 5, 1]
--- ```
function K_Table.rotate(A: {any}, x: number?)
	x = x or 1
	assert(x)

	if x ~= 0 then
		if x > 0 then
			local value = table.remove(A)
			table.insert(A, 1, value)
		elseif x < 0 then
			local value = table.remove(A, 1)
			table.insert(A, value)
		end
		K_Table.rotate(A, x - math.sign(x))
	else
		return
	end
end

--- returns elements of array as a page
--- ```
--- t = {} -- [1, ..., 25]
--- page(t, 10, 1) -- [1, ..., 10]
--- page(t, 10, 2) -- [11, ..., 20]
--- page(t, 10, 3) -- [21, ..., 25]
--- page(t, 10, 4) -- []
--- ```
function K_Table.page<T>(A: {T}, size: number, offset: number): {T}
	local Max = #A
	return table.move(
		A,
		1 + math.clamp((offset - 1) * size, 0, Max),
		math.clamp(offset * size, 0, Max),
		1,
		table.create(Max)
	)
end

return table.freeze(K_Table)