--!strict

local Time						= require(script.Parent.Time)

--- ### Debounce.luau
---
--- returns true if debounce passed, returns false if not passed
return function(target: Instance, name: string, time: number): boolean
	local Now, Until = Time(), target:GetAttribute("_Debounce_" .. name) or 0
	if Until > Now then return false end
	target:SetAttribute("_Debounce_" .. name, Now + time)
	return true
end