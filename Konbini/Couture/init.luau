--!strict

local RunService = game:GetService("RunService")
local IsServer = RunService:IsServer()

local HttpService = game:GetService("HttpService")
local InsertService = game:GetService("InsertService")

local Players = game:GetService("Players")

local AccessoryPart = script:WaitForChild("AccessoryPart")
local Weld = script:WaitForChild("Weld")

--- ### Couture.luau
---
--- the closest thing to client-authoritative accessory handling
local Couture = {
	AccessoryProperties = {
		"BackAccessory";
		"FaceAccessory";
		"FrontAccessory";
		"HairAccessory";
		"HatAccessory";
		"NeckAccessory";
		"ShouldersAccessory";
		"WaistAccessory";
	};
	BodyColorProperties = {
		"HeadColor";
		"TorsoColor";
		"LeftArmColor";
		"LeftLegColor";
		"RightArmColor";
		"RightLegColor";
	};
	BodyPartProperties = {
		"Face";
	};
	ClothingProperties = {
		"GraphicTShirt";
		"Shirt";
		"Pants";
	};
	FemaleTorsos = {
		86499666; --- r15 torso
		48474356; --- r6 torso
	};

	AssetPrefix = "rbxassetid://";
	DefaultFace = "rbxasset://textures/face.png";
	Flag = "Accessory";

	Empty = {
		Accessories = table.create(0);
		Face = "rbxasset://textures/face.png";

		HeadColor = "0xa3a2a5";
		TorsoColor = "0xa3a2a5";
		LeftArmColor = "0xa3a2a5";
		LeftLegColor = "0xa3a2a5";
		RightArmColor = "0xa3a2a5";
		RightLegColor = "0xa3a2a5";

		Shirt = "rbxassetid://0";
		Pants = "rbxassetid://0";
		GraphicTShirt = "rbxassetid://0";

		FemaleTorso = false;
	};
}

AccessoryPart:SetAttribute(Couture.Flag, true)

--- returns an `AccessoryPart` from assetid (server-only), or an empty AccessoryPart if no assetid is provided
function Couture.create(assetid: number?)
	if not assetid then
		local clone = AccessoryPart:Clone()
		clone.Name = "Accessory"
		clone.Parent = script

		return clone
	end

	assert(IsServer, "Couture.create() can only be called on server (InsertService limitation T__T)")
	local asset = InsertService:LoadAsset(assetid)

	local accessory = asset:FindFirstChildOfClass("Accessory")
	assert(accessory)
	assert(accessory:IsA("Accessory"))

	local handle = accessory:FindFirstChild("Handle") or accessory:WaitForChild("Handle")
	assert(handle)
	assert(handle:IsA("BasePart"))

	local attachment = handle:FindFirstChildOfClass("Attachment")
	assert(attachment)
	assert(attachment:IsA("Attachment"))

	handle.Name = tostring(assetid)
	handle.Locked = false
	handle.EnableFluidForces = false
	handle.CanCollide = false
	handle.CanTouch = false
	handle.CanQuery = false
	handle.Massless = true
	handle.Anchored = false
	handle.Position = Vector3.zero
	handle.Size = Vector3.one
	handle.Parent = script

	handle:SetAttribute(Couture.Flag, true)

	asset:Destroy()

	return handle
end

function Couture.folder(player: Player)
	local f = player:FindFirstChild("Couture")
	if f then
		return f
	end

	local folder = Instance.new("Folder")
	folder.Name = "Couture"
	folder.Parent = player

	return folder
end

--- attaches accessorypart to rig
function Couture.attach(rig: Instance, accessorypart: BasePart, parent: Instance?)
	local accessoryattachment = accessorypart:FindFirstChildOfClass("Attachment")
	if not accessoryattachment then return false end

	local rigattachment = Couture.findattachment(rig, accessoryattachment.Name)
	if not rigattachment then return false end

	accessorypart:SetAttribute(Couture.Flag, true)
	accessorypart.Parent = parent or rig
	accessorypart.CFrame = rigattachment.WorldCFrame * accessoryattachment.CFrame:Inverse()

	local weld = Weld:Clone()
	weld.Part0 = accessorypart
	weld.Part1 = rigattachment.Parent
	weld.Parent = accessorypart

	return true
end

--- returns attachment on rig
function Couture.findattachment(rig: Instance, attachmentref: string): Attachment?
	for _, thing in rig:GetChildren() do
		if thing:GetAttribute(Couture.Flag) then continue end

		if thing:IsA("BasePart") or thing:IsA("MeshPart") then
			for _, maybeattachment in thing:GetChildren() do
				if maybeattachment:IsA("Attachment") and maybeattachment.Name == attachmentref then
					return maybeattachment
				end
			end
		end
	end

	return
end

--- loads `AccessoryParts` from array of assetids
function Couture.load(assetids: {number}, container: Instance)
	assert(IsServer, "Couture.create() can only be called on server (InsertService limitation T__T)")

	local result = {}

	for _, assetid in assetids do
		local s, e = pcall(Couture.create, assetid)
		if not s then
			warn(e)
		else
			e.Parent = container
			table.insert(result, e)
		end
	end

	return result
end

--- returns array of `AccessoryParts` parented under `container`
function Couture.get(container: Instance, assetids: {number|string}?)
	local result = table.create(32)

	if assetids then
		for _, assetid in assetids do
			if type(assetid) == "number" then
				assetid = tostring(assetid)
			end

			local thing = container:FindFirstChild(assetid::string)
			if not thing then continue end
			if not thing:IsA("BasePart") then continue end
			if not thing:GetAttribute(Couture.Flag) then continue end

			table.insert(result, thing)
		end
	else
		local things = container:GetChildren()
	
		for _, thing in things do
			if not thing:IsA("BasePart") then continue end
			if not thing:GetAttribute(Couture.Flag) then continue end
	
			table.insert(result, thing)
		end
	end

	return result
end

--- encodes data type into a datastore-savable table
function Couture.encode(t: {[string]: any} | HumanoidDescription | Player | number | string)
	local result = {}::{[string]: any}

	if type(t) == "table" then
		for k, v in t do
			if k == "Accessories" then
				local split = string.split(v, ",")
				local array = table.create(#split)
				for _, stringid in split do
					table.insert(array, tonumber(stringid))
				end
	
				result[k] = array
	
				continue
			end
			if typeof(v) == "Color3" then
				v = "0x" .. v:ToHex()
			end
			
			result[k] = v
		end
	elseif type(t) == "string" then
		local userid = Players:GetUserIdFromNameAsync(t)
		if userid < 1 then return Couture.Empty end

		return Couture.encode(userid)
	elseif type(t) == "number" then
		if t < 1 then return Couture.Empty end

		return Couture.encode(Players:GetHumanoidDescriptionFromUserId(t))
	elseif typeof(t) == "Instance" then
		if t:IsA("HumanoidDescription") then
			do --- accessories
				local accessories = table.create(4 * #Couture.AccessoryProperties)
	
				for _, property in Couture.AccessoryProperties do
					local value = (t::any)[property] :: string
					if value ~= "" then
						for _, stringid in string.split(value, ",") do
							table.insert(accessories, tonumber(stringid))
						end
					end
				end
	
				result.Accessories = accessories
			end
	
			do --- body colors
				for _, property in Couture.BodyColorProperties do
					local value = (t::any)[property] :: Color3
					result[property] = "0x" .. value:ToHex()
				end
			end
	
			do --- body parts
				for _, property in Couture.BodyPartProperties do
					local value = (t::any)[property] :: number
	
					if (property == "Face")
					and (value == 0)
					then
						result[property] = Couture.DefaultFace
						continue
					end

					if property == "Face" then
						local insertmodel = InsertService:LoadAsset(value)
						local thing = insertmodel:FindFirstChildOfClass("Decal")
						if thing then
							result[property] = thing.Texture
							
							insertmodel:Destroy()
						end
						continue
					end
	
					result[property] = Couture.AssetPrefix .. tostring(value)
				end
			end

			do --- clothing
				for _, property in Couture.ClothingProperties do
					local value = (t::any)[property] :: number
					if value == 0 then
						result[property] = Couture.AssetPrefix .. "0"
						continue
					end

					local insertmodel = InsertService:LoadAsset(value)
					local thing = insertmodel:FindFirstChildOfClass("Shirt") or insertmodel:FindFirstChildOfClass("Pants") or insertmodel:FindFirstChildOfClass("ShirtGraphic")
					if thing then
						if thing:IsA("Shirt") then
							result[property] = Couture.AssetPrefix .. (string.match(thing.ShirtTemplate, "%d+") or "0")
						elseif thing:IsA("Pants") then
							result[property] = Couture.AssetPrefix .. (string.match(thing.PantsTemplate, "%d+") or "0")
						elseif thing:IsA("ShirtGraphic") then
							result[property] = Couture.AssetPrefix .. (string.match(thing.Graphic, "%d+") or "0")
						end

						insertmodel:Destroy()
					else
						warn(`shirt or pants or shirtgraphic not found (classname "{thing.ClassName}")`)
					end
				end
			end
	
			do --- female torso
				result.FemaleTorso = table.find(Couture.FemaleTorsos, t.Torso) ~= nil
			end
		elseif t:IsA("Player") then
			if t.UserId < 1 then
				return Couture.Empty
			end

			return Couture.encode(Players:GetHumanoidDescriptionFromUserId(t.UserId))
		end
	end

	return result
end

--- decodes encoded table from `Couture.encode`
function Couture.decode(t: {[string]: any})
	local result = {}::{[string]: any}

	for k, v in t do
		if k == "Accessories" then
			result[k] = table.concat(v, ",")

			continue
		end
		if table.find(Couture.BodyColorProperties, k) then
			local num = tonumber(v)
			if num and num <= 16777215 then --- 0xFFFFFF
				result[k] = Color3.fromHex(string.gsub(v, "0x", "")::string)

				continue
			end
		end

		result[k] = v
	end

	return result
end

function Couture.tostringjson(t: {[string]: any})
	return HttpService:JSONEncode(t)
end

function Couture.totablejson(s: string)
	return HttpService:JSONDecode(s)
end

return Couture