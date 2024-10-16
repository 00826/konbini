--!strict

--- ### Misc.luau
--- 
--- miscellaneous functions and wrappers
local Misc = {
	--- returns value normalized as a boolean
	toboolean = function(value: any): boolean
		if not value then return false end
		local t = type(value)
		return
			(t == "boolean" and value) or
			(t == "number" and value > 0) or
			(t == "string" and value ~= "") or
			(t == "vector" and value.Magnitude > 0) or
			(t == "table" and next(value) ~= nil) or
			(t == "function" and (value : -> ())()) or false
	end
}

--- ### Misc.Preload
--- 
--- ContentProvider wrapper
Misc.Preload = {
	matches = {
		"assetdelivery.roblox.com";
		"rbxassetid://";
		--- "rbxasset://";
	};

	--- returns true if value is a preload-able asset string
	canpreload = function(value: string)
		for _, partial in Misc.Preload.matches do
			if string.match(value, partial) then
				return true
			end
		end
		return false
	end;

	--- deep searches through target and inserts all `rbxassetid://` strings into assetlist
	index = function(target: {any}|Instance, assetlist: {string})
		local function insert(value: string)
			if not Misc.Preload.canpreload(value) then return end
			if table.find(assetlist, value) then return end
	
			table.insert(assetlist, value)
		end
	
		local function iter(this: {any})
			for _, value in this do
				if type(value) == "table" then
					iter(value)
					continue
				elseif typeof(value) == "Instance" then
					if value:IsA("MeshPart") then
						insert(value.MeshId)
						insert(value.TextureID)
					elseif value:IsA("SpecialMesh") then
						insert(value.MeshId)
						insert(value.TextureId)
					elseif value:IsA("Texture") then
						insert(value.Texture)
					elseif value:IsA("Decal") then
						insert(value.Texture)
					elseif value:IsA("ParticleEmitter") then
						insert(value.Texture)
					elseif value:IsA("Shirt") then
						insert(value.ShirtTemplate)
					elseif value:IsA("Pants") then
						insert(value.PantsTemplate)
					end
					iter(value:GetChildren())
				elseif type(value) == "string" then
					insert(value)
				end
			end
		end
	
		if type(target) == "table" then
			iter(target)
		elseif typeof(target) == "Instance" then
			iter(target:GetChildren())
		end
	end;

	--- `ContentProvider:PreloadAsync(assets, f)`
	async = function(assets: {any}, f: ((contentstring: string, assetfetchstatus: Enum.AssetFetchStatus) -> ())?): number
		local s = os.clock()
		game:GetService("ContentProvider"):PreloadAsync(assets, f) --- contentprovider service should only ideally be called once so its never stored as a variable on the uppermost scope
		return (os.clock() - s) * 1000
	end;
}

return Misc