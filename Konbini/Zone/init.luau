--!strict

local types						= require(script.Parent.types)

local RunService				= game:GetService("RunService")
local IsServer					= RunService:IsServer()

local Players					= game:GetService("Players")

local R							= Random.new()

local function send(thing: Instance, to: Instance)
	thing.Parent = to
end

--- ### Zone.luau
---
--- server-defined, client-authoritative, to-each-his-own load zones \
--- .Parent assignments are deferred
local Zone = {
	Cache = {};

	Focus = Vector3.zero;
	Current = nil :: string?;

	ReparentRate = 1/30;
	ReparentLimit = 2;
	DefaultLoadContainer = workspace;
	DefaultOffloadContainer = script;

	Remote = script:WaitForChild("ZoneRemote");
	SyncLimit = 1;
	SyncTimes = {};
}

--- creates empty zone with name and placement/emplacement/never allocation size `(?=128)`
function Zone.create(zoneid: string, size: number?): types.Zone
	size = size or 128

	assert(size, "lf new type solver")
	assert(Zone.Cache[zoneid] == nil, `attempt to overwrite zone "{zoneid}"`)

	local NewZone: types.Zone = {
		Container = nil;
		Position = nil;
		Radius = nil;

		Placements = table.create(size);
		Emplacements = table.create(size);
		Never = table.create(size);
	}

	Zone.Cache[zoneid] = NewZone

	return NewZone
end

--- writes settings to target zone
function Zone.write(z: types.Zone, settings: types.Zone)
	for key, value: any in settings do
		if type(value) == "table" then
			if not z[key] then
				z[key] = table.create(#value)
			end
			table.clear(z[key])
			table.move(value, 1, #value, 1, z[key])
		else
			z[key] = value
		end
	end
end

--- solves zone that should be loaded
function Zone.frame()
	local overlaps = table.create(1)

	local focus = Zone.Focus
	for k, z in Zone.Cache do
		assert(z.Position, `zone {k} not assigned position`)
		assert(z.Radius, `zone {k} not assigned radius`)

		if (focus - z.Position).Magnitude < z.Radius then
			table.insert(overlaps, k)
		end
	end

	if #overlaps == 1 then
		local zoneid = overlaps[1]
		if zoneid == Zone.Current then
			--- zone already loaded
			return
		else
			Zone.Current = zoneid
		end
	else
		--- zone overlap (> 1)
		--- no zones to load (== 0)
		return
	end
end

--- iterates through zone placements and emplacements, reparenting 1 placement and 1 emplacement that is *not* a descendant of its respective focus container
function Zone.reparent(z: types.Zone, isinfocus: boolean): number
	local total = 0

	assert(z.Placements, z, "zone no placement array")
	assert(z.Emplacements, "zone no emplacement array")

	local LoadContainer = z.Container or Zone.DefaultLoadContainer
	assert(LoadContainer, "zone no load container")

	if isinfocus then
		--- load 1 placement
		--- offload 1 emplacement
		for _, thing in z.Placements do
			if thing:IsDescendantOf(LoadContainer) then
				continue
			else
				task.defer(send, thing, LoadContainer)
				total += 1
				break
			end
		end
		for _, thing in z.Emplacements do
			if thing:IsDescendantOf(Zone.DefaultOffloadContainer) then
				continue
			else
				task.defer(send, thing, Zone.DefaultOffloadContainer)
				total += 1
				break
			end
		end
	else
		--- offload 1 placement
		--- load 1 emplacement
		for _, thing in z.Placements do
			if thing:IsDescendantOf(Zone.DefaultOffloadContainer) then
				continue
			else
				task.defer(send, thing, Zone.DefaultOffloadContainer)
				total += 1
				break
			end
		end
		for _, thing in z.Emplacements do
			if thing:IsDescendantOf(LoadContainer) then
				continue
			else
				task.defer(send, thing, LoadContainer)
				total += 1
				break
			end
		end
	end

	return total
end

--- `server`: sends `Zone.Cache` to target player \
--- `client`: requests `Zone.Cache` from server, yielding until a response is received
function Zone.sync(player: Player?): typeof(Zone.Cache)?
	if IsServer then
		assert(player, "expected target player")
		Zone.Remote:FireClient(player, Zone.Cache)
	else
		Zone.Remote:FireServer()
		local zonepacket: {[string]: types.Zone}, err: string? = Zone.Remote.OnClientEvent:Wait()
		if zonepacket then
			for zoneid, recvzone in zonepacket do
				if not Zone.Cache[zoneid] then
					Zone.create(zoneid)
				end
	
				local thiszone = Zone.Cache[zoneid]
				Zone.write(thiszone, recvzone)
			end
		else
			warn(err)
		end
		return Zone.Cache
	end
	return
end

--- creates a silhouette of model, intended for optimization using the `comp` function \
--- `transform` is deferred
function Zone.silhouette(object: Model, comp: (original: Instance) -> boolean, transform: (copy: Instance) -> ()): Model
	assert(object.PrimaryPart, `{object} PrimaryPart not set`)

	local silhouette = Instance.new("Model")
	silhouette.Name = object.Name
	silhouette.Parent = Zone.DefaultOffloadContainer

	local primarypart = object.PrimaryPart:Clone()
	primarypart.Parent = silhouette
	silhouette.PrimaryPart = primarypart

	for _, thing in object:GetChildren() do
		if thing == object.PrimaryPart then
			continue
		else
			if comp(thing) then
				local newthing = thing:Clone()
				newthing.Parent = silhouette
	
				task.defer(transform, newthing)
			end
		end
	end

	return silhouette
end

--- solves load zone radius of object \
--- `mode` \
--- `0`: r = avg extent size \
--- `1`: r = max extent size (optimistic) \
--- `2`: r = min extent size (pessimistic)
function Zone.radius(object: Model, mode: number, ignoreYaxis: boolean?): number
	local size = object:GetExtentsSize()
	local dimensions = table.create(3)
	if ignoreYaxis == true then
		table.insert(dimensions, size.X)
		table.insert(dimensions, size.Z)
	else
		table.insert(dimensions, size.X)
		table.insert(dimensions, size.Y)
		table.insert(dimensions, size.Z)
	end

	if mode == 0 then
		local sum = 0
		for _, value in dimensions do
			sum += value
		end
		return sum / #dimensions
	elseif mode == 1 then
		return math.max(select(1, unpack(dimensions)))
	elseif mode == 2 then
		return math.min(select(1, unpack(dimensions)))
	end
	error(`no radius case for mode {mode}`)
end

--- returns a vector3 position of zone spawnbox, position, or zero-vector
function Zone.spawnpoint(z: types.Zone): Vector3
	local spawnbox = z.SpawnBox
	if spawnbox then
		local halfsize = spawnbox.Size * 0.5
		local X, Z = halfsize.X, halfsize.Z
		return (spawnbox.CFrame * CFrame.new(
			R:NextNumber(-X, X),
			0,
			R:NextNumber(-Z, Z)
		)).Position
	else
		return z.Position or Vector3.zero
	end
end

--- force-loads zone
--- all placements sent to load container
--- all emplacements sent to offload container
function Zone.forceload(z: types.Zone)
	assert(z.Placements)
	assert(z.Emplacements)
	assert(z.Never)

	local LoadContainer = z.Container or Zone.DefaultLoadContainer
	assert(LoadContainer, "zone no load container")

	for _, thing in z.Placements do
		task.defer(send, thing, LoadContainer)
	end
	for _, thing in z.Emplacements do
		task.defer(send, thing, Zone.DefaultOffloadContainer)
	end
	for _, thing in z.Never do
		task.defer(send, thing, Zone.DefaultOffloadContainer)
	end
end

--- force-offloads zone
--- all placements sent to offload container
--- all emplacements sent to load container
function Zone.forceoffload(z: types.Zone)
	assert(z.Placements)
	assert(z.Emplacements)
	assert(z.Never)

	local LoadContainer = z.Container or Zone.DefaultLoadContainer
	assert(LoadContainer, "zone no load container")

	for _, thing in z.Placements do
		task.defer(send, thing, Zone.DefaultOffloadContainer)
	end
	for _, thing in z.Emplacements do
		task.defer(send, thing, LoadContainer)
	end
	for _, thing in z.Never do
		task.defer(send, thing, Zone.DefaultOffloadContainer)
	end
end

if IsServer then
	Zone.Remote.OnServerEvent:Connect(function(player: Player)
		local userid = player.UserId
		if not Zone.SyncTimes[userid] then
			Zone.SyncTimes[userid] = 0
		end

		local now = os.clock()
		if Zone.SyncTimes[userid] < now then
			Zone.SyncTimes[userid] = now + Zone.SyncLimit
			Zone.sync(player)
			return
		end
		Zone.Remote:FireClient(player, nil, `retry sync in {now - Zone.SyncTimes[userid]}s`)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		Zone.SyncTimes[player.UserId] = nil
	end)
else
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		if elapsed < Zone.ReparentRate then
			return
		else
			elapsed -= Zone.ReparentRate

			local total = 0
			for k, z in Zone.Cache do
				total += Zone.reparent(z, k == Zone.Current)

				if total >= Zone.ReparentLimit then
					break
				end
			end
		end
	end)
end

return Zone