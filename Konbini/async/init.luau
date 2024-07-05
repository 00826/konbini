--!strict

local async = { __index = {} }

function async.__index:await(complete: (() -> ())?, catch: ((traceback: string) -> ())?, timeout: number?)
	self.timeout = timeout or self.timeout

	repeat
		self.result = self.fun()
		if not self.result then
			self.timeout -= task.wait()
		end
	until (self.result ~= false) or (self.timeout < 0)

	if self.result then
		if complete then complete() end
	else
		if catch then catch(debug.traceback()) end
	end

	return self
end

function async.__index:try(complete: (() -> ())?, catch: ((traceback: string) -> ())?)
	local s, e = pcall(self.fun)
	if s then
		if complete then complete() end
	else
		if catch then catch(debug.traceback(e)) end
	end
	return self
end

function async.__index:thenrepeat(timeout: number?)
	self.result = false
	self.timeout = timeout or 5
	return self
end

function async.__index:thendo(f: () -> boolean, timeout: number?)
	self.fun = f
	self.result = false
	self.timeout = timeout or 5
	return self
end

--- ### async.luau
---
--- oh to have a function like task.await() \
--- all methods return itself for easy chaining
return function(f: () -> boolean)
	return setmetatable({
		fun = f;
		result = false;
		timeout = 5;
	}, async)
end