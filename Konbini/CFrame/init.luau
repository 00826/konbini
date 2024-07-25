--!strict
--!native
--!optimize 2

local types						= require(script.Parent.types)

local DefaultR					= Random.new()

--- ### CFrame.luau
---
--- CFrame convenience module
local K_CFrame = {
	RX90						= CFrame.Angles(math.rad(90), 0, 0);
	RY90						= CFrame.Angles(0, math.rad(90), 0);
	RZ90						= CFrame.Angles(0, 0, math.rad(90));

	RXn90						= CFrame.Angles(-math.rad(90), 0, 0);
	RYn90						= CFrame.Angles(0, -math.rad(90), 0);
	RZn90						= CFrame.Angles(0, 0, -math.rad(90));

	RX180						= CFrame.Angles(math.pi, 0, 0);
	RY180						= CFrame.Angles(0, math.pi, 0);
	RZ180						= CFrame.Angles(0, 0, math.pi);

	RXn180						= CFrame.Angles(-math.pi, 0, 0);
	RYn180						= CFrame.Angles(0, -math.pi, 0);
	RZn180						= CFrame.Angles(0, 0, -math.pi);
}

--- applies selected axis from copyfrom to target \
--- if no axis is passed, then all rotational components will be applied
function K_CFrame.applyaxis(target: CFrame | Vector3, copyfrom: CFrame, axis: types.xyzAxis?): CFrame
	if not axis then
		return CFrame.new(target.X, target.Y, target.Z, select(4, copyfrom:GetComponents()))
	end

	local X, Y, Z = copyfrom:ToOrientation()
	local C0 = CFrame.new(target.X, target.Y, target.Z)

	return axis == "X" and C0 * CFrame.Angles(X, 0, 0)
		or axis == "Y" and C0 * CFrame.Angles(0, Y, 0)
		or axis == "Z" and C0 * CFrame.Angles(0, 0, Z)
		or CFrame.identity
end

--- returns true if point is within volume defined by cframe and size
function K_CFrame.ispointinvolume(point: Vector3, volumecframe: CFrame, volumesize: Vector3): boolean
	local ObjectSpace = volumecframe:PointToObjectSpace(point)
	volumesize *= 0.5

	return
		(math.abs(ObjectSpace.X) <= volumesize.X) and
		(math.abs(ObjectSpace.Y) <= volumesize.Y) and
		(math.abs(ObjectSpace.Z) <= volumesize.Z)
end

--- returns true if point is within volume defined by cframe and size
function K_CFrame.ispointinvolumeXZ(point: Vector3, volumecframe: CFrame, volumesize: Vector3): boolean
	local ObjectSpace = volumecframe:PointToObjectSpace(point)
	volumesize *= 0.5

	return
		(math.abs(ObjectSpace.X) <= volumesize.X) and
		(math.abs(ObjectSpace.Z) <= volumesize.Z)
end

--- returns nearest point, towards worldpoint, from cube defined by cframe and size
function K_CFrame.nearestpoint(worldpoint: Vector3, cframe: CFrame, size: Vector3): Vector3
	local ObjectSpace = cframe:PointToObjectSpace(worldpoint)
	size *= 0.5

	local X, Y, Z = size.X, size.Y, size.Z
	return cframe * Vector3.new(
		math.clamp(ObjectSpace.X, -X, X),
		math.clamp(ObjectSpace.Y, -Y, Y),
		math.clamp(ObjectSpace.Z, -Z, Z)
	)
end

--- returns random pivot in volume
function K_CFrame.randompivotinvolume(volumecframe: CFrame, volumesize: Vector3, R: Random?): CFrame
	if not R then R = DefaultR end
	local SHalf = volumesize * 0.5
	local X, Y, Z = SHalf.X, SHalf.Y, SHalf.Z
	return R and volumecframe * CFrame.new(
		R:NextNumber(-X, X),
		R:NextNumber(-Y, Y),
		R:NextNumber(-Z, Z)
	) or volumecframe
end

return table.freeze(K_CFrame)