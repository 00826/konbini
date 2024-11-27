--!strict
--!native

local types = require(script.Parent.types)

local int8 = 1/127

local function subf(x: string): string
	return #x == 1 and "0" .. x or x
end

--- ### Encoder.luau
---
--- buffer and string helper functions
local Encoder = {
	WidthLookup = {
		i8 = 1; u8 = 1;
		i16 = 2; u16 = 2;
		i24 = 3; u24 = 3;
		i32 = 4; u32 = 4; f32 = 4;
		f64 = 8;
	}
}

--- asserts all types of table `a` against typestring-table `typetable` \
--- values of typetable are separated such that each type is capturable by pattern `%w+` and is compared against `typeof(a[k])` \
--- returns table `c` of all truthful asserted values with respect to `typetable`
--- ```lua
--- e_assert({cats = 5}, {cats = "number"}) --- ok
--- e_assert({}, {cats = "number|nil"}) --- ok
--- e_assert({cats = Vector3.one}, {cats = "number|nil"}) --- error: expected typeof(a["cats"]) (Vector3) to be in set number|nil
--- ```
function Encoder.assert<T>(a: T & {[string]: unknown}, typetable: {[string]: string}): T & {[string]: unknown}
	assert(type(a) == "table", string.format("expected type(a) (%s) to be table", type(a)))

	local c = {}

	for key, typestring in typetable do
		local value = a[key]
		local type = typeof(value)

		string.gsub(typestring, "%w+", function(substring)
			if substring == type then
				c[key] = value
				return substring
			end
			
			error(string.format("expected typeof(a[%s]) (%s) to be in typeof-set %s", key, type, typestring), 2)
		end)
	end

	return c :: T & {[string]: unknown}
end

--- returns byte width with respect to int/float types
function Encoder.sizeof(intfloats: {types.intfloat|number}): number
	local size = 0
	for _, width in intfloats do
		if type(width) == "number" then
			size += width
		elseif type(width) == "string" then
			size += Encoder.WidthLookup[width] or 0
		end
	end
	return size
end

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

--- reads unit vector from buffer
function Encoder.readunitvector(b: buffer, offset: number): Vector3
	return Vector3.new(
		buffer.readi8(b, offset),
		buffer.readi8(b, offset + 1),
		buffer.readi8(b, offset + 2)
	) * int8
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
	local z = buffer.readstring(b, x, range or 1)
	buffer.writestring(b, x, buffer.readstring(b, y, range or 1))
	buffer.writestring(b, y, z)
end

--- returns true if `a == b`
function Encoder.compare(a: buffer, b: buffer): boolean
	local sizeA = buffer.len(a)
	local sizeB = buffer.len(b)
	if sizeA ~= sizeB then
		return false
	else
		for offset = 0, sizeA - 1 do
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

	buffer.writeu8(b, offset, bit32.extract(abs, 0, 8))
	buffer.writeu8(b, offset + 1, bit32.extract(abs, 8, 8))

	local x = bit32.extract(abs, 16, 8)
	buffer.writeu8(b, offset + 2, bit32.replace(x, sign, 7, 1))
end

--- reads signed 24-bit integer from buffer
function Encoder.readi24(b: buffer, offset: number): number
	local int = 0
	int = bit32.replace(int, buffer.readu8(b, offset), 0, 8)
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
	buffer.writeu8(b, offset, bit32.extract(value, 0, 8))
	buffer.writeu8(b, offset + 1, bit32.extract(value, 8, 8))
	buffer.writeu8(b, offset + 2, bit32.extract(value, 16, 8))
end

--- reads unsigned 24-bit integer from buffer
function Encoder.readu24(b: buffer, offset: number): number
	local int = 0
	int = bit32.replace(int, buffer.readu8(b, offset), 0, 8)
	int = bit32.replace(int, buffer.readu8(b, offset + 1), 8, 8)
	int = bit32.replace(int, buffer.readu8(b, offset + 2), 16, 8)
	return int
end

--- returns a `int16`-width matrix-buffer \
--- space complexity of `2 + (2*columns*rows)` \
--- *matrix value placements start at offset `2`, as column/row info is stored in the first 2 bytes*
function Encoder.creatematrix(columns: number, rows: number): buffer
	local m = buffer.create( 2 + (2 * columns * rows) )

	buffer.writeu8(m, 0, columns)
	buffer.writeu8(m, 1, rows)

	return m
end

--- writes value to `int16`-width matrix-buffer
function Encoder.writematrix(m: buffer, column: number, row: number, value: number)
	local width = 2 * buffer.readu8(m, 0)
	local offset = (2 * column) + ((row - 1) * width)

	buffer.writei16(m, offset, value)
end

--- writes set of values to row of `int16`-width matrix-buffer \
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

--- reads set of values along row of `int16`-width matrix-buffer
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

--- reads sum of values along column of `int16`-width matrix-buffer
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

--- returns matrix as a two-dimensional numeric array \
--- `precision (?=4)`: # of digits to display per value \
--- `output (?=false)`: print matrix in output
function Encoder.unpackmatrix(m: buffer, precision: number?, output: boolean?): { {number} }
	local columns = buffer.readu8(m, 0)
	local rows = buffer.readu8(m, 1)

	local u = table.create(rows)
	local sums = table.create(columns, 0)

	local digits = "%0" .. tostring(precision or 4) .. "d"

	if output then
		print(`{columns}x{rows} (2 + {buffer.len(m)-2} bytes) matrix: `, m)
	end

	for i = 1, rows do
		local r = Encoder.readrowmatrix(m, i)
		table.insert(u, r)

		local strings = table.create(columns)
		for a, b in ipairs(r) do
			strings[a] = string.format(digits, b)
			sums[a] += b
		end
		if output then
			print(`[{i}]	`, table.concat(strings, " "))
		end
	end

	for a, b in ipairs(sums) do
		sums[a] = string.format(digits, Encoder.readcolumnmatrix(m, a))::any
	end
	if output then
		print("----")
		print(`[sum]	`, table.concat(sums, " "))
	end

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

--- equivalent to `bit32.replace(x, value, field, width)`
function Encoder.writebits(x: number, field: number, width: number, value: number): number
	return bit32.replace(x, value, field, width)
end

--- returns range of bits as a string
function Encoder.readbits(x: number, field: number, range: number): string
	local bitstring = ""
	for i = 1, range do
		bitstring ..= tostring(bit32.extract(x, field + i))
	end
	return bitstring
end

--- returns a randomized alphanumeric string `[A-Za-z0-9], P(62,r)=62^r` \
--- `len (?=4, P(62,4)=677040)`: string length
function Encoder.string(len: number?): string
	local str = ""
	for i = 1, len or 4 do
		local value = types.R:NextInteger(1, 36)
		if value <= 26 then
			local coinflip = types.R:NextInteger(0, 1) == 0
			if coinflip then
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

--- replaces substrings in text matching capture pattern with respect to replacement table \
--- `capture (?=%S+)`: capture substrings separated by whitespaces
function Encoder.alias(text: string, replace: {[string]: string}, pattern: string?): string
	return string.gsub(text, pattern or "%S+", function(s: string)
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

--- applies richtext color to substrings in text matching capture pattern with respect to Color3/hex code palette \
--- `capture (?=%S+)`: capture substrings separated by whitespaces
function Encoder.richcolor(text: string, palette: {[string]: Color3|string}, pattern: string?): string
	return string.gsub(text, pattern or "%S+", function(s: string)
		local color = palette[s]
		if color then
			if typeof(color) == "Color3" then
				color = color:ToHex()
			end

			assert(typeof(color) == "string")
			return [[<font color="#]] .. color .. [[">]] .. s .. [[</font>]]
		end
		return s
	end)
end

--- returns unicode offset formatted as luau string `"\u{CODEPOINT}"`
function Encoder.codepoint(offset: number|string): string
	if type(offset) == "string" then
		return "\\u{" .. offset .. "}"
	elseif type(offset) == "number" then
		return "\\u{" .. string.format("%04d", offset) .. "}"
	else
		error(`expected number or string, got {type(offset)} "{offset}"`)
	end
end

--- formats time into a hour-minute-second-esque notation
function Encoder.hourminutesecond(time: number, notation: types.Notation?): string
	--[[
		os.date("!%X", time) is the fastest for all inputs below 86400, because any input at or above 86400 breaks the formatting
		string.gsub(string.format(), time, subf) is the second fastest for all inputs, never has a formatting break, but is ~10% slower than os.date("!%X", time)
		combining both through comparing time >= 86400 gives a faster average across all possible inputs
	]]
	if notation == "DD:HH:MM:SS" then
		if time >= 86400 then
			local D = time // 86400
			time -= D * 86400
			local H = time // 3600
			time -= H * 3600
			local M = time // 60
			time -= M * 60
			return string.gsub(string.format("%d:%d:%d:%d", D, H, M, time), "%d+", subf)
		else
			return "00:" .. os.date("!%X", time)
		end
	elseif notation == "HH:MM:SS" then
		if time >= 86400 then
			local H = time // 3600
			time -= H * 3600
			local M = time // 60
			time -= M * 60
			return string.gsub(string.format("%d:%d:%d", H, M, time), "%d+", subf)
		else
			return os.date("!%X", time)
		end
	elseif notation == "MM:SS" then
		if time >= 3600 then
			local M = time // 60
			time -= M * 60
			return string.gsub(string.format("%d:%d", M, time), "%d+", subf)
		else
			return string.sub(os.date("!%X", time), 4, 8)
		end
	elseif notation == "M:SS" then
		return string.gsub(string.sub(os.date("!%X", time), 4, 8), "^0", "")
	end
	return os.date("!%X", time)
end

--- returns a timestamp of current utc time with respect to format option
function Encoder.timestamp(format: types.Format): types.Timestamp
	local T0 = os.date("!*t")
	local T1 = table.clone(T0)

	local timestamp = {
		Id = "";
		Seed = 0;
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

return Encoder