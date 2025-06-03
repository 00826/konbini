--!strict
--!native

local Rand = Random.new()

local function rstring(len: number)
	local str = ""
	for i = 1, len do
		local value = Rand:NextInteger(1, 36)
		if value <= 26 then
			if Rand:NextInteger(0, 1) == 0 then
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

--- `Item = {[1] = key::string; [2...] = value::any}`
export type Item = { string|any }

--- ### Table.luau
---
--- extension of table library
local TableK = {}

--- returns a reverse iterator function, array `t`, and the number `0`
function TableK.ipairsr<T>(t: {T}): (({T}, number) -> (number?, T), {T}, number)
	return coroutine.wrap(function()
		for i = #t, 1, -1 do
			coroutine.yield(i, t[i])
		end
	end), t, 0
end

--- similar to `table.insert`, where `T[random alphanumeric key (len ?=4)] = value` \
--- returns `random alphanumeric key` for convenience
function TableK.insertkey(t: {[string]: any}, value: any, len: number?)
	local key = string.rep("0", len or 4)

	repeat key = rstring(len or 4)
	until t[key] == nil

	t[key] = value

	return key
end

--- returns average or weighted average of elements in array \
--- assumes a single-type array populated with types that support operators `+`, `*`, `/`
function TableK.average(array: {any}, weights: {number}?)
	local len = #array
	local sum = table.remove(array, 1)
	for i, v in ipairs(array) do
		sum += v * (weights and weights[i] or 1)
	end

	return sum and sum / len
end

--- returns list of elements picked from droptable \
--- compatible with weighted tables whose sum of values does not equal 100
function TableK.droptable<T>(droptable: {[string]: T}, count: number?, R: Random?, comp: ((T) -> number)?)
	local items = table.create(count or 1)
	local weightsum = 0

	for key, value in droptable do
		if comp then
			weightsum += comp(value)
		elseif type(value) == "number" then
			weightsum += value
		else
			assert(comp, "comp() must be passed for non-numeric droptable {[%s]: %s}", typeof(key), typeof(value))
		end
	end

	for _ = 1, count or 1 do
		local roll, passed = (R or Rand):NextNumber(0, weightsum), 0
		for key, value in droptable do
			if comp then
				passed += comp(value)
			elseif type(value) == "number" then
				passed += value
			else
				assert(comp, "comp() must be passed for non-numeric droptable {[%s]: %s}", typeof(key), typeof(value))
			end

			if roll < passed then
				table.insert(items, key)
				break
			end
		end
	end

	return items
end

--- returns list of elements drawn from droplist
function TableK.droplist<T>(droplist: {T}, count: number?, R: Random?)
	local len = #droplist
	if len == 0 then
		--- warn(`empty array passed, returning new empty array`)
		return table.create(0)
	else
		local B = table.clone(droplist);
		(R or Rand):Shuffle(B)
	
		local offset = (count or 1) - 1
		local start = (R or Rand):NextInteger(1, len - offset)
		local range = math.clamp(start + offset, 1, #B)

		return table.move(B, start, range, 1, table.create(count or 1))
	end
end

--- returns list of keys contained in `t` \
--- `allocate (?=32)`: array portion allocated
function TableK.listkeys<T>(t: {[T]: any}, allocate: number?)
	local list = table.create(allocate or 32)

	for k in t do
		table.insert(list, k)
	end

	return list
end

--- rotates array `A` `x` times such that:
--- ```
--- rotate([1, 2, 3, 4, 5], 1) -> [5, 1, 2, 3, 4]
--- rotate([1, 2, 3, 4, 5], -1) -> [2, 3, 4, 5, 1]
--- ```
function TableK.rotate(A: {any}, x: number?)
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
		TableK.rotate(A, x - math.sign(x))
	else
		return
	end
end

--- returns elements of array as a page
--- ```
--- t = {} --- [1, ..., 25]
--- page(t, 10, 1) --- [1, ..., 10]
--- page(t, 10, 2) --- [11, ..., 20]
--- page(t, 10, 3) --- [21, ..., 25]
--- page(t, 10, 4) --- []
--- ```
function TableK.page<T>(A: {T}, size: number, offset: number)
	local len = #A

	return
		table.move(
			A,
			1 + math.clamp((offset - 1) * size, 0, len),
			math.clamp(offset * size, 0, len),
			1,
			table.create(len)
		)
end

--- returns the max # of pages that can be displayed with respect to size
function TableK.numpages(A: {any}, size: number)
	return math.clamp(math.ceil(#A / size), 1, math.huge)
end

--- returns key-value should `value` exist in `t`
function TableK.fromvalue(t: {[any]: any}, value: any): (any, any)
	for k, v in t do
		if v == value then
			return k, v
		end
	end

	return nil, nil
end

--- returns a deep-copy of table
function TableK.deepcopy(t: {[any]: any}): {[any]: any}
	local copy = {}

	for k, v in t do
		if type(v) == "table" then
			copy[k] = TableK.deepcopy(v)
		else
			copy[k] = v
		end
	end

	return copy
end

--- returns union of a and b, avoiding repeating elements and preserving sort order
function TableK.union<T>(a: {T}, b: {T})
	local union = table.clone(a)

	for _, value in ipairs(b) do
		if not table.find(union, value) then
			table.insert(union, value)
		end
	end

	return union
end

--- patches target table using source as a truth state
function TableK.patch<T>(target: {[T]: any}, source: {[T]: any})
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

--- limits size of array
function TableK.limit(A: {any}, size: number)
	if #A > size then
		table.remove(A)
		TableK.limit(A, size)
	else
		return
	end
end

--- returns an item \
--- equivalent to `return {id, value}`
function TableK.itemcreate(id: string, value: any): Item
	return {id, value}
end

--- inserts item, by its associated `id`, to list \
--- *does not account for duplicates*
function TableK.iteminsert(list: {Item}, id: string, value: any)
	table.insert(list, TableK.itemcreate(id, value))
end

--- returns:
--- `id (i[1])` item id \
--- `value (i[2...])` item value(s)
function TableK.itemunpack(i: Item): (string, ...any)
	return unpack(i)
end

--- removes all items associated with `id`, from list \
--- *starts at `i = #list`, ends at `i = 1`, accounting for duplicates*
function TableK.itemremove(list: {Item}, id: string)
	for i = #list, 1, -1 do
		if list[i][1] == id then
			table.remove(list, i)
		end
	end
end

--- returns item, from its associated `id`, stored in list
function TableK.itemfind(list: {Item}, id: string): Item?
	for _, thing in list do
		if thing[1] == id then
			return thing
		end
	end

	return nil
end

return TableK