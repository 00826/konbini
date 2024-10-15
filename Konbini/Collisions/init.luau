--!strict

local types = require(script.Parent.types)

local TweenService = game:GetService("TweenService")

local Choreographs = script:WaitForChild("C")

local WhitelistParams = RaycastParams.new()
WhitelistParams.FilterType = Enum.RaycastFilterType.Include
WhitelistParams.IgnoreWater = true

local BlacklistParams = RaycastParams.new()
BlacklistParams.FilterType = Enum.RaycastFilterType.Exclude
BlacklistParams.IgnoreWater = true

local OverlapWhite = OverlapParams.new()
OverlapWhite.FilterType = Enum.RaycastFilterType.Include
OverlapWhite.RespectCanCollide = false

local OverlapBlack = OverlapParams.new()
OverlapBlack.FilterType = Enum.RaycastFilterType.Exclude
OverlapBlack.RespectCanCollide = false

local function Tween(object: Instance, properties: {[string]: any}, time: number, ...)
	TweenService:Create(object, TweenInfo.new(time, ...), properties):Play()
end

---@native
local function FastDistance(point0: Vector3, point1: Vector3): number
	point1 -= point0
	local x, y, z = point1.X, point1.Y, point1.Z
	return ((x * x) + (y * y) + (z * z)) ^ 0.5
end

--- ### Collisions.luau
---
--- collision solver and spatial query wrapper
local Collisions = {
	choreographtime = 1/15;
}

--- sets collision group of baseparts under model
function Collisions.setmodelcollisiongroup(model: Model, collisiongroup: string)
	for _, Part in model:GetDescendants() do
		if Part:IsA("Part") then
			Part.CollisionGroup = collisiongroup
		elseif Part:IsA("MeshPart") then
			Part.CollisionGroup = collisiongroup
		end
	end
end

--- simulates raycast against models with theoretical furthest possible raycast
function Collisions.quickcast(at: Vector3, distance: number, search: {Model}): {Model}
	local found = table.create(#search)
	for _, Model in search do
		local C0, Size = Model:GetBoundingBox()
		Size *= 0.5

		if FastDistance(at, C0.Position) <= (math.max(Size.X, Size.Y, Size.Z) + distance) then
			table.insert(found, Model)
		end
	end

	return found
end

--- non-cancollide-safe BasePart:GetTouchingParts()
function Collisions.collide(part: BasePart): {BasePart}
	local C = part.Touched:Connect(function() end)
	local T = part:GetTouchingParts()
	C:Disconnect()
	return T
end

--- `workspace:GetPartBoundsInBox()`
function Collisions.box(listtype: types.CastList, search: {Instance}, at: CFrame, size: Vector3): {BasePart}
	local Overlap = (listtype == "Whitelist" and OverlapWhite) or (listtype == "Blacklist" and OverlapBlack)
	assert(typeof(Overlap) == "OverlapParams")
	Overlap.FilterDescendantsInstances = search

	return workspace:GetPartBoundsInBox(at, size, Overlap)
end

--- `workspace:GetPartBoundsInRadius()`
function Collisions.ball(listtype: types.CastList, search: {Instance}, at: Vector3, radius: number): {BasePart}
	local Overlap = (listtype == "Whitelist" and OverlapWhite) or (listtype == "Blacklist" and OverlapBlack)
	assert(typeof(Overlap) == "OverlapParams")
	Overlap.FilterDescendantsInstances = search

	return workspace:GetPartBoundsInRadius(at, radius, Overlap)
end

--- returns: \
--- `distance`: units between `at` and its nearest point on `target` \
--- `radians`: angle between the cone cast with `at & look` against `target` \
--- `position`: nearest point on target towards its position on cone
function Collisions.cone(at: Vector3, look: Vector3, target: MeshPart): (number, number, Vector3)
	local distance = FastDistance(at, target:GetClosestPointOnSurface(at))
	local pivot = at + (look * distance)
	local point = target:GetClosestPointOnSurface(pivot)
	return distance, look:Angle((point - at).Unit), point

	--faster, but less accurate against larger target sizes.
	--hard-coding to swap depending on target mass is out-of-scope (hypocritical)
	--[[local distance = FastDistance(at, target.Position)
	local pivot = at + (look * distance)
	return distance, look:Angle((target:GetClosestPointOnSurface(pivot) - at).Unit)]]
end

--- `workspace:RaycastWhitelist()`
function Collisions.raywhitelist(at: Vector3, direction: Vector3, whitelist: {Instance}): RaycastResult
	WhitelistParams.FilterDescendantsInstances = whitelist
	return workspace:Raycast(at, direction, WhitelistParams)
end

--- `workspace:RaycastBlacklist()`
function Collisions.rayblacklist(at: Vector3, direction: Vector3, blacklist: {Instance}): RaycastResult
	BlacklistParams.FilterDescendantsInstances = blacklist
	return workspace:Raycast(at, direction, BlacklistParams)
end

--- `workspace:Fancast()` \
--- `resolution (?=3, minimum)`: # of rays that the fancast is composed of
function Collisions.fancast(listtype: types.CastList, at: Vector3, direction: Vector3, radians: number, search: {Instance}, resolution: number?): {RaycastResult}
	resolution = math.clamp(resolution or 3, 3, math.huge)
	assert(resolution)

	local bucket = table.create(resolution)
	local results = table.create(resolution)

	local distance = direction.Magnitude
	local step = radians / (resolution - 1)
	local pivot = CFrame.new(at, at + direction) * CFrame.Angles(0, -0.5 * radians, 0)

	for i = 1, resolution do
		local real = pivot * CFrame.Angles(0, (i - 1) * step, 0)

		local result: RaycastResult? = nil
		if listtype == "Whitelist" then
			result = Collisions.raywhitelist(at, real.LookVector * distance, search)
		elseif listtype == "Blacklist" then
			result = Collisions.rayblacklist(at, real.LookVector * distance, search)
		end

		--- Collisions.choreographRay(at, real.LookVector * distance, result)

		if result then
			if table.find(bucket, result.Instance) then continue end
			table.insert(bucket, result.Instance)
			table.insert(results, result)
		end
	end

	return results
end

--- choreographs a box-shaped hitbox
function Collisions.choreographBox(at: Vector3, towards: Vector3, size: Vector3, time: number): typeof(Choreographs.Box)
	local thisbox = Choreographs.Box:Clone()
	thisbox.CFrame = CFrame.lookAt(at, towards)
	thisbox.Parent = workspace

	thisbox.Inner.Size = size
	thisbox.Outer.Size = size

	Tween(thisbox.Inner, {Size = Vector3.zero, Visible = false}, time)

	task.delay(time, Collisions.choreographOut, thisbox, {Size = Vector3.zero, Visible = false})

	return thisbox
end

--- choreographs a planar hitbox
function Collisions.choreographPlane(at: Vector3, towards: Vector3, size: Vector3, time: number): typeof(Choreographs.Plane)
	local thisplane = Choreographs.Plane:Clone()
	thisplane.CFrame = CFrame.lookAt(at, towards)
	thisplane.Parent = workspace

	local realsize = Vector3.new(size.X, 2, size.Z)
	thisplane.Inner.Size = realsize
	thisplane.Outer.Size = realsize

	Tween(thisplane.Inner, {Size = 2 * Vector3.yAxis, Visible = false}, time)

	task.delay(time, Collisions.choreographOut, thisplane, {Size = 2 * Vector3.yAxis, Visible = false})

	return thisplane
end

--- choreographs a radial hitbox
function Collisions.choreographRadius(at: Vector3, radius: number, time: number): typeof(Choreographs.Radius)
	local thisradius = Choreographs.Radius:Clone()
	thisradius.Position = at
	thisradius.Parent = workspace

	thisradius.Inner.Radius = radius
	thisradius.Outer.Radius = radius

	Tween(thisradius.Inner, {Radius = 0, Visible = false}, time)

	task.delay(time, Collisions.choreographOut, thisradius, {Radius = 0, Visible = false})

	return thisradius
end

--- choreographs a ball-shaped hitbox
function Collisions.choreographBall(at: Vector3, towards: Vector3, radius: number, time: number): typeof(Choreographs.Ball)
	local thisball = Choreographs.Ball:Clone()
	thisball.CFrame = CFrame.lookAt(at, towards)
	thisball.Parent = workspace

	thisball.Inner.Radius = radius
	thisball.Outer.Radius = radius

	Tween(thisball.Inner, {Radius = 0, Visible = false}, time)

	task.delay(time, Collisions.choreographOut, thisball, {Radius = 0, Visible = false})

	return thisball
end

--- choreographs a beam-shaped hitbox
function Collisions.choreographBeam(at: Vector3, towards: Vector3, radius: number, distance: number, time: number): typeof(Choreographs.Beam)
	local thisbeam = Choreographs.Beam:Clone()
	thisbeam.CFrame = CFrame.lookAt(at, towards)
	thisbeam.Parent = workspace

	thisbeam.Inner.Height = distance
	thisbeam.Outer.Height = distance
	thisbeam.Inner.Radius = radius
	thisbeam.Outer.Radius = radius

	local cf = CFrame.new(0, 0, -distance * 0.5)
	thisbeam.Inner.CFrame = cf
	thisbeam.Outer.CFrame = cf

	Tween(thisbeam.Inner, {Radius = 0, Visible = false}, time)

	task.delay(time, Collisions.choreographOut, thisbeam, {Radius = 0, Visible = false})

	return thisbeam
end

--- choreographs a cone-shaped hitbox
function Collisions.choreographCone(at: Vector3, towards: Vector3, angle: number, distance: number, time: number): typeof(Choreographs.Cone)
	local thiscone = Choreographs.Cone:Clone()
	thiscone.CFrame = CFrame.lookAt(at, towards)
	thiscone.Parent = workspace

	thiscone.Inner.Height = distance
	thiscone.Outer.Height = distance

	local r = distance * math.tan(math.rad(angle))
	thiscone.Inner.Radius = r
	thiscone.Outer.Radius = r

	local v = Vector3.zAxis * -distance * 0.5
	thiscone.Inner.SizeRelativeOffset = v
	thiscone.Outer.SizeRelativeOffset = v

	Tween(thiscone.Inner, {Radius = 0, Visible = false}, time)

	task.delay(time, Collisions.choreographOut, thiscone, {Radius = 0, Visible = false})

	return thiscone
end

--- choreographs a raycast with respect to its (possibly nil) resultant raycastresult
function Collisions.choreographRay(origin: Vector3, direction: Vector3, result: RaycastResult?): typeof(Choreographs.Ray)
	local thisray = Choreographs.Ray:Clone()
	thisray.Parent = workspace

	thisray.A.WorldPosition = origin
	thisray.B.WorldPosition = origin + direction

	if result then
		thisray.C.Beam.Enabled = true
		thisray.C.WorldPosition = origin
		thisray.D.WorldPosition = result.Position
		Tween(thisray.C.Beam, {Width0 = 0, Enabled = false}, Collisions.choreographtime)
	else
		thisray.C.Beam.Enabled = false
	end

	Tween(thisray.A.Beam, {Width0 = 0, Enabled = false}, Collisions.choreographtime)

	task.delay(Collisions.choreographtime, function()
		thisray:Destroy()
	end)

	return thisray
end

--- applies a shrink effect against choreograph instance `C` \
--- C is destroyed after the effect is applied
function Collisions.choreographOut(C: any, properties: {[string]: any})
	Tween(C.Outer, properties, Collisions.choreographtime)
	task.wait(Collisions.choreographtime)
	C:Destroy()
end

return Collisions