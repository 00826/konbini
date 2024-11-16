--!strict

--- ### await.luau
---
--- `task.await()` \
--- returns: \
--- ... itself for `.thendo()` chaining \
--- ... boolean describing success or failure state of `f()` \
--- \
--- *function `f` must always return a boolean to demonstrate function completion*
local function await(timeout: number, f: () -> boolean, catch: ((traceback: string, message: string) -> ())?)
	local t = {
		_timeout = timeout;
		_function = f;

		thendo = await;
	}

	local _, initial = pcall(f)
	if initial ~= true then
		local success, result = false, nil
		repeat t._timeout -= task.wait()
			success, result = pcall(f)
		until (result == true) or (success == false) or (t._timeout < 0)

		if result == true then
			return t, result
		elseif not success then
			if catch then
				catch(debug.traceback(), tostring(result)) --- questionable
			end

			return t, false
		elseif t._timeout < 0 then
			if catch then
				catch(debug.traceback(), "await timeout exhausted")
			else
				warn("await timeout exhausted")
			end

			return t, false
		end
	end

	return t, initial
end

return await