--!strict
--!native
--!optimize 2

local intSize					= 2 -- int16

local Matrix = { __index = {} }

--- returns matrix buffer
function Matrix.__index:createbuffer(): buffer
	return buffer.create(self.Size)
end

--- returns corrected index of row i
function Matrix.__index:solve_i(i: number): number
	return (i - 1) * (intSize * self.ColumnSize)
end

--- returns corrected index of column j
function Matrix.__index:solve_j(j: number): number
	return (j - 1) * intSize
end

--- returns index of row
function Matrix.__index:find_i(row: string): number?
	local i = table.find(self.Rows, row)
	if not i then
		warn(`find_i "{row}"`)
		return nil
	end
	return self:solve_i(i)
end

--- returns index of column
function Matrix.__index:find_j(column: string): number?
	local j = table.find(self.Columns, column)
	if not j then
		warn(`find_j "{column}"`)
		return nil
	end
	return self:solve_j(j)
end

--- returns value stored at specified row and column
function Matrix.__index:read(b: buffer, rowId: string, column: string): number
	local i = self:find_i(rowId) :: number?
	if not i then return 0 end
	local j = self:find_j(column) :: number?
	if not j then return 0 end

	return buffer.readi16(b, i + j)
end

--- returns sum of values stored at column
function Matrix.__index:readcolumn(b: buffer, column: string): number
	local j = self:find_j(column) :: number?
	if not j then return 0 end

	local Sum = 0
	for i = 1, self.RowSize do
		i = self:solve_i(i)
		Sum += buffer.readi16(b, i + j)
	end

	return Sum
end

--- returns key-value table of values stored at row
function Matrix.__index:readrow(b: buffer, row: string): {[string]: number}
	local i = self:find_i(row) :: number?
	if not i then return {} end

	local Row = {}
	for j, StatId in ipairs(self.Columns) do
		j = self:solve_j(j)
		Row[StatId] = buffer.readi16(b, i + j)
	end

	return Row
end

--- sets value along column \
--- if value is omitted, value is 0
function Matrix.__index:writecolumn(b: buffer, columnId: string, value: number?): ()
	local j = self:find_j(columnId) :: number?
	if not j then return end

	for i = 1, self.RowSize do
		i = self:solve_i(i)
		buffer.writei16(b, i + j, value or 0)
	end
end

--- sets values along row
function Matrix.__index:writerow(b: buffer, row: string, valuetable: {[string]: number}): ()
	local i = self:find_i(row) :: number?
	if not i then return end

	for columnId, value in valuetable do
		local j = self:find_j(columnId)
		if not j then continue end

		buffer.writei16(b, i + j, value)
	end
end

--- clears matrix buffer \
--- equivalent to `buffer.fill(b, 0, 0)`
function Matrix.__index:clear(b: buffer): ()
	buffer.fill(b, 0, 0)
end

--- clears all values along column
function Matrix.__index:clearcolumn(b: buffer, column: string): ()
	local j = self:find_j(column) :: number?
	if not j then return end

	for i = 1, self.RowSize do
		i = self:solve_i(i)
		buffer.writei16(b, i + j, 0)
	end
end

--- clears all values along row
function Matrix.__index:clearrow(b: buffer, row: string): ()
	local i = self:find_i(row) :: number?
	if not i then return end

	for j = 1, self.ColumnSize do
		j = self:solve_j(j)
		buffer.writei16(b, i + j, 0)
	end
end

--- returns string interpreted from buffer
--- ```lua
--- buffer[0 -10 4 2 1] -> "0 -10 4 2 1"
--- ```
function Matrix.__index:tostring(b: buffer): string
	local bString = ""
	for i = 0, buffer.len(b) - intSize, intSize do
		bString ..= tostring(buffer.readi16(b, i)) .. " "
	end
	return bString
end

--- returns buffer interpreted from string
--- ```lua
--- "0 -10 4 2 1" -> buffer[0 -10 4 2 1]
--- ```
function Matrix.__index:fromstring(bufferstring: string): buffer
	local b = self:createbuffer()
	for i, sValue in ipairs(string.split(bufferstring, " ")) do
		i = (i - 1) * intSize
		if i + intSize > self.Size then
			break
		else
			buffer.writei16(b, i, tonumber(sValue) or 0)
		end
	end

	return b
end

--- unpacks matrix buffer for debugging
function Matrix.__index:unpack(b: buffer): ()
	do
		local t = table.create(self.ColumnSize)
		for _, StatId in ipairs(self.Columns) do
			local s = string.sub(StatId, 1, 3)
			table.insert(t, string.upper(s .. string.rep("_", 3 - #s)))
		end
		print(`[id]	`, table.concat(t, " "))
	end
	for i = 1, self.RowSize do
		i = self:solve_i(i)
		local t = table.create(self.ColumnSize)
		for j in ipairs(self.Columns) do
			table.insert(t, string.format("%03d", buffer.readi16(b, i + self:solve_j(j))))
		end
		print(`[{i}]	`, table.concat(t, " "))
	end
	do
		local t = table.create(self.ColumnSize)
		for _, columnId in ipairs(self.Columns) do
			table.insert(t, string.format("%03d", self:readcolumn(b, columnId)))
		end
		print(`[sum]	`, table.concat(t, " "))
	end
	print("----")
end

--- ### Matrix.luau
---
--- matrix/excel-style implementation \
--- useful for key-value stats
--- ```
--- 		c1	c2	c3	c4
--- 	r1	1	1	0	2
--- 	r2	0	0	5	0
--- 	r3	0	4	3	-1
--- 	---
--- 	sum	1	5	8	1
--- ```
return function(rows: {string}, columns: {string})
	local RowSize = #rows
	local ColumnSize = #columns
	local Size = intSize * RowSize * ColumnSize

	return setmetatable({
		Rows = rows;
		RowSize = RowSize;

		Columns = columns;
		ColumnSize = ColumnSize;

		Size = Size;
	}, Matrix)
end