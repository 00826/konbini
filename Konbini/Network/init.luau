--!strict

local types = require(script.Parent.types)

local RunService = game:GetService("RunService")
local IsServer = RunService:IsServer()

local Players = game:GetService("Players")

local ByteSizes = {
	_remoteoverhead = 9;
	--- _remotefunctionoverhead = 2;
	_clienttoserveroverhead = 5;
	_type = 1;
	_nil = 0;

	f64 = 8;
	f32 = 4;
	u32 = 4;
	i32 = 4;
	u16 = 2;
	i16 = 2;
	u8 = 1;
	i8 = 1;

	Axes = 6;
	boolean = 1;
	BrickColor = 4;
	CFrame = 19;
	Color3 = 12;
	Color3uint8 = 3;
	ColorSequenceKeypoint = 16;
	EnumItem = 4;
	Faces = 6;
	number = 8;
	NumberRange = 8;
	NumberSequenceKeypoint = 12;
	PhysicalProperties = 20;
	Ray = 24;
	Rect = 16;
	UDim = 8;
	UDim2 = 16;
	Vector2 = 8;
	Vector2int16 = 4;
	Vector3 = 12;
	Vector3int16 = 6;
};

local function vlq(initialsize: number, length: number)
	return math.max(math.ceil(math.log(length + initialsize, 128)), initialsize)
end

--- ### Network.luau
---
--- remote wrapper \
--- thank you pyseph for remote packet size counter
local Network = {
	Queue = {};

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

function Network.measurepacket(packet: {any}, clienttoserver: boolean)
	local total = ByteSizes._remoteoverhead + ByteSizes._type

	for a, b in ipairs(packet) do
		total += Network.sizeof(b) + ByteSizes._type
	end

	return total
end

function Network.sizeof(data: any)
	local total = 0
	if data ~= nil then
		total += ByteSizes._type
	end

	local datatype = typeof(data)

	if datatype == "string" then
		local len = #data
		total += vlq(1, len) + len
	elseif datatype == "buffer" then
		local len = buffer.len(data)
		total += vlq(1, len) + len
	elseif datatype == "NumberSequence" then
		total += 4
		for _, keypoint in (data::NumberSequence).Keypoints do
			total += ByteSizes.NumberSequenceKeypoint
		end
	elseif datatype == "ColorSequence" then
		total += 4
		for _, keypoint in (data::ColorSequence).Keypoints do
			total += ByteSizes.ColorSequenceKeypoint
		end
	elseif datatype == "table" then
		local keys = 0
		local sum = 0

		if data[1] ~= nil then
			for _, v in data do
				keys += 1
				sum += Network.sizeof(v)::number + ByteSizes._type
			end
		else
			for k, v in data do
				keys += 1
				sum += Network.sizeof(k)::number + Network.sizeof(v) + ByteSizes._type
			end
		end

		total += vlq(1, keys) + sum
	elseif ByteSizes[datatype] then
		total += ByteSizes[datatype]
	else
		error(`unknown type {datatype}`)
	end

	return total
end

if IsServer then
else

end

return Network