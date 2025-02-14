--!strict
--!native

local types = require(script.Parent.types)

--- ### Stats.luau
---
--- general stat solver \
--- \
--- bars, status effects, stats
local Stats = {
	R = Random.new();
}

--- returns a random integer within `[0, upperlimit]` \
--- `R (?=Stats.R)`
function Stats.roll(upperlimit: number, R: Random?)
	return (R or Stats.R):NextInteger(0, upperlimit)
end

--- returns `roll / upperlimit <= odds`
function Stats.outcome(roll: number, upperlimit: number, odds: number)
	return roll / upperlimit <= odds
end

--- returns a bar buffer \
--- \
--- `buffer[f32 value, f32 maxvalue]` \
--- mutator functions associated with bars attempt to clamp value within `[0, bar maxvalue]`
function Stats.createbar(value: number, maxvalue: number)
	local b = buffer.create(4 + 4)

	buffer.writef32(b, 0, value)
	buffer.writef32(b, 4, maxvalue)

	return b
end

--- writes to bar buffer
function Stats.barwrite(b: buffer, value: number?, maxvalue: number?)
	if maxvalue then
		buffer.writef32(b, 0, buffer.readf32(b, 4) * math.clamp(buffer.readf32(b, 0) / maxvalue, 0, 1))
		buffer.writef32(b, 4, maxvalue)
	end
	if value then
		buffer.writef32(b, 0, math.clamp(value, 0, buffer.readf32(b, 4)))
	end
end

--- applies deltas to bar buffer
function Stats.bardelta(b: buffer, value: number?, maxvalue: number?)
	if maxvalue then
		maxvalue += buffer.readf32(b, 4)
		buffer.writef32(b, 0, buffer.readf32(b, 4) * math.clamp(buffer.readf32(b, 0) / maxvalue, 0, 1))
		buffer.writef32(b, 4, maxvalue)
	end
	if value then
		value += buffer.readf32(b, 0)
		buffer.writef32(b, 0, math.clamp(value, 0, buffer.readf32(b, 4)))
	end
end

--- returns `bar.Value - x >= 0`
function Stats.barpeek(b: buffer, x: number)
	return buffer.readf32(b, 0) - x >= 0
end

--- returns `bar.Value >= bar.MaxValue`
function Stats.barmax(b: buffer)
	return buffer.readf32(b, 0) >= buffer.readf32(b, 4)
end

--- equivalent to `buffer.writef32(b, 0, buffer.readf32(b, 0) - x)`
function Stats.barexpend(b: buffer, x: number)
	buffer.writef32(b, 0, buffer.readf32(b, 0) - x)
end

--- returns bar buffer `value, maxvalue`
function Stats.barunpack(b: buffer)
	return buffer.readf32(b, 0), buffer.readf32(b, 4)
end

--- returns a status buffer \
--- `stacks (?=1)` \
--- \
--- `buffer[f32 expiry, u8 stacks]`
function Stats.createstatus(expiry: number, stacks: number?)
	local s = buffer.create(4 + 1)

	buffer.writef32(s, 0, expiry)
	buffer.writeu8(s, 4, stacks or 1)

	return s
end

--- directly writes to status buffer
function Stats.statuswrite(s: buffer, expiry: number?, stacks: number?)
	if expiry then
		buffer.writef32(s, 0, expiry)
	end
	if stacks then
		buffer.writeu8(s, 4, stacks)
	end
end

function Stats.statusadd(st: {[string]: buffer}, key: string, expiry: number, stacks: number?)
	local s = st[key]
	if not s then
		s = Stats.createstatus(expiry, stacks)
		st[key] = s
	else
		Stats.statuswrite(s, expiry, stacks)
	end
end

--- applies deltas to status buffer \
--- if bounds are passed, values are clamped within `value = [bounds[1], bounds[2]]`
function Stats.statusdelta(s: buffer, expiry: number?, stacks: number?, expirybounds: {number}?, stackbounds: {number}?)
	if expiry then
		expiry += buffer.readf32(s, 0)
		if expirybounds then
			expiry = math.clamp(expiry, expirybounds[1], expirybounds[2])
		end
		buffer.writef32(s, 0, expiry)
	end
	if stacks then
		stacks += buffer.readu8(s, 4)
		if stackbounds then
			stacks = math.clamp(stacks, stackbounds[1], stackbounds[2])
		end
		buffer.writeu8(s, 4, stacks)
	end
end

--- returns status buffer `expiry, stacks`
function Stats.statusunpack(s: buffer)
	return buffer.readf32(s, 0), buffer.readu8(s, 4)
end

--- returns: \
--- `manifest`, table describing multipliers and additives with respect to `manifesttable` \
--- `expiries`, array of expired or zeroed status ids with respect to `now` \
--- \
--- optional scoped keys to only read from a specific set of status effects \
--- *expiries of `-1` are indefinite* \
--- *zero-stack status buffers are interpreted as expired*
function Stats.statusmanifest(st: {[string]: buffer}, manifesttable: types.StatusManifestTable, now: number, scope: {string}?)
	local manifest, expiries = {}, table.create(16)

	if scope then
		local faketable = {}
		for _, key in scope do
			faketable[key] = st[key]
		end

		return Stats.statusmanifest(faketable, manifesttable, now)
	else
		for statusid, statusbuffer in st do
			local active, _, stacks = Stats.statusinterpret(statusbuffer, now)
			if not active then
				table.insert(expiries, statusid)
				continue
			end
	
			local entry = manifesttable[statusid]
			if not entry then
				warn(`manifesttable["{statusid}"] missing`)
				continue
			end
	
			for key, addmul in entry.Values::{[string]: types.StatusAddMul} do
				if not manifest[key] then
					manifest[key] = {Add = 0; Mul = 0;}
				end
	
				local real = manifest[key]
				real.Add += (addmul.Add or 0) * stacks
				real.Mul += (addmul.Mul or 0) * stacks
			end
		end
	end

	return manifest, expiries
end

--- returns shallow array of active status effects \
--- `limit` active effect peek limit
function Stats.statuspeek(st: {[string]: buffer}, keys: {string}, now: number, limit: number?)
	local result, total = table.create(#keys), 0

	for _, key in keys do
		local s = st[key]
		if not s then continue end

		local active = buffer.readf32(s, 0) > now ---Stats.statusinterpret(s, now)
		if not active then continue end

		table.insert(result, key)
		total += 1

		if limit and total >= limit then
			return result
		end
	end

	return result
end

--- compares multiple state tables \
--- `limit` active effect peek limit
function Stats.statusmultipeek(states: { {[string]: buffer} }, keys: {string}, now: number, limit: number?)
	local final, len = table.create(0), 0

	for _, state in ipairs(states) do --- for consistent checking/sequencing
		local result = Stats.statuspeek(state, keys, now, limit)
		local resultlen = #result
		if resultlen > len then
			final = result
			len = resultlen
		end
	end

	return final
end

--- returns display table of active status effects \
--- optional scoped keys to only display a specific set of status effects
function Stats.statusdisplay(st: {[string]: buffer}, now: number, scope: {string}?)
	local result = {}

	if scope then
		local faketable = {}
		for _, key in scope do
			faketable[key] = st[key]
		end

		return Stats.statusdisplay(faketable, now)
	else
		for key, s in st do
			local active, expires, stacks = Stats.statusinterpret(s, now)
			if not active then continue end
	
			result[key] = {
				Expires = expires;
				Stacks = stacks;
			}
		end
	end

	return result
end

--- returns: \
--- `true` if status buffer is "active" \
--- `number` status buffer time until expiry \
--- `number` status buffer stacks \
--- \
--- zero-stacks takes precedence over expiry time. meaning that an indefinite status effect can be force-expired by setting stacks to 0
function Stats.statusinterpret(s: buffer, now)
	local expiry, stacks = buffer.readf32(s, 0), buffer.readu8(s, 4)

	if stacks <= 0 then
		return false, 0, stacks
	elseif expiry == -1 then
		return true, -1, stacks
	end

	return expiry > now, expiry - now, stacks
end

--- returns empty i16 stat matrix
function Stats.creatematrix(columns: {string}, rows: {string})
	local a, b = #columns, #rows
	local m = buffer.create( 2 + (2 * a * b) )

	buffer.writeu8(m, 0, a)
	buffer.writeu8(m, 1, b)

	return m
end

--- returns sorted arrays representing rows (sources) and columns (values) of stat matrix with respect to matrix entry table `et` and matrix source table `st` \
--- `et_dst:` matrix column destination table/cache \
--- `st_dst:` matrix row destination table/cache
function Stats.matrixcolumnsrows(et: types.MatrixEntryTable, st: types.MatrixSourceTable, et_dst: {}?, st_dst: {}?)
	local columns, rows = table.create(8), table.create(8)

	for key in et do
		table.insert(columns, key)
	end
	table.sort(columns)
	if et_dst then
		table.clear(et_dst)
		table.move(columns, 1, #columns, 1, et_dst)
	end

	for key in st do
		table.insert(rows, key)
	end
	table.sort(rows)
	if st_dst then
		table.clear(st_dst)
		table.move(rows, 1, #rows, 1, st_dst)
	end

	return columns, rows
end

--- returns sum of columns of stat matrix
function Stats.matrixreadcolumn(n: buffer, column: number?)
	--[[
		this exists so that the shorthand to read a stat column can be:
		`sum = Stats.matrixsum(n, table.find(columns, column))`
		as the return values of table.find() are not guaranteed
		so this function can't really throw a type error
	]]
	assert(column, "missing column (stat values)")

	local columns, rows = buffer.readu8(n, 0), buffer.readu8(n, 1)

	local offset, sum = 2 * column, 0

	for i = 1, rows do
		sum += buffer.readi16(n, offset)
		offset += 2 * columns
	end

	return sum
end

--- returns array representation of row of numeric stat matrix from variant table `vt` with respect to columns \
--- should be passed into `Stats.matrixwriterow`
function Stats.matrixrow(vt: {[string]: number}, columns: {string})
	local row = table.create(#columns, 0)

	for k, v in vt do
		local i = table.find(columns, k)
		if i then
			row[i] = v
		end
	end

	return row
end

--- writes values to row (source) of numeric stat matrix
function Stats.matrixwriterow(n: buffer, row: number?, values: {number}?)
	--[[
		... read assertion comment in Stats.matrixsum; shorthand:
		`Stats.matrixwriterow(n, table.find(rows, row), {})`
	]]
	assert(row, "missing row (stat source)")

	local columns = buffer.readu8(n, 0)
	local width = 2 * columns
	local offset = 2 + ((row - 1) * width)

	if values then
		for i, value in ipairs(values) do
			buffer.writei16(n, offset + (2 * (i - 1)), value)

			if i >= columns then
				break
			end
		end
	else
		buffer.fill(n, offset, 0, width)
	end
end

return Stats 