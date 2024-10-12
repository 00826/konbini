--!strict

local types						= require(script.Parent.types)

local DSS						= game:GetService("DataStoreService")
local RunService				= game:GetService("RunService")

local IsServer					= RunService:IsServer()

local DataRemote				= script:WaitForChild("DataRemote") :: RemoteEvent

local ServerCache				= {} :: {[Player]: {Data: types.SaveTemplate}}
local ClientCache				= {} :: types.SaveTemplate

local Bind						= require(script.Parent.Bind)

--- ### Data.luau
---
--- data handler
--- intended to be used in conjunction with profileservice
local Data = {
	Config						= require(script:WaitForChild("Config"));

	LoadHook					= nil :: ((Player: Player) -> {Data: types.SaveTemplate}?)?;
	ReleaseHook					= nil :: ((Player: Player) -> boolean)?;
}

--- returns player's save data
function Data.get(player: Player?): types.SaveTemplate
	if IsServer then
		assert(player)
		return ServerCache[player].Data
	else
		return ClientCache
	end
end

--- reads player's data value stored at key
function Data.read(player: Player, key: string): unknown
	if IsServer then
		return ServerCache[player].Data[key]
	else
		return ClientCache[key]
	end
end

--- sends select keys and their associated value to player
function Data.sync(player: Player, keys: {string}?): ()
	assert(IsServer)

	local SaveData = ServerCache[player].Data
	local Packet = {}

	for _, Key in (keys or Data.Config.SyncKeys) do
		Packet[Key] = SaveData[Key]
	end

	DataRemote:FireClient(player, Packet)
end

--- is called when a sync packet is received
function Data.recv(packet: types.SaveTemplate): ()
	assert(not IsServer)

	for k, v in packet do
		ClientCache[k] = v
		Bind("k_Data_" .. (k :: any)):Fire(v)
	end
end

--- fires function when value is written to key
function Data.listento(key: string, f: (value: any) -> ()): types.Disconnect
	return Bind("k_Data_" .. key):Connect(f)
end

--- adds player saveprofile to cache
function Data.addprofile(player: Player, SaveProfile: { Data: types.SaveTemplate })
	assert(IsServer)

	ServerCache[player] = SaveProfile
end

function Data.releaseprofile(player: Player)
	assert(IsServer)

	if ServerCache[player] then
		(ServerCache[player] :: any):Release()
	end
end

--- removes player saveprofile from cache
function Data.removeprofile(player: Player)
	assert(IsServer)

	ServerCache[player] = nil
end

--- gdpr what i need you to do
--- ```
--- "24103210 12345 67890"
--- "24103210, 12345, 67890"
--- ```
function Data.wipe(gameid: number, lazystring: string): ()
	local DataStore = DSS:GetDataStore(Data.Config.Name)
	assert(game.GameId == gameid, "gameid mismatch")
	assert(RunService:IsStudio() and RunService:IsEdit() and IsServer and DataStore)

	local SaveKey = Data.Config.SaveKey
	local Failures = table.create(32)

	local _, x = string.gsub(lazystring, "%d+", function(LazyId)
		local s, e = pcall(function()
			DataStore:RemoveAsync(LazyId .. SaveKey)
		end)

		if not s then
			print(string.format("unable to wipe data key %s:", LazyId), e)
			table.insert(Failures, tonumber(LazyId))
			return ""
		else
			print(string.format("wiped data key %s:", LazyId))
		end

		return LazyId
	end)

	print(string.format("%d entries wiped", x))
	if #Failures > 0 then
		print(string.format("failed to wipe %d entries:", #Failures), Failures)
	end
end

if IsServer then
else
	DataRemote.OnClientEvent:Connect(Data.recv)
end

return Data