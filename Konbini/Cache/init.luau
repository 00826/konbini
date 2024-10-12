--!strict

local Cache					= {}

local C = { __index = {} }
C.__len = function(self)
	return #self.Items
end
C.__iter = function(self)
	return pairs(self.Items)
end

--- adds `thing` to cached items
function C.__index:add<T>(thing: T): ()
	if self.Filter then
		if not self.Filter(thing) then return end
	end

	if not table.find(self.Items, thing) then
		table.insert(self.Items, thing)

		for _, f in self.AddedListeners do
			if getfenv(f).script.Parent == nil then
				table.remove(self.AddedListeners, table.find(self.AddedListeners, f) or 0)
				continue
			end
			task.defer(f, thing)
		end
	end
end

--- removes `thing` from cached items
function C.__index:remove<T>(thing: T): T?
	local Removed = table.remove(self.Items, table.find(self.Items, thing) or 0)

	if Removed ~= nil then
		for _, f in self.RemovedListeners do
			if getfenv(f).script.Parent == nil then
				table.remove(self.RemovedListeners, table.find(self.RemovedListeners, f) or 0)
				continue
			end
			task.defer(f, Removed)
		end
	end

	return Removed
end

--- returns index or nil of `thing` in cached items, if any
function C.__index:find<T>(thing: T): number?
	return table.find(self.Items, thing)
end

--- fires function when an item is added to cached items
function C.__index:ItemAdded<T>(f: (thing: T) -> ()): () -> ()
	table.insert(self.AddedListeners, f)
	return function ()
		table.remove(self.AddedListeners, table.find(self.AddedListeners, f) or 0)
	end
end

--- fires function when an item is removed from cached items
function C.__index:ItemRemoved<T>(f: (thing: T) -> ()): () -> ()
	table.insert(self.RemovedListeners, f)
	return function ()
		table.remove(self.RemovedListeners, table.find(self.RemovedListeners, f) or 0)
	end
end

--- connects .ChildAdded and .ChildRemoved events of `thing`
function C.__index:Connect(thing: Instance): ()
	if self.Connections[thing] then
		for _, Connection in self.Connections[thing] do
			Connection:Disconnect()
		end
		table.clear(self.Connections[thing])
	else
		self.Connections[thing] = table.create(2)
	end

	local ConnectTable = self.Connections[thing]
	table.insert(ConnectTable, thing.ChildAdded:Connect(function(ThisThing: Instance)
		self:add(ThisThing)
	end))
	table.insert(ConnectTable, thing.ChildRemoved:Connect(function(ThisThing: Instance)
		self:remove(ThisThing)
	end))
	for _, ThisThing in thing:GetChildren() do
		self:add(ThisThing)
	end
end

--- disconnects .ChildAdded and .ChildRemoved connections set by Instance `thing`
function C.__index:Disconnect(thing: Instance): ()
	if self.Connections[thing] then
		for _, Connection in self.Connections[thing] do
			Connection:Disconnect()
		end
		table.clear(self.Connections[thing])
		self.Connections[thing] = nil
	end
end

--- disconnects all instance connections
function C.__index:DisconnectAll(): ()
	for thing in self.Connections do
		self:Disconnect(thing)
	end
end

--- destroys cache object
function C.__index:Destroy(): ()
	local Name = self.Name
	self:DisconnectAll()
	table.clear(self.Items)
	table.clear(self.AddedListeners)
	table.clear(self.RemovedListeners)
	table.clear(self)
	setmetatable(self, nil)
	Cache[Name] = nil
end

--- ### Cache.luau
---
--- shallow instance cacher
return function(name: string, size: number?)
	if not Cache[name] then
		Cache[name] = setmetatable({
			Name = name;
			Items = table.create(size or 64);
			Filter = nil :: ((Instance) -> boolean)?;
			Connections = {};
			AddedListeners = table.create(8);
			RemovedListeners = table.create(8);
		}, C)
	end
	return Cache[name]
end