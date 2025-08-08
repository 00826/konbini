--!strict
--!native

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

--- ### Table.luau
---
--- table library extension
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
	local key = rstring(len or 4)

	if t[key] ~= nil then
		repeat key = rstring(4)
		until t[key] == nil
	end

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

--- returns list of entries from weighted droptable
function TableK.droptable(droptable: { { key: string, weight: number } & {[string]: any} }, count: number?, R: Random?)
	local items = table.create(count or 1)
	local weightsum = 0

	for _, entry in droptable do
		weightsum += entry.weight
	end

	for _ = 1, count or 1 do
		local roll, passed = (R or Rand):NextNumber(0, weightsum), 0
		for _, entry in droptable do
			passed += entry.weight

			if roll <= passed then
				table.insert(items, entry)
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
			table.create(size)
		)
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

--- returns `a ∪ b` (`table.move(b, 1, #b, #a + 1, table.clone(a))`)
function TableK.union<T>(a: {T}, b: {T})
	return table.move(b, 1, #b, #a + 1, table.clone(a))
end

--- returns `a ∖ b`
function TableK.negate<T>(a: {T}, b: {T})
	local c = table.clone(a)
	for _, value in b do
		table.remove(c, table.find(c, value) or 0)
	end

	return c
end

--- returns a page controller
function TableK.createpagecontroller(pagesize: number)
	return {
		Offset = 1;
		Options = table.create(pagesize);
		Size = pagesize;
	}
end

--- applies `delta` to pagecontroller `pc`, returning: \
--- `page`: page of `pc.Options` with respect to `pc.Offset` and `pc.Size` \
--- `oldoffset`: previous `pc.Offset` \
--- `newoffset`: current `pc.Offset` \
--- `numpages`: max # of pages that can be displayed
function TableK.pagecontrollernext(pc: typeof(TableK.createpagecontroller(...)), delta: number)
	local len = #pc.Options
	local size = pc.Size

	local numpages = math.clamp(math.ceil(len / size), 1, math.huge)

	local lastoffset = pc.Offset
	pc.Offset = math.clamp(pc.Offset + delta, 1, numpages)

	local newoffset = pc.Offset

	return table.move(
		pc.Options,
		1 + math.clamp((newoffset - 1) * size, 0, len),
		math.clamp(newoffset * size, 0, len),
		1,
		table.create(size)
	), lastoffset, newoffset, numpages
end

--- resets page controller
function TableK.pagecontrollerreset(pc: typeof(TableK.createpagecontroller(...)), resize: number?)
	pc.Offset = 1
	table.clear(pc.Options)
	pc.Size = resize or pc.Size
end

--- returns an item (`{id, ...}`)
function TableK.createitem(id: string, ...: any)
	return {id, ...}::{string|any}
end

--- inserts item, by its associated `id`, to list \
--- *does not account for duplicates*
function TableK.iteminsert(list: { typeof(TableK.createitem(...)) }, id: string, ...: any)
	table.insert(list, TableK.createitem(id, ...))
end

--- returns:
--- `id (i[1])` item id \
--- `value (i[2...])` item value(s)
function TableK.itemunpack(i: typeof(TableK.createitem(...))): (string, ...any)
	return unpack(i)
end

--- removes all items associated with `id`, from list \
--- *starts at `i = #list`, ends at `i = 1`, accounting for duplicates*
function TableK.itemremove(list: { typeof(TableK.createitem(...)) }, id: string)
	for i = #list, 1, -1 do
		if list[i][1] == id then
			table.remove(list, i)
		end
	end
end

--- returns item, from its associated `id`, stored in list
function TableK.itemfind(list: { typeof(TableK.createitem(...)) }, id: string): typeof(TableK.createitem(...))?
	for _, thing in list do
		if thing[1] == id then
			return thing
		end
	end

	return nil
end

return TableK