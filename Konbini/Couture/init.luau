--!strict

local RunService				= game:GetService("RunService")
local IsServer					= RunService:IsServer()

local InsertService				= game:GetService("InsertService")

local Players					= game:GetService("Players")

local AccessoryPart				= script:WaitForChild("AccessoryPart")
local Weld						= script:WaitForChild("Weld")

AccessoryPart:SetAttribute("IsAccessory", true)

---### Couture.luau
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
		-- "GraphicTShirt";
		"Shirt";
		"Pants";
	};
	AssetPrefix = "rbxassetid://";
}

--- returns table of clothing ids
function Couture.readclothing(player: Player): {[string]: number}
	local couturefolder = player:FindFirstChild("CoutureFolder")
	if not couturefolder then
		return {}
	else
		local clothingids = {}
		for _, DescProperty in Couture.ClothingProperties do
			clothingids[DescProperty] = couturefolder:GetAttribute(DescProperty) :: number
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
		for _, DescProperty in Couture.BodyPartProperties do
			bodypartids[DescProperty] = couturefolder:GetAttribute(DescProperty) :: number
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
		for _, DescProperty in Couture.BodyColorProperties do
			colors[DescProperty] = couturefolder:GetAttribute(DescProperty) :: Color3
		end
		return colors
	end
end

--- returns: \
--- list of accessories or an empty table \
--- boolean if the couture folder doesn't exist
function Couture.getaccessories(player: Player): ({BasePart}, boolean)
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
	for _, Thing in character:GetChildren() do
		if Thing:GetAttribute("IsAccessory") then
			Thing:Destroy()
		end
	end
end

--- creates accessorypart from accessory instance
function Couture.frominstance(accessory: Accessory, name: string?): BasePart
	local Handle = accessory:FindFirstChild("Handle")
	assert(Handle, `{accessory} missing Handle`)

	local AccessoryAttachment = Handle:FindFirstChildOfClass("Attachment")
	local AccessoryMesh = Handle:IsA("MeshPart") and Handle or Handle:FindFirstChildOfClass("SpecialMesh") 

	assert(AccessoryAttachment, `{accessory} missing attachment`)
	assert(AccessoryMesh, `{accessory} handle not a meshpart or missing specialmesh`)

	local MeshProperties = {
		Offset = Vector3.zero;
		Scale = Vector3.one;
		VertexColor = Vector3.one;
	}

	if AccessoryMesh:IsA("SpecialMesh") then
		MeshProperties.MeshId = AccessoryMesh.MeshId
		MeshProperties.TextureId = AccessoryMesh.TextureId
		MeshProperties.Offset = AccessoryMesh.Offset
		MeshProperties.Scale = AccessoryMesh.Scale
		MeshProperties.VertexColor = AccessoryMesh.VertexColor
	elseif AccessoryMesh:IsA("MeshPart") then
		MeshProperties.MeshId = AccessoryMesh.MeshId
		MeshProperties.TextureId = AccessoryMesh.TextureID
		MeshProperties.Scale = AccessoryMesh.Size / AccessoryMesh.MeshSize
	end

	return Couture.createaccessory(name or accessory.Name,
		{
			Name = AccessoryAttachment.Name;
			CFrame = AccessoryAttachment.CFrame;
		},
		MeshProperties
	)
end

--- creates accessorypart
function Couture.createaccessory(name: string, attachment: {}, specialmesh: {}): BasePart
	local NewPart = AccessoryPart:Clone()
	NewPart.Name = name

	local AccessoryAttachment = NewPart:FindFirstChildOfClass("Attachment")
	if AccessoryAttachment then
		for Property, Value in attachment do
			AccessoryAttachment[Property] = Value
		end
	end

	local AccessoryMesh = NewPart:FindFirstChildOfClass("SpecialMesh")
	if AccessoryMesh then
		for Property, Value in specialmesh do
			AccessoryMesh[Property] = Value
		end
	end

	return NewPart
end

--- attaches accessorypart to character
function Couture.attachaccessory(character: Instance, accessorypart: BasePart, parent: Instance?): boolean
	local AccessoryAttachment = accessorypart:FindFirstChildOfClass("Attachment")
	if not AccessoryAttachment then return false end

	local RigAttachment = Couture.findattachment(character, AccessoryAttachment.Name)
	if not RigAttachment then return false end

	accessorypart.Parent = parent or character
	accessorypart.CFrame = RigAttachment.WorldCFrame * AccessoryAttachment.CFrame:Inverse()

	local W = Weld:Clone()
	W.Part0 = accessorypart
	W.Part1 = RigAttachment.Parent
	W.Parent = accessorypart

	return true
end

--- returns attachment on character
function Couture.findattachment(character: Instance, attachmentref: string): Attachment?
	for _, Thing in character:GetChildren() do
		if Thing:GetAttribute("IsAccessory") then continue end

		if Thing:IsA("BasePart") or Thing:IsA("MeshPart") then
			for _, MaybeAttachment in Thing:GetChildren() do
				if MaybeAttachment:IsA("Attachment") and MaybeAttachment.Name == attachmentref then
					return MaybeAttachment
				end
			end
		end
	end
	return
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

	local preexisting = player:FindFirstChildOfClass("HumanoidDescription")
	if preexisting then preexisting:Destroy() end

	local newdescription = Players:GetHumanoidDescriptionFromUserId(player.UserId)
	newdescription.Parent = player

	for _, DescProperty in Couture.AccessoryProperties do
		task.defer(pcall, function(humanoiddescription: HumanoidDescription, container: Instance)
			local Value = (humanoiddescription :: any)[DescProperty]
			if Value == "" then return false end

			for _, Id in Value:split(",") do
				Id = tonumber(Id)
				if not Id then continue end

				local s, e = pcall(function(assetid: number)
					local InsertModel = InsertService:LoadAsset(assetid)
					local RealAccessory = Couture.frominstance(InsertModel:FindFirstChildOfClass("Accessory"))
					InsertModel:Destroy()
					RealAccessory:SetAttribute("Type", DescProperty)
					RealAccessory.Parent = container
				end, Id)
				if not s then warn(Id, e) end
			end
			return true
		end, newdescription, couturefolder :: Folder)
	end
	for _, DescProperty in Couture.BodyColorProperties do
		task.defer(pcall, function(humanoiddescription: HumanoidDescription, container: Instance)

			container:SetAttribute(DescProperty, (humanoiddescription :: any)[DescProperty])

			return true
		end, newdescription, couturefolder :: Folder)
	end
	for _, DescProperty in Couture.BodyPartProperties do
		task.defer(pcall, function(humanoiddescription: HumanoidDescription, container: Instance)

			container:SetAttribute(DescProperty, Couture.AssetPrefix .. (humanoiddescription :: any)[DescProperty])
			
			return true
		end, newdescription, couturefolder :: Folder)
	end
	for _, DescProperty in Couture.ClothingProperties do
		task.defer(pcall, function(humanoiddescription: HumanoidDescription, container: Instance)

			container:SetAttribute(DescProperty, Couture.AssetPrefix .. (humanoiddescription :: any)[DescProperty])
			
			return true
		end, newdescription, couturefolder :: Folder)
	end

	return newdescription
end

return Couture