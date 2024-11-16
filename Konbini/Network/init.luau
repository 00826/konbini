--!strict

local types = require(script.Parent.types)

local Players = game:GetService("Players")

local RunService = game:GetService("RunService")
local IsServer = RunService:IsServer()

local await = require(script.Parent.await)

--- ### Network.luau
---
--- `RemoteEvent` wrapper
local Network = {
	Cache = {} :: {[string]: types.Remote};
	PollTimeout = 5;
}

script.ChildAdded:Connect(function(Remote: types.Remote)
	Network.Cache[Remote.Name] = Remote
end)
for _, Remote: types.Remote in script:GetChildren() do
	Network.Cache[Remote.Name] = Remote
end

--- sends `...` via remote to client(s) of clientarg
function Network.toclient(remote: string, clientarg: types.ClientArg?, ...: any?)
	local remoteevent = Network.Cache[remote]
	if typeof(clientarg) == "nil" then
		remoteevent:FireAllClients(...)
	elseif typeof(clientarg) == "number" then
		local P = Players:GetPlayerByUserId(clientarg)
		if P then
			remoteevent:FireClient(P, ...)
		end
	elseif typeof(clientarg) == "Instance" then
		assert(clientarg:IsA("Player"))
		remoteevent:FireClient(clientarg, ...)
	elseif typeof(clientarg) == "table" then
		for _, Client in clientarg do
			if typeof(Client) == "number" then
				local P = Players:GetPlayerByUserId(Client)
				if P then
					remoteevent:FireClient(P, ...)
				end
			else
				remoteevent:FireClient(Client, ...)
			end
		end
	elseif typeof(clientarg) == "function" then
		for _, Client in Players:GetPlayers() do
			if clientarg(Client) == true then
				remoteevent:FireClient(clientarg, ...)
			end
		end
	end
end

--- sends `...` via remote to server
function Network.toserver(remote: string, ...: any?)
	local remoteevent = Network.Cache[remote]

	remoteevent:FireServer(...)
end

--- `server`: creates and/or connects remote to `f` with option to make the remote unreliable \
--- `client`: connects remote to `f` with option to yield until the remote is created (recommended)
function Network.recv(remote: string, f: ((...any) -> ())?, yield: boolean?, unreliable: boolean?): RBXScriptConnection?
	local remoteevent = Network.Cache[remote]

	if IsServer then
		if not remoteevent then
			local newremote = Instance.new(unreliable and "UnreliableRemoteEvent" or "RemoteEvent")
			newremote.Name = remote
			newremote.Parent = script

			remoteevent = newremote
		end
		if f then
			return remoteevent.OnServerEvent:Connect(f)
		end
	else
		if yield and not remoteevent then
			remoteevent = script:WaitForChild(remote)
			Network.Cache[remote] = remoteevent
		end
		if f then
			return remoteevent.OnClientEvent:Connect(f)
		end
	end
	return
end

--- `client`: sends `...` via remote to server, yielding the calling thread until a response is received, returning the values, if any, contained in the response
function Network.poll(remote: string, ...: any?): {any}
	local remoteevent = Network.Cache[remote]
	local packet = nil

	local C = remoteevent.OnClientEvent:Once(function(...) packet = {...} end)
	remoteevent:FireServer(...)

	await(Network.PollTimeout, function() return packet ~= nil end, function(traceback: string) warn(`{traceback}: Network.poll({remote}, ...) did not receive packet after {Network.PollTimeout}s`) end)

	if C then C:Disconnect() end

	return packet and unpack(packet) or {}
end

return Network