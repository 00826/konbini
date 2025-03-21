return {
	Name = "PlayerData";
	SaveKey = "_1a";

	--- keys that are replicated via Data.sync
	SyncKeys = table.freeze{
		"Slots";

		"Outfits";
		"Bank";

		"Crew";
	} :: {string};
}