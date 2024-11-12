--- ### Keyframe.luau
---
--- tweening with fps control and more tweenable data types

local types = require(script.Parent.types)

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Bucket = {}

local Tweenable = table.freeze{
	"number";
	"boolean";
	"vector";

	"CFrame";
	"Color3";
	"ColorSequence";
	"EnumItem";
	"NumberRange";
	"NumberSequence";
	"UDim";
	"UDim2";
}

---@native
local function istweenable<T>(a: T): boolean
	local h, k = type(a), typeof(a)
	for _, t in Tweenable do
		if h == t then
			return true
		elseif k == t then
			return true
		end
	end
	return false
end

---@native
local function lerp(initial: number, goal: number, a: number)
	return (1 - a) * initial + a * goal
end

local function lerpcolorsequencekeypoint(initial: ColorSequenceKeypoint, goal: ColorSequenceKeypoint, a: number)
	return ColorSequenceKeypoint.new(lerp(initial.Time, goal.Time, a), initial.Value:Lerp(goal.Value, a))
end

local function lerpnumbersequencekeypoint(initial: NumberSequenceKeypoint, goal: NumberSequenceKeypoint, a: number)
	return NumberSequenceKeypoint.new(lerp(initial.Time, goal.Time, a), lerp(initial.Value, goal.Value, a), lerp(initial.Envelope, goal.Envelope, a))
end

local function getvalue(initial: any, goal: any, a: number, style: Enum.EasingStyle, direction: Enum.EasingDirection): any
	a = TweenService:GetValue(a, style, direction)

	local h, k = type(initial), typeof(initial)

	if h == "number" then
		return lerp(initial, goal, a)
	elseif h == "boolean" then
		if (initial == goal) then
			return goal
		elseif (initial == true) and (goal == false) then
			return a < 1
		elseif (initial == false) and (goal == true) then
			return a >= 1
		end
	elseif h == "vector" then
		return initial:Lerp(goal, a)
	elseif k == "CFrame" then
		return initial:Lerp(goal, a)
	elseif k == "Color3" then
		return initial:Lerp(goal, a)
	elseif k == "ColorSequence" then
		local keys0 = initial.Keypoints
		local keys1 = goal.Keypoints :: {ColorSequenceKeypoint}

		local len = #keys0
		assert(len == #keys1, "initial and goal ColorSequences must have the same # of ColorSequenceKeypoints")

		local sequencekeys = table.create(len)
		for i, csk in ipairs(keys0) do
			sequencekeys[i] = lerpcolorsequencekeypoint(csk, keys1[i], a)
		end

		return ColorSequence.new(sequencekeys)
	elseif k == "EnumItem" then
		return a < 1 and initial or goal
	elseif k == "NumberRange" then
		return NumberRange.new(lerp(initial.Min, goal.Min, a), lerp(initial.Max, goal.Max, a))
	elseif k == "NumberSequence" then
		local keys0 = initial.Keypoints
		local keys1 = goal.Keypoints :: {NumberSequenceKeypoint}

		local len = #keys0
		assert(len == #keys1, "initial and goal NumberSequences must have the same # of NumberSequenceKeypoints")

		local sequencekeys = table.create(len)
		for i, nsk in ipairs(keys0) do
			sequencekeys[i] = lerpnumbersequencekeypoint(nsk, keys1[i], a)
		end

		return NumberSequence.new(sequencekeys)
	elseif k == "UDim" then
		return UDim.new(lerp(initial.Scale, goal.Scale, a), lerp(initial.Offset, goal.Offset, a))
	elseif k == "UDim2" then
		return initial:Lerp(goal, a)
	end

	error(`untweenable property (this should not happen) type({h}) typeof({k})`)
end

local function interpolate(object: Instance, keyframeinfo: types.KeyframeInfo, dt: number)
	local framerate = keyframeinfo.Framerate
	keyframeinfo.Framerule += dt
	keyframeinfo.Elapsed += dt
	if keyframeinfo.Framerule < framerate then return end
	keyframeinfo.Framerule -= framerate

	local a = math.clamp(keyframeinfo.Elapsed / keyframeinfo.Time, 0, 1)
	local style = keyframeinfo.Style
	local direction = keyframeinfo.Direction

	for property, initial in keyframeinfo.Initial do
		local goal = keyframeinfo.Goal[property]
		local value = getvalue(initial, goal, a, style, direction)
		if value ~= nil then
			(object::any)[property] = value
		end
	end

	if a >= 1 then
		table.clear(Bucket[object] or table.create(0))
		Bucket[object] = nil

		if keyframeinfo.Destruct then
			task.delay(keyframeinfo.Destruct, function()
				object:Destroy()
			end)
		end
	end
end

RunService.Heartbeat:Connect(function(dt)
	for object, keyframeinfo in Bucket do
		if keyframeinfo.IsPaused then continue end
		task.defer(interpolate, object, keyframeinfo, dt)
	end
end)

--- transforms properties of object toward goal with respect to framerate \
--- `time(?=1)`: seconds for keyframes to complete \
--- `style(?=Enum.EasingDirection.Linear)`: effect easingstyle \
--- `direction(?=Enum.EasingDirection.Out)`: effect easingdirection \
--- `framerate(?=1/60)`: effect framerate \
--- `destruct(?=nil)`: destroy object `n` seconds after effect completion \
--- all transformations are deferred \
--- \
--- returns a mutable `KeyframeInfo` table for convenience
return function(object: Instance, goal: {[string]: types.KeyframeType}, time: number?, style: Enum.EasingStyle?, direction: Enum.EasingDirection?, framerate: number?, destruct: number?): types.KeyframeInfo
	if Bucket[object] then
		Bucket[object] = nil
	end

	local keyframeinfo = {
		Framerate = framerate or 1/60;
		Framerule = 0;

		Time = time or 1;
		Elapsed = 0;
		IsPaused = false;

		Style = style or Enum.EasingStyle.Linear;
		Direction = direction or Enum.EasingDirection.Out;

		Initial = {};
		Goal = table.clone(goal);
		Destruct = destruct;
	}

	keyframeinfo.Reset = function()
		keyframeinfo.Elapsed = 0
	end;
	keyframeinfo.Pause = function()
		keyframeinfo.IsPaused = true
	end;
	keyframeinfo.Resume = function()
		for property in goal do
			keyframeinfo.Initial[property] = (object::any)[property]
		end
		keyframeinfo.IsPaused = false
	end;
	keyframeinfo.Stop = function()
		table.clear(Bucket[object] or table.create(0))
		Bucket[object] = nil
	end;

	for property, value in goal do
		if istweenable(value) then
			keyframeinfo.Initial[property] = (object::any)[property]
		else
			warn(`skipping untweenable property "{property}" type({type(value)}) typeof({typeof(value)})`)
		end
	end

	Bucket[object] = keyframeinfo

	return keyframeinfo
end