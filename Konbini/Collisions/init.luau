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

local f = function() end
local FancastResolution = 10

local function Tween(object: Instance, properties: {[string]: any}, time: number, ...)
	TweenService:Create(object, TweenInfo.new(time, ...), properties):Play()
end

local function ChoreographOut(C: any, properties: {[string]: any})
	Tween(C.Outer, properties, 0.1)
	task.wait(0.1)
	C:Destroy()
end

---@native
local function FastDistance(point0: Vector3, point1: Vector3): number
	point1 -= point0
	local x, y, z = point1.X, point1.Y, point1.Z
	return ((x * x) + (y * y) + (z * z)) ^ 0.5
end

--- ### Collisions.luau
---
--- collision solver
--- avoids using OverlapParams.new() spam when raycasting/shapecasting \
--- wraps GetPartBoundsInBox/GetPartBoundsInRadius/GetPartsInPart into a single function
local Collisions = {}

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
function Collisions.quickcast(origin: Vector3, distance: number, search: {Model}): {Model}
	local found = table.create(#search)
	for _, Model in search do
		local C0, Size = Model:GetBoundingBox()
		Size *= 0.5

		if FastDistance(origin, C0.Position) <= (math.max(Size.X, Size.Y, Size.Z) + distance) then
			table.insert(found, Model)
		end
	end

	return found
end

--- non-cancollide-safe BasePart:GetTouchingParts()
function Collisions.collide(part: BasePart): {BasePart}
	local C = part.Touched:Connect(f)
	local T = part:GetTouchingParts()
	C:Disconnect()
	return T
end

--- all-in-one `workspace:GetPartBoundsInBox()`, `workspace:GetPartBoundsInRadius()`
function Collisions.cast(castshape: types.CastShape, listtype: types.CastList, search: {Instance}, cframevector: CFrame|Vector3, sizeradius: Vector3|number): {BasePart}
	local Overlap = (listtype == "Whitelist" and OverlapWhite) or (listtype == "Blacklist" and OverlapBlack)
	assert(typeof(Overlap) == "OverlapParams")
	Overlap.FilterDescendantsInstances = search

	if castshape == "Box" then
		return workspace:GetPartBoundsInBox(cframevector, sizeradius, Overlap)
	elseif castshape == "Ball" then
		return workspace:GetPartBoundsInRadius(cframevector, sizeradius, Overlap)
	else
		warn(`invalid shape {castshape}`)
	end

	return table.create(0)
end

--- casts a whitelist raycast at origin towards direction
function Collisions.raywhitelist(origin: Vector3, direction: Vector3, whitelist: {Instance}): RaycastResult
	WhitelistParams.FilterDescendantsInstances = whitelist
	return workspace:Raycast(origin, direction, WhitelistParams)
end

--- casts a blacklist raycast at origin towards direction
function Collisions.rayblacklist(origin: Vector3, direction: Vector3, blacklist: {Instance}): RaycastResult
	BlacklistParams.FilterDescendantsInstances = blacklist
	return workspace:Raycast(origin, direction, BlacklistParams)
end

--- fancasts at origin towards direction
function Collisions.fancast(origin: Vector3, direction: Vector3, angle: number, search: {Instance}, isblacklist: boolean?): {RaycastResult}
	local Step = (math.rad(angle * 0.5)) / FancastResolution
	local Distance = direction.Magnitude
	local C0 = CFrame.lookAt(origin, origin + direction.Unit)

	local Parts, Results = table.create(FancastResolution), table.create(FancastResolution * 2)

	local function Fan(n: number)
		local Look0 = (C0 * CFrame.Angles(0, n * Step, 0)).LookVector

		local RaycastResult: RaycastResult = isblacklist and Collisions.rayblacklist(origin, Look0 * Distance, search) or Collisions.raywhitelist(origin, Look0 * Distance, search)

		if RaycastResult then
			if table.find(Parts, RaycastResult.Instance) then return end
			table.insert(Parts, RaycastResult.Instance)
			table.insert(Results, RaycastResult)
		end
	end

	for i = 0, FancastResolution, 1 do
		Fan(i)
		if i == 0 then continue end --- skip doing 0th raycast twice
		Fan(-i)
	end

	return Results
end

--- choreographs a box-shaped hitbox
function Collisions.choreographBox(at: Vector3, towards: Vector3, size: Vector3, time: number): typeof(Choreographs.Box)
	local thisbox = Choreographs.Box:Clone()
	thisbox.CFrame = CFrame.lookAt(at, towards)
	thisbox.Parent = workspace

	thisbox.Inner.Size = size
	thisbox.Outer.Size = size

	Tween(thisbox.Inner, {Size = Vector3.zero, Visible = false}, time)

	task.delay(time, ChoreographOut, thisbox, {Size = Vector3.zero, Visible = false})

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

	task.delay(time, ChoreographOut, thisplane, {Size = 2 * Vector3.yAxis, Visible = false})

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

	task.delay(time, ChoreographOut, thisradius, {Radius = 0, Visible = false})

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

	task.delay(time, ChoreographOut, thisball, {Radius = 0, Visible = false})

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

	task.delay(time, ChoreographOut, thisbeam, {Radius = 0, Visible = false})

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

	task.delay(time, ChoreographOut, thiscone, {Radius = 0, Visible = false})

	return thiscone
end

return Collisions