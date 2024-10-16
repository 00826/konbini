--!strict

local DefaultR = Random.new()

local int8 = 1/127

--- ### Encoder.luau
---
--- buffer and string helper functions
local Encoder = {}

--- trims trailing whitespaces from string in buffer
function Encoder.trimstring(str: string): string
	return string.gsub(string.gsub(str, "%s+", " "), "\u{0000}", "")
end

--- reads Vector3 from buffer
function Encoder.readvector3(b: buffer, offset: number): Vector3
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

--- writes unit vector from buffer
function Encoder.readunitvector(b: buffer, offset: number): Vector3
	return Vector3.new(
		buffer.readi8(b, offset + 0),
		buffer.readi8(b, offset + 1),
		buffer.readi8(b, offset + 2)
	) * int8
end

--- writes unit vector to buffer \
--- `x,y,z`: mapped to `[-127, 127]`
function Encoder.writeunitvector(b: buffer, offset: number, value: Vector3)
	buffer.writei8(b, offset + 0, math.clamp(value.X * 127, -127, 127))
	buffer.writei8(b, offset + 1, math.clamp(value.Y * 127, -127, 127))
	buffer.writei8(b, offset + 2, math.clamp(value.Z * 127, -127, 127))
end

--- reads CFrame from buffer
function Encoder.readcframe(b: buffer, offset: number): CFrame
	return CFrame.new(
		buffer.readf32(b, offset),
		buffer.readf32(b, offset + 4),
		buffer.readf32(b, offset + 8)
	) * CFrame.fromOrientation(
		buffer.readi16(b, offset + 12) / 100,
		buffer.readi16(b, offset + 14) / 100,
		buffer.readi16(b, offset + 16) / 100
	)
end

--- writes CFrame to buffer
function Encoder.writecframe(b: buffer, offset: number, value: CFrame)
	buffer.writef32(b, offset, value.X)
	buffer.writef32(b, offset + 4, value.Y)
	buffer.writef32(b, offset + 8, value.Z)

	local rx, ry, rz = value:ToOrientation()
	buffer.writei16(b, offset + 12, rx * 100)
	buffer.writei16(b, offset + 14, ry * 100)
	buffer.writei16(b, offset + 16, rz * 100)
end

--- reads boolean from buffer
function Encoder.readboolean(b: buffer, offset: number): boolean
	return buffer.readu8(b, offset) == 1
end

--- writes boolean to buffer
function Encoder.writeboolean(b: buffer, offset: number, value: boolean?)
	buffer.writeu8(b, offset, value and 1 or 0)
end

--- rotates range of values to the right
--- ```
--- rrotatef64([1, 2, 3, 4, 5]) -> [5, 1, 2, 3, 4]
--- ```
function Encoder.rrotatef64(b: buffer, offset: number, range: number)
	local x = buffer.readf64(b, offset + range - 8)
	buffer.copy(b, offset + 8, b, offset, range - 8)
	buffer.writef64(b, offset, x)
end

--- rotates range of values to the left
--- ```
--- lrotatef64([1, 2, 3, 4, 5]) -> [2, 3, 4, 5, 1]
--- ```
function Encoder.lrotatef64(b: buffer, offset: number, range: number)
	local x = buffer.readf64(b, offset)
	buffer.copy(b, offset, b, offset + 8, range - 8)
	buffer.writef64(b, offset + range - 8, x)
end

--- swaps values stored at two offsets
function Encoder.swapf64(b: buffer, x: number, y: number)
	local z = buffer.readf64(b, x)
	buffer.writef64(b, x, buffer.readf64(b, y))
	buffer.writef64(b, y, z)
end

--- returns true if `a == b`
function Encoder.compare(a: buffer, b: buffer): boolean
	local sizeA = buffer.len(a)
	local sizeB = buffer.len(b)
	if sizeA ~= sizeB then
		return false
	else
		for offset = 1, sizeA do
			offset -= 1
			if buffer.readu8(a, offset) ~= buffer.readu8(b, offset) then
				return false
			end
		end
	end
	return true
end

--- merges value stored in new buffer into old buffer, returning values of changes made \
--- returns: \
--- `[buffer old u8] @ [offset] == [buffer new u8] @ [offset]` \
--- `[buffer old u8] @ [offset]` \
--- `[buffer new u8] @ [offset]`
function Encoder.mergeu8(old: buffer, new: buffer, offset: number): (boolean, number, number)
	local x = buffer.readu8(old, offset)
	local y = buffer.readu8(new, offset)
	local applychange = x ~= y
	if applychange then
		buffer.copy(old, offset, new, offset, 1)
	end
	return applychange, x, y
end

--- writes signed 24-bit integer to buffer
function Encoder.writei24(b: buffer, offset: number, value: number)
	local sign = math.sign(value) < 0 and 1 or 0
	if sign == 1 then
		value += 1
	end
	local abs = math.abs(value)

	buffer.writeu8(b, offset + 0, bit32.extract(abs, 0, 8))
	buffer.writeu8(b, offset + 1, bit32.extract(abs, 8, 8))

	local x = bit32.extract(abs, 16, 8)
	buffer.writeu8(b, offset + 2, bit32.replace(x, sign, 7, 1))
end

--- reads signed 24-bit integer from buffer
function Encoder.readi24(b: buffer, offset: number): number
	local int = 0
	int = bit32.replace(int, buffer.readu8(b, offset + 0), 0, 8)
	int = bit32.replace(int, buffer.readu8(b, offset + 1), 8, 8)
	int = bit32.replace(int, buffer.readu8(b, offset + 2), 16, 8)
	local sign = bit32.extract(int, 23, 1) == 1 and -1 or 1
	local value = bit32.extract(int, 0, 23) * sign
	if sign < 0 then
		value -= 1
	end
	return value
end

--- writes unsigned 24-bit integer to buffer
function Encoder.writeu24(b: buffer, offset: number, value: number)
	buffer.writeu8(b, offset + 0, bit32.extract(value, 0, 8))
	buffer.writeu8(b, offset + 1, bit32.extract(value, 8, 8))
	buffer.writeu8(b, offset + 2, bit32.extract(value, 16, 8))
end

--- reads unsigned 24-bit integer from buffer
function Encoder.readu24(b: buffer, offset: number): number
	local int = 0
	int = bit32.replace(int, buffer.readu8(b, offset + 0), 0, 8)
	int = bit32.replace(int, buffer.readu8(b, offset + 1), 8, 8)
	int = bit32.replace(int, buffer.readu8(b, offset + 2), 16, 8)
	return int
end

--- returns an empty `i16`-width matrix-buffer \
--- *matrices are one-indexed (buffers are zero-indexed), as column/row info is stored in the first 2 bytes*
function Encoder.creatematrix(columns: number, rows: number): buffer
	local m = buffer.create( 2 + (2 * columns * rows) )

	buffer.writeu8(m, 0, columns)
	buffer.writeu8(m, 1, rows)

	return m
end

--- writes value to matrix-buffer
function Encoder.writematrix(m: buffer, column: number, row: number, value: number)
	local width = 2 * buffer.readu8(m, 0)
	local offset = (2 * column) + ((row - 1) * width)

	buffer.writei16(m, offset, value)
end

--- writes set of values to row of matrix-buffer \
--- if values are omitted, the range is filled with zeroes
function Encoder.writerowmatrix(m: buffer, row: number, values: {number}?)
	local columns = buffer.readu8(m, 0)
	local width = 2 * columns
	local offset = 2 + ((row - 1) * width)

	if values then
		for i = 1, columns do
			buffer.writei16(m, offset + (2 * (i - 1)), values[i] or 0)
		end
	else
		buffer.fill(m, offset, 0, width)
	end
end

--- reads set of values along row of matrix-buffer
function Encoder.readrowmatrix(m: buffer, row: number): {number}
	local columns = buffer.readu8(m, 0)
	local width = 2 * columns
	local offset = 2 + ((row - 1) * width)
	local r = table.create(columns, 0)

	for i = 1, columns do
		r[i] = buffer.readi16(m, offset)
		offset += 2
	end

	return r
end

--- reads sum of values along column of matrix-buffer
function Encoder.readcolumnmatrix(m: buffer, column: number): number
	local rows = buffer.readu8(m, 1)
	local width = 2 * buffer.readu8(m, 0)

	local offset = 2 * column
	local sum = 0

	for i = 1, rows do
		sum += buffer.readi16(m, offset)
		offset += width
	end

	return sum
end

function Encoder.unpackmatrix(m: buffer): { {number} }
	local columns = buffer.readu8(m, 0)
	local rows = buffer.readu8(m, 1)

	local u = table.create(rows)
	local sums = table.create(columns, 0)

	print(`{columns}x{rows} (2 + {buffer.len(m)-2} bytes) matrix: `, m)

	for i = 1, rows do
		local r = Encoder.readrowmatrix(m, i)
		table.insert(u, r)

		local strings = table.create(columns)
		for a, b in ipairs(r) do
			strings[a] = string.format("%04d", b)
			sums[a] += b
		end
		print(`[{i}]	`, table.concat(strings, " "))
	end

	for a, b in ipairs(sums) do
		sums[a] = string.format("%04d", Encoder.readcolumnmatrix(m, a))::any
	end
	print("----")
	print(`[sum]	`, table.concat(sums, " "))

	return u
end

--- writes value to bit-field-width of u32 stored in buffer at offset \
--- returns new value, for convenience \
--- accessible bit range: `[0, 31]`
function Encoder.writeflagu32(b: buffer, offset: number, field: number, width: number, value: number): number
	local x = bit32.replace(buffer.readu32(b, offset), value, field, width)
	buffer.writeu32(b, offset, x)
	return x
end

--- reads value stored along bit-field-width of u32 stored in buffer at offset \
--- accessible bit range: `[0, 31]`
function Encoder.readflagu32(b: buffer, offset: number, field: number, width: number): number
	return bit32.extract(buffer.readu32(b, offset), field, width)
end

--- returns a randomized alphanumeric string `[A-Za-z0-9], P(62,r)=62^r` \
--- `len (?=4, P(62,4)=677040)`: string length
function Encoder.string(len: number?): string
	local str = ""
	for i = 1, len or 4 do
		local value = DefaultR:NextInteger(1, 36)
		if value <= 26 then
			local coinflip = DefaultR:NextInteger(0, 1) == 0
			if coinflip then
				str ..= string.char(value + 64) -- [A-Z]
			else
				str ..= string.char(value + 96) -- [a-z]
			end
		else
			str ..= tostring(36 - value) -- [0-9]
		end
	end
	return str
end

--- replaces captures matching `flag .. "%w+"` in text with respect to replacement table
function Encoder.alias(text: string, flag: string, replace: {[string]: string}): string
	if string.find(text, flag) then
		text = string.gsub(text, flag .. "%w+", function(s: string)
			return replace[select(2, unpack(string.split(s, flag)))] or "[missing alias]"
		end)
	end
	return text
end

return Encoder