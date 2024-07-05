--!strict

local TweenService				= game:GetService("TweenService")

--- ### Tween.luau
---
--- TweenService wrapper
return function(Object: Instance, Properties: {[string]: any}, Time: number, ...)
	TweenService:Create(Object, TweenInfo.new(Time, ...), Properties):Play()
end