--!strict

local DSS = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local IsServer = RunService:IsServer()

local DataRemote = script:WaitForChild("DataRemote") :: RemoteEvent

local ServerCache = {} :: {[Player]: {Data: any}}
local ClientCache = {} :: any

local Hook = require(script.Parent.Hook)

--- ### Data.luau
---
--- data handler
--- intended to be used in conjunction with profileservice
local Data = { Config = require(script:WaitForChild("Config")); }

--- returns player's save data
function Data.get(player: Player?): any
	if IsServer then
		--- assert(player)
		if player and ServerCache[player] then
			return ServerCache[player].Data
		end
	else
		return ClientCache
	end

	return
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
function Data.sync(player: Player, keys: {string}?)
	assert(IsServer)

	local savedata = ServerCache[player].Data
	local packet = {}

	for _, key in (keys or Data.Config.SyncKeys) do
		packet[key] = savedata[key]
	end

	DataRemote:FireClient(player, packet)
end

--- is called when a sync packet is received
function Data.recv(packet: any)
	assert(not IsServer)

	for k, v in packet do
		ClientCache[k] = v
		Hook("k_DataChanged_" .. (k :: any)).Fire(v)
	end
end

--- fires function when value is written to key
function Data.changed(key: string, f: (value: any) -> ())
	return Hook("k_DataChanged_" .. key).Connect(f)
end

--- adds player saveprofile to cache
function Data.addprofile(player: Player, saveprofile: { Data: any })
	assert(IsServer)

	ServerCache[player] = saveprofile
end

--- removes player saveprofile from cache
function Data.removeprofile(player: Player)
	assert(IsServer)

	pcall(function()
		(ServerCache[player]::any):EndSession()
	end)
	ServerCache[player] = nil
end

function Data.tostring(data: any)
	return HttpService:JSONEncode(data)
end

function Data.totable(string: any)
	return HttpService:JSONDecode(string)
end

--- gdpr what i need you to do
--- ```
--- "24103210 12345 67890"
--- "24103210, 12345, 67890"
--- ```
function Data.wipe(gameid: number, lazystring: string)
	local datastore = DSS:GetDataStore(Data.Config.Name)
	assert(game.GameId == gameid, "gameid mismatch")
	assert(RunService:IsStudio() and RunService:IsEdit() and IsServer and datastore)

	local savekey = Data.Config.SaveKey
	local failures = table.create(32)

	local _, x = string.gsub(lazystring, "%d+", function(LazyId)
		local s, e = pcall(function()
			datastore:RemoveAsync(LazyId .. savekey)
		end)

		if not s then
			print(string.format("unable to wipe data key %s:", LazyId), e)
			table.insert(failures, tonumber(LazyId))
			return ""
		else
			print(string.format("wiped data key %s:", LazyId))
		end

		return LazyId
	end)

	print(string.format("%d entries wiped", x))
	if #failures > 0 then
		print(string.format("failed to wipe %d entries:", #failures), failures)
	end
end

if IsServer then
else
	DataRemote.OnClientEvent:Connect(Data.recv)
end

return Data