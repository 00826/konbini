--!strict

local types						= require(script.Parent.types)

local WhitelistParams			= RaycastParams.new()
WhitelistParams.FilterType		= Enum.RaycastFilterType.Include
WhitelistParams.IgnoreWater		= true

local BlacklistParams			= RaycastParams.new()
BlacklistParams.FilterType		= Enum.RaycastFilterType.Exclude
BlacklistParams.IgnoreWater		= true

local OverlapWhite				= OverlapParams.new()
OverlapWhite.FilterType			= Enum.RaycastFilterType.Include
OverlapWhite.RespectCanCollide	= false

local OverlapBlack				= OverlapParams.new()
OverlapBlack.FilterType			= Enum.RaycastFilterType.Exclude
OverlapBlack.RespectCanCollide	= false

local f							= function() end
local FancastResolution			= 10

local DebugPart					= script:WaitForChild("DebugPart")

--local Vert1 = Vector3.new(1, 1, 1)
local Vert2 = Vector3.new(-1, 1, 1)
local Vert3 = Vector3.new(-1, -1, 1)
local Vert4 = Vector3.new(1, -1, 1)
--local Vert5 = Vector3.new(-1, -1, -1)
local Vert6 = Vector3.new(-1, 1, -1)
local Vert7 = Vector3.new(1, 1, -1)
local Vert8 = Vector3.new(1, -1, -1)

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
function Collisions.cast(castshape: types.CastShape, listtype: types.CastList, search: {Instance}, cframevector: CFrame|Vector3, sizeradius: Vector3|number, debugpart: boolean?): {BasePart}
	local Overlap = (listtype == "Whitelist" and OverlapWhite) or (listtype == "Blacklist" and OverlapBlack)
	assert(typeof(Overlap) == "OverlapParams")
	Overlap.FilterDescendantsInstances = search

	if castshape == "Box" then
		if debugpart then
			task.defer(Collisions.debugpart, cframevector, sizeradius, Enum.PartType.Block)
		end
		return workspace:GetPartBoundsInBox(cframevector, sizeradius, Overlap)
	elseif castshape == "Ball" then
		if debugpart then
			task.defer(Collisions.debugpart, cframevector, Vector3.one * 2 * sizeradius, Enum.PartType.Ball)
		end
		return workspace:GetPartBoundsInRadius(cframevector, sizeradius, Overlap)
	else
		warn(`invalid shape {castshape}`)
	end

	return table.create(0)
end

--- casts a whitelist raycast at origin towards direction
function Collisions.raywhitelist(origin: Vector3, direction: Vector3, whitelist: {Instance}, debugpart: boolean?): RaycastResult
	WhitelistParams.FilterDescendantsInstances = whitelist
	if debugpart then
		local Distance = direction.Magnitude
		task.defer(Collisions.debugpart, CFrame.lookAt(origin, origin + direction) * CFrame.new(0, 0, -Distance * 0.5), Vector3.new(0.5, 0.5, Distance), Enum.PartType.Block)
	end
	return workspace:Raycast(origin, direction, WhitelistParams)
end

--- casts a blacklist raycast at origin towards direction
function Collisions.rayblacklist(origin: Vector3, direction: Vector3, blacklist: {Instance}, debugpart: boolean?): RaycastResult
	BlacklistParams.FilterDescendantsInstances = blacklist
	if debugpart then
		local Distance = direction.Magnitude
		task.defer(Collisions.debugpart, CFrame.lookAt(origin, origin + direction) * CFrame.new(0, 0, -Distance * 0.5), Vector3.new(0.5, 0.5, Distance), Enum.PartType.Block)
	end
	return workspace:Raycast(origin, direction, BlacklistParams)
end

--- fancasts at origin towards direction
function Collisions.fancast(origin: Vector3, direction: Vector3, theta: number, search: {Instance}, isblacklist: boolean?): {RaycastResult}
	local Step = (math.rad(theta * 0.5)) / FancastResolution
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

--- returns vertices of Model or Part
function Collisions.vertices(pv: Model | Part): {Vector3}
	local C0, S0
	if pv:IsA("Model") then
		C0 = pv:GetPivot()
		S0 = pv:GetExtentsSize() * 0.5
	else
		C0 = pv.CFrame
		S0 = pv.Size * 0.5
	end
	return {
		(C0 * (S0 --[[* Vert1]]));
		(C0 * (S0 * Vert2));
		(C0 * (S0 * Vert3));
		(C0 * (S0 * Vert4));
		(C0 * (-S0 --[[* Vert5]]));
		(C0 * (S0 * Vert6));
		(C0 * (S0 * Vert7));
		(C0 * (S0 * Vert8));
	}
end

--- creates a debug part for 0.1 seconds
function Collisions.debugpart(cframevector: CFrame|Vector3, sizeradius: Vector3|number, shape: Enum.PartType?, forever: boolean?): BasePart
	local P = DebugPart:Clone() :: Part

	if typeof(cframevector) == "CFrame" then
		P.CFrame = cframevector
	else
		P.Position = cframevector
	end

	if type(sizeradius) == "number" then
		P.Size = Vector3.one * sizeradius
	else
		P.Size = sizeradius
	end

	P.Shape = shape or Enum.PartType.Block
	P.Parent = workspace

	if not forever then
		task.delay(0.1, function()
			P:Destroy()
		end)
	end

	return P
end

return Collisions