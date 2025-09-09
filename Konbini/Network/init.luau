--!strict

local RunService = game:GetService("RunService")
local IsServer = RunService:IsServer()

local Players = game:GetService("Players")

local RemoteEvent = script:WaitForChild("RemoteEvent")
local UnreliableRemoteEvent = script:WaitForChild("UnreliableRemoteEvent")

local Types = require(script.Parent:WaitForChild("Types"))

--- resolves optimal remote wrt packet size of network send args
@native
local function resolveremote(b: buffer, i: {Instance})
	local len = 1 + buffer.len(b) + (#i * 5)
	
	if IsServer then
		if len > 127 then
			len += 13
		else
			len += 12
		end
	else
		if len > 127 then
			len += 18
		else
			len += 17
		end
	end

	if len >= 1000 then
		return RemoteEvent
	else
		return UnreliableRemoteEvent
	end
end

--- hard-checks network recv args
@native
local function assertrecvtypes(b: buffer, i: {Instance})
	assert(type(b) == "buffer", string.format("expected buffer, got %s", type(b)))
	assert(type(i) == "table", string.format("expected table, got %s", type(i)))
	for _, instance in i do
		assert(typeof(instance) == "Instance", string.format("expected Instance, got %s", typeof(i)))
	end
end

--- appends u8 network scope to end of buffer
@native
local function writescope(b: buffer, u8: number)
	local size = buffer.len(b) + 1
	local s = buffer.create(size)
	buffer.copy(s, 0, b)
	buffer.writeu8(s, size - 1, u8)

	return s
end

--- reads u8 network scope from end of buffer
@native
local function readscope(s: buffer)
	return buffer.readu8(s, buffer.len(s) - 1)
end

--- removes u8 network scope from end of buffer
@native
local function removescope(s: buffer)
	local size = buffer.len(s) - 1
	local b = buffer.create(size)
	buffer.copy(b, 0, s, 0, size)

	return b
end

--- ### Network.luau
---
--- buffer-based remote interface
local Network = {
	Framerate = 1/60;
	Scopes = table.create(255);
	Queue = table.create(64);
}

--- returns network scope, creating one if it does not already exist
function Network.scope(scope: string)
	local i
	for thisi, thisscope in Network.Scopes do
		if thisscope == scope then
			i = thisi
			break
		end
	end

	if not i then
		assert(IsServer, string.format("unknown scope %s", scope))
		assert(#Network.Scopes <= 2^8-1, "network at max scopes (uint8 limit)")
		table.insert(Network.Scopes, scope)
		
		i = table.find(Network.Scopes, scope)::any
		script:SetAttribute(scope, i)
	end

	return i
end

--- sends value to network scope \
--- `force(="Reliable"|"Unreliable")`: forces remoteevent when this value is sent \
--- `force(=nil)`: automatically resolves remoteevent wrt value size \
--- `front(=true)`: value is inserted to front of queue \
--- `front(=false|nil)`: value is inserted to back of queue
function Network.send(scope: string, value: any, client:
	| nil
	| number
	| Player
	| { number|Player }
	| (Player) -> boolean,
	force: "Reliable"|"Unreliable"?,
	front: boolean?
)
	local u8scope = Network.scope(scope)

	local unscoped, instances = Types.pack(value)
	local scoped = writescope(unscoped, u8scope)

	if front == true then
		table.insert(Network.Queue, 1, {scoped::any, instances::any, client::any, force::any})
	else
		table.insert(Network.Queue, {scoped::any, instances::any, client::any, force::any})
	end
end

--- receives value from network scope
function Network.recv(scope: string, recv: ((value: any) -> ()) & (player: Player, value: any) -> ())
	if IsServer then
		--- add scope if doesnt already exist
		local u8scope = Network.scope(scope)

		local function serverrecv(player: Player, s: buffer, i: {Instance})
			assertrecvtypes(s, i)

			if u8scope == readscope(s) then
				local value = Types.unpack(removescope(s), 0, i)
				recv(player, value)
			end
		end

		return 
			RemoteEvent.OnServerEvent:Connect(serverrecv),
			UnreliableRemoteEvent.OnServerEvent:Connect(serverrecv)
	else
		local function clientrecv(s: buffer, i: {Instance})
			assertrecvtypes(s, i)

			local u8scope = Network.scope(scope)
			if u8scope == readscope(s) then
				local value = Types.unpack(removescope(s), 0, i)
				recv(value)
			end
		end

		return 
			RemoteEvent.OnClientEvent:Connect(clientrecv),
			UnreliableRemoteEvent.OnClientEvent:Connect(clientrecv)
	end
end

if IsServer then
	local function flush(queue: {any})
		local entry = table.remove(queue, 1)
		if entry then
			local scoped = entry[1]
			local instances = entry[2]
			local client = entry[3]
			local force = entry[4]

			local remote
			if force == "Reliable" then
				remote = RemoteEvent
			elseif force == "Unreliable" then
				remote = UnreliableRemoteEvent
			else
				remote = resolveremote(scoped, instances)	
			end
			
			if type(client) == "nil" then --- fire all
				remote:FireAllClients(scoped, instances)
			elseif type(client) == "number" then --- fire by userid
				local player = Players:GetPlayerByUserId(client)
				if player then
					remote:FireClient(player, scoped, instances)
				end
			elseif typeof(client) == "Instance" then --- fire by player
				assert(client:IsA("Player"), string.format("expected instance player, got %s %s", client.ClassName, client.Name))
				remote:FireClient(client, scoped, instances)
			elseif type(client) == "table" then --- fire by list of userids or players
				for _, a in client do
					if typeof(a) == "Instance" then
						remote:FireClient(a, scoped, instances)
					elseif typeof(a) == "number" then
						local player = Players:GetPlayerByUserId(a)
						if player then
							remote:FireClient(player, scoped, instances)
						end
					else
						warn("value dropped for client", typeof(a), a, "expected instance player or number userid")
					end
				end
			elseif type(client) == "function" then --- fire by case
				for _, a in Players:GetPlayers() do
					if client(a) == true then
						remote:FireClient(a, scoped, instances)
					end
				end
			else
				warn(string.format("(value dropped) error solving client: type(%s) typeof(%s)", type(client), typeof(client)), client, client)
			end

			flush(queue)
		else
			return
		end
	end

	local recent = os.clock() - Network.Framerate
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		local dt = now - recent
		if dt > Network.Framerate then
			recent = now - (dt - Network.Framerate)

			flush(Network.Queue)
		end
	end)
else
	local function flush(queue: {any})
		local entry = table.remove(Network.Queue, 1)
		if entry then
			local scoped = entry[1]
			local instances = entry[2]
			local force = entry[4]

			local remote
			if force == "Reliable" then
				remote = RemoteEvent
			elseif force == "Unreliable" then
				remote = UnreliableRemoteEvent
			else
				remote = resolveremote(scoped, instances)	
			end

			remote:FireServer(scoped, instances)

			flush(queue)
		else
			return
		end
	end

	local recent = os.clock() - Network.Framerate
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		local dt = now - recent
		if dt > Network.Framerate then
			recent = now - (dt - Network.Framerate)

			flush(Network.Queue)
		end
	end)

	script.AttributeChanged:Connect(function(scope: string)
		local i = script:GetAttribute(scope)
		assert(type(i) == "number")
		Network.Scopes[i] = scope
	end)
	for scope, i in script:GetAttributes() do
		assert(type(i) == "number")
		Network.Scopes[i] = scope
	end
end

return Network