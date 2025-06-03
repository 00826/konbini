--!strict

local DSS = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local IsServer = RunService:IsServer()

local ServerCache = {} :: { [Player]: { Data: any } }
local ClientCache = {} :: any

--- ### Data.luau
---
--- data handler \
--- intended to be used in conjunction with profileservice
local Data = {
	Config = {
		--- string describing the name of datastore
		Datastore = "PlayerData";
		--- string describing suffix appended to datastore key
		Suffix = "_1a";
	};
}

--- returns cached save data associated with `player` or `Players.LocalPlayer` if called locally
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

--- writes key-value to client cache
function Data.write(key: string, value: any)
	assert(not IsServer)

	ClientCache[key] = value
end

--- adds player saveprofile to server cache
function Data.insert(player: Player, saveprofile: { Data: any })
	assert(IsServer)

	ServerCache[player] = saveprofile
end

--- removes player saveprofile from server cache
function Data.remove(player: Player)
	assert(IsServer)

	ServerCache[player] = nil
end

--- gdpr what i need you to do \
--- capture pattern: `%d+`
--- ```
--- "12345 67890"
--- "12345, 67890"
--- ```
function Data.wipe(gameid: number, lazystring: string)
	local datastore = DSS:GetDataStore(Data.Config.Datastore)
	assert(game.GameId == gameid, "gameid mismatch")
	assert(RunService:IsStudio() and RunService:IsEdit() and IsServer and datastore)

	local suffix = Data.Config.Suffix
	local failures = table.create(32)

	local _, x = string.gsub(lazystring, "%d+", function(lazyid)
		local s, e = pcall(function()
			datastore:RemoveAsync(lazyid .. suffix)
		end)

		if not s then
			print(string.format("unable to wipe data key %s:", lazyid), e)
			table.insert(failures, tonumber(lazyid))
			return ""
		else
			print(string.format("wiped data key %s:", lazyid))
		end

		return lazyid
	end)

	print(string.format("%d entries wiped", x))
	if #failures > 0 then
		print(string.format("failed to wipe %d entries:", #failures), failures)
	end
end

return Data