--!strict

local types						= require(script.Parent.types)

local Players					= game:GetService("Players")

local RunService				= game:GetService("RunService")
local IsServer					= RunService:IsServer()

local async						= require(script.Parent.async)

--- ### Network.luau
---
--- `RemoteEvent` wrapper
local Network = {
	Cache						= {} :: {[string]: types.Remote};
	PollTimeout					= 5;
}

script.ChildAdded:Connect(function(Remote: types.Remote)
	Network.Cache[Remote.Name] = Remote
end)
for _, Remote: types.Remote in script:GetChildren() do
	Network.Cache[Remote.Name] = Remote
end

--- sends `...` via remote to client(s) of clientarg
function Network.toclient(remote: string, clientarg: types.ClientArg?, ...: any?): ()
	local Remote = Network.Cache[remote]
	if typeof(clientarg) == "nil" then
		Remote:FireAllClients(...)
	elseif typeof(clientarg) == "number" then
		local P = Players:GetPlayerByUserId(clientarg)
		if P then
			Remote:FireClient(P, ...)
		end
	elseif typeof(clientarg) == "Instance" then
		assert(clientarg:IsA("Player"))
		Remote:FireClient(clientarg, ...)
	elseif typeof(clientarg) == "table" then
		for _, Client in clientarg do
			Remote:FireClient(clientarg, ...)
		end
	elseif typeof(clientarg) == "function" then
		for _, Client in Players:GetPlayers() do
			if clientarg(Client) == true then
				Remote:FireClient(clientarg, ...)
			end
		end
	end
end

--- sends `...` via remote to server
function Network.toserver(remote: string, ...: any?): ()
	local Remote = Network.Cache[remote]

	Remote:FireServer(...)
end

--- `server`: creates and/or connects remote to `f` with option to make the remote unreliable \
--- `client`: connects remote to `f` with option to yield until the remote is created (recommended)
function Network.recv(remote: string, f: ((...any) -> ())?, yield: boolean?, unreliable: boolean?): RBXScriptConnection?
	local Remote = Network.Cache[remote]

	if IsServer then
		if not Remote then
			local NewRemote = Instance.new(unreliable and "UnreliableRemoteEvent" or "RemoteEvent")
			NewRemote.Name = remote
			NewRemote.Parent = script

			Remote = NewRemote
		end
		if f then
			return Remote.OnServerEvent:Connect(f)
		end
	else
		if yield and not Remote then
			Remote = script:WaitForChild(Remote)
			Network.Cache[remote] = Remote
		end
		if f then
			return Remote.OnClientEvent:Connect(f)
		end
	end
	return
end

--- `client`: sends `...` via remote to server, yielding the calling thread until a response is received, returning the values, if any, contained in the response
function Network.poll(remote: string, ...: any?): {any}
	local Remote = Network.Cache[remote]
	local Packet = nil

	local C = Remote.OnClientEvent:Once(function(...) Packet = {...} end)
	Remote:FireServer(...)

	async(function() return Packet ~= nil end):await(nil, nil, Network.PollTimeout)

	if C then C:Disconnect() end

	return Packet and unpack(Packet) or {}
end

return Network