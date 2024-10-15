--!strict

local TweenService = game:GetService("TweenService")

--- ### Tween.luau
---
--- TweenService wrapper
return function(object: Instance, properties: {[string]: any}, time: number, ...)
	TweenService:Create(object, TweenInfo.new(time, ...), properties):Play()
end