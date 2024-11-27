--!strict

local types = require(script.Parent.types)

local RunService = game:GetService("RunService")
local IsServer = RunService:IsServer()

local Players = game:GetService("Players")

--- ### Network.luau
---
--- remote wrapper
local Network = {
	RemoteEvent = script:WaitForChild("RemoteEvent");
	UnreliableRemoteEvent = script:WaitForChild("UnreliableRemoteEvent");
}

--- sends packet related to this scope
function Network.send(scope: string, packet: { }, unreliable: boolean?, client: types.ClientArg?)
	local remote = unreliable and Network.UnreliableRemoteEvent or Network.RemoteEvent
	if IsServer then
		if type(client) == "nil" then --- fire all
			remote:FireAllClients(scope, packet)
		elseif type(client) == "number" then --- fire by userid
			local player = Players:GetPlayerByUserId(packet)
			if player then
				remote:FireClient(player, scope, packet)
			end
		elseif typeof(client) == "Instance" then --- fire by player
			assert(client:IsA("Player"), debug.traceback(string.format("expected Player, got %s", client.ClassName), 2))
			remote:FireClient(client, scope, packet)
		elseif type(client) == "table" then --- fire by list of userids or players
			for _, a in client do
				if typeof(a) == "number" then
					local player = Players:GetPlayerByUserId(a)
					if player then
						remote:FireClient(player, scope, packet)
					end
				else
					remote:FireClient(a, scope, packet)
				end
			end
		elseif type(client) == "function" then --- fire by case
			for _, a in Players:GetPlayers() do
				if client(a) == true then
					remote:FireClient(a, scope, packet)
				end
			end
		else
			warn(string.format("(packet dropped) error solving client: type(%s) typeof(%s)", type(client), typeof(client)), client, packet)
		end
	else
		remote:FireServer(scope, packet)
	end
end

--- connects function to remote-events related to this scope
function Network.recv(scope: string, recv: ((packet: { }) -> ()) & (player: Player, packet: { }) -> ())
	if IsServer then
		local function serverrecv(player: Player, recvscope: string, packet: { })
			assert(type(recvscope) == "string", debug.traceback(string.format("expected string scope, got %s", type(recvscope)), 2))
			assert(type(packet) == "table", debug.traceback(string.format("expected table packet, got %s", type(packet)), 2))

			if recvscope == scope then recv(player, packet) end
		end
		local a = Network.RemoteEvent.OnServerEvent:Connect(serverrecv)
		local b = Network.UnreliableRemoteEvent.OnServerEvent:Connect(serverrecv)

		return a, b
	else
		local function clientrecv(recvscope: string, packet: { })
			assert(type(recvscope) == "string", debug.traceback(string.format("expected string scope, got %s", type(recvscope)), 2))
			assert(type(packet) == "table", debug.traceback(string.format("expected table packet, got %s", type(packet)), 2))

			if recvscope == scope then recv(packet) end
		end
		local a = Network.RemoteEvent.OnClientEvent:Connect(clientrecv)
		local b = Network.UnreliableRemoteEvent.OnClientEvent:Connect(clientrecv)

		return a, b
	end
end

--- yields until this scope receives a packet from the server
function Network.wait(scope: string, timeout: number?)
	assert(not IsServer, debug.traceback("Network.wait() can only be called on client", 2))

	local a, b, response
	local function scopewait(recvscope: string, packet: { })
		assert(type(recvscope) == "string", debug.traceback(string.format("expected string scope, got %s", type(recvscope)), 2))

		if recvscope == scope then
			response = packet

			if a then a:Disconnect() end
			if b then b:Disconnect() end
		end
	end
	a = Network.RemoteEvent.OnClientEvent:Once(scopewait)
	b = Network.UnreliableRemoteEvent.OnClientEvent:Once(scopewait)

	timeout = timeout or 5
	assert(timeout)

	repeat timeout -= task.wait() until (timeout < 0) or (response ~= nil)

	if (timeout < 0) and (response == nil) then
		warn(`Network.wait({scope}, {timeout}) timeout exhausted`)
	end

	if a then a:Disconnect() end
	if b then b:Disconnect() end

	return response
end

return Network