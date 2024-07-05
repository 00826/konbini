--!strict

local types						= require("./Konbini/types")

local Cache						= {}


local Bind = { __index = {} }

--- connects function to group
function Bind.__index:Connect(f: (...any) -> ()): types.Disconnect
	table.insert(self.funcs, f)
	return function() self:Disconnect(f) end
end

--- passes vararg to all bound functions
function Bind.__index:Fire(...: any): ()
	for i = #self.funcs, 1, -1 do
		local f = self.funcs[i]
		if getfenv(f).script.Parent == nil then
			table.remove(self.funcs, i)
			continue
		end
		task.defer(f, ...)
	end
	self:Resume(...)
end

--- recursively resumes all yielded threads and passes vararg `...` into `task.defer(coroutine, ...)`
function Bind.__index:Resume(...: any): ()
	local co = table.remove(self.yields)
	if co then
		task.defer(co, ...)
		self:Resume(...)
	else
		return
	end
end

--- yields thread until `Fire()` is called
function Bind.__index:Wait(): ...any
	table.insert(self.yields, coroutine.running())
	return coroutine.yield()
end

--- disconnects bound function
function Bind.__index:Disconnect(f: (...any) -> ()): ()
	table.remove(self.funcs, table.find(self.funcs, f) or 0)
end

--- disconnects all bound functions and resumes all yielded threads
function Bind.__index:DisconnectAll(): ()
	table.clear(self.funcs)
	self:Resume()
end

--- destroys bind, clears all connected functions, and resumes all yielded threads
function Bind.__index:Destroy(): ()
	local Name = self.Name
	self:DisconnectAll()
	table.clear(self)
	setmetatable(self, nil)
	Cache[Name] = nil
end

--- ### Bind.luau
---
--- binds multiple functions to a single group
return function(name: string, size: number?)
	if not Cache[name] then
		Cache[name] = setmetatable({ Name = name; funcs = table.create(size or 8); yields = table.create(size or 8); }, Bind)
	end
	return Cache[name]
end