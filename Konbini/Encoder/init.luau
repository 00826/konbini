--!strict
--!native

local HttpService = game:GetService("HttpService")

local Rand = Random.new()

local function subf(x: string)
	return #x == 1 and "0" .. x or x
end

--- ### Encoder.luau
---
--- primitive type helper functions
local Encoder = {
	Abbreviations = {""; "K"; "M"; "B"; "T"; "Qd", "Qt", "Sx", "Sp", "Oc", "No", "De"};
}

--- trims trailing whitespaces from string in buffer
function Encoder.trimstring(str: string)
	return string.gsub(string.gsub(str, "%s+", " "), "\u{0000}", "")
end

--- reads Vector3 from buffer
function Encoder.readvector3(b: buffer, offset: number)
	return Vector3.new(
		buffer.readf32(b, offset),
		buffer.readf32(b, offset + 4),
		buffer.readf32(b, offset + 8)
	)
end

--- writes Vector3 to buffer
function Encoder.writevector3(b: buffer, offset: number, value: Vector3)
	buffer.writef32(b, offset, value.X)
	buffer.writef32(b, offset + 4, value.Y)
	buffer.writef32(b, offset + 8, value.Z)
end

--- reads unit vector from buffer
function Encoder.readunitvector(b: buffer, offset: number)
	return Vector3.new(
		buffer.readi8(b, offset),
		buffer.readi8(b, offset + 1),
		buffer.readi8(b, offset + 2)
	) * 1/127
end

--- writes unit vector to buffer \
--- `x,y,z`: mapped to `[-127, 127]`
function Encoder.writeunitvector(b: buffer, offset: number, value: Vector3)
	buffer.writei8(b, offset, math.clamp(value.X * 127, -127, 127))
	buffer.writei8(b, offset + 1, math.clamp(value.Y * 127, -127, 127))
	buffer.writei8(b, offset + 2, math.clamp(value.Z * 127, -127, 127))
end

--- reads Vector3i24 from buffer
function Encoder.readvector3i24(b: buffer, offset: number, precision: number?)
	return Vector3.new(
		Encoder.readi24(b, offset),
		Encoder.readi24(b, offset + 3),
		Encoder.readi24(b, offset + 6)
	) * (precision and 1/precision or 1)
end

--- writes Vector3i24 to buffer
function Encoder.writevector3i24(b: buffer, offset: number, value: Vector3, precision: number?)
	if precision then
		value *= precision
	end
	Encoder.writei24(b, offset, value.X)
	Encoder.writei24(b, offset + 3, value.Y)
	Encoder.writei24(b, offset + 6, value.Z)
end

--- rotates range of values with fixed variable size to the right
--- ```
--- rrotate(bufferu8[23, 33, 91], 0, 1, 3) -> [91, 23, 33]
--- ```
function Encoder.rrotate(b: buffer, offset: number, size: number, range: number)
	local x = buffer.readstring(b, offset + (size * (range - 1)), size) --- pull last value [91]
	buffer.copy(b, offset + size, b, offset, (size * range) - size) --- push range leading up to last value up by 1 place [23, 23, 33]
	buffer.writestring(b, offset, x) --- write to first value
end

--- rotates range of values with fixed variable size to the left
--- ```
--- lrotate(bufferu8[23, 33, 91], 0, 1, 3) -> [33, 91, 23]
--- ```
function Encoder.lrotate(b: buffer, offset: number, size: number, range: number)
	local last = (size * range) - size

	local x = buffer.readstring(b, offset, size) --- pull first value [23]
	buffer.copy(b, offset, b, offset + size, last) --- push range after the first value down by 1 place [33, 91, 91]
	buffer.writestring(b, offset + last, x) --- write to last value
end

--- swaps range of bytes stored at offsets `x` and `y` \
--- `range (?=1)` range of bytes to swap
function Encoder.swap(b: buffer, x: number, y: number, range: number?)
	range = range or 1
	local temp = buffer.create(range::number)
	buffer.copy(temp, x, b, 0, range)
	buffer.copy(b, x, b, y, range)
	buffer.copy(b, y, temp, 0, range)
end

--- returns `a == b` \
--- `offset (?=0)` begin comparison at offset
function Encoder.compare(a: buffer, b: buffer, offset: number?)
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
				return Encoder.compare(a, b, offset + 4)
			else
				return false
			end
		elseif traverse >= 2 then
			--- print(`comparing u16 {buffer.readu16(a, offset)} against {buffer.readu16(b, offset)} at {offset}, {offset+2}/{lenA}`)
			if buffer.readu16(a, offset) == buffer.readu16(b, offset) then
				return Encoder.compare(a, b, offset + 2)
			else
				return false
			end
		else
			--- print(`comparing u8 {buffer.readu8(a, offset)} against {buffer.readu8(b, offset)} at {offset}, {offset+1}/{lenA}`)
			if buffer.readu8(a, offset) == buffer.readu8(b, offset) then
				return Encoder.compare(a, b, offset + 1)
			else
				return false
			end
		end
	end
end

--- writes signed 24-bit integer to buffer
function Encoder.writei24(b: buffer, offset: number, value: number)
	local sign = math.sign(value) < 0 and 1 or 0
	if sign == 1 then
		value += 1
	end
	local abs = math.abs(value)
	
	buffer.writebits(b, offset, 23, abs)
	buffer.writebits(b, offset + 23, 1, sign)
end

--- reads signed 24-bit integer from buffer
function Encoder.readi24(b: buffer, offset: number)
	local value = buffer.readbits(b, offset, 23)
	local sign = buffer.readbits(b, offset + 23, 1)
	
	if sign == 1 then
		value *= -1
		value -= 1
	end
	
	return value
end

--- writes unsigned 24-bit integer to buffer
function Encoder.writeu24(b: buffer, offset: number, value: number)
	buffer.writebits(b, offset, 24, value)
end

--- reads unsigned 24-bit integer from buffer
function Encoder.readu24(b: buffer, offset: number)
	return buffer.readbits(b, offset, 24)
end

--- returns a `int16`-width matrix-buffer \
--- space complexity of `2 + (2*columns*rows)` \
--- *matrix value placements start at offset `2`, as column/row info is stored in the first 2 bytes. \
--- args passed into mutator functions, however, should be zero-indexed.*
function Encoder.creatematrix(columns: number, rows: number)
	local m = buffer.create( 2 + (2 * columns * rows) )

	buffer.writeu8(m, 0, columns)
	buffer.writeu8(m, 1, rows)

	return m
end

--- writes value to matrix
function Encoder.matrixwrite(m: buffer, column: number, row: number, value: number)
	local width = 2 * buffer.readu8(m, 0)
	local offset = 2 + (2 * column) + (row * width)

	buffer.writei16(m, offset, value)
end

--- extract value from matrix
function Encoder.matrixextract(m: buffer, column: number, row: number)
	local width = 2 * buffer.readu8(m, 0)
	local offset = 2 + (2 * column) + (row * width)

	return buffer.readi16(m, offset)
end

--- clears matrix, preserving the first two bits that contain row/column info \
--- equivalent to `buffer.fill(m, 2, 0)`
function Encoder.matrixclear(m: buffer)
	buffer.fill(m, 2, 0)
end

--- reads set of values along row of matrix
function Encoder.matrixreadrow(m: buffer, row: number): {number}
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
function Encoder.matrixextractrow(m: buffer, row: number)
	local columns = buffer.readu8(m, 0)
	local width = 2 * columns
	local offset = 2 + (row * width)

	local copy = buffer.create(width)
	buffer.copy(copy, 0, m, offset, width)

	return copy
end

--- returns a string interpretation of matrix row
function Encoder.matrixinterpretrow(m: buffer, row: number)
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
function Encoder.matrixreadcolumn(m: buffer, column: number)
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
function Encoder.matrixextractcolumn(m: buffer, column: number)
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
function Encoder.matrixinterpretcolumn(m: buffer, column: number)
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
function Encoder.createbar(width: number, maxvalue: number, value: number?)
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
function Encoder.barwrite(b: buffer, value: number?, maxvalue: number?)
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
function Encoder.bardelta(b: buffer, value: number?, maxvalue: number?)
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
function Encoder.barexpend(b: buffer, x: number)
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
function Encoder.barunpack(b: buffer)
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
function Encoder.createstate(expiry: number, stacks: number?)
	local s = buffer.create(4 + 1)

	buffer.writef64(s, 0, expiry)
	buffer.writeu8(s, 4, stacks or 1)

	return s
end

--- writes value to state buffer expiry portion
function Encoder.stateexpiry(s: buffer, value: number)
	buffer.writef64(s, 0, value)
end

--- writes value to state buffer stacks portion
function Encoder.statestacks(s: buffer, value: number)
	buffer.writeu8(s, 4, value)
end

--- adds value to state buffer stacks portion
function Encoder.statestacksdelta(s: buffer, value: number)
	buffer.writeu8(s, 4, buffer.readu8(s, 4) + value)
end

--- sets or creates (if it doesn't exist already) a state at `st[key]`
function Encoder.stateset(st: {[string]: buffer}, key: string, expiry: number, stacks: number?)
	local state = st[key]
	if not state then
		st[key] = Encoder.createstate(expiry, stacks)
	else
		buffer.writef64(state, 0, expiry)
		if stacks then
			buffer.writeu8(state, 4, stacks)
		end
	end
end

--- returns list of active states contained in state table `st`
function Encoder.statefind(st: {[string]: buffer}, keys: {string}, now: number)
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
function Encoder.stateunpack(s: buffer)
	return buffer.readf64(s, 0), buffer.readu8(s, 4)
end

--- returns numeric stage `base / base` \
--- `base (?=2)`: stage base value
function Encoder.createstage(width: number, base: number?)
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
function Encoder.stagewrite(s: buffer, byteoffset: number, value: number)
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
function Encoder.stagedelta(s: buffer, byteoffset: number, value: number)
	local bitoffset = byteoffset * 8
	if math.sign(value) == 1 then
		buffer.writebits(s, bitoffset, 4, math.clamp(value + buffer.readbits(s, bitoffset, 4), 0, 15))
	else
		buffer.writebits(s, bitoffset + 4, 4, math.clamp(math.abs(value) + buffer.readbits(s, bitoffset + 4, 4), 0, 15))
	end
end

--- returns numeric stage `x / y`
function Encoder.stageread(s: buffer, byteoffset: number)
	local bitoffset = byteoffset * 8
	return buffer.readbits(s, bitoffset, 4) / buffer.readbits(s, bitoffset + 4, 4)
end

--- returns `bit32.replace(0, 1, 0)` intended for todo32 library \
--- multi-step, multi-requisite tasks in 32 bits: \
--- `000000` `[0, 5]` todo step \
--- `00 00000000 00000000 00000000` `[6, 31]` todo progress
function Encoder.createtodo32()
	return bit32.replace(0, 1, 0)
end

--- adds signal progress to todo32 integer with respect to todo map \
--- returns: \
--- `t`: todo32 integer, mutated \
--- `todostep`: todo step against `#map`, where `todostep >= #map` indicates todo completion
function Encoder.todo32add(t: number, signal: { key: string, value: number }, map: { { { key: number, value: {string} } } })
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
			local width = Encoder.numbits(key)
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
function Encoder.todo32step(t: number)
	return bit32.extract(t, 0, 6)
end

--- returns todo completion details: \
--- `todostep`: todo step against `#map` \
--- `receipt`: `{ {requisiteprogress, requisitegoal} }` \
--- \
--- if `bit32.extract(t, 0, 6)` is not an index of `map`, the todo is considered complete: \
--- ... `todostep` will be returned as `#map + 1` for external `if todostep > #map then ... end` case \
--- ... `receipt` will be returned as `table.create(0)`
function Encoder.todo32receipt(t: number, map: { { { key: number, value: {string} } } })
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
			local width = Encoder.numbits(key)
			local requisiteprogress = bit32.extract(t, offset, width)
			table.insert(receipt, {requisiteprogress, key})

			offset += width
		end

		return todostep, receipt
	end
end

--- returns # of bytes required to store given value \
--- equivalent to `1 + (math.log(value, 2) // 8)`
function Encoder.numbytes(value: number)
	return 1 + (math.log(value, 2) // 8)
end

--- returns # of bits required to store given value \
--- equivalent to `1 + math.log(value, 2) // 1`
function Encoder.numbits(value: number)
	return 1 + math.log(value, 2) // 1
end

--- returns `byteoffset * 8`
function Encoder.bitoffset(byteoffset: number)
	return byteoffset * 8 --- yes i unironically need this kthxbai!!
end

--- returns range of bits as a string
function Encoder.stringbits(x: number, field: number, range: number)
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
function Encoder.prog(p: {number?}, xp: number, required: (number) -> number, max: number?, offset: number?)
	local i = offset or 1
	local level = p[i] or 1
	assert(type(level) == "number", "expected level of `p` to be type number")
	local ups = 0

	if max then
		if level > max then
			p[i + 1] = 0

			return ups
		end
	end

	local reqxp = required(level)
	local oldxp = p[i + 1] or 0
	assert(type(oldxp) == "number", "expected xp of `p` to be type number")
	
	local newxp = oldxp + xp

	if newxp > reqxp then
		p[1] = level + 1
		p[2] = newxp - reqxp
		ups += 1

		return ups + Encoder.prog(p, 0, required, max, offset)
	else
		p[1] = level
		p[2] = newxp

		return ups
	end
end

--- returns value represented as a boolean
function Encoder.toboolean(value: any)
	if not value then return false end
	local t = type(value)
	return
		(t == "boolean" and value) or
		(t == "number" and value == value) or
		(t == "string" and value ~= "") or
		(t == "vector" and value.Magnitude > 0) or
		(t == "table" and next(value) ~= nil) or
		(t == "function" and (value::any)()) or false
end

--- returns a randomized alphanumeric string `[A-Za-z0-9], P(62,r)=62^r` \
--- `len (?=4, P(62,4)=677040)`: string length
function Encoder.string(len: number?)
	local str = string.rep("0", len or 4)
	for i = 1, len or 4 do
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

--- replaces substrings in text matching capture `pattern (?="[%w+_]+")` with respect to replacement table
function Encoder.alias(text: string, replace: {[string]: string}, pattern: string?)
	return string.gsub(text, pattern or "[%w+_]+", function(s: string)
		return replace[s] or s
	end)
end

--- applies richtext formatting to text \
--- *assumes that richtext closure suffix follows pattern `string.match(prefix, "%a+")`*
--- ```
--- Encoder.richtext("italicize me", "i") --> <i>italicize me</i>
--- Encoder.richtext("color me surprised", `font color="#ff00ff"`) --> <font color="#ff00ff">color me surprised</font>
--- ```
function Encoder.richformat(text: string, prefix: string)
	local closure = string.match(prefix, "%a+")
	assert(closure)

	-- return `<{prefix}>{text}</{closure}>`
	return "<" .. prefix .. ">" .. text .. "</" .. closure .. ">"
end

--- formats time into a hour-minute-second-esque notation
function Encoder.hourminutesecond(time: number, notation: 
	| "DD:HH:MM:SS"
	| "HH:MM:SS"
	| "MM:SS"
	| "M:SS"
	?,
appendms: boolean?): string
	--[[
		os.date("!%X", time) is the fastest for all inputs below 86400, because any input at or above 86400 breaks the formatting
		string.gsub(string.format(), time, subf) is the second fastest for all inputs, never has a formatting break, but is ~10% slower than os.date("!%X", time)
		combining both through comparing time >= 86400 gives a faster average across all possible inputs
	]]
	local hms = ""
	if notation == "DD:HH:MM:SS" then
		if time >= 86400 then
			local D = time // 86400
			time -= D * 86400
			local H = time // 3600
			time -= H * 3600
			local M = time // 60
			time -= M * 60

			hms = string.gsub(string.format("%d:%d:%d:%d", D, H, M, time), "%d+", subf)
		else
			hms = "00:" .. os.date("!%X", time)
		end
	elseif notation == "HH:MM:SS" then
		if time >= 86400 then
			local H = time // 3600
			time -= H * 3600
			local M = time // 60
			time -= M * 60

			hms = string.gsub(string.format("%d:%d:%d", H, M, time), "%d+", subf)
		else
			hms = os.date("!%X", time)
		end
	elseif notation == "MM:SS" then
		if time >= 3600 then
			local M = time // 60
			time -= M * 60
			hms = string.gsub(string.format("%d:%d", M, time), "%d+", subf)
		else
			hms = string.sub(os.date("!%X", time), 4, 8)
		end
	elseif notation == "M:SS" then
		hms = string.gsub(string.sub(os.date("!%X", time), 4, 8), "^0", "")
	end

	hms = hms == "" and os.date("!%X", time) or hms
	if appendms then
		local _, frac = math.modf(time)
		hms ..= string.sub(tostring(frac), 2, 5)
	end

	return hms
end

--- returns a timestamp of current utc time with respect to format option or time in minutes
function Encoder.timestamp(format:
	| number
	| "Hour"
	| "Biphase"
	| "Day"
	| "Week"
	| "Season"
	| "Biseason"
	| "Year"
)
	local T0 = os.date("!*t")
	local T1 = table.clone(T0)

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
		T1.min = format * math.ceil((T1.min + 1) / format)
		T1.sec = 0

		local year, yday, hour, qtrhour = T0.year, T0.yday, T0.hour, math.ceil((T0.min + 1) / format) - 1
		timestamp.Id = string.format("%d_%d_%d_%d", year, yday, hour, qtrhour)
		timestamp.Seed = tonumber(year .. yday .. hour .. qtrhour) :: number
	else
		if format == "Hour" then
			--- `February 14, 2024, 06:44` --> `"2024_45_6"`
			T1.hour = math.floor(T1.hour + 1)
			T1.min = 0
			T1.sec = 0

			local year, yday, hour = T0.year, T0.yday, T0.hour
			timestamp.Id = string.format("%d_%d_%d", year, yday, hour)
			timestamp.Seed = tonumber(year .. yday .. hour) :: number
		elseif format == "Biphase" then
			--- `February 14, 2024, 06:44` --> `"2024_45_AM"`
			--- `February 14, 2024, 16:44` --> `"2024_45_PM"`
			T1.hour = 12 * math.ceil((T1.hour + 1) / 12)
			T1.min = 0
			T1.sec = 0

			local year, yday, phase = T0.year, T0.yday, os.date("!%p")
			timestamp.Id = string.format("%d_%d_%s", year, yday, phase)
			timestamp.Seed = tonumber(year .. yday .. string.byte(phase)) :: number
		elseif format == "Day" then
			--- `February 14, 2024` --> `"2024_45"`
			T1.day += 1
			T1.hour = 0
			T1.min = 0
			T1.sec = 0

			local year, yday = T0.year, T0.yday
			timestamp.Id = string.format("%d_%d", year, yday)
			timestamp.Seed = tonumber(year .. yday) :: number
		elseif format == "Week" then
			--- `February 14, 2024` --> `"2024_7_06"` (06th week of 2024)
			T1.day += 8 - T0.wday
			T1.hour = 0
			T1.min = 0
			T1.sec = 0

			local year, week, yweek = T0.year, T0.wday, os.date("!%U")
			timestamp.Id = string.format("%d_%d_%s", year, week, yweek)
			timestamp.Seed = tonumber(year .. week .. yweek) :: number
		elseif format == "Season" then
			--- `February 14, 2024` --> `"2024_1"`
			--- Mar-May: `1` (spring)
			--- Jun-Aug: `2` (summer)
			--- Sep-Nov: `3` (fall)
			--- Dec-Feb: `4` (winter)
			T1.month += 1 + ((11 - math.ceil((T1.month - 3) % 12)) % 3)
			T1.day = 1
			T1.hour = 0
			T1.min = 0
			T1.sec = 0

			local year, month = T0.year, math.ceil((1 + ((T0.month - 3) % 12)) / 3)
			timestamp.Id = string.format("%d_%d", year, month)
			timestamp.Seed = tonumber(year .. month) :: number
		elseif format == "Biseason" then
			--- `February 14, 2024` --> `"2024_1"`
			--- Jan-Jun: `1` (SS)
			--- Jul-Dec: `2` (FW)
			T1.month = math.ceil(T1.month / 6)
			T1.day = 1
			T1.hour = 0
			T1.min = 0
			T1.sec = 0

			local year, month = T0.year, math.ceil(T0.month / 6)
			timestamp.Id = string.format("%d_%d", year, month)
			timestamp.Seed = tonumber(year .. month) :: number
		elseif format == "Year" then
			--- `February 14, 2024` --> `"2024"`
			T1.year += 1
			T1.month = 1
			T1.day = 1
			T1.hour = 0
			T1.min = 0
			T1.sec = 0

			timestamp.Id = tostring(T0.year)
			timestamp.Seed = tonumber(T0.year) :: number
		end
	end

	timestamp.Until = os.time(T1) - os.time(T0)

	return timestamp
end

--- formats number: \
--- thousands separated by `tsep (?=".")` \
--- decimals separated by `dsep (?=".")`, truncated by `places (?=1)`
function Encoder.formatnumber(x: number, tsep: string?, dsep: string?, places: number?)
	if places == 0 then
		return Encoder.commanumber(x, tsep)
	else
		local num = tostring(x)
		local i = string.find(num, "%.")
		
		if i then
			return Encoder.commanumber(x, tsep) .. (dsep or ".") .. string.sub(num, 1 + i, i + (places or 1))
		else
			return Encoder.commanumber(x, tsep)
		end
	end
end

--- formats number, thousands separated by `tsep (?=",")`
function Encoder.commanumber(x: number, tsep: string?)
	if math.abs(x) < 1000 then
		return tostring(math.floor(x))
	else
		local str = string.reverse(string.gsub(string.reverse(tostring(math.floor(x))), "(%d%d%d)", "%1" .. (tsep or ","))::any)
		return string.sub(str, string.find(str, "%d")::any, -1)
	end
end

--- abbreviates number, decimals separated by `dsep (?=".")`, truncated by `places (?=1)`
function Encoder.abbreviatenumber(x: number, places: number?, dsep: string?)
	local exp = math.floor(math.log(math.max(1, math.abs(x)), 1000))
	local suffix = Encoder.Abbreviations[1 + exp] or ("e+" .. exp)
	
	return string.gsub(tostring(math.floor(x * ((10 ^ (places or 1)) / (1000 ^ exp))) / (10 ^ (places or 1))), "[.]", dsep or ".") .. suffix
end

--- returns `string.format("%x", value)`
function Encoder.tohexadecimal(value: number)
	return string.format("%x", value)
end

--- returns `tonumber(value, 16)`
function Encoder.fromhexadecimal(value: string)
	return tonumber(value, 16)
end

type thumb =
	((type: "Asset", id: number, size: "150x150"|"420x420") -> string)
&	((type: "Avatar", id: number, size: "48x48"|"60x60"|"100x100"|"150x150"|"180x180"|"352x352"|"420x420"|"720x720") -> string)
&	((type: "AvatarBust", id: number, size: "50x50"|"60x60"|"75x75"|"100x100"|"150x150"|"180x180"|"352x352"|"420x420") -> string)
&	((type: "AvatarHeadShot", id: number, size: "48x48"|"60x60"|"100x100"|"150x150"|"180x180"|"352x352"|"420x420") -> string)
&	((type: "BadgeIcon", id: number, size: "150x150") -> string)
&	((type: "BundleThumbnail", id: number, size: "150x150"|"420x420") -> string)
&	((type: "FontFamily", id: number, size: "1200x80") -> string)
&	((type: "GameIcon", id: number, size: "50x50"|"150x150") -> string)
&	((type: "GamePass", id: number, size: "150x150") -> string)
&	((type: "GameThumbnail", id: number, size: "256x144"|"384x216"|"480x270"|"576x324"|"768x432") -> string)
&	((type: "GroupIcon", id: number, size: "150x150"|"420x420") -> string)
&	((type: "Outfit", id: number, size: "150x150"|"420x420") -> string)

local rbxthumb: thumb = function(type, id, size)
	return string.format("rbxthumb://type=%s&id=%d&w=%s&h=%s", type, id, unpack(string.split(size, "x")))
end

--- returns `rbxthumb://` thumbnail
Encoder.rbxthumb = rbxthumb

--- returns `HttpService:JSONEncode(input)`
function Encoder.jsonencode(input: any)
	return HttpService:JSONEncode(input)
end

--- returns `HttpService:JSONDecode(input)`
function Encoder.jsondecode(input: string)
	return HttpService:JSONDecode(input)
end

return Encoder