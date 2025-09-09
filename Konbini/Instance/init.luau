--!strict

local RunService = game:GetService("RunService")
local IsServer = RunService:IsServer()

local InsertService = game:GetService("InsertService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local AccessoryPart = script:WaitForChild("AccessoryPart")
local Animation = script:WaitForChild("Animation")
local BallSocketConstraint = script:WaitForChild("BallSocketConstraint")
local Motor6D = script:WaitForChild("Motor6D")
local RigidConstraint = script:WaitForChild("RigidConstraint")
local SoundPart = script:WaitForChild("SoundPart")
local Weld = script:WaitForChild("Weld")

export type MoverClass =
	| "BodyGyro"
	| "BodyVelocity"
	| "BodyPosition"

--- ### Instance.luau
---
--- Instance library extension
local InstanceK = {
	Movers = script:WaitForChild("Movers");

	AccessoryFlag = "Accessory";
	AppearanceFlag = "AppearanceDescription";
	AppearanceMap = {
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
		ClothingColorProperties = {
			"ShirtColor";
			"PantsColor"
		};
		BodyPartProperties = {
			"Face";
		};
		ClothingProperties = {
			"GraphicTShirt";
			"Shirt";
			"Pants";
		};
		GirlTorsos = {
			86499666; --- r15 torso
			48474356; --- r6 torso
		};
		DefaultFace = "rbxasset://textures/face.png";
	};

	DebouncePrefix = "__d_";
}

AccessoryPart:SetAttribute(InstanceK.AccessoryFlag, true)

--- equivalent to `TweenService:Create(object, TweenInfo.new(time, style(?=Enum.EasingStyle.Linear) ...), properties):Play()` \
--- `...[1]`: `Enum.EasingDirection` \
--- `...[2...]`: (remainder of `TweenInfo.new()` args)
function InstanceK.tween(object: Instance, properties: {[string]: any}, time: number, style: Enum.EasingStyle?, ...)
	TweenService:Create(object, TweenInfo.new(time, style or Enum.EasingStyle.Linear, ...), properties):Play()
end

--- `fov(?=70)` \
--- `name(?="Camera")`
function InstanceK.camera(cframe: CFrame, fov: number?, name: string?)
	local camera = Instance.new("Camera")
	camera.CFrame = cframe
	camera.FieldOfView = fov or 70
	camera.Name = name or "Camera"
	camera.Parent = workspace

	return camera
end

--- applies attribute debounce to instance, returning true if debounce passes \
--- if `time` is nil, the debounce attribute is reset and the function will return true
function InstanceK.debounce(thing: Instance, name: string, now: number?, time: number?)
	if time then
		assert(now, "'now' must be passed if time ~= nil")
		local later = thing:GetAttribute(InstanceK.DebouncePrefix .. name) or 0
		if later < now then
			thing:SetAttribute(InstanceK.DebouncePrefix .. name, now + time)

			return true
		else
			return false
		end
	else
		thing:SetAttribute(InstanceK.DebouncePrefix .. name, nil)
		return true
	end
end

--- welds b to a at offset \
--- `a`: "root" part \
--- `b`: "loose" part \
--- `offset: (?=CFrame.identity)`: `b.CFrame = a.CFrame * offset` \
--- `force:` `b.CFrame = force`
function InstanceK.weld(a: BasePart, b: BasePart, offset: CFrame?, force: CFrame?)
	local newweld = Weld:Clone()
	if force then
		b.CFrame = force
	else
		b.CFrame = a.CFrame * (offset or CFrame.identity)
	end
	newweld.Part0 = b
	newweld.Part1 = a
	newweld.Parent = b

	return newweld
end

--- emits sound at optional position or instance
function InstanceK.emitsound(sound: Sound, at: (Vector3|Instance)?, playbackspeed: number?, timeposition: number?)
	if typeof(at) == "Instance" then
		local real: BasePart? = nil
		if at:IsA("BasePart") then
			real = at
		elseif at:IsA("Model") then
			real = at.PrimaryPart
		else
			assert(`{at.ClassName} {at}`)
		end
		assert(real)

		local newsound = sound:Clone()
		newsound.Parent = real
		newsound.PlaybackSpeed = playbackspeed or 1
		newsound.TimePosition = timeposition or 0
		newsound.PlayOnRemove = false

		newsound.Stopped:Once(function()
			newsound:Destroy()
		end)
		newsound.Ended:Once(function()
			newsound:Destroy()
		end)

		newsound:Play()

		return newsound
	elseif typeof(at) == "Vector3" then
		local newpart = SoundPart:Clone()
		newpart.Position = at
		newpart.Parent = workspace

		local newsound = sound:Clone()
		newsound.Parent = newpart
		newsound.PlaybackSpeed = playbackspeed or 1
		newsound.TimePosition = timeposition or 0
		newsound.PlayOnRemove = true
		
		newpart:Destroy()

		return newsound
	else
		local newsound = sound:Clone()
		newsound.Parent = script
		newsound.PlaybackSpeed = playbackspeed or 1
		newsound.TimePosition = timeposition or 0
		newsound.PlayOnRemove = true

		newsound:Destroy()

		return newsound
	end
end

--- memory-safe `Player:LoadCharacter()`
function InstanceK.loadcharacter(player: Player, description: HumanoidDescription?)
	if player.Character then
		player.Character:Destroy()
		player.Character = nil

		player.PlayerGui:ClearAllChildren()
	end
	if IsServer then
		if description then
			player:LoadCharacterWithHumanoidDescription(description)
		else
			player:LoadCharacter()
		end
	end
end

--- ragdolls motors contained in target \
--- motors must be owned by the current calling environment
function InstanceK.ragdoll(target: Model, state: boolean, motors: {string}?)
	if state == true then
		assert(motors, "expected motor target list")
		for _, motor6d in target:GetDescendants() do
			if motor6d:IsA("Motor6D") and table.find(motors, motor6d.Name) then
				if not motor6d.Part1 then warn(`motor6d {motor6d} no part0`); continue end

				motor6d.Part1:SetAttribute("MotorName", motor6d.Name)
				motor6d.Part1:SetAttribute("MotorVelocity", motor6d.MaxVelocity)
				local socket = BallSocketConstraint:Clone()
				local A0, A1 = Instance.new("Attachment"), Instance.new("Attachment")
				A0.Parent = motor6d.Part0
				A1.Parent = motor6d.Part1

				socket.Attachment0 = A0
				socket.Attachment1 = A1

				A0.CFrame = motor6d.C0
				A1.CFrame = motor6d.C1

				socket.Parent = motor6d.Parent

				motor6d:Destroy()
			end
		end
	elseif state == false then
		for _, ballsocket in target:GetDescendants() do
			if ballsocket:IsA("BallSocketConstraint") then
				if not ballsocket.Attachment0 then warn(`ballsocket {ballsocket} no attachment0`); continue end
				if not ballsocket.Attachment1 then warn(`ballsocket {ballsocket} no attachment1`); continue end

				ballsocket.UpperAngle = 0
				ballsocket.TwistUpperAngle = 0
				ballsocket.TwistLowerAngle = 0

				local motor6d = Motor6D:Clone()
				motor6d.Part0 = ballsocket.Attachment0.Parent
				motor6d.Part1 = ballsocket.Attachment1.Parent
				motor6d.C0 = ballsocket.Attachment0.CFrame
				motor6d.C1 = ballsocket.Attachment1.CFrame
				motor6d.Name = motor6d.Part1:GetAttribute("MotorName")
				motor6d.MaxVelocity = motor6d.Part1:GetAttribute("MotorVelocity")
				motor6d.Parent = ballsocket.Parent

				ballsocket.Attachment0:Destroy()
				ballsocket.Attachment1:Destroy()
				ballsocket:Destroy()
			end
		end
	end
end

--- sets collision group of baseparts under target
function InstanceK.setcollisiongroup(target: Instance, collisiongroup: string)
	for _, thing in target:GetDescendants() do
		if thing:IsA("BasePart") then
			thing.CollisionGroup = collisiongroup
		end
	end
end

--- applies bodymover to primarypart of target \
--- *in contexts where `time` is omitted, the bodymover will remain indefinitely*
function InstanceK.bodymover(target: Model|BasePart, class: MoverClass, time: number?, properties: {[string]: any}?): BodyMover?
	local rootpart
	if target:IsA("Model") then
		rootpart = target.PrimaryPart
	else
		rootpart = target
	end
	assert(rootpart, string.format("'%s' has no primarypart", target.Name))

	local newmover = InstanceK.Movers:FindFirstChildOfClass(class):Clone()

	if properties then
		for k, v in properties do
			newmover[k] = v
		end
	end

	if time then
		task.delay(time, newmover.Destroy, newmover)
	end

	newmover.Parent = rootpart
	return newmover
end

--- clears bodymovers from primarypart of target
function InstanceK.bodymoverclear(target: Model|BasePart, class: MoverClass)
	local rootpart
	if target:IsA("Model") then
		rootpart = target.PrimaryPart
	else
		rootpart = target
	end
	assert(rootpart, string.format("'%s' has no primarypart", target.Name))

	for _, thing in rootpart:GetChildren() do
		if thing.ClassName == class then
			thing:Destroy()
		end
	end
end

--- creates an `Animation` instance with its `AnimationId` property set to `id`
function InstanceK.createanimationfromid(id: string)
	local a = Animation:Clone()
	a.AnimationId = id
	a.Parent = script

	return a
end

--- plays animation
function InstanceK.playanimation(animator: Animator, animation: Animation, priority: Enum.AnimationPriority?, speed: number?, fadetime: number?, weight: number?)
	local animtrack = animator:LoadAnimation(animation)
	animtrack:Play(fadetime or Animation.FadeTime, weight, speed)
	animtrack.Priority = priority or Enum.AnimationPriority.Action

	return animtrack
end

--- adjusts animationtrack speed to fit *played* time \
--- `speed = tracklength / time`
function InstanceK.animationfitplayed(animtrack: AnimationTrack, time: number)
	animtrack:AdjustSpeed(animtrack.Length / time)
end

--- adjusts animationtrack speed to fit *remaining* time \
--- `speed = (tracklength - tracktime) / time`
function InstanceK.animationfitremaining(animtrack: AnimationTrack, time: number)
	animtrack:AdjustSpeed((animtrack.Length - animtrack.TimePosition) / time)
end

--- creates an animation controller
function InstanceK.createanimationcontroller(animator: Animator)
	return {
		Animator = animator;
		Priority = Enum.AnimationPriority.Action;
		FadeTime = 1/24;

		AnimationTrack = nil :: AnimationTrack?;

		KeyframeReached = nil :: (keyframe: string) -> ()?;
		KeyframeReachedConnection = nil :: RBXScriptConnection?;
	}
end

--- plays animation wrt animationcontroller
function InstanceK.animationcontrollerplay(ac: typeof(InstanceK.createanimationcontroller(...)), animation: Animation?, priority: Enum.AnimationPriority?, speed: number?, fadetime: number?, weight: number?)
	if ac.KeyframeReachedConnection then
		ac.KeyframeReachedConnection:Disconnect()
		ac.KeyframeReachedConnection = nil
	end
	if ac.AnimationTrack then
		ac.AnimationTrack:Stop(fadetime or ac.FadeTime)
		ac.AnimationTrack = nil
	end

	if animation ~= nil then
		local animtrack = ac.Animator:LoadAnimation(animation)
		ac.AnimationTrack = animtrack
		ac.KeyframeReachedConnection = animtrack.KeyframeReached:Connect(function(...)
			if ac.KeyframeReached then
				ac.KeyframeReached(...)
			end
		end)

		animtrack:Play(fadetime or ac.FadeTime, weight, speed)
		animtrack.Priority = priority or ac.Priority
	end

	return ac.AnimationTrack
end

--- returns `true` if animationcontroller's animationtrack can be overridden by a mismatching animation
function InstanceK.animationcontrollerevaluate(ac: typeof(InstanceK.createanimationcontroller(...)), animation: Animation?)
	local animtrack = ac.AnimationTrack

	if animtrack == nil then
		return true
	else
		return animtrack.Animation ~= animation
	end
end

--- return `true` if `thing` has a `LocalTransparencyModifier` property
function InstanceK.istransparencymodifiable(thing: Instance)
	if thing:IsA("BasePart") then
		return true
	elseif thing:IsA("Decal") then
		return true
	elseif thing:FindFirstAncestorOfClass("Tool") then
		return false
	end

	return false
end

--- creates a transparency controller using localtransparencymodifier
function InstanceK.createtransparencycontroller(thing: Instance)
	local things = thing:GetDescendants()
	local controller = {
		Rig = thing;

		TargetTransparency = 0;
		RealTransparency = 0;

		Disconnected = false;
		Cache = table.create(#things);
		DescendantAdded = nil :: RBXScriptConnection?;
		DescendantRemoving = nil :: RBXScriptConnection?;
	}

	for _, thisthing in things do
		if InstanceK.istransparencymodifiable(thisthing) then
			table.insert(controller.Cache, thisthing)
		end
	end

	controller.DescendantAdded = thing.DescendantAdded:Connect(function(thisthing: any)
		if InstanceK.istransparencymodifiable(thisthing) and not table.find(controller.Cache, thisthing) then
			table.insert(controller.Cache, thisthing)
			thisthing.LocalTransparencyModifier = controller.RealTransparency
		end
	end)
	controller.DescendantRemoving = thing.DescendantRemoving:Connect(function(thisthing: any)
		if InstanceK.istransparencymodifiable(thisthing) then
			table.remove(controller.Cache, table.find(controller.Cache, thisthing) or 0)
		end
	end)

	controller.Disconnect = function()
		controller.Disconnected = true
		if controller.DescendantAdded then
			controller.DescendantAdded:Disconnect()
		end
		if controller.DescendantRemoving then
			controller.DescendantRemoving:Disconnect()
		end

		table.clear(controller)
	end

	return controller
end

--- refreshes `LocalTransparencyModifier` of instances associated with `TransparencyController`
function InstanceK.transparencycontrollerstep(tc: typeof(InstanceK.createtransparencycontroller(...)))
	if tc.Disconnected then return false end

	local target = tc.TargetTransparency
	if target ~= tc.RealTransparency then
		for _, thing: any in tc.Cache do
			thing.LocalTransparencyModifier = target
		end
		tc.RealTransparency = target

		return true
	end

	return false
end

--- encodes data type into an appearance description table (datastore-friendly)
function InstanceK.createappearancedescription(t: {[string]: any} | HumanoidDescription | Player | number | string)
	local appearancemap = InstanceK.AppearanceMap
	
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
				v = v:ToHex()
			end
			
			result[k] = v
		end
	elseif type(t) == "string" then
		local userid = Players:GetUserIdFromNameAsync(t)
		if userid < 1 then return InstanceK.emptydescription() end

		return InstanceK.createappearancedescription(userid)
	elseif type(t) == "number" then
		if t < 1 then return InstanceK.emptydescription() end

		return InstanceK.createappearancedescription(Players:GetHumanoidDescriptionFromUserId(t))
	elseif typeof(t) == "Instance" then
		if t:IsA("HumanoidDescription") then
			do --- accessories
				local accessories = table.create(4 * #appearancemap.AccessoryProperties)
	
				for _, property in appearancemap.AccessoryProperties do
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
				for _, property in appearancemap.BodyColorProperties do
					local value = (t::any)[property] :: Color3
					result[property] = value:ToHex()
				end
			end
	
			do --- body parts
				for _, property in appearancemap.BodyPartProperties do
					local value = (t::any)[property] :: number
	
					if (property == "Face")
					and (value == 0)
					then
						result[property] = appearancemap.DefaultFace
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
	
					result[property] = "rbxassetid://" .. tostring(value)
				end
			end

			do --- clothing
				for _, property in appearancemap.ClothingProperties do
					local value = (t::any)[property] :: number
					if value == 0 then
						result[property] = "rbxassetid://0"
						continue
					end

					local insertmodel = InsertService:LoadAsset(value)
					local thing = insertmodel:FindFirstChildOfClass("Shirt") or insertmodel:FindFirstChildOfClass("Pants") or insertmodel:FindFirstChildOfClass("ShirtGraphic")
					if thing then
						if thing:IsA("Shirt") then
							result[property] = "rbxassetid://" .. (string.match(thing.ShirtTemplate, "%d+") or "0")
						elseif thing:IsA("Pants") then
							result[property] = "rbxassetid://" .. (string.match(thing.PantsTemplate, "%d+") or "0")
						elseif thing:IsA("ShirtGraphic") then
							result[property] = "rbxassetid://" .. (string.match(thing.Graphic, "%d+") or "0")
						end

						insertmodel:Destroy()
					else
						warn(`shirt or pants or shirtgraphic not found (classname "{thing.ClassName}")`)
					end
				end
			end
	
			do --- female torso
				result.GirlTorso = table.find(appearancemap.GirlTorsos, t.Torso) ~= nil
			end
		elseif t:IsA("Player") then
			if t.UserId < 1 then
				return InstanceK.emptydescription()
			end

			return InstanceK.createappearancedescription(Players:GetHumanoidDescriptionFromUserId(t.UserId))
		end
	end

	return result
end

--- decodes appearance description table 
function InstanceK.decodeappearancedescription(a: typeof(InstanceK.createappearancedescription(...)))
	local appearancemap = InstanceK.AppearanceMap

	local result = {}::{[string]: any}

	for k, v in a::{[string]: any} do
		if k == "Accessories" then
			result[k] = table.concat(v, ",")

			continue
		end
		if table.find(appearancemap.BodyColorProperties, k) or table.find(appearancemap.ClothingColorProperties, k) then
			local num = tonumber(v, 16)
			if num and num <= 16777215 then
				result[k] = Color3.fromHex(v)

				continue
			end
		end

		result[k] = v
	end

	return result
end

--- attaches basepart to instance \
--- assumes that both basepart and instance have an attachment instance with matching names
function InstanceK.attach(instance: Instance, basepart: BasePart, parent: Instance?)
	local accessoryattachment = basepart:FindFirstChildOfClass("Attachment")
	if not accessoryattachment then return false end

	local rigattachment = InstanceK.findattachment(instance, accessoryattachment.Name)
	if not rigattachment then return false end

	basepart:SetAttribute(InstanceK.AccessoryFlag, true)
	basepart.Parent = parent or instance

	local constraint = RigidConstraint:Clone()
	constraint.Parent = basepart
	constraint.Attachment0 = rigattachment
	constraint.Attachment1 = accessoryattachment

	return true
end

--- returns attachment in instance
function InstanceK.findattachment(instance: Instance, name: string): Attachment?
	for _, thing in instance:GetChildren() do
		if thing:GetAttribute(InstanceK.AccessoryFlag) then continue end

		if thing:IsA("BasePart") or thing:IsA("MeshPart") then
			for _, maybeattachment in thing:GetChildren() do
				if maybeattachment:IsA("Attachment") and maybeattachment.Name == name then
					return maybeattachment
				end
			end
		end
	end

	return
end

--- returns an `AccessoryPart` from assetid (server-only), or an empty AccessoryPart if no assetid is provided
function InstanceK.createaccessory(assetid: number?)
	if not assetid then
		local clone = AccessoryPart:Clone()
		clone.Name = "Accessory"
		clone.Parent = script

		return clone
	end

	assert(IsServer, "InstanceK.createaccessory() can only be called on server (InsertService limitation T__T)")
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

	handle:SetAttribute(InstanceK.AccessoryFlag, true)

	asset:Destroy()

	return handle
end

--- returns an empty appearance description
function InstanceK.emptydescription()
	return {
		Accessories = table.create(0);
		Face = "rbxasset://textures/face.png";

		HeadColor = "a3a2a5";
		TorsoColor = "a3a2a5";
		LeftArmColor = "a3a2a5";
		LeftLegColor = "a3a2a5";
		RightArmColor = "a3a2a5";
		RightLegColor = "a3a2a5";

		Shirt = "rbxassetid://0";
		Pants = "rbxassetid://0";
		GraphicTShirt = "rbxassetid://0";

		GirlTorso = false;
	};
end

--- creates a zone
function InstanceK.createzone(root: Instance)
	local z = {
		Model = root;

		LoadContainer = workspace;
		OffloadContainer = script;

		Queue = table.create(#root:GetChildren());

		Instances = root:GetChildren();
		InstanceAddedConnection = nil :: RBXScriptConnection?;

		ReparentConnection = nil :: RBXScriptConnection?;
		ReparentRate = 2;
	}

	z.InstanceAddedConnection = root.ChildAdded:Connect(function(thing: Instance)
		if not table.find(z.Instances, thing) then
			table.insert(z.Instances, thing)
			table.insert(z.Queue, thing)
		end
	end)

	return z
end

--- loads zone instances into loadcontainer
function InstanceK.zoneload(z: typeof(InstanceK.createzone(...)), callback: (Instance, number, number) -> ()?)
	InstanceK.zonereparent(z, z.LoadContainer, callback)
end

--- offloads zone instances into offloadcontainer
function InstanceK.zoneoffload(z: typeof(InstanceK.createzone(...)), callback: (Instance, number, number) -> ()?)
	InstanceK.zonereparent(z, z.OffloadContainer, callback)
end

--- reparents zone instances into container
function InstanceK.zonereparent(z: typeof(InstanceK.createzone(...)), container: Instance, callback: (Instance, number, number) -> ()?)
	if z.ReparentConnection then z.ReparentConnection:Disconnect() end
	z.ReparentConnection = nil

	table.clear(z.Queue)
	table.move(z.Instances, 1, #z.Instances, 1, z.Queue)
	local x, y = 0, #z.Queue

	z.ReparentConnection = RunService.Heartbeat:Connect(function(dt)
		for i = 1, z.ReparentRate do
			local thing = table.remove(z.Queue)

			if thing then
				if not thing:IsDescendantOf(container) then
					thing.Parent = container
				end

				x += 1
				if callback then
					task.defer(callback, thing, x, y)
				end
			else
				if z.ReparentConnection then z.ReparentConnection:Disconnect() end
				z.ReparentConnection = nil
			end
		end
	end)
end

--- `return pcall(contentprovider.PreloadAsync, contentprovider, assets, f)`
function InstanceK.preloadasync(assets: {any}, f: ((contentstring: string, assetfetchstatus: Enum.AssetFetchStatus) -> ())?)
	local contentprovider = game:GetService("ContentProvider")

	return pcall(contentprovider.PreloadAsync, contentprovider, assets, f)
end

--- filters list of preload-able assets, removing possible duplicates to save time \
--- *"...however these strings must correspond to image assets. Attempting to load non-image assets through the use of their content ID strings will result in failure."*
function InstanceK.preloadfilter(assets: { string | Instance }): { string | Instance }
	local list = table.create(#assets) :: { string | Instance }

	for _, thing in assets do
		if typeof(thing) == "string" then
			if thing ~= "" and not table.find(list, thing) then table.insert(list, thing) end
		elseif typeof(thing) == "Instance" then
			if thing:IsA("Decal") then --- things with an image component
				local id = thing.Texture
				if id ~= "" and not table.find(list, id) then table.insert(list, id) end
			elseif thing:IsA("Beam") then
				local id = thing.Texture
				if id ~= "" and not table.find(list, id) then table.insert(list, id) end
			elseif thing:IsA("ImageButton") then
				local id = thing.Image
				if id ~= "" and not table.find(list, id) then table.insert(list, id) end
			elseif thing:IsA("ImageHandleAdornment") then
				local id = thing.Image
				if id ~= "" and not table.find(list, id) then table.insert(list, id) end
			elseif thing:IsA("ImageLabel") then
				local id = thing.Image
				if id ~= "" and not table.find(list, id) then table.insert(list, id) end
			elseif thing:IsA("ParticleEmitter") then
				local id = thing.Texture
				if id ~= "" and not table.find(list, id) then table.insert(list, id) end
			elseif thing:IsA("Pants") then
				local id = thing.PantsTemplate
				if id ~= "" and not table.find(list, id) then table.insert(list, id) end
			elseif thing:IsA("Shirt") then
				local id = thing.ShirtTemplate
				if id ~= "" and not table.find(list, id) then table.insert(list, id) end
			elseif thing:IsA("Sky") then
				for _, id in {
					thing.SkyboxBk;
					thing.SkyboxDn;
					thing.SkyboxFt;
					thing.SkyboxLf;
					thing.SkyboxRt;
					thing.SkyboxUp;
				} do
					if id ~= "" and not table.find(list, id) then table.insert(list, id) end
				end
			elseif thing:IsA("Texture") then
				local id = thing.Texture
				if id ~= "" and not table.find(list, id) then table.insert(list, id) end
			elseif thing:IsA("Trail") then
				local id = thing.Texture
				if id ~= "" and not table.find(list, id) then table.insert(list, id) end
			elseif thing:IsA("Animation") then --- things with a non-image component
				table.insert(list, thing)
			elseif thing:IsA("CharacterMesh") then
				table.insert(list, thing)
			elseif thing:IsA("MeshPart") then
				table.insert(list, thing)
			elseif thing:IsA("Sound") then
				table.insert(list, thing)
			elseif thing:IsA("SpecialMesh") then
				table.insert(list, thing)
			end
		end
	end

	return list
end

return InstanceK