--!strict

local types = require(script.Parent.types)

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

@native
local function fastdistance(a: Vector3, b: Vector3): number
	b -= a
	local x, y, z = b.X, b.Y, b.Z
	return ((x * x) + (y * y) + (z * z)) ^ 0.5
end

--- ### Collisions.luau
---
--- collision solver and spatial query wrapper
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
function Collisions.quickcast(at: Vector3, distance: number, search: {Model}): {Model}
	local found = table.create(#search)
	for _, Model in search do
		local cframe, size = Model:GetBoundingBox()
		size *= 0.5

		if fastdistance(at, cframe.Position) <= (math.max(size.X, size.Y, size.Z) + distance) then
			table.insert(found, Model)
		end
	end

	return found
end

--- non-cancollide-safe BasePart:GetTouchingParts()
function Collisions.collide(part: BasePart): {BasePart}
	local c = part.Touched:Connect(function() end)
	local t = part:GetTouchingParts()
	c:Disconnect()
	return t
end

--- `workspace:GetPartBoundsInBox()`
function Collisions.box(listtype: types.CastList, search: {Instance}, at: CFrame, size: Vector3): {BasePart}
	local overlap = (listtype == "Whitelist" and OverlapWhite) or (listtype == "Blacklist" and OverlapBlack)
	assert(typeof(overlap) == "OverlapParams")
	overlap.FilterDescendantsInstances = search

	return workspace:GetPartBoundsInBox(at, size, overlap)
end

--- `workspace:GetPartBoundsInRadius()`
function Collisions.ball(listtype: types.CastList, search: {Instance}, at: Vector3, radius: number): {BasePart}
	local overlap = (listtype == "Whitelist" and OverlapWhite) or (listtype == "Blacklist" and OverlapBlack)
	assert(typeof(overlap) == "OverlapParams")
	overlap.FilterDescendantsInstances = search

	return workspace:GetPartBoundsInRadius(at, radius, overlap)
end

--- returns: \
--- `distance`: units between `at` and its nearest point on `target` \
--- `radians`: angle between the cone cast with `at & look` against `target` \
--- `position`: nearest point on target towards its position on cone
function Collisions.cone(at: Vector3, look: Vector3, target: MeshPart): (number, number, Vector3)
	local point = target:GetClosestPointOnSurface(at)
	local distance = fastdistance(at, point)
	return distance, look:Angle((point - at).Unit), point
end

--- `workspace:RaycastWhitelist()` \
--- `collisiongroup (?="Default")`
function Collisions.raywhitelist(at: Vector3, direction: Vector3, whitelist: {Instance}, collisiongroup: string?): RaycastResult
	WhitelistParams.FilterDescendantsInstances = whitelist
	WhitelistParams.CollisionGroup = collisiongroup  or "Default"
	return workspace:Raycast(at, direction, WhitelistParams)
end

--- `workspace:RaycastBlacklist()` \
--- `collisiongroup (?="Default")`
function Collisions.rayblacklist(at: Vector3, direction: Vector3, blacklist: {Instance}, collisiongroup: string?): RaycastResult
	BlacklistParams.FilterDescendantsInstances = blacklist
	WhitelistParams.CollisionGroup = collisiongroup  or "Default"
	return workspace:Raycast(at, direction, BlacklistParams)
end

--- `workspace:Fancast()` \
--- `resolution (?=3, minimum)`: # of rays that the fancast is composed of \
--- `collisiongroup (?="Default")`
function Collisions.fancast(listtype: types.CastList, at: Vector3, direction: Vector3, radians: number, search: {Instance}, resolution: number?, collisiongroup: string?): {RaycastResult}
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
			result = Collisions.raywhitelist(at, real.LookVector * distance, search, collisiongroup)
		elseif listtype == "Blacklist" then
			result = Collisions.rayblacklist(at, real.LookVector * distance, search, collisiongroup)
		end

		if result then
			if table.find(bucket, result.Instance) then continue end
			table.insert(bucket, result.Instance)
			table.insert(results, result)
		end
	end

	return results
end

--- returns true if point is within bounds of box defined by cframe and size
@native
function Collisions.ispointinbox(point: Vector3, cframe: CFrame, size: Vector3)
	local absoluteobjectspace = cframe:PointToObjectSpace(point):Abs()
	size *= 0.5

	return
		(absoluteobjectspace.X <= size.X) and
		(absoluteobjectspace.Y <= size.Y) and
		(absoluteobjectspace.Z <= size.Z)
end

--- returns true if point is within bounds of radius defined by position and radius
function Collisions.ispointinradius(point: Vector3, position: Vector3, radius: number)
	return fastdistance(point, position) <= radius
end

return Collisions