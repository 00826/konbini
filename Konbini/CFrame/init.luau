--!strict
--!native
--!optimize 2

--- ### CFrame.luau
---
--- CFrame convenience module
local CFrameK = {
	angles = table.freeze{
		x = table.freeze{
			pi = CFrame.Angles(math.pi, 0, 0);
			pi2 = CFrame.Angles(math.pi/2, 0, 0);
			pi4 = CFrame.Angles(math.pi/4, 0, 0);
			_pi = CFrame.Angles(-math.pi, 0, 0);
			_pi2 = CFrame.Angles(-math.pi/2, 0, 0);
			_pi4 = CFrame.Angles(-math.pi/4, 0, 0);
		};
		y = table.freeze{
			pi = CFrame.Angles(0, math.pi, 0);
			pi2 = CFrame.Angles(0, math.pi/2, 0);
			pi4 = CFrame.Angles(0, math.pi/4, 0);
			_pi = CFrame.Angles(0, -math.pi, 0);
			_pi2 = CFrame.Angles(0, -math.pi/2, 0);
			_pi4 = CFrame.Angles(0, -math.pi/4, 0);
		};
		z = table.freeze{
			pi = CFrame.Angles(0, 0, math.pi);
			pi2 = CFrame.Angles(0, 0, math.pi/2);
			pi4 = CFrame.Angles(0, 0, math.pi/4);
			_pi = CFrame.Angles(0, 0, -math.pi);
			_pi2 = CFrame.Angles(0, 0, -math.pi/2);
			_pi4 = CFrame.Angles(0, 0, -math.pi/4);
		};
	};
	--- returns `CFrame.fromEulerAngles(v.X, v.Y, v.Z, Enum.RotationOrder.XYZ)`
	anglesFromVector = function(v: Vector3)
		return CFrame.fromEulerAngles(v.X, v.Y, v.Z, Enum.RotationOrder.XYZ)
	end;
	--- returns `Vector3.new(c:ToEulerAngles(Enum.RotationOrder.XYZ))`
	vectorFromAngles = function(c: CFrame)
		return Vector3.new(c:ToEulerAngles(Enum.RotationOrder.XYZ))
	end;
}

--- applies selected axis from copyfrom to target \
--- if no axis is passed, then all rotational components will be applied
function CFrameK.applyaxis(target: CFrame | Vector3, copyfrom: CFrame, axis: Enum.Axis?): CFrame
	if not axis then
		return CFrame.new(target.X, target.Y, target.Z, select(4, copyfrom:GetComponents()))
	end

	local X, Y, Z = copyfrom:ToOrientation()
	local C0 = CFrame.new(target.X, target.Y, target.Z)

	return axis == Enum.Axis.X and C0 * CFrame.Angles(X, 0, 0)
		or axis == Enum.Axis.Y and C0 * CFrame.Angles(0, Y, 0)
		or axis == Enum.Axis.Z and C0 * CFrame.Angles(0, 0, Z)
		or CFrame.identity
end

--- returns cframe rotated towards lookvector at uniform rate within `[0, 1]`
function CFrameK.matchlookvector(cframe: CFrame, lookvector: Vector3, rate: number): CFrame
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

return table.freeze(CFrameK)