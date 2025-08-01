--!strict

local RunService = game:GetService("RunService")
local IsServer = RunService:IsServer()

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local DatastoreService = game:GetService("DataStoreService")
local LocalizationService = game:GetService("LocalizationService")
local MarketplaceService = game:GetService("MarketplaceService")
local PolicyService = game:GetService("PolicyService")
local HttpService = game:GetService("HttpService")

--- ### Patronage.luau
---
--- player patronage (devproducts, gamepasses, premium, group membership, global lists, etc)
local Patronage = {
	RegionFlag = "Region"; --- for external use
	PolicyFlag = "PolicyInfo"; --- for external use
}

--- returns `pcall(DatastoreService.GetDataStore, DatastoreService, name, scope, options)`
function Patronage.datastore(name: string, scope: string?, options: DataStoreGetOptions?)
	return pcall(DatastoreService.GetDataStore, DatastoreService, name, scope, options)
end

--- returns `pcall(datastore.GetAsync, datastore, key, getoptions)`
function Patronage.datastoreget(datastore: DataStore, key: string, getoptions: DataStoreGetOptions?)
	return pcall(datastore.GetAsync, datastore, key, getoptions)
end

--- returns `pcall(datastore.SetAsync, datastore, key, value, userids, datastoresetoptions)`
function Patronage.datastoreset(datastore: DataStore|OrderedDataStore, key: string, value: any, userids: {number}?, datastoresetoptions: DataStoreSetOptions?)
	return pcall(datastore.SetAsync, datastore, key, value, userids, datastoresetoptions)
end

--- returns `pcall(datastore.UpdateAsync, datastore, key, transform)`
function Patronage.datastoreupdate(datastore: DataStore|OrderedDataStore, key: string, transform: (any, DataStoreKeyInfo) -> (any, {number}?))
	return pcall(datastore.UpdateAsync, datastore, key, transform)
end

--- returns `pcall(datastore.RemoveAsync, datastore, key)`
function Patronage.datastoreremove(datastore: DataStore|OrderedDataStore, key: string)
	return pcall(datastore.RemoveAsync, datastore, key)
end

--- returns `pcall(DatastoreService.GetOrderedDataStore, DatastoreService, name, scope)`
function Patronage.getordereddatastore(name: string, scope: string?)
	return pcall(DatastoreService.GetOrderedDataStore, DatastoreService, name, scope)
end

--- returns `pcall(ordereddatastore.GetSortedAsync, ordereddatastore, ascending, pagesize, minvalue, maxvalue)`
function Patronage.ordereddatastoregetsorted(ordereddatastore: OrderedDataStore, ascending: boolean, pagesize: number, minvalue: number?, maxvalue: number?)
	return pcall(ordereddatastore.GetSortedAsync, ordereddatastore, ascending, pagesize, minvalue, maxvalue)
end

--- returns `pcall(datastorepages.AdvanceToNextPageAsync, datastorepages)`
function Patronage.datastorepagesnext(datastorepages: DataStorePages)
	return pcall(datastorepages.AdvanceToNextPageAsync, datastorepages)
end

--- returns `pcall(datastorepages.GetCurrentPage, datastorepages)`
function Patronage.datastorepagescurrent(datastorepages: DataStorePages)
	return pcall(datastorepages.GetCurrentPage, datastorepages)
end

--- returns `DatastoreService:GetRequestBudgetForRequestType(requesttype)`
function Patronage.requestbudget(requesttype: Enum.DataStoreRequestType)
	return DatastoreService:GetRequestBudgetForRequestType(requesttype)
end

--- returns `pcall(a.IsInGroup, a, groupid)`
function Patronage.isingroup(a: Player, groupid: number)
	return pcall(a.IsInGroup, a, groupid)
end

--- returns `pcall(a.IsFriendsWith, a, b.UserId)`
function Patronage.isfriendswith(a: Player, b: Player)
	return pcall(a.IsFriendsWith, a, b.UserId)
end

--- returns `pcall(LocalizationService.GetCountryRegionForPlayerAsync, LocalizationService, player)`
function Patronage.region(player: Player)
	assert(IsServer, "Patronage.region can only be called on server")

	return pcall(LocalizationService.GetCountryRegionForPlayerAsync, LocalizationService, player)
end

--- returns `pcall(PolicyService.GetPolicyInfoForPlayerAsync, PolicyService, player)`
function Patronage.policyinfo(player: Player)
	assert(IsServer, "Patronage.policyinfo can only be called on server")

	return pcall(PolicyService.GetPolicyInfoForPlayerAsync, PolicyService, player)
end

--- returns value from json-encoded policyinfo
function Patronage.policyfromjson(json: string,
	key:  "AreAdsAllowed" --- boolean; immersive ads
		| "ArePaidRandomItemsRestricted" --- boolean; lootboxes
		| "AllowedExternalLinkReferences" --- {string}; external links 
		| "IsContentSharingAllowed" --- boolean; share content off platform
		| "IsEligibleToPurchaseCommerceProduct" --- boolean; off platform commerce products
		| "IsEligibleToPurchaseSubscription" --- boolean; in-game subscriptions
		| "IsPaidItemTradingAllowed" --- boolean; item trading
		| "IsSubjectToChinaPolicies" --- boolean; great mentor, heroic leader
		| string
)
	local decoded = HttpService:JSONDecode(json)

	if type(decoded) == "table" then
		return decoded[key]
	end

	return nil
end

--- returns `pcall(MarketplaceService.GetProductInfo, MarketplaceService, id, itemtype)`
function Patronage.getproductinfo(id: number, itemtype: Enum.InfoType)
	return pcall(MarketplaceService.GetProductInfo, MarketplaceService, id, itemtype)
end

--- returns an empty minimum marketplace product
function Patronage.minproduct()
	return {
		--- devproduct or gamepass
		Type = "DevProduct" :: "DevProduct"|"Gamepass";
		--- devproduct or gamepass id
		Id = 0;
	}
end

--- prompts devproduct or gamepass purchase \
--- if called locally, `player` default to the localplayer \
--- returns, depending on product type: \
--- `product.Type == "DevProduct"`: `pcall(pcall(MarketplaceService.PromptProductPurchase, MarketplaceService, player, product.Id))` \
--- `product.Type == "Gamepass"`: `pcall(pcall(MarketplaceService.PromptGamePassPurchase, MarketplaceService, player, product.Id))`
function Patronage.promptpurchase(product: typeof(Patronage.minproduct()) & {[string]: unknown}, player: Player?)
	player = player or LocalPlayer
	assert(player, "Patronage.promptpurchase() expected Player, got", typeof(player))

	if product.Type == "DevProduct" then
		return pcall(MarketplaceService.PromptProductPurchase, MarketplaceService, player, product.Id)
	elseif product.Type == "Gamepass" then
		return pcall(MarketplaceService.PromptGamePassPurchase, MarketplaceService, player, product.Id)
	else
		error("expected product type DevProduct or Gamepass, got product type", product.Type)
	end
end

--- returns `pcall(MarketplaceService.PromptPremiumPurchase, MarketplaceService, player or LocalPlayer)`
function Patronage.promptpremiumpurchase(player: Player?)
	return pcall(MarketplaceService.PromptPremiumPurchase, MarketplaceService, player or LocalPlayer)
end

--- returns empty devproduct purchase receipt info
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
	assert(IsServer, "Patronage.receipt can only be called on server")

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

return Patronage