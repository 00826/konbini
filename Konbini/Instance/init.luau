--!strict

local RunService = game:GetService("RunService")
local IsServer = RunService:IsServer()

local TweenService = game:GetService("TweenService")

local Animation = script:WaitForChild("Animation")
local BallSocketConstraint = script:WaitForChild("BallSocketConstraint")
local Motor6D = script:WaitForChild("Motor6D")
local SoundPart = script:WaitForChild("SoundPart")
local Weld = script:WaitForChild("Weld")

export type Tree = {
	ClassName: string;
	Children: { Tree }?;
	Parent: Instance?;

	[string]: unknown;
}

export type MoverClass =
	| "BodyGyro"
	| "BodyVelocity"
	| "BodyPosition"

--- ### Instance.luau
---
--- Instance library extension
local InstanceK = {
	Movers = script:WaitForChild("Movers");

	DebouncePrefix = "__d_";
}

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

--- recursively searches for the highest ancestor of class
--- ```
--- --- Fish: Model
--- --- ┣━ Scales: Part
--- --- ┣━ Eyes: Part
--- --- ┗┳ Fins: Model
--- ---  ┣━ RightFin: Part
--- ---  ┗━ LeftFin: Part
--- --- ┗━ Animator: Animator
--- InstanceK.findhighestancestorofclass(RightFin, "Model") --> Fish
--- ```
function InstanceK.findhighestancestorofclass(instance: Instance, classname: string): Instance?
	local ancestor = instance:FindFirstAncestorOfClass(classname)
	if ancestor then
		local thisancestor = InstanceK.findhighestancestorofclass(ancestor, classname)
		if not thisancestor then
			return ancestor
		else
			ancestor = thisancestor
		end
	end

	return ancestor
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
function InstanceK.applybodymover(target: Model|BasePart, class: MoverClass, time: number?, properties: {[string]: any}?): BodyMover?
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
function InstanceK.clearbodymovers(target: Model|BasePart, class: MoverClass)
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
function InstanceK.steptransparencycontroller(tc: typeof(InstanceK.createtransparencycontroller(...)))
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



--- `ContentProvider:PreloadAsync(assets)` \
--- `destruct (?=false)`: clear assets after preloading? if asset is an instance, `:Destroy`
function InstanceK.preloadasync(assets: {any}, f: ((contentstring: string, assetfetchstatus: Enum.AssetFetchStatus) -> ())?, destruct: boolean?)
	game:GetService("ContentProvider"):PreloadAsync(assets, f) --- call jit bc its only really used once

	if destruct then
		for _, thing in assets do
			if typeof(thing) == "Instance" then
				thing:Destroy()
			end
		end

		table.clear(assets)
	end
end

--- returns a filtered list of `ContentProvider:PreloadAsync()`-digestible instances \
--- \
--- *"...For any of the Instances which have properties that define links to content, such as a Decal or a Sound, the engine attempts to load these assets from Roblox."*
function InstanceK.preloadfilter(things: {Instance}): {Instance}
	local filtered: {any} = table.create(#things)

	for _, thing in things do
		if not thing:IsA("MeshPart")
		and not thing:IsA("SpecialMesh")
		and not thing:IsA("Texture")
		and not thing:IsA("Decal")
		and not thing:IsA("ImageLabel")
		and not thing:IsA("ImageButton")
		and not thing:IsA("Animation")
		and not thing:IsA("ParticleEmitter")
		and not thing:IsA("Shirt")
		and not thing:IsA("Pants")
		then continue end
		
		table.insert(filtered, thing)
	end

	return filtered
end

--- converts asset id strings into a `ContentProvider:PreloadAsync()`-digestible array \
--- \
--- *"...however these strings must correspond to image assets. Attempting to load non-image assets through the use of their content ID strings will result in failure."*
function InstanceK.preloadconvert(assetids: {string}, class: "Image"|"Sound"|"Animation"|"Mesh"): {string|Sound|Animation|SpecialMesh}
	local assets: {any} = table.create(#assetids)

	if class == "Image" then
		table.move(assetids, 1, #assetids, 1, assets)
	elseif class == "Sound" then
		for _, assetid in assetids do
			local sound = Instance.new("Sound")
			sound.SoundId = assetid

			table.insert(assets, sound)
		end
	elseif class == "Animation" then
		for _, assetid in assetids do
			local animation = Instance.new("Animation")
			animation.AnimationId = assetid

			table.insert(assets, animation)
		end
	elseif class == "Mesh" then
		for _, assetid in assetids do
			local specialmesh = Instance.new("SpecialMesh")
			specialmesh.MeshType = Enum.MeshType.FileMesh
			specialmesh.MeshId = assetid

			table.insert(assets, specialmesh)
		end
	end

	return assets
end

return InstanceK