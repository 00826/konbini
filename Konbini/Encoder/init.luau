--!strict

local HttpService				= game:GetService("HttpService")

local int8						= 1 / 127

--- ### Encoder.luau
---
--- buffer helper functions
local Encoder = {}

--- trims trailing whitespaces from string stored in buffer
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

--- generates a random guid
function Encoder.guid(len: number?): string
	return string.sub(string.gsub(HttpService:GenerateGUID(false), "-", ""), 1, (len or 8))
end

return Encoder