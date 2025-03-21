--!strict
--!native

local types = require(script.Parent.types)

local Encoder = require(script.Parent.Encoder)

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

--- similar to `table.insert`, where `T[random alphanumeric key] = value` \
--- returns `random alphanumeric key` for convenience \
--- `len (?=4)`: key length
function TableK.insertkey(t: {[string]: any}, value: any, len: number?)
	local key = string.rep("0", len or 4)
	repeat key = Encoder.string(len or 4)
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
			assert(comp, `comp() must be passed for non-numeric droptable \{[{typeof(key)}]: {typeof(value)}}`)
		end
	end

	for _ = 1, count or 1 do
		local roll, passed = (R or types.R):NextNumber(0, weightsum), 0
		for key, value in droptable do
			if comp then
				passed += comp(value)
			elseif type(value) == "number" then
				passed += value
			else
				assert(comp, `comp() must be passed for non-numeric droptable \{[{typeof(key)}]: {typeof(value)}}`)
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
		(R or types.R):Shuffle(B)
	
		local offset = (count or 1) - 1
		local start = (R or types.R):NextInteger(1, len - offset)
		local range = math.clamp(start + offset, 1, #B)

		return table.move(B, start, range, 1, table.create(count or 1))
	end
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
	local max = #A

	return table.move(
		A,
		1 + math.clamp((offset - 1) * size, 0, max),
		math.clamp(offset * size, 0, max),
		1,
		table.create(max)
	)
end

--- returns true if table contains value and its associated key
function TableK.contains(t: {[any]: any}, value: any): (boolean, string?)
	for k, v in t do
		if value == v then
			return true, k
		end
	end

	return false
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

return table.freeze(TableK)