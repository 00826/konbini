--!strict
--!native

local Hooks = {}

--- ### Hook.luau
---
--- oopless function binder \
--- all bound functions are deferred
return function(name: string)
	if not Hooks[name] then
		Hooks[name] = {
			_functions = {};
			_onces = {};
			_yields = {};
		}
		local hook = Hooks[name]

		--- recursively resumes yielded threads
		local function resume(...: any)
			local co = table.remove(hook._yields)
			if co then
				task.defer(co, ...)
				resume(...)
			else
				return
			end
		end

		--- recursively removes-then-defers functions bound by hook.once()
		local function onces(...: any)
			local f = table.remove(hook._onces)
			if f then
				task.defer(f, ...)
				onces(...)
			else
				return
			end
		end

		--- connects function to this hook
		hook.connect = function(f: (...any) -> ())
			table.insert(hook._functions, f)

			return function()
				table.remove(hook._functions, table.find(hook._functions, f) or 0)
			end
		end
		--- connects function to this hook to be fired once
		hook.once = function(f: (...any) -> ())
			table.insert(hook._onces, f)

			return function()
				table.remove(hook._onces, table.find(hook._onces, f) or 0)
			end
		end
		--- yields thread until this hook is fired
		hook.wait = function()
			table.insert(hook._yields, coroutine.running())

			return coroutine.yield()
		end
		--- calls functions bound to this hook along with any arguments passed
		hook.fire = function(...: any)
			for _, f in hook._functions do
				task.defer(f, ...)
			end
			
			onces(...)
			resume(...)
		end
		--- disconnects all functions bound to this hook
		hook.disconnectall = function()
			table.clear(hook._functions)
			table.clear(hook._onces)
		end
		--- destroys this hook, resuming any yielded threads prior to destruction
		hook.destroy = function(...: any)
			resume(...)

			table.clear(hook._functions)
			table.clear(hook._onces)
			
			table.clear(hook)
			Hooks[name] = nil
		end
	end

	return Hooks[name]
end