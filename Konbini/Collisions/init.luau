--!strict

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

--- ### Collisions.luau
---
--- collision solver and spatial query wrapper
local Collisions = {}

--- `workspace:GetPartBoundsInBox()`
function Collisions.box(type: "Whitelist" | "Blacklist", search: {Instance}, at: CFrame, size: Vector3)
	local overlap:any = (type == "Whitelist" and OverlapWhite) or (type == "Blacklist" and OverlapBlack)
	overlap.FilterDescendantsInstances = search

	return workspace:GetPartBoundsInBox(at, size, overlap)
end

--- `workspace:GetPartBoundsInRadius()`
function Collisions.ball(type: "Whitelist" | "Blacklist", search: {Instance}, at: Vector3, radius: number)
	local overlap:any = (type == "Whitelist" and OverlapWhite) or (type == "Blacklist" and OverlapBlack)
	overlap.FilterDescendantsInstances = search

	return workspace:GetPartBoundsInRadius(at, radius, overlap)
end

--- `workspace:Raycast()` against `search` list & `collisiongroup (?="Default")`
function Collisions.raycast(type: "Whitelist" | "Blacklist", at: Vector3, direction: Vector3, search: {Instance}, collisiongroup: string?)
	local list:any = (type == "Whitelist" and WhitelistParams) or (type == "Blacklist" and BlacklistParams)
	list.FilterDescendantsInstances = search
	list.CollisionGroup = collisiongroup or "Default"

	return workspace:Raycast(at, direction, list)
end

--- `workspace:Fancast()` with `resolution (?=3, minimum)` casts against `search` list & `collisiongroup (?="Default")`
function Collisions.fancast(type: "Whitelist" | "Blacklist", at: Vector3, direction: Vector3, radians: number, search: {Instance}, resolution: number?, collisiongroup: string?)
	resolution = math.clamp(resolution or 3, 3, math.huge)
	assert(resolution)

	local bucket = table.create(resolution)
	local results = table.create(resolution)

	local distance = direction.Magnitude
	local step = radians / (resolution - 1)
	local pivot = CFrame.new(at, at + direction) * CFrame.Angles(0, -0.5 * radians, 0)

	for i = 1, resolution do
		local real = pivot * CFrame.Angles(0, (i - 1) * step, 0)

		local result: RaycastResult? = Collisions.raycast(type, at, real.LookVector * distance, search, collisiongroup)

		if result then
			if table.find(bucket, result.Instance) then continue end
			table.insert(bucket, result.Instance)
			table.insert(results, result)
		end
	end

	return results
end

return Collisions