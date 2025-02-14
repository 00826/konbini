--!strict
--!native
--!optimize 2

--- ### CFrame.luau
---
--- extension of CFrame library
local CFrameK = {
	--- returns `CFrame.fromOrientation(v.X, v.Y, v.Z)`
	anglesfromvector = function(v: Vector3)
		return CFrame.fromOrientation(v.X, v.Y, v.Z)
	end;
	--- returns `Vector3.new(c:ToOrientation())`
	vectorfromangles = function(c: CFrame)
		return Vector3.new(c:ToOrientation())
	end;
}

--- applies selected axis from copyfrom to target \
--- if no axis is passed, then all rotational components will be applied
function CFrameK.applyaxis(target: CFrame | Vector3, copyfrom: CFrame, axis: Enum.Axis?)
	if not axis then
		return CFrame.new(target.X, target.Y, target.Z, select(4, copyfrom:GetComponents()))
	end

	local x, y, z = copyfrom:ToOrientation()
	local cframe = CFrame.new(target.X, target.Y, target.Z)

	return axis == Enum.Axis.X and cframe * CFrame.Angles(x, 0, 0)
		or axis == Enum.Axis.Y and cframe * CFrame.Angles(0, y, 0)
		or axis == Enum.Axis.Z and cframe * CFrame.Angles(0, 0, z)
		or CFrame.identity
end

--- returns cframe rotated towards lookvector at uniform rate within `[0, 1]`
function CFrameK.rotatetolookvector(cframe: CFrame, lookvector: Vector3, rate: number)
	local angle = cframe.LookVector:Angle(lookvector)
	
	if angle < 5e-7 then
		return cframe
	elseif angle > math.pi - 5e-7 then
		return cframe * CFrame.Angles(0, math.pi * rate, 0)
	else
		local axis = cframe.LookVector:Cross(lookvector)
		return CFrame.fromAxisAngle(axis, angle * rate) * cframe.Rotation + cframe.Position
	end
end

--- affixes numeric or vector3 volume to cframe; equvalent to: \
--- `number`: `cframe * CFrame.new(0, 0, volume * 0.5)` \
--- `Vector3`: `cframe * CFrame.new(0, 0, volume.Z * 0.5)`
function CFrameK.affix(cframe: CFrame, volume: number|Vector3, axis: Vector3)
	if type(volume) == "number" then 
		return cframe * CFrame.new(0, 0, volume * 0.5)
	else
		volume *= axis * 0.5
		return cframe * CFrame.new(volume)
	end
end

return table.freeze(CFrameK)