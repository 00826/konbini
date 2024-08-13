--!strict

--- ### Misc.luau
--- 
--- miscellaneous functions and wrappers
local Misc = {}

--- ### Misc.Preload
--- 
--- ContentProvider wrapper
Misc.Preload = {
	matches = {
		"assetdelivery.roblox.com";
		"rbxassetid://";
		--"rbxasset://";
	};
}

--- returns true if value is a preload-able asset string
function Misc.Preload.canpreload(value: string): boolean
	for _, partial in Misc.Preload.matches do
		if string.match(value, partial) then
			return true
		end
	end
	return false
end

--- deep searches through target and inserts all `rbxassetid://` strings into assetlist
function Misc.Preload.index(target: {any}|Instance, assetlist: {string})
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
end

--- `ContentProvider:PreloadAsync(a, f)`
function Misc.Preload.async(assetlist: {any}, f: ((contentstring: string, assetfetchstatus: Enum.AssetFetchStatus) -> ())?): number
	local s = os.clock()
	game:GetService("ContentProvider"):PreloadAsync(assetlist, f) -- contentprovider service should only ideally be called once so its never stored as a variable on the uppermost scope
	return (os.clock() - s) * 1000
end

--- ### Misc.Color
---
--- Color functions
Misc.Color = {}

--- returns a saturation-adjusted color
function Misc.Color.adjustsaturation(color: Color3, delta: number): Color3
	local H, S, V = color:ToHSV()
	return Color3.fromHSV(H, math.clamp(S + (delta / 100), 0, 1), V)
end

--- returns inversion of color
function Misc.Color.invert(color: Color3): Color3
	return Color3.new(1 - color.R, 1 - color.G, 1 - color.B)
end

--- returns approximate sort value of color
function Misc.Color.sortvalue(color: Color3): number
	return (color:ToHSV()) * 100
end

--- returns color as a vertexcolor
function Misc.Color.tovertexcolor(color: Color3): Vector3
	return Vector3.new(color.R, color.G, color.B) / 255
end

--- returns vertexcolor as a color3
function Misc.Color.fromvertexcolor(vertexcolor: Vector3): Color3
	vertexcolor *= 255
	return Color3.new(vertexcolor.X, vertexcolor.Y, vertexcolor.Z)
end

--- returns color3 in colorsequence at interpolant `a`
function Misc.Color.getcolorinsequence(colorsequence: ColorSequence, a: number): Color3
	local LastKeypoint = nil
	for _, Keypoint in ipairs(colorsequence.Keypoints) do
		if a < Keypoint.Time then
			local T0 = LastKeypoint.Time

			return LastKeypoint.Value:Lerp(Keypoint.Value, (a - T0) / (Keypoint.Time - T0))
		end
		LastKeypoint = Keypoint
	end
	return LastKeypoint and LastKeypoint.Value or Color3.fromRGB(255, 255, 255)
end

--- returns value normalized as a boolean
function Misc.toboolean(value: any): boolean
	if not value then return false end
	local t = type(value)
	return (t == "boolean" and value) or (t == "number" and value > 0) or (t == "string" and value ~= "") or (t == "vector" and value.Magnitude > 0) or (t == "table" and next(value) ~= nil) or (t == "function" and (value :: () -> ())()) or false
end

return Misc