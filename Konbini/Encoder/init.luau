--!strict

local R							= Random.new()

local int8						= 1 / 127

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
function Encoder.writevector3(b: buffer, offset: number, value: Vector3): ()
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
function Encoder.writeunitvector(b: buffer, offset: number, value: Vector3): ()
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
function Encoder.writecframe(b: buffer, offset: number, value: CFrame): ()
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
function Encoder.writeboolean(b: buffer, offset: number, value: boolean?): ()
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

--- returns a randomized alphanumeric string `[A-Za-z0-9], P(62,r)=62^r` \
--- `len (?=4, P(62,4)=677040)` string length
function Encoder.string(len: number?): string
	local str = ""
	for i = 1, len or 4 do
		local value = R:NextInteger(1, 36)
		if value <= 26 then
			local coinflip = R:NextInteger(0, 1) == 0
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