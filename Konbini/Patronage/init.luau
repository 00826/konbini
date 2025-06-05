--!strict

local RunService = game:GetService("RunService")
local IsServer = RunService:IsServer()

local DataStoreService = game:GetService("DataStoreService")
local LocalizationService = game:GetService("LocalizationService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local PolicyService = game:GetService("PolicyService")

--- ### Patronage.luau
---
--- player patronage (devproducts, gamepasses, premium, group membership, etc)
local Patronage = {
	Config = {
		--- numeric array describing groupids where membership and rank is recorded
		GroupIds = {
		} :: {number};
	
		--- string describing the name of patronage datastore \
		--- in cases where `Datastore == ""`, patronage datstore is never retrieved
		Datastore = "";
		--- string array describing scopes of patronage datastore \
		--- example `{ "VIPs"; "Banned"; }`
		DatastoreScopes = {
		} :: {string};
		--- number describing interval in seconds by which patronage datastore is refreshed \
		--- patronage datastore is always refreshed on init
		DatastoreRate = 600;
	
		--- string array of policyservice keys \
		--- unknown keys identified by Patronage.policystring() toss a warning and are appended to the end of this array
		PolicyMap = {
			"AreAdsAllowed";
			"ArePaidRandomItemsRestricted";
			--- "AllowedExternalLinkReferences"; --- type == table
			"IsContentSharingAllowed";
			"IsEligibleToPurchaseCommerceProduct";
			"IsEligibleToPurchaseSubscription";
			"IsPaidItemTradingAllowed";
			"IsSubjectToChinaPolicies";
		} :: {string};
	};

	Lists = {};
	__listsloaded = false;
}

function Patronage.minproduct()
	return {
		--- devproduct or gamepass
		Type = "DevProduct" :: "DevProduct"|"Gamepass";
		--- devproduct or gamepass id
		Id = 0;
	}
end

--- returns patronage profile of player (yields) \
--- profile is cached and retrievable with `Patronage.get()` \
--- `producttable (?={})`: table of devproducts and/or gamepasses
function Patronage.createprofile(player: Player, producttable: {[string]: typeof(Patronage.minproduct()) & {[string]: unknown}}?)
	local userid = player.UserId
	local profile = {
		--- number describing the player userid of this profile
		UserId = userid;
		--- 2-wide string (country code) describing player region
		Region = LocalizationService:GetCountryRegionForPlayerAsync(player);

		--- boolean describing if this userid has roblox premium subscription
		IsPremium = player.MembershipType == Enum.MembershipType.Premium;
		--- binary string describing policyservice restrictions appled to this userid
		PolicyString = Patronage.policystring(player);

		--- array describing group membership states of this userid with respect to patronage config
		Groups = table.create(100);
		--- array describing gamepasses that are owned by this userid
		Gamepasses = table.create(32);
		--- array describing the patronage lists where this userid is present
		Lists = table.create(#Patronage.Config.DatastoreScopes);
	}

	Patronage.refreshgroups(profile.Groups, userid)
	Patronage.refreshgamepasses(profile.Gamepasses, userid, producttable or {})
	Patronage.refreshlists(profile.Lists, userid)

	return profile
end

--- returns player policyservice restrictions as a binary string \
--- non-boolean values are ignored
function Patronage.policystring(player: Player)
	local policyinfo = PolicyService:GetPolicyInfoForPlayerAsync(player)
	local policymap = Patronage.Config.PolicyMap
	local coveredkeys = table.create(1 + #policymap) --- extra 1 in case of new policy string
	local policystring = ""

	--- load known policy keys
	for i, policykey in ipairs(policymap) do
		local value = policyinfo[i]
		if type(value) == "boolean" then
			table.insert(coveredkeys, policykey)

			policystring ..= value == true and "1" or "0"
		else
			--- skip non boolean
		end
	end

	--- load and index unknown policy keys
	for policykey, value in policyinfo do
		if type(value) == "boolean" then
			if table.find(coveredkeys, policykey) then continue end
			if not table.find(policymap, policykey) then
				table.insert(policymap, policykey)
				warn(`[Patronage]: unknown policy key "{policykey}"; stored at offset {#policymap}`)
			end

			policystring ..= value == true and "1" or "0"
		else
			--- skip non boolean
		end
	end

	return policystring
end

--- returns value of policyservice restriction applied to patronage profile \
--- returns `nil` if key is unindexed and therefore unreadable
function Patronage.readpolicykey(profile: typeof(Patronage.createprofile(...)), key: 
	--- ads
	| "AreAdsAllowed"
	--- lootboxes
	| "ArePaidRandomItemsRestricted"
	--- | "AllowedExternalLinkReferences"
	--- off platform sharing
	| "IsContentSharingAllowed"
	--- commerce
	| "IsEligibleToPurchaseCommerceProduct"
	--- subscriptions
	| "IsEligibleToPurchaseSubscription"
	--- trading
	| "IsPaidItemTradingAllowed"
	--- china
	| "IsSubjectToChinaPolicies"
	--- (unknown/undefined)
	| string --- account for undefined policies that may in fact exist
): boolean?
	local offset = table.find(Patronage.Config.PolicyMap, key)
	if not offset then
		warn(`[Patronage]: unindexed policy key "{key}"`)
		return nil
	end
	return string.sub(profile.PolicyString, offset, offset) == "1"
end

--- refreshes userid group membership and rank
function Patronage.refreshgroups(profilegroups: { { GroupId: number; Rank: number; } }, userid: number)
	table.clear(profilegroups)

	local player = Players:GetPlayerByUserId(userid)
	if player then
		for _, groupid in Patronage.Config.GroupIds do
			table.insert(profilegroups, { GroupId = groupid; Rank = player:GetRankInGroup(groupid); })
		end
	else
		warn(`[Patronage]: attempt to refresh groups against nonexistent player`)
	end
end

--- refreshes userid presence in datastore scopes
function Patronage.refreshlists(profilelists: {string}, userid: number)
	table.clear(profilelists)

	for _, scope in Patronage.Config.DatastoreScopes do
		local list = Patronage.Lists[scope]
		if list then
			if table.find(list, userid) then
				table.insert(profilelists, scope)
			end
		end
	end
end

--- refreshes userid owned gamepasses with respect to product table
function Patronage.refreshgamepasses(profilepasses: {number}, userid: number, producttable: {[string]: typeof(Patronage.minproduct()) & {[string]: unknown}})
	--- table.clear(profilepasses) --- never clear, roll with ethos of "gamepasses should never be deleted"

	for key, product in producttable do
		if product.Type == "Gamepass" then
			if table.find(profilepasses, product.Id) then continue end

			local s, e = pcall(function()
				if MarketplaceService:UserOwnsGamePassAsync(userid, product.Id) then
					table.insert(profilepasses, product.Id)
				end
			end)
			if not s then warn(`[Patronage]: error loading solving ownership of gamepass id {product.Id}: {e}`) end
		end
	end
end

--- prompts devproduct or gamepass purchase \
--- if called locally, `player` will default to the localplayer
function Patronage.promptpurchase(product: typeof(Patronage.minproduct()) & {[string]: unknown}, player: Player?)
	player = player or LocalPlayer
	assert(player, "[Patronage]: Patronage.promptpurchase() error resolving player")

	if product.Type == "DevProduct" then
		MarketplaceService:PromptProductPurchase(player or LocalPlayer, product.Id)
	elseif product.Type == "Gamepass" then
		MarketplaceService:PromptGamePassPurchase(player or LocalPlayer, product.Id)
	end
end

--- prompts roblox premium purchase
function Patronage.promptpremiumpurchase(player: Player?)
	return MarketplaceService:PromptPremiumPurchase(player or LocalPlayer)
end

--- returns empty receipt info
function Patronage.receiptinfo()
	return {
		--- unique purchase id
		PurchaseId = "";
		--- purchaser userid
		PlayerId = 0;
		--- devproduct id
		ProductId = 0;
		--- placeid of purchase
		PlaceIdWherePurchased = 0;
		--- currency spent
		CurrencySpent = 0;
		--- Enum.CurrencyType.Robux
		CurrencyType = Enum.CurrencyType.Robux;
	}
end

--- connects: \
--- `MarketplaceService.ProcessReceipt` -> `productpurchased` \
--- `MarketplaceService.PromptGamePassPurchaseFinished` -> `productpurchased` \
--- `Players.PlayerMembershipChanged` -> `membershipchanged`
function Patronage.receipt(productpurchased: (player: Player, product: typeof(Patronage.minproduct())) -> boolean, membershipchanged: (player: Player, membershiptype: Enum.MembershipType) -> ())
	assert(RunService:IsServer(), "[Patronage]: Patronage.receipt can only be invoked on server")

	--- devproduct
	MarketplaceService.ProcessReceipt = function(receipt: typeof(Patronage.receiptinfo()))
		return productpurchased(Players:GetPlayerByUserId(receipt.PlayerId), { Type = "DevProduct"; Id = receipt.ProductId; })
			and Enum.ProductPurchaseDecision.PurchaseGranted
			or Enum.ProductPurchaseDecision.NotProcessedYet
	end
	--- gamepass
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, gamepassid: number, purchased: boolean)
		if not purchased then return end

		return productpurchased(player, { Type = "Gamepass"; Id = gamepassid; })
	end)
	--- bc
	Players.PlayerMembershipChanged:Connect(function(player: Player)
		membershipchanged(player, player.MembershipType)
	end)
end

--- adds userids to scoped patronage list
function Patronage.listinsert(scope: string, userids: {number})
	assert(RunService:IsServer(), "[Patronage]: Patronage.listinsert can only be called on server")

	local datastorename = Patronage.Config.Datastore
	local datastore = DataStoreService:GetDataStore(datastorename)
	assert(datastore, string.format("[Patronage]: error fetching Datastore '%s'", datastorename))

	local s, e = pcall(function()
		datastore:UpdateAsync(scope, function(list: {number}?, datastorekeyinfo: DataStoreKeyInfo)
			if not list then list = {} end
			assert(list, "this should not happen")

			for _, userid in userids do
				if not table.find(list, userid) then
					table.insert(list, userid)
				end
			end

			return list
		end)
	end)
	if not s then
		warn(`[Patronage]: Patronage.listinsert() error: {e}`)
	else
		print("[Patronage.listinsert]: Added", userids, `to patronage list "{scope}"`)
	end

	return s
end

--- removes userids from scoped patronage list
function Patronage.listremove(scope: string, userids: {number})
	assert(RunService:IsServer(), "[Patronage]: Patronage.listremove can only be called on server")

	local datastorename = Patronage.Config.Datastore
	local datastore = DataStoreService:GetDataStore(datastorename)
	assert(datastore, string.format("[Patronage]: error fetching Datastore '%s'", datastorename))

	local s, e = pcall(function()
		datastore:UpdateAsync(scope, function(list: {number}?, datastorekeyinfo: DataStoreKeyInfo)
			if not list then list = {} end
			assert(list, "this should not happen")

			for _, userid in userids do
				table.remove(list, table.find(list, userid) or 0)
			end

			return list
		end)
	end)
	if not s then
		warn(`[Patronage]: Patronage.listremove() error: {e}`)
	else
		print("[Patronage.listremove]: Removed", userids, `from patronage list "{scope}"`)
	end

	return s
end

--- deferred whenever patronage lists are updated \
--- left blank to be overwritten externally
Patronage.listsupdated = function(lists: typeof(Patronage.Lists))
	
end

if IsServer then
	local datastorename = Patronage.Config.Datastore
	if datastorename == "" then
		--- print(`[Patronage]: VIP list disabled`)
	else
		local datastore = DataStoreService:GetDataStore(datastorename)
		assert(datastore, string.format("[Patronage]: error fetching Datastore '%s'", datastorename))

		print(`[Patronage]: Using Datastore "{datastorename}"`)

		local rate = Patronage.Config.DatastoreRate
		local elapsed = rate
		RunService.Heartbeat:Connect(function(dt: number)
			elapsed += dt
			if elapsed < rate then return end
			elapsed = 0

			for _, scope in Patronage.Config.DatastoreScopes do
				if not Patronage.Lists[scope] then
					Patronage.Lists[scope] = table.create(128)
				end

				local scopetable = Patronage.Lists[scope]

				local s, e = pcall(function()
					local list = datastore:GetAsync(scope)

					if list and type(list) == "table" then
						table.clear(scopetable)
						table.move(list, 1, #list, 1, scopetable)
					end
				end)
				if not s then warn(`[Patronage]: Datastore scope "{scope}" error: {e}`) end
			end

			Patronage.__listsloaded = true

			task.defer(Patronage.listsupdated, Patronage.Lists)
		end)
	end
end

return Patronage