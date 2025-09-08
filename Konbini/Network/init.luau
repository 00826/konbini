--!strict

local RunService = game:GetService("RunService")
local IsServer = RunService:IsServer()

local Players = game:GetService("Players")

local RemoteEvent = script:WaitForChild("RemoteEvent")
local UnreliableRemoteEvent = script:WaitForChild("UnreliableRemoteEvent")

export type ClientArg = 
	| nil
	| number
	| Player
	| { number|Player }
	| (Player) -> boolean

--- ### Network.luau
---
--- basic remote interface
local Network = {}

--- sends packet related to this scope
function Network.send(scope: string, packet: { }, unreliable: boolean?, client: ClientArg?)
	local remote = unreliable and UnreliableRemoteEvent or RemoteEvent

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
		local a = RemoteEvent.OnServerEvent:Connect(serverrecv)
		local b = UnreliableRemoteEvent.OnServerEvent:Connect(serverrecv)

		return a, b
	else
		local function clientrecv(recvscope: string, packet: { })
			assert(type(recvscope) == "string", debug.traceback(string.format("expected string scope, got %s", type(recvscope)), 2))
			assert(type(packet) == "table", debug.traceback(string.format("expected table packet, got %s", type(packet)), 2))

			if recvscope == scope then recv(packet) end
		end
		local a = RemoteEvent.OnClientEvent:Connect(clientrecv)
		local b = UnreliableRemoteEvent.OnClientEvent:Connect(clientrecv)

		return a, b
	end
end

return Network