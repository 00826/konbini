--!strict

local Cache = {}

--- ### Hook.luau
---
--- oopless function binder \
--- all bound functions are deferred
--- ```luau
--- Hook("KonbiniHook").Connect(print)
--- Hook("KonbiniHook").Fire("o/ hi!") --- o/ hi!
--- ```
return function(name: string)
	if not Cache[name] then
		Cache[name] = {
			_functions = {};
			_yields = {};
		}
		local hook = Cache[name]

		--- recursively resumes yielded threads
		local function resume(...: any)
			local co = table.remove(hook._yields)
			if co then
				task.defer(co, ...)
				hook.Resume(...)
			else
				return
			end
		end

		--- connects function to this hook
		hook.Connect = function(f: (...any) -> ())
			table.insert(hook._functions, f)

			return function()
				table.remove(hook._functions, table.find(hook._functions, f) or 0)
			end
		end
		--- yields thread until this hook is fired
		hook.Wait = function()
			table.insert(hook._yields, coroutine.running())
			return coroutine.yield()
		end
		--- calls functions bound to this hook along with any arguments passed
		hook.Fire = function(...: any)
			for i = #hook._functions, 1, -1 do
				local f = hook._functions[i]
				if getfenv(f).script.Parent == nil then
					table.remove(hook._functions, i)
					continue
				end

				task.defer(f, ...)
			end
			resume(...)
		end
		--- disconnects all functions bound to this hook
		hook.DisconnectAll = function()
			table.clear(hook._functions)
		end
		--- destroys this hook, resuming any yielded threads prior to destruction
		hook.Destroy = function(...: any)
			resume(...)

			table.clear(hook._functions)
			table.clear(hook)
			Cache[name] = nil
		end
	end

	return Cache[name]
end