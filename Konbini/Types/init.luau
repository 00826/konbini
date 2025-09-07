--!strict
--!native

local HttpService = game:GetService("HttpService")

local Rand = Random.new()

local function subf(x: string)
	return string.len(x) == 1 and "0" .. x or x
end

--- ### Types.luau
---
--- primitive type functions
local Types = {
	Abbreviations = {"", "K", "M", "B", "T", "Qd", "Qt", "Sx", "Sp", "Oc", "No", "De"};
}

--- reads Vector3 from buffer
function Types.readvector3(b: buffer, offset: number)
	return Vector3.new(
		buffer.readf32(b, offset),
		buffer.readf32(b, offset + 4),
		buffer.readf32(b, offset + 8)
	)
end

--- writes Vector3 to buffer
function Types.writevector3(b: buffer, offset: number, value: Vector3)
	buffer.writef32(b, offset, value.X)
	buffer.writef32(b, offset + 4, value.Y)
	buffer.writef32(b, offset + 8, value.Z)
end

--- reads unit vector from buffer
function Types.readunitvector(b: buffer, offset: number)
	return Vector3.new(
		buffer.readi8(b, offset),
		buffer.readi8(b, offset + 1),
		buffer.readi8(b, offset + 2)
	) * 1/127
end

--- writes unit vector to buffer \
--- `x,y,z`: mapped to `[-127, 127]`
function Types.writeunitvector(b: buffer, offset: number, value: Vector3)
	buffer.writei8(b, offset, math.clamp(value.X * 127, -127, 127))
	buffer.writei8(b, offset + 1, math.clamp(value.Y * 127, -127, 127))
	buffer.writei8(b, offset + 2, math.clamp(value.Z * 127, -127, 127))
end

--- reads Vector3i24 from buffer
function Types.readvector3i24(b: buffer, offset: number, precision: number?)
	return Vector3.new(
		Types.readi24(b, offset),
		Types.readi24(b, offset + 3),
		Types.readi24(b, offset + 6)
	) * (precision and 1/precision or 1)
end

--- writes Vector3i24 to buffer
function Types.writevector3i24(b: buffer, offset: number, value: Vector3, precision: number?)
	if precision then
		value *= precision
	end
	Types.writei24(b, offset, value.X)
	Types.writei24(b, offset + 3, value.Y)
	Types.writei24(b, offset + 6, value.Z)
end

--- rotates range of values with fixed variable size to the right
--- ```
--- rrotate(bufferu8[23, 33, 91], 0, 1, 3) -> [91, 23, 33]
--- ```
function Types.rrotate(b: buffer, offset: number, size: number, range: number)
	local x = buffer.readstring(b, offset + (size * (range - 1)), size) --- pull last value [91]
	buffer.copy(b, offset + size, b, offset, (size * range) - size) --- push range leading up to last value up by 1 place [23, 23, 33]
	buffer.writestring(b, offset, x) --- write to first value
end

--- rotates range of values with fixed variable size to the left
--- ```
--- lrotate(bufferu8[23, 33, 91], 0, 1, 3) -> [33, 91, 23]
--- ```
function Types.lrotate(b: buffer, offset: number, size: number, range: number)
	local last = (size * range) - size

	local x = buffer.readstring(b, offset, size) --- pull first value [23]
	buffer.copy(b, offset, b, offset + size, last) --- push range after the first value down by 1 place [33, 91, 91]
	buffer.writestring(b, offset + last, x) --- write to last value
end

--- swaps range of bytes stored at offsets `x` and `y` \
--- `range (?=1)` range of bytes to swap
function Types.swap(b: buffer, x: number, y: number, range: number?)
	range = range or 1
	local temp = buffer.create(range::number)
	buffer.copy(temp, x, b, 0, range)
	buffer.copy(b, x, b, y, range)
	buffer.copy(b, y, temp, 0, range)
end

--- returns `a == b` \
--- `offset (?=0)` begin comparison at offset
function Types.compare(a: buffer, b: buffer, offset: number?)
	local lenA = buffer.len(a)
	local lenB = buffer.len(b)

	offset = offset or 0
	assert(offset) --- solver kick rocks

	if lenA ~= lenB then
		return false
	elseif offset >= lenA then
		return true
	else
		local traverse = lenA - offset
		if traverse >= 4 then
			--- print(`comparing u32 {buffer.readu32(a, offset)} against {buffer.readu32(b, offset)} at {offset}, {offset+4}/{lenA}`)
			if buffer.readu32(a, offset) == buffer.readu32(b, offset) then
				return Types.compare(a, b, offset + 4)
			else
				return false
			end
		elseif traverse >= 2 then
			--- print(`comparing u16 {buffer.readu16(a, offset)} against {buffer.readu16(b, offset)} at {offset}, {offset+2}/{lenA}`)
			if buffer.readu16(a, offset) == buffer.readu16(b, offset) then
				return Types.compare(a, b, offset + 2)
			else
				return false
			end
		else
			--- print(`comparing u8 {buffer.readu8(a, offset)} against {buffer.readu8(b, offset)} at {offset}, {offset+1}/{lenA}`)
			if buffer.readu8(a, offset) == buffer.readu8(b, offset) then
				return Types.compare(a, b, offset + 1)
			else
				return false
			end
		end
	end
end

--- returns a duplicate of buffer
function Types.duplicate(b: buffer)
	local dupe = buffer.create(buffer.len(b))
	buffer.copy(dupe, 0, b)

	return dupe
end

--- writes signed 24-bit integer to buffer
function Types.writei24(b: buffer, offset: number, value: number)
	local bitoffset = offset * 8
	local sign = math.sign(value) < 0 and 1 or 0
	if sign == 1 then
		value += 1
	end
	
	buffer.writebits(b, bitoffset, 23, math.abs(value))
	buffer.writebits(b, bitoffset + 23, 1, sign)
end

--- reads signed 24-bit integer from buffer
function Types.readi24(b: buffer, offset: number)
	local bitoffset = offset * 8
	local value = buffer.readbits(b, bitoffset, 23)
	local sign = buffer.readbits(b, bitoffset + 23, 1)
	
	if sign == 1 then
		value *= -1
		value -= 1
	end
	
	return value
end

--- writes unsigned 24-bit integer to buffer
function Types.writeu24(b: buffer, offset: number, value: number)
	buffer.writebits(b, offset * 8, 24, value)
end

--- reads unsigned 24-bit integer from buffer
function Types.readu24(b: buffer, offset: number)
	return buffer.readbits(b, offset * 8, 24)
end

--- returns a `int16`-width matrix-buffer \
--- space complexity of `2 + (2*columns*rows)` \
--- *matrix value placements start at offset `2`, as column/row info is stored in the first 2 bytes. \
--- args passed into mutator functions, however, should be zero-indexed.*
function Types.creatematrix(columns: number, rows: number)
	local m = buffer.create( 2 + (2 * columns * rows) )

	buffer.writeu8(m, 0, columns)
	buffer.writeu8(m, 1, rows)

	return m
end

--- writes value to matrix
function Types.matrixwrite(m: buffer, column: number, row: number, value: number)
	local width = 2 * buffer.readu8(m, 0)
	local offset = 2 + (2 * column) + (row * width)

	buffer.writei16(m, offset, value)
end

--- extract value from matrix
function Types.matrixextract(m: buffer, column: number, row: number)
	local width = 2 * buffer.readu8(m, 0)
	local offset = 2 + (2 * column) + (row * width)

	return buffer.readi16(m, offset)
end

--- clears matrix, preserving the first two bits that contain row/column info \
--- equivalent to `buffer.fill(m, 2, 0)`
function Types.matrixclear(m: buffer)
	buffer.fill(m, 2, 0)
end

--- reads set of values along row of matrix
function Types.matrixreadrow(m: buffer, row: number): {number}
	local columns = buffer.readu8(m, 0)
	local width = 2 * columns
	local offset = 2 + (row * width)

	local r = table.create(columns, 0)

	for i = 1, columns do
		r[i] = buffer.readi16(m, offset)
		offset += 2
	end

	return r
end

--- returns a copy of row of matrix
function Types.matrixextractrow(m: buffer, row: number)
	local columns = buffer.readu8(m, 0)
	local width = 2 * columns
	local offset = 2 + (row * width)

	local copy = buffer.create(width)
	buffer.copy(copy, 0, m, offset, width)

	return copy
end

--- returns a string interpretation of matrix row
function Types.matrixinterpretrow(m: buffer, row: number)
	local columns = buffer.readu8(m, 0)
	local width = 2 * columns
	local offset = 2 + (row * width)

	local str = ""
	for _ = 1, columns do
		str ..= string.format("%05d ", buffer.readi16(m, offset)) --- format precision is 05d because i16's have at most 5 integers not including the sign
		offset += 2
	end

	return str
end

--- reads sum of values along column of matrix
function Types.matrixreadcolumn(m: buffer, column: number)
	local rows = buffer.readu8(m, 1)
	local width = 2 * buffer.readu8(m, 0)
	local offset = 2 + (2 * column)

	local sum = 0
	for _ = 1, rows do
		sum += buffer.readi16(m, offset)
		offset += width
	end

	return sum
end

--- returns a copy of column of matrix
function Types.matrixextractcolumn(m: buffer, column: number)
	local rows = buffer.readu8(m, 1)
	local width = 2 * buffer.readu8(m, 0)
	local offset = 2 + (2 * column)

	local copy = buffer.create(2 * rows)
	for i = 0, rows - 1, 1 do
		buffer.writei16(copy, 2 * i, buffer.readi16(m, offset))
		offset += width
	end

	return copy
end

--- returns a string interpretation of matrix row
function Types.matrixinterpretcolumn(m: buffer, column: number)
	local rows = buffer.readu8(m, 1)
	local width = 2 * buffer.readu8(m, 0)
	local offset = 2 + (2 * column)

	local str = ""
	for _ = 1, rows do
		str ..= string.format("%05d ", buffer.readi16(m, offset)) --- format precision is 05d because i16's have at most 5 integers not including the sign
		offset += width
	end

	return str
end

--- returns a width`(?=4(f32))`-wide bar buffer \
--- `width: 2 -> u16` `[u16 value (?=maxvalue), u16 maxvalue]` \
--- `width: 4 -> f32` `[f32 value (?=maxvalue), f32 maxvalue]`
function Types.createbar(width: number, maxvalue: number, value: number?)
	local b = buffer.create(width + width)

	if width == 2 then
		buffer.writeu16(b, 0, value or maxvalue)
		buffer.writeu16(b, 2, maxvalue)
	elseif width == 4 then
		buffer.writef32(b, 0, value or maxvalue)
		buffer.writef32(b, 4, maxvalue)
	else
		error("bar width error: bar has width of " .. tostring(width) .. ", expected 4(2*u16) or 8(2*f32)")
	end

	return b
end

--- writes to bar buffer \
--- `maxvalue~=nil`: attempts to scale stored value to fit `maxvalue`
function Types.barwrite(b: buffer, value: number?, maxvalue: number?)
	local width = buffer.len(b)

	if maxvalue then
		if width == 4 then
			buffer.writeu16(b, 0, buffer.readu16(b, 2) * math.clamp(buffer.readu16(b, 0) / maxvalue, 0, 1))
			buffer.writeu16(b, 2, maxvalue)
		elseif width == 8 then
			buffer.writef32(b, 0, buffer.readf32(b, 4) * math.clamp(buffer.readf32(b, 0) / maxvalue, 0, 1))
			buffer.writef32(b, 4, maxvalue)
		else
			error("bar width error: bar has width of " .. tostring(width) .. ", expected 4(2*u16) or 8(2*f32)")
		end
	end
	if value then
		if width == 4 then
			buffer.writeu16(b, 0, math.clamp(value, 0, buffer.readu16(b, 2)))
		elseif width == 8 then
			buffer.writef32(b, 0, math.clamp(value, 0, buffer.readf32(b, 4)))
		else
			error("bar width error: bar has width of " .. tostring(width) .. ", expected 4(2*u16) or 8(2*f32)")
		end
	end
end

--- applies deltas to bar buffer \
--- `maxvalue~=nil`: attempts to scale stored value to fit `maxvalue`
function Types.bardelta(b: buffer, value: number?, maxvalue: number?)
	local width = buffer.len(b)

	if maxvalue then
		if width == 4 then
			maxvalue += buffer.readu16(b, 2)
			buffer.writeu16(b, 0, buffer.readu16(b, 2) * math.clamp(buffer.readu16(b, 0) / maxvalue, 0, 1))
			buffer.writeu16(b, 2, maxvalue)
		elseif width == 8 then
			maxvalue += buffer.readf32(b, 4)
			buffer.writef32(b, 0, buffer.readf32(b, 4) * math.clamp(buffer.readf32(b, 0) / maxvalue, 0, 1))
			buffer.writef32(b, 4, maxvalue)
		else
			error("bar width error: bar has width of " .. tostring(width) .. ", expected 4(2*u16) or 8(2*f32)")
		end
	end
	if value then
		if width == 4 then
			value += buffer.readu16(b, 0)
			buffer.writeu16(b, 0, math.clamp(value, 0, buffer.readu16(b, 2)))
		elseif width == 8 then
			value += buffer.readf32(b, 0)
			buffer.writef32(b, 0, math.clamp(value, 0, buffer.readf32(b, 4)))
		else
			error("bar width error: bar has width of " .. tostring(width) .. ", expected 4(2*u16) or 8(2*f32)")
		end
	end
end

--- equivalent to `buffer.writef32(b, 0, buffer.readf32(b, 0) - x)`
function Types.barexpend(b: buffer, x: number)
	local width = buffer.len(b)

	if width == 4 then
		buffer.writeu16(b, 0, math.clamp(buffer.readu16(b, 0) - x, 0, 65535))
	elseif width == 8 then
		buffer.writef32(b, 0, buffer.readf32(b, 0) - x)
	else
		error("bar width error: bar has width of " .. tostring(width) .. ", expected 4(2*u16) or 8(2*f32)")
	end
end

--- returns bar buffer `value, maxvalue`
function Types.barunpack(b: buffer)
	local width = buffer.len(b)

	if width == 4 then
		return buffer.readu16(b, 0), buffer.readu16(b, 2)
	elseif width == 8 then
		return buffer.readf32(b, 0), buffer.readf32(b, 4)
	else
		error("bar width error: bar has width of " .. tostring(width) .. ", expected 4(2*u16) or 8(2*f32)")
	end
end

--- returns a `[f64 expiry, u8 stacks (?=1)]` state buffer \
--- a state is considered "expired" if `stacks == 0` or `expiry < time` \
--- a state is considrered "indefinite" if `expiry == -1`
function Types.createstate(expiry: number, stacks: number?)
	local s = buffer.create(4 + 1)

	buffer.writef64(s, 0, expiry)
	buffer.writeu8(s, 4, stacks or 1)

	return s
end

--- writes value to state buffer expiry portion
function Types.stateexpiry(s: buffer, value: number)
	buffer.writef64(s, 0, value)
end

--- writes value to state buffer stacks portion
function Types.statestacks(s: buffer, value: number)
	buffer.writeu8(s, 4, value)
end

--- adds value to state buffer stacks portion
function Types.statestacksdelta(s: buffer, value: number)
	buffer.writeu8(s, 4, buffer.readu8(s, 4) + value)
end

--- sets or creates (if it doesn't exist already) a state at `st[key]`
function Types.stateset(st: {[string]: buffer}, key: string, expiry: number, stacks: number?)
	local state = st[key]
	if not state then
		st[key] = Types.createstate(expiry, stacks)
	else
		buffer.writef64(state, 0, expiry)
		if stacks then
			buffer.writeu8(state, 4, stacks)
		end
	end
end

--- returns list of active states contained in state table `st`
function Types.statefind(st: {[string]: buffer}, keys: {string}, now: number)
	local result = table.create(#keys)

	for _, key in keys do
		local s = st[key]
		if not s then continue end

		local expiry = buffer.readf64(s, 0)
		if expiry == -1 then
			table.insert(result, key)
			continue
		end
		local active = expiry > now
		if not active then continue end

		table.insert(result, key)
	end

	return result
end

--- returns state buffer `expiry, stacks`
function Types.stateunpack(s: buffer)
	return buffer.readf64(s, 0), buffer.readu8(s, 4)
end

--- returns numeric stage `base / base` \
--- `base (?=2)`: stage base value
function Types.createstage(width: number, base: number?)
	local s = buffer.create(width)
	for i = 0, width - 1, 1 do
		local bitoffset = i * 8
		buffer.writebits(s, bitoffset, 4, base or 2)
		buffer.writebits(s, bitoffset + 4, 4, base or 2)
	end

	return s
end

--- writes value to signed portion of numeric stage
--- ```luau
--- createstage(1) --- 2/2
--- stagewrite(s, 0, 5) --- 5/2
--- stagewrite(s, 0, -3) --- 5/3
--- ```
function Types.stagewrite(s: buffer, byteoffset: number, value: number)
	local bitoffset = byteoffset * 8
	if math.sign(value) == 1 then
		buffer.writebits(s, bitoffset, 4, math.clamp(value, 0, 15))
	else
		buffer.writebits(s, bitoffset + 4, 4, math.clamp(math.abs(value), 0, 15))
	end
end

--- adds value to signed portion of numeric stage
--- ```luau
--- createstage(1) --- 2/2
--- stagedelta(s, 0, 1) --- 3/2
--- stagedelta(s, 0, -2) --- 3/4
--- ```
function Types.stagedelta(s: buffer, byteoffset: number, value: number)
	local bitoffset = byteoffset * 8
	if math.sign(value) == 1 then
		buffer.writebits(s, bitoffset, 4, math.clamp(value + buffer.readbits(s, bitoffset, 4), 0, 15))
	else
		buffer.writebits(s, bitoffset + 4, 4, math.clamp(math.abs(value) + buffer.readbits(s, bitoffset + 4, 4), 0, 15))
	end
end

--- returns numeric stage `x / y`
function Types.stageread(s: buffer, byteoffset: number)
	local bitoffset = byteoffset * 8
	return buffer.readbits(s, bitoffset, 4) / buffer.readbits(s, bitoffset + 4, 4)
end

--- returns `bit32.replace(0, 1, 0)` intended for todo32 library \
--- multi-step, multi-requisite tasks in 32 bits: \
--- `000000` `[0, 5]` todo step \
--- `00 00000000 00000000 00000000` `[6, 31]` todo progress
function Types.createtodo32()
	return bit32.replace(0, 1, 0)
end

--- adds signal progress to todo32 integer with respect to todo map \
--- returns: \
--- `t`: todo32 integer, mutated \
--- `todostep`: todo step against `#map`, where `todostep >= #map` indicates todo completion
function Types.todo32add(t: number, signal: { key: string, value: number }, map: { { { key: number, value: {string} } } })
	local todostep = bit32.extract(t, 0, 6)
	todostep = map[todostep] and todostep or 1

	local step = map[todostep] or map[1]
	assert(step, "todo32: cannot progress an empty map")

	local maxstep = #map
	
	if todostep > maxstep then
		t = bit32.replace(t, maxstep, 0, 6)
		t = bit32.replace(t, 0, 6, 26)

		return t, todostep
	else
		local sum = 0
		local goal = 0

		local offset = 6
		for _, requisite in ipairs(step) do
			local key, value = requisite.key, requisite.value
			local width = Types.numbits(key)
			local requisiteprogress = bit32.extract(t, offset, width)
			if table.find(value, signal.key) then
				requisiteprogress = math.clamp(requisiteprogress + signal.value, 0, 2^width - 1)
			end
			t = bit32.replace(t, requisiteprogress, offset, width)

			sum += requisiteprogress
			goal += key
			offset += width
		end

		if sum >= goal then
			todostep += 1

			t = bit32.replace(t, todostep, 0, 6)
			t = bit32.replace(t, 0, 6, 26)
		end

		return t, todostep
	end
end

--- returns todo32 step \
--- equivalent to `bit32.extract(t, 0, 6)`
function Types.todo32step(t: number)
	return bit32.extract(t, 0, 6)
end

--- returns todo completion details: \
--- `todostep`: todo step against `#map` \
--- `receipt`: `{ {number requisiteprogress, string requisitekey} }` \
--- \
--- if `bit32.extract(t, 0, 6)` is not an index of `map`, the todo is considered complete: \
--- ... `todostep` will be returned as `#map + 1` for external `if todostep > #map then ... end` case \
--- ... `receipt` will be returned as `table.create(0)`
function Types.todo32receipt(t: number, map: { { { key: number, value: {string} } } })
	local todostep = bit32.extract(t, 0, 6)

	local step = map[todostep]
	if not step then
		return #map + 1, table.create(0)
	end
	
	local maxstep = #map

	if todostep > maxstep then
		return todostep, table.create(0)
	else
		local receipt = table.create(maxstep)

		local offset = 6
		for _, requisite in ipairs(step) do
			local key = requisite.key
			local width = Types.numbits(key)
			local requisiteprogress = bit32.extract(t, offset, width)
			table.insert(receipt, {requisiteprogress, key})

			offset += width
		end

		return todostep, receipt
	end
end

--- returns # of bytes required to store given value \
--- equivalent to `1 + (math.log(value, 2) // 8)`
function Types.numbytes(value: number)
	return 1 + (math.log(value, 2) // 8)
end

--- returns # of bits required to store given value \
--- equivalent to `1 + math.log(value, 2) // 1`
function Types.numbits(value: number)
	return 1 + math.log(value, 2) // 1
end

--- returns `byteoffset * 8`
function Types.bitoffset(byteoffset: number)
	return byteoffset * 8 --- yes i unironically need this kthxbai!!
end

--- returns range of bits as a string
function Types.stringbits(x: number, field: number, range: number)
	local bitstring = ""
	for i = 1, range do
		bitstring ..= tostring(bit32.extract(x, field + i))
	end

	return bitstring
end

--- recursively progresses `{ number level, number xp }`-typed array \
--- `p`: progression array \
--- `xp`: xp to add \
--- `required`: returns, with respect to current level, the xp required to progress to the next level \
--- `max (?=nil)`: if `level > max`, preserves current level and sets xp to 0 \
--- `offset (?=1)`: offset where `level = p[offset]` and `xp = p[offset + 1]` \
--- returns # of progression steps made
function Types.prog(p: {number?}, xp: number, required: (number) -> number, max: number?, offset: number?)
	local i = offset or 1
	local j = i + 1

	local level = p[i] or 1
	assert(type(level) == "number", "expected level of `p` to be type number")
	local ups = 0

	if max then
		if level > max then
			p[j] = 0

			return ups
		end
	end

	local reqxp = required(level)
	local oldxp = p[j] or 0
	assert(type(oldxp) == "number", "expected xp of `p` to be type number")

	local newxp = oldxp + xp

	if newxp >= reqxp then
		p[i] = level + 1
		p[j] = newxp - reqxp
		ups += 1

		return ups + Types.prog(p, 0, required, max, offset)
	else
		p[i] = level
		p[j] = newxp

		return ups
	end
end

--- returns a deep copy of table
function Types.deepcopy(t: {[any]: any}): {[any]: any}
	local copy = {}

	for k, v in t do
		if type(v) == "table" then
			copy[k] = Types.deepcopy(v)
		elseif type(v) == "buffer" then
			local b = buffer.create(buffer.len(v))
			buffer.copy(b, 0, v, 0)
			copy[k] = b::any
		else
			copy[k] = v
		end
	end

	return copy
end

--- returns a diff-table describing changes made from `old -> new` \
--- \
--- `[!]` nil-values are of type `string` and equate to `"nil"`
function Types.diff(new: {[string]: any}, old: {[string]: any})
	local result: { [any]: any } = {}

	for key, newvalue in new do
		local oldvalue = old[key]

		local newtype = type(newvalue)
		local oldtype = type(oldvalue)

		if newtype == oldtype then
			if newtype == "table" then
				if next(newvalue) == nil then --- empty
					if next(oldvalue) ~= nil then
						result[key] = {}
					end
				else
					local diff = Types.diff(newvalue, oldvalue)
					if next(diff) ~= nil then
						result[key] = {}
						for a, b in diff do
							result[key][a] = b
						end
					end
				end
			elseif newtype == "buffer" then
				if not Types.compare(newvalue, oldvalue) then
					result[key] = Types.duplicate(newvalue)
				end
			else
				if newvalue ~= oldvalue then
					result[key] = newvalue
				end
			end
		else
			if newvalue ~= oldvalue then
				if newtype == "table" then
					result[key] = Types.deepcopy(newvalue)
				elseif newtype == "buffer" then
					result[key] = Types.duplicate(newvalue)
				else
					result[key] = newvalue
				end
			end
		end
	end

	for key in old do
		if new[key] == nil then
			result[key] = "nil"
		end
	end

	return result
end

--- reconciles result of `Types.diff(...)` into `t` \
--- attempts to convert string-keys of `t` into numeric indices \
--- to account for array diffs being converted from `{any} -> {[string]: any}` when passed over the network
function Types.reconcile(t: {}, diff: typeof(Types.diff(...)))
	if #diff > 0 then
		for i, v in ipairs(diff) do
			if type(v) == "table" then
				if not t[i] then
					t[i] = {}
				end
				if next(v) == nil then
					table.clear(t[i])
				end
				
				Types.reconcile(t[i], v)
			elseif type(v) == "buffer" then
				local preexisting = t[i]
				local len = buffer.len(v)
				if type(preexisting) == "buffer" and buffer.len(preexisting) == len then
					buffer.copy(preexisting, 0, v, 0)
				else
					local b = buffer.create(len)
					buffer.copy(b, 0, v, 0)
					t[i] = b::any
				end
			elseif v == "nil" then
				t[i] = nil
			else
				t[i] = v
			end
		end
	else
		for k, v in diff do
			local i = tonumber(k)
			if i ~= nil then
				k = i
			end

			if type(v) == "table" then
				if not t[k] then
					t[k] = {}
				end
				if next(v) == nil then
					table.clear(t[k])
				end
				
				Types.reconcile(t[k], v)
			elseif type(v) == "buffer" then
				local preexisting = t[k]
				local len = buffer.len(v)
				if type(preexisting) == "buffer" and buffer.len(preexisting) == len then
					buffer.copy(preexisting, 0, v, 0)
				else
					local b = buffer.create(len)
					buffer.copy(b, 0, v, 0)
					t[k] = b::any
				end
			elseif v == "nil" then
				t[k] = nil
			else
				t[k] = v
			end
		end
	end
end

--- returns an item (`{id, ...}`)
function Types.createitem(id: string, ...: any)
	return {id, ...}::{string|any}
end

--- inserts item, by its associated `id`, to list \
--- *does not account for duplicates*
function Types.iteminsert(list: { typeof(Types.createitem(...)) }, id: string, ...: any)
	table.insert(list, Types.createitem(id, ...))
end

--- removes all items associated with `id`, from list \
--- *starts at `i = #list`, ends at `i = 1`, accounting for duplicates*
function Types.itemremove(list: { typeof(Types.createitem(...)) }, id: string)
	for i = #list, 1, -1 do
		if list[i][1] == id then
			table.remove(list, i)
		end
	end
end

--- returns item, from its associated `id`, stored in list
function Types.itemfind(list: { typeof(Types.createitem(...)) }, id: string): typeof(Types.createitem(...))?
	for _, thing in list do
		if thing[1] == id then
			return thing
		end
	end

	return nil
end

--- returns first key-value pair from nested table `t` that satisfies `t[k][scope] == value`
function Types.scope<T>(t: {[string]: any}, scope: string, value: any): (any?, {[string]: any}?)
	for k, v in t do
		if v[scope] == value then
			return k, v
		end
	end

	return nil, nil
end

--- rotates array `A` `x` times such that:
--- ```
--- rotate([1, 2, 3, 4, 5], 1) -> [5, 1, 2, 3, 4]
--- rotate([1, 2, 3, 4, 5], -1) -> [2, 3, 4, 5, 1]
--- ```
function Types.rotate(t: {any}, x: number?)
	x = x or 1
	assert(x)

	if x ~= 0 then
		if x > 0 then
			local value = table.remove(t)
			table.insert(t, 1, value)
		elseif x < 0 then
			local value = table.remove(t, 1)
			table.insert(t, value)
		end

		Types.rotate(t, x - math.sign(x))
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
function Types.page<T>(t: {T}, size: number, offset: number)
	local len = #t

	return table.move(
		t,
		1 + math.clamp((offset - 1) * size, 0, len),
		math.clamp(offset * size, 0, len),
		1,
		table.create(size)
	)
end

--- `T[random alphanumeric key (len ?=4)] = value` \
--- returns `random alphanumeric key` for convenience \
--- guarantees that `tonumber(key) == nil` to avoid errors when sending such a key over the network boundary
function Types.insertkey(t: {[string]: any}, value: any, len: number?)
	len = len or 4
	assert(len)

	local key = nil

	repeat key = Types.createstring(len)
	until (key ~= nil) and (tonumber(key) == nil) and (t[key] == nil)

	t[key] = value

	return key
end

--- returns a reverse iterator function and the table for use in a for loop
function Types.ipairsr<T>(t: {T}): (({T}, number) -> (number?, T), {T}, number)
	return coroutine.wrap(function()
		for i = #t, 1, -1 do
			coroutine.yield(i, t[i])
		end
	end), t, 0
end

--- returns random value from list
function Types.nextvaluefromlist<T>(t: {T}, R: Random?): T?
	if #t < 0 then
		return nil
	else
		return t[(R or Rand):NextInteger(1, #t)]
	end
end

--- returns random value from weighted table
function Types.nextvaluefromweightedtable<T>(t: { { key: string, weight: number } & T }, R: Random?): T?
	if #t < 0 then
		return nil
	else
		local sum = 0
		for _, entry in t do
			sum += entry.weight
		end
		
		local roll, passed = (R or Rand):NextNumber(0, sum), 0
		for _, entry in t do
			passed += entry.weight

			if roll <= passed then
				return entry
			end
		end

		return nil
	end
end

--- returns `t[1] ∪ ... ∪ t[#t]`
function Types.union<T>(t: { {T} })
	local result = {}
	for _, list in ipairs(t) do
		table.move(list, 1, #list, #result + 1, result)
	end

	return result
end

--- returns a randomized alphanumeric string \
--- all characters elements of set `[A-Za-z0-9]`
function Types.createstring(len: number)
	local b = buffer.create(len)
	for i = 0, len - 1, 1 do
		local value = Rand:NextInteger(1, 62)
		if value <= 26 then --- [a-z] [abcdefghijklmnopqrstuvwxyz] [1-26] -> [97-122] 
			buffer.writeu8(b, i, value + 96)
		elseif value <= 52 then --- [A-Z] [ABCDEFGHIJKLMNOPQRSTUVWXYZ] [27-52] -> [65-90] 
			buffer.writeu8(b, i, value + 38)
		else --- elseif value <= 62 then --- [0-9] [0123456789] [53-62] -> [48-57]
			buffer.writeu8(b, i, value - 5)
		end
	end

	return buffer.tostring(b)
end

--- trims trailing whitespaces from string read from buffer
function Types.trimstring(str: string)
	return string.gsub(string.gsub(str, "%s+", " "), "\u{0000}", "")
end

--- replaces substrings in text matching capture `pattern (?="[%w+_]+")` with respect to replacement table
function Types.alias(text: string, replace: {[string]: string}, pattern: string?)
	return string.gsub(text, pattern or "[%w+_]+", function(s: string)
		return replace[s] or s
	end)
end

--- applies richtext formatting tags to text \
--- *assumes that richtext closure suffix follows pattern `string.match(prefix, "%a+")`*
--- ```
--- Types.richtext("color me surprised", "i", "font color='#ff00ff'") --> <font color="#ff00ff"><i>color me surprised</i></font>
--- Types.richtext("color me surprised", "i", Color3.fromRGB(255, 0, 255)) --> <font color="#ff00ff"><i>color me surprised</i></font>
--- ```
function Types.richformat(text: string, ...: string|Color3)
	for i, prefix in ipairs({...}::any) do
		if typeof(prefix) == "Color3" then
			prefix = "font color='#" .. prefix:ToHex() .. "'"
		end

		local closure = string.match(prefix, "%a+")
		if closure then
			text = "<" .. prefix .. ">" .. text .. "</" .. closure .. ">"
		else
			warn(string.format("skipped bad format tag #%d '%s'", i, prefix))
		end
	end

	return text
end

--- formats time into a hour-minute-second-esque notation
function Types.hourminutesecond(time: number, notation: "DD:HH:MM:SS" | "HH:MM:SS" | "MM:SS" | "M:SS", appendms: boolean?): string
	--[[
		os.date("!%X", time) is the fastest for all inputs below 86400, because any input at or above 86400 breaks the formatting
		string.gsub(string.format(), time, subf) is the second fastest for all inputs, never has a formatting break, but is ~10% slower than os.date("!%X", time)
		combining both through comparing time >= 86400 gives a faster average across all possible inputs
	]]
	local hms = ""
	if notation == "DD:HH:MM:SS" then
		if time >= 86400 then
			local days = time // 86400
			time -= days * 86400
			local hours = time // 3600
			time -= hours * 3600
			local minutes = time // 60
			time -= minutes * 60

			hms = string.gsub(string.format("%d:%d:%d:%d", days, hours, minutes, time), "%d+", subf)
		else
			hms = "00:" .. os.date("!%X", time)
		end
	elseif notation == "HH:MM:SS" then
		if time >= 86400 then
			local hours = time // 3600
			time -= hours * 3600
			local minutes = time // 60
			time -= minutes * 60

			hms = string.gsub(string.format("%d:%d:%d", hours, minutes, time), "%d+", subf)
		else
			hms = os.date("!%X", time)
		end
	elseif notation == "MM:SS" then
		if time >= 3600 then
			local minutes = time // 60
			time -= minutes * 60
			hms = string.gsub(string.format("%d:%d", minutes, time), "%d+", subf)
		else
			hms = string.sub(os.date("!%X", time), 4, 8)
		end
	elseif notation == "M:SS" then
		if time >= 3600 then
			local minutes = time // 60
			time -= minutes * 60
			hms = string.gsub(string.format("%d:%d", minutes, time), "%d+", subf)
		else
			hms = string.gsub(string.sub(os.date("!%X", time), 4, 8), "^0", "")
		end
	end

	if appendms then
		local stringtime = tostring(time)

		local init = string.find(stringtime, "%.")
		if init then
			local append = string.sub(stringtime, init, init + 3)
			
			for i = 2, 4, 1 do
				local substring = string.sub(append, i, i)
				if substring == "" then
					append ..= "0"
				end
			end

			hms ..= append
		else
			hms ..= ".000"
		end
	end

	return hms
end

--- returns a timestamp of current utc time with respect to format option or time in minutes
function Types.timestamp(format: "Hour" | "Biphase" | "Day" | "Week" | "Season" | "Biseason" | "Year" | number)
	local datetable = os.date("!*t") --- read from this table as a truth state
	local datetablecopy = table.clone(datetable) --- write to this table, keys inherited from datetable

	local timestamp = {
		--- unique, non-recurring string describing format time
		Id = "";
		--- unique, non-recurring number describing format time
		Seed = 0;
		--- time until format changes
		Until = 0;
	}

	if type(format) == "number" then
		--- `Format: 5`
		--- `February 14, 2024, 06:44` --> `"2024_45_6_8"`
		--- `Format: 10`
		--- `February 14, 2024, 06:44` --> `"2024_45_6_4"`
		--- `Format: 15`
		--- `February 14, 2024, 06:44` --> `"2024_45_6_2"`
		datetablecopy.min = format * math.ceil((datetablecopy.min + 1) / format)
		datetablecopy.sec = 0

		local year, yday, hour, qtrhour = datetable.year, datetable.yday, datetable.hour, math.ceil((datetable.min + 1) / format) - 1
		timestamp.Id = string.format("%d_%d_%d_%d", year, yday, hour, qtrhour)
		timestamp.Seed = tonumber(year .. yday .. hour .. qtrhour) :: number
	else
		if format == "Hour" then
			--- `February 14, 2024, 06:44` --> `"2024_45_6"`
			datetablecopy.hour = math.floor(datetablecopy.hour + 1)
			datetablecopy.min = 0
			datetablecopy.sec = 0

			local year, yday, hour = datetable.year, datetable.yday, datetable.hour
			timestamp.Id = string.format("%d_%d_%d", year, yday, hour)
			timestamp.Seed = tonumber(year .. yday .. hour) :: number
		elseif format == "Biphase" then
			--- `February 14, 2024, 06:44` --> `"2024_45_AM"`
			--- `February 14, 2024, 16:44` --> `"2024_45_PM"`
			datetablecopy.hour = 12 * math.ceil((datetablecopy.hour + 1) / 12)
			datetablecopy.min = 0
			datetablecopy.sec = 0

			local year, yday, phase = datetable.year, datetable.yday, os.date("!%p")
			timestamp.Id = string.format("%d_%d_%s", year, yday, phase)
			timestamp.Seed = tonumber(year .. yday .. string.byte(phase)) :: number
		elseif format == "Day" then
			--- `February 14, 2024` --> `"2024_45"`
			datetablecopy.day += 1
			datetablecopy.hour = 0
			datetablecopy.min = 0
			datetablecopy.sec = 0

			local year, yday = datetable.year, datetable.yday
			timestamp.Id = string.format("%d_%d", year, yday)
			timestamp.Seed = tonumber(year .. yday) :: number
		elseif format == "Week" then
			--- `February 14, 2024` --> `"2024_7_06"` (06th week of 2024)
			datetablecopy.day += 8 - datetable.wday
			datetablecopy.hour = 0
			datetablecopy.min = 0
			datetablecopy.sec = 0

			local year, week, yweek = datetable.year, datetable.wday, os.date("!%U")
			timestamp.Id = string.format("%d_%d_%s", year, week, yweek)
			timestamp.Seed = tonumber(year .. week .. yweek) :: number
		elseif format == "Season" then
			--- `February 14, 2024` --> `"2024_1"`
			--- Mar-May: `1` (spring)
			--- Jun-Aug: `2` (summer)
			--- Sep-Nov: `3` (fall)
			--- Dec-Feb: `4` (winter)
			datetablecopy.month += 1 + ((11 - math.ceil((datetablecopy.month - 3) % 12)) % 3)
			datetablecopy.day = 1
			datetablecopy.hour = 0
			datetablecopy.min = 0
			datetablecopy.sec = 0

			local year, month = datetable.year, math.ceil((1 + ((datetable.month - 3) % 12)) / 3)
			timestamp.Id = string.format("%d_%d", year, month)
			timestamp.Seed = tonumber(year .. month) :: number
		elseif format == "Biseason" then
			--- `February 14, 2024` --> `"2024_1"`
			--- Jan-Jun: `1` (SS)
			--- Jul-Dec: `2` (FW)
			datetablecopy.month = math.ceil(datetablecopy.month / 6)
			datetablecopy.day = 1
			datetablecopy.hour = 0
			datetablecopy.min = 0
			datetablecopy.sec = 0

			local year, month = datetable.year, math.ceil(datetable.month / 6)
			timestamp.Id = string.format("%d_%d", year, month)
			timestamp.Seed = tonumber(year .. month) :: number
		elseif format == "Year" then
			--- `February 14, 2024` --> `"2024"`
			datetablecopy.year += 1
			datetablecopy.month = 1
			datetablecopy.day = 1
			datetablecopy.hour = 0
			datetablecopy.min = 0
			datetablecopy.sec = 0

			timestamp.Id = tostring(datetable.year)
			timestamp.Seed = tonumber(datetable.year) :: number
		end
	end

	timestamp.Until = os.time(datetablecopy) - os.time(datetable)

	return timestamp
end

--- formats number: \
--- thousands separated by `tsep (?=".")` \
--- decimals separated by `dsep (?=".")`, truncated by `places (?=1)`
function Types.formatnumber(x: number, tsep: string?, dsep: string?, places: number?)
	if places == 0 then
		return Types.commanumber(x, tsep)
	else
		local num = tostring(x)
		local i = string.find(num, "%.")
		
		if i then
			return Types.commanumber(x, tsep) .. (dsep or ".") .. string.sub(num, 1 + i, i + (places or 1))
		else
			return Types.commanumber(x, tsep)
		end
	end
end

--- formats number, thousands separated by `tsep (?=",")`
function Types.commanumber(x: number, tsep: string?)
	if math.abs(x) < 1000 then
		return tostring(math.floor(x))
	else
		local str = string.reverse(string.gsub(string.reverse(tostring(math.floor(x))), "(%d%d%d)", "%1" .. (tsep or ","))::any)
		return string.sub(str, string.find(str, "%d")::any, -1)
	end
end

--- abbreviates number, decimals separated by `dsep (?=".")`, truncated by `places (?=1)`
function Types.abbreviatenumber(x: number, places: number?, dsep: string?)
	local exp = math.floor(math.log(math.max(1, math.abs(x)), 1000))
	local suffix = Types.Abbreviations[1 + exp] or ("e+" .. exp)
	
	return string.gsub(tostring(math.floor(x * ((10 ^ (places or 1)) / (1000 ^ exp))) / (10 ^ (places or 1))), "[.]", dsep or ".") .. suffix
end

--- returns `HttpService:JSONEncode(input)`
function Types.jsonencode(input: any)
	return HttpService:JSONEncode(input)
end

--- returns `HttpService:JSONDecode(input)`
function Types.jsondecode(input: string)
	return HttpService:JSONDecode(input)
end

return Types