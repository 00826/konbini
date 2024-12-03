--!strict

local types = require(script.Parent.types)

local RunService = game:GetService("RunService")
local IsServer = RunService:IsServer()

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Ball = script:WaitForChild("BallSocketConstraint")
local Motor = script:WaitForChild("Motor6D")
local MoverRemote = script:WaitForChild("MoverRemote")
local SoundPart = script:WaitForChild("SoundPart")
local Weld = script:WaitForChild("Weld")

local KeyframeBucket = {} :: {[Instance]: types.KeyframeInfo}
local Keyframable = table.freeze{
	"number";
	"boolean";

	"CFrame";
	"Color3";
	"ColorSequence";
	"EnumItem";
	"NumberRange";
	"NumberSequence";
	"UDim";
	"UDim2";
	"Vector2";
	"Vector3";
}

local function iskeyframable<T>(a: T): boolean
	local h, k = type(a), typeof(a)
	for _, t in Keyframable do
		if h == t then
			return true
		elseif k == t then
			return true
		end
	end
	return false
end

@native
local function lerp(initial: number, goal: number, a: number)
	return (1 - a) * initial + a * goal
end

local function lerpcolorsequencekeypoint(initial: ColorSequenceKeypoint, goal: ColorSequenceKeypoint, a: number)
	return ColorSequenceKeypoint.new(lerp(initial.Time, goal.Time, a), initial.Value:Lerp(goal.Value, a))
end

local function lerpnumbersequencekeypoint(initial: NumberSequenceKeypoint, goal: NumberSequenceKeypoint, a: number)
	return NumberSequenceKeypoint.new(lerp(initial.Time, goal.Time, a), lerp(initial.Value, goal.Value, a), lerp(initial.Envelope, goal.Envelope, a))
end

local function getvalue(initial: any, goal: any, a: number, style: Enum.EasingStyle, direction: Enum.EasingDirection): any
	a = TweenService:GetValue(a, style, direction)

	local h, k = type(initial), typeof(initial)

	if h == "number" then
		return lerp(initial, goal, a)
	elseif h == "boolean" then
		if (initial == goal) then
			return goal
		elseif (initial == true) and (goal == false) then
			return a < 1
		elseif (initial == false) and (goal == true) then
			return a >= 1
		end
	elseif k == "Vector3" then
		return initial:Lerp(goal, a)
	elseif k == "CFrame" then
		return initial:Lerp(goal, a)
	elseif k == "Color3" then
		return initial:Lerp(goal, a)
	elseif k == "ColorSequence" then
		local keys0 = initial.Keypoints
		local keys1 = goal.Keypoints :: {ColorSequenceKeypoint}

		local len = #keys0
		assert(len == #keys1, "initial and goal ColorSequences must have the same # of ColorSequenceKeypoints")

		local sequencekeys = table.create(len)
		for i, csk in ipairs(keys0) do
			sequencekeys[i] = lerpcolorsequencekeypoint(csk, keys1[i], a)
		end

		return ColorSequence.new(sequencekeys)
	elseif k == "EnumItem" then
		return a < 1 and initial or goal
	elseif k == "NumberRange" then
		return NumberRange.new(lerp(initial.Min, goal.Min, a), lerp(initial.Max, goal.Max, a))
	elseif k == "NumberSequence" then
		local keys0 = initial.Keypoints
		local keys1 = goal.Keypoints :: {NumberSequenceKeypoint}

		local len = #keys0
		assert(len == #keys1, "initial and goal NumberSequences must have the same # of NumberSequenceKeypoints")

		local sequencekeys = table.create(len)
		for i, nsk in ipairs(keys0) do
			sequencekeys[i] = lerpnumbersequencekeypoint(nsk, keys1[i], a)
		end

		return NumberSequence.new(sequencekeys)
	elseif k == "UDim" then
		return UDim.new(lerp(initial.Scale, goal.Scale, a), lerp(initial.Offset, goal.Offset, a))
	elseif k == "UDim2" then
		return initial:Lerp(goal, a)
	elseif k == "Vector2" then
		return initial:Lerp(goal, a)
	end

	error(`untweenable property (this should not happen) type({h}) typeof({k})`)
end

local function interpolate(object: Instance, keyframeinfo: types.KeyframeInfo, dt: number)
	local framerate = keyframeinfo.Framerate
	keyframeinfo.Framerule += dt
	keyframeinfo.Elapsed += dt
	if keyframeinfo.Framerule < framerate then return end
	keyframeinfo.Framerule -= framerate

	local a = math.clamp(keyframeinfo.Elapsed / keyframeinfo.Time, 0, 1)
	local style = keyframeinfo.Style
	local direction = keyframeinfo.Direction

	for property, initial in keyframeinfo.Initial do
		local goal = keyframeinfo.Goal[property]
		local value = getvalue(initial, goal, a, style, direction)
		if value ~= nil then
			(object::any)[property] = value
		end
	end

	if a >= 1 then
		table.clear(KeyframeBucket[object] or table.create(0))
		KeyframeBucket[object] = nil

		if keyframeinfo.Destruct then
			task.delay(keyframeinfo.Destruct, function()
				object:Destroy()
			end)
		end
	end
end

--- ### Instance.luau
---
--- extension of Instance library & instance-related functions
local InstanceK = {
	Movers = script:WaitForChild("Movers");
	EmitContainer = workspace;

	KeyframeFramerate = 1/30;
	KeyframeActiveObjects = 0;
}

--- recursive `Instance.new()` using instance tree
function InstanceK.new(tree: types.Tree): Instance
	local newinstance: any = Instance.new(tree.ClassName)

	for property, value in pairs(tree) do
		if property == "ClassName" then continue end
		if property == "Parent" then continue end
		if property == "Children" then continue end

		--- yes, these checks make the function very slow
		--- but property write errors on yet-to-be-parented instances are silent and yield indefinitely
		--- so its preferred to have something that works versus something thats fast
		if not InstanceK.ispropertyof(newinstance, property) then
			warn(`{debug.traceback()}{property} is not a property of {tree.ClassName} "{tree.Name or tree.ClassName}"`)
			continue
		end
		if (newinstance[property] ~= nil) and (typeof(value) ~= typeof(newinstance[property])) then
			warn(`{debug.traceback()}Attempt to write {typeof(value)} to {tree.ClassName} "{tree.Name or tree.ClassName}" property {property} ({typeof(newinstance[property])})`)
			continue
		end

		newinstance[property] = value
	end

	if tree.Children then
		for _, branch in (tree.Children::{[string]: types.Tree}) do
			branch.Parent = newinstance
			InstanceK.new(branch)
		end
	end

	newinstance.Parent = tree.Parent

	return newinstance
end

--- returns instance at the end of path `"path/to/instance"`, beginning at root `instance`
function InstanceK.path(instance: Instance, path: string, yield: boolean?): Instance?
	for _, ref in ipairs(string.split(path, "/")) do
		local new = yield and instance:WaitForChild(ref) or instance:FindFirstChild(ref)

		if not new then
			warn(`ref "{ref}" is not a member of {instance.ClassName} "{instance}"`)
			return nil
		end
		instance = new
	end

	return instance
end

--- returns true if property is a property of instance
function InstanceK.ispropertyof(instance: Instance, property: string): boolean
	return pcall(function() return (instance :: any)[property] end)
end

--- welds b to a at offset \
--- `a`: "root" part \
--- `b`: "loose" part \
--- `offset: (?=CFrame.identity)`: `b.CFrame = a.CFrame * offset` \
--- `force:` `b.CFrame = force`
function InstanceK.weld(a: BasePart, b: BasePart, offset: CFrame?, force: CFrame?): WeldConstraint
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

--- iterative property setter
function InstanceK.properties(instance: Instance, properties: {[string]: any})
	for k, v in properties do
		if k == "Parent" then continue end
		(instance :: any)[k] = v
	end
	if properties.Parent then
		instance.Parent = properties.Parent
	end
end

--- iterative attribute setter
function InstanceK.attributes(instance: Instance, attributes: {[string]: any})
	for k, v in attributes do
		instance:SetAttribute(k, v)
	end
end

--- yields until child of class is parented under instance
function InstanceK.waitforchildofclass(instance: Instance, classname: string, timeout: number?): Instance?
	local thing, time = instance:FindFirstChildOfClass(classname), timeout or 10
	if not thing then
		repeat
			time -= task.wait()
			thing = instance:FindFirstChildOfClass(classname)
		until (thing ~= nil) or (time < 0)
	end

	return thing
end

--- returns first child of instance where `comp(a) -> true`
function InstanceK.findfirstchildwithcase(instance: Instance, comp: (a: Instance) -> boolean): Instance?
	for _, thing in instance:GetChildren() do
		if comp(thing) then return thing end
	end

	return
end

--- returns children of instance where `comp(a) -> true`
function InstanceK.getchildrenwithcase(instance: Instance, comp: (a: Instance) -> boolean)
	local things = instance:GetChildren()
	local list = table.create(#things)
	for _, thing in things do
		if comp(thing) == false then continue end
		table.insert(list, thing)
	end

	return list
end

--- destroys children of instance where `comp(a) -> true`
function InstanceK.clearchildrenwithcase(instance: Instance, comp: (a: Instance) -> boolean)
	for _, thing in instance:GetChildren() do
		if comp(thing) == false then continue end
		thing:Destroy()
	end
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
function InstanceK.emitSound(sound: Sound, at: (Vector3|Instance)?)
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
		newsound.PlayOnRemove = false

		newsound.Stopped:Once(function()
			newsound:Destroy()
		end)
		newsound.Ended:Once(function()
			newsound:Destroy()
		end)

		newsound:Play()
	elseif typeof(at) == "Vector3" then
		local newpart = SoundPart:Clone()
		newpart.Parent = workspace

		local newsound = sound:Clone()
		newsound.Parent = newpart
		newsound.PlayOnRemove = true
		
		newpart:Destroy()
	else
		local newsound = sound:Clone()
		newsound.Parent = script
		newsound.PlayOnRemove = true

		newsound:Destroy()
	end
end

--- emits a clone of instance template `t` at vector3 or attached to basepart \
--- `clone<t> -> parented -> deferred transform(?) -> delayed destruct(?) -> return clone<t>` \
--- if both `at` and `template` are baseparts, then `t` will be unanchored and massless-ed *prior* to welding. weldconstraint is parented to emitted clone of `t`
function InstanceK.emit<t>(template: t & Instance, at: Vector3|CFrame|BasePart|Model, transform: ((real: t) -> ())?, destruct: number?)
	local real = template:Clone()

	if typeof(at) == "Vector3" then
		real.Parent = InstanceK.EmitContainer
		if real:IsA("BasePart") then
			real.Position = at
		end
	elseif typeof(at) == "CFrame" then
		real.Parent = InstanceK.EmitContainer
		if real:IsA("BasePart") then
			real.CFrame = at
		end
	elseif at:IsA("BasePart") then
		real.Parent = at
		if real:IsA("BasePart") then
			real.Anchored = false
			real.Massless = true

			InstanceK.weld(at, real)
		end
	elseif at:IsA("Model") then
		real.Parent = at
		if real:IsA("BasePart") then
			real.Anchored = false
			real.Massless = true

			InstanceK.weld(at.PrimaryPart, real)
		end
	else
		real:Destroy()
		error(typeof(at))
	end

	if transform then
		task.defer(transform, real)
	end

	if destruct then
		task.delay(destruct, function() real:Destroy() end)
	end

	return real
end

--- memory-safe `Player:LoadCharacter()`
function InstanceK.loadcharacter(player: Player, description: HumanoidDescription?)
	if player.Character then
		player.Character:Destroy()
		player.Character = nil
	end
	if IsServer then
		if description then
			player:LoadCharacterWithHumanoidDescription(description)
		else
			player:LoadCharacter()
		end
	end
end

--- disables humanoidstates
function InstanceK.disablestates(humanoid: Humanoid, states: {Enum.HumanoidStateType})
	for _, State: Enum.HumanoidStateType in states do
		humanoid:SetStateEnabled(State, false)
	end
end

--- returns `target.PrimaryPart:GetNetworkOwner() == (owner or Players.LocalPlayer)`
function InstanceK.isnetworkowner(target: Model, owner: Player?): boolean
	assert(target.PrimaryPart, `{target} has no primarypart`)
	return target.PrimaryPart:GetNetworkOwner() == (owner or Players.LocalPlayer)
end

--- sets network owner of target primarypart to owner
function InstanceK.setnetworkowner(target: Model, owner: Player?)
	assert(target.PrimaryPart, `{target} has no primarypart`)
	target.PrimaryPart:SetNetworkOwner(owner)
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
				local socket: BallSocketConstraint = Ball:Clone()
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

				local motor6d = Motor:Clone()
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

--- toggles cancollide on targeted limbs
function InstanceK.setlimbcancollide(target: Model, cancollide: boolean, limbs: {string})
	for _, name in limbs do
		local basepart = target:FindFirstChild(name)
		if basepart and basepart:IsA("BasePart") then
			basepart.CanCollide = cancollide
		end
	end
end

--- applies bodymover to primarypart of target \
--- *in contexts where `time` is omitted, the bodymover will remain indefinitely*
function InstanceK.applybodymover(target: Model|BasePart, class: types.MoverClass, time: number?, properties: {[string]: any}?): BodyMover?
	local rootpart
	if target:IsA("Model") then
		rootpart = target.PrimaryPart
	else
		rootpart = target
	end
	assert(rootpart, `{target} has no PrimaryPart`)

	if IsServer then
		local player = Players:GetPlayerFromCharacter(target) or rootpart:GetNetworkOwner()

		if player then
			MoverRemote:FireClient(player, target, class, time, properties)
			return
		end
	end

	local newmover = InstanceK.Movers:FindFirstChildOfClass(class):Clone()

	if properties then
		for k, v in properties do
			newmover[k] = v
		end
	end

	if time then
		task.delay(time, function()
			newmover:Destroy()
		end)
	end

	newmover.Parent = rootpart
	return newmover
end

--- clears bodymovers from primarypart of target
function InstanceK.clearbodymovers(target: Model|BasePart, class: types.MoverClass)
	local rootpart
	if target:IsA("Model") then
		rootpart = target.PrimaryPart
	else
		rootpart = target
	end
	assert(rootpart, `{target} has no PrimaryPart`)

	for _, thing in rootpart:GetChildren() do
		if thing.ClassName == class then
			thing:Destroy()
		end
	end
end

--- equivalent to `TweenService:Create(object, TweenInfo.new(time, ...), properties):Play()` \
--- `...[1]`: `Enum.EasingStyle` \
--- `...[2]`: `Enum.EasingDirection` \
--- `...[3...]`: (remainder of `TweenInfo.new()` args)
function InstanceK.tween(object: Instance, properties: {[string]: any}, time: number, ...)
	TweenService:Create(object, TweenInfo.new(time, ...), properties):Play()
end

--- transforms properties of object toward goal with respect to framerate \
--- `time(?=1)`: seconds for keyframes to complete \
--- `style(?=Enum.EasingDirection.Linear)`: effect easingstyle \
--- `direction(?=Enum.EasingDirection.Out)`: effect easingdirection \
--- `framerate(?=InstanceK.KeyframeFramerate)`: effect framerate \
--- `destruct(?=nil)`: destroy object `n` seconds after effect completion \
--- all transformations are deferred \
--- \
--- returns a mutable `KeyframeInfo` table
function InstanceK.keyframe(object: Instance, goal: {[string]: types.KeyframeType}, time: number?, style: Enum.EasingStyle?, direction: Enum.EasingDirection?, framerate: number?, destruct: number?): types.KeyframeInfo
	assert(not IsServer, "InstanceK.keyframe() can only be called on client")

	if KeyframeBucket[object] then
		KeyframeBucket[object] = nil
	end

	local keyframeinfo = {
		Framerate = framerate or InstanceK.KeyframeFramerate;
		Framerule = 0;

		Time = time or 1;
		Elapsed = 0;
		IsPaused = false;

		Style = style or Enum.EasingStyle.Linear;
		Direction = direction or Enum.EasingDirection.Out;

		Initial = {};
		Goal = table.clone(goal);
		Destruct = destruct;
	}

	keyframeinfo.Reset = function()
		keyframeinfo.Elapsed = 0
	end;
	keyframeinfo.Pause = function()
		keyframeinfo.IsPaused = true
	end;
	keyframeinfo.Resume = function()
		for property in goal do
			keyframeinfo.Initial[property] = (object::any)[property]
		end
		keyframeinfo.IsPaused = false
	end;
	keyframeinfo.Stop = function()
		table.clear(KeyframeBucket[object] or table.create(0))
		KeyframeBucket[object] = nil
	end;

	for property, value in goal do
		if iskeyframable(value) then
			keyframeinfo.Initial[property] = (object::any)[property]
		else
			warn(`skipping untweenable property "{property}" type({type(value)}) typeof({typeof(value)})`)
		end
	end

	KeyframeBucket[object] = keyframeinfo

	return keyframeinfo
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

if IsServer then
else
	MoverRemote.OnClientEvent:Connect(InstanceK.applybodymover)

	RunService.Heartbeat:Connect(function(dt)
		local x = 0
		for object, keyframeinfo in KeyframeBucket do
			if keyframeinfo.IsPaused then continue end
			task.defer(interpolate, object, keyframeinfo, dt)
			x += 1
		end
		InstanceK.KeyframeActiveObjects = x
	end)
end

return InstanceK