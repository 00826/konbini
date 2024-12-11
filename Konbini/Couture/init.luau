--!strict

local RunService = game:GetService("RunService")
local IsServer = RunService:IsServer()

local InsertService = game:GetService("InsertService")

local Players = game:GetService("Players")

local AccessoryPart = script:WaitForChild("AccessoryPart")
local Weld = script:WaitForChild("Weld")

AccessoryPart:SetAttribute("IsAccessory", true)

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
		--- "GraphicTShirt";
		"Shirt";
		"Pants";
	};
	FemaleTorsos = {
		86499666; --- r15 torso
		48474356; --- r6 torso
	};
	AssetPrefix = "rbxassetid://";
}

--- returns table of clothing ids
function Couture.readclothing(player: Player): {[string]: string}
	local couturefolder = player:FindFirstChild("CoutureFolder")
	if not couturefolder then
		return {}
	else
		local clothingids = {}
		for _, descproperty in Couture.ClothingProperties do
			clothingids[descproperty] = couturefolder:GetAttribute(descproperty) :: string
		end
		return clothingids
	end
end

--- returns table of body part ids
function Couture.readbodyparts(player: Player): {[string]: number}
	local couturefolder = player:FindFirstChild("CoutureFolder")
	if not couturefolder then
		return {}
	else
		local bodypartids = {}
		for _, descproperty in Couture.BodyPartProperties do
			bodypartids[descproperty] = couturefolder:GetAttribute(descproperty) :: number
		end
		return bodypartids
	end
end

--- returns table of body colors
function Couture.readbodycolors(player: Player): {[string]: Color3}
	local couturefolder = player:FindFirstChild("CoutureFolder")
	if not couturefolder then
		return {}
	else
		local colors = {}
		for _, descproperty in Couture.BodyColorProperties do
			colors[descproperty] = couturefolder:GetAttribute(descproperty) :: Color3
		end
		return colors
	end
end

--- returns: \
--- list of accessories or an empty table \
--- boolean if the couture folder doesn't exist
function Couture.readaccessories(player: Player): ({BasePart}, boolean)
	local couturefolder = player:FindFirstChild("CoutureFolder")
	if not couturefolder then
		return table.create(0), false
	else
		return couturefolder:GetChildren() :: any, true
	end
end

--- adds accessories to character, parented to optional container \
--- accessories passed are cloned
function Couture.addaccessories(character: Instance, accessoryparts: {BasePart}, container: Folder?)
	for _, accessorypart in accessoryparts do
		Couture.attachaccessory(character, accessorypart:Clone(), container)
	end
end

--- clears accessories stored in character
function Couture.clearaccessories(character: Instance)
	for _, thing in character:GetChildren() do
		if thing:GetAttribute("IsAccessory") then
			thing:Destroy()
		end
	end
end

--- creates accessorypart from accessory instance
function Couture.frominstance(accessory: Accessory, name: string?)
	local handle = accessory:FindFirstChild("Handle")
	assert(handle, `{accessory} missing Handle`)

	local accessoryattachment = handle:FindFirstChildOfClass("Attachment")
	local accessorymesh = handle:IsA("MeshPart") and handle or handle:FindFirstChildOfClass("SpecialMesh") 

	assert(accessoryattachment, `{accessory} missing attachment`)
	assert(accessorymesh, `{accessory} handle not a meshpart or missing specialmesh`)

	local meshproperties = {
		Offset = Vector3.zero;
		Scale = Vector3.one;
		VertexColor = Vector3.one;
	}

	if accessorymesh:IsA("SpecialMesh") then
		meshproperties.MeshId = accessorymesh.MeshId
		meshproperties.TextureId = accessorymesh.TextureId
		meshproperties.Offset = accessorymesh.Offset
		meshproperties.Scale = accessorymesh.Scale
		meshproperties.VertexColor = accessorymesh.VertexColor
	elseif accessorymesh:IsA("MeshPart") then
		meshproperties.MeshId = accessorymesh.MeshId
		meshproperties.TextureId = accessorymesh.TextureID
		meshproperties.Scale = accessorymesh.Size / accessorymesh.MeshSize
	end

	return Couture.createaccessory(name or accessory.Name,
		{
			Name = accessoryattachment.Name;
			CFrame = accessoryattachment.CFrame;
		},
		meshproperties
	)
end

--- creates accessorypart
function Couture.createaccessory(name: string, attachment: {}, specialmesh: {})
	local newpart = AccessoryPart:Clone()
	newpart.Name = "Couture__" .. name

	local accessoryattachment = newpart:FindFirstChildOfClass("Attachment")
	if accessoryattachment then
		for Property, Value in attachment do
			accessoryattachment[Property] = Value
		end
	end

	local accessorymesh = newpart:FindFirstChildOfClass("SpecialMesh")
	if accessorymesh then
		for Property, Value in specialmesh do
			accessorymesh[Property] = Value
		end
	end

	return newpart
end

--- attaches accessorypart to character
function Couture.attachaccessory(character: Instance, accessorypart: BasePart, parent: Instance?)
	local accessoryattachment = accessorypart:FindFirstChildOfClass("Attachment")
	if not accessoryattachment then return false end

	local rigattachment = Couture.findattachment(character, accessoryattachment.Name)
	if not rigattachment then return false end

	accessorypart.Parent = parent or character
	accessorypart.CFrame = rigattachment.WorldCFrame * accessoryattachment.CFrame:Inverse()

	local weld = Weld:Clone()
	weld.Part0 = accessorypart
	weld.Part1 = rigattachment.Parent
	weld.Parent = accessorypart

	return true
end

--- returns attachment on character
function Couture.findattachment(character: Instance, attachmentref: string): Attachment?
	for _, thing in character:GetChildren() do
		if thing:GetAttribute("IsAccessory") then continue end

		if thing:IsA("BasePart") or thing:IsA("MeshPart") then
			for _, MaybeAttachment in thing:GetChildren() do
				if MaybeAttachment:IsA("Attachment") and MaybeAttachment.Name == attachmentref then
					return MaybeAttachment
				end
			end
		end
	end
	return
end

--- returns if player avatar is wearing a female torso with respect to `Couture.FemaleTorsos`
function Couture.isusingfemaletorso(player: Player)
	local couturefolder = player:FindFirstChild("CoutureFolder")
	if couturefolder then
		return couturefolder:GetAttribute("UseFemaleTorso") == true
	end
	return false
end

--- applies player appearance to couture folder, creating relevant instances (couturefolder, humanoiddescription) if they do not already exist
function Couture.refresh(player: Player): HumanoidDescription
	assert(IsServer)

	local couturefolder = player:FindFirstChild("CoutureFolder")
	if not couturefolder then
		couturefolder = Instance.new("Folder")
		assert(couturefolder)
		couturefolder.Name = "CoutureFolder"
		couturefolder.Parent = player
	else
		couturefolder:ClearAllChildren()
	end
	assert(couturefolder)

	if player.UserId < 1 then
		local desc = Instance.new("HumanoidDescription")
		desc.Parent = player
		return desc
	end

	local preexisting = player:FindFirstChildOfClass("HumanoidDescription")
	if preexisting then preexisting:Destroy() end

	local newdescription = Players:GetHumanoidDescriptionFromUserId(player.UserId)
	newdescription.Parent = player

	local remaining = table.create(
		#Couture.AccessoryProperties +
		#Couture.BodyColorProperties +
		#Couture.BodyPartProperties +
		#Couture.ClothingProperties
	)

	table.move(Couture.AccessoryProperties, 1, #Couture.AccessoryProperties, #remaining + 1, remaining)
	table.move(Couture.BodyColorProperties, 1, #Couture.BodyColorProperties, #remaining + 1, remaining)
	table.move(Couture.BodyPartProperties, 1, #Couture.BodyPartProperties, #remaining + 1, remaining)
	table.move(Couture.ClothingProperties, 1, #Couture.ClothingProperties, #remaining + 1, remaining)
	
	task.defer(function()
		for _, descproperty in Couture.AccessoryProperties do
			pcall(function(humanoiddescription: HumanoidDescription, container: Instance)
				local value = (humanoiddescription :: any)[descproperty]
				if value == "" then return false end
	
				for _, Id in value:split(",") do
					Id = tonumber(Id)
					if not Id then continue end
	
					local s, e = pcall(function(assetid: number)
						local insertmodel = InsertService:LoadAsset(assetid)
						local realaccessory = Couture.frominstance(insertmodel:FindFirstChildOfClass("Accessory"))
						insertmodel:Destroy()
						realaccessory:SetAttribute("Type", descproperty)
						realaccessory.Parent = container
					end, Id)
					if not s then warn(Id, e) end
				end
				return true
			end, newdescription, couturefolder)

			table.remove(remaining, table.find(remaining, descproperty) or 0)
		end
	end)
	task.defer(function()
		for _, descproperty in Couture.BodyColorProperties do
			pcall(function(humanoiddescription: HumanoidDescription, container: Instance)
	
				container:SetAttribute(descproperty, (humanoiddescription :: any)[descproperty])
	
				return true
			end, newdescription, couturefolder)

			table.remove(remaining, table.find(remaining, descproperty) or 0)
		end
	end)
	task.defer(function()
		for _, descproperty in Couture.BodyPartProperties do
			pcall(function(humanoiddescription: HumanoidDescription, container: Instance)
	
				container:SetAttribute(descproperty, Couture.AssetPrefix .. (humanoiddescription :: any)[descproperty])
				
				return true
			end, newdescription, couturefolder)

			table.remove(remaining, table.find(remaining, descproperty) or 0)
		end
	end)
	task.defer(function()
		for _, descproperty in Couture.ClothingProperties do
			pcall(function(humanoiddescription: HumanoidDescription, container: Instance)
				local insertmodel = InsertService:LoadAsset((humanoiddescription :: any)[descproperty])
				local shirtorpants = insertmodel:FindFirstChildOfClass("Shirt") or insertmodel:FindFirstChildOfClass("Pants")
				if shirtorpants then
					if shirtorpants:IsA("Shirt") then
						container:SetAttribute(descproperty, Couture.AssetPrefix .. (string.match(shirtorpants.ShirtTemplate, "%d+") or "0"))
					elseif shirtorpants:IsA("Pants") then
						container:SetAttribute(descproperty, Couture.AssetPrefix .. (string.match(shirtorpants.PantsTemplate, "%d+") or "0"))
					end
					insertmodel:Destroy()
				else
					warn("shirt or pants not found")
				end
				
				return true
			end, newdescription, couturefolder)

			table.remove(remaining, table.find(remaining, descproperty) or 0)
		end
	end)
	task.defer(function()
		if table.find(Couture.FemaleTorsos, newdescription.Torso) then
			couturefolder:SetAttribute("UseFemaleTorso", true)
		else
			couturefolder:SetAttribute("UseFemaleTorso", false)
		end
	end)

	repeat task.wait() until #remaining == 0

	return newdescription
end

return Couture