--- ### Config.luau
---
--- patronage config
return table.freeze{
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
	--- unknown keys identified by Patronage.policystring() are appended to the end of this array
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
}