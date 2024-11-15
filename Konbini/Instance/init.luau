--!strict

local types = require(script.Parent.types)

local RunService = game:GetService("RunService")
local IsServer = RunService:IsServer()

local Players = game:GetService("Players")

local Ball = script:WaitForChild("BallSocketConstraint")
local Motor = script:WaitForChild("Motor6D")
local MoverRemote = script:WaitForChild("MoverRemote")
local SoundPart = script:WaitForChild("SoundPart")
local Weld = script:WaitForChild("Weld")

--- ### Instance.luau
---
--- extension of Instance library & instance-related functions
local InstanceK = {
	Movers = {};
	emitContainer = workspace;
}

for _, BodyMover in script:WaitForChild("Movers"):GetChildren() do
	InstanceK.Movers[BodyMover.ClassName] = BodyMover
end

--- recursive `Instance.new()` using instance tree
function InstanceK.new(tree: types.Tree): Instance
	local newinstance: any = Instance.new(tree.ClassName)

	for Property, Value in pairs(tree) do
		if Property == "ClassName" then continue end
		if Property == "Parent" then continue end
		if Property == "Children" then continue end

		--- yes, these checks make the function very slow
		--- but property write errors on yet-to-be-parented instances are silent and yield indefinitely
		--- so its preferred to have something that works versus something thats fast
		if not InstanceK.IsPropertyOf(newinstance, Property) then
			warn(`{debug.traceback()}{Property} is not a property of {tree.ClassName} "{tree.Name or tree.ClassName}"`)
			continue
		end
		if (newinstance[Property] ~= nil) and (typeof(Value) ~= typeof(newinstance[Property])) then
			warn(`{debug.traceback()}Attempt to write {typeof(Value)} to {tree.ClassName} "{tree.Name or tree.ClassName}" property {Property} ({typeof(newinstance[Property])})`)
			continue
		end

		newinstance[Property] = Value
	end

	if tree.Children then
		for _, v in pairs(tree.Children) do
			v.Parent = newinstance
			InstanceK.new(v)
		end
	end

	newinstance.Parent = tree.Parent

	return newinstance
end

--- returns instance at the end of path `"path/to/instance"`, beginning at root `inst`
function InstanceK.Path(inst: Instance, Path: string, Yield: boolean?): Instance?
	for _, Ref in ipairs(string.split(Path, "/")) do
		local new = Yield and inst:WaitForChild(Ref) or inst:FindFirstChild(Ref)

		if not new then
			warn(`Ref "{Ref}" is not a member of {inst.ClassName} "{inst}"`)
			return nil
		end
		inst = new
	end
	return inst
end

--- returns true if property is a property of instance
function InstanceK.IsPropertyOf(inst: Instance, property: string): boolean
	return pcall(function() return (inst :: any)[property] end)
end

--- welds b to a at offset \
--- `a`: "root" part \
--- `b`: "loose" part
function InstanceK.Weld(a: BasePart, b: BasePart, offset: CFrame?): WeldConstraint
	local newweld = Weld:Clone()
	b.CFrame = a.CFrame * (offset or CFrame.identity)
	newweld.Part0 = b
	newweld.Part1 = a
	newweld.Parent = b
	return newweld
end

--- iterative `Property` setter
function InstanceK.Properties(inst: Instance, properties: {[string]: any})
	for k, v in properties do
		if k == "Parent" then continue end
		(inst :: any)[k] = v
	end
	if properties.Parent then
		inst.Parent = properties.Parent
	end
end

--- iterative `Attribute` setter
function InstanceK.Attributes(inst: Instance, attributes: {[string]: any})
	for k, v in attributes do
		inst:SetAttribute(k, v)
	end
end

--- yields until child of class is parented under instance
function InstanceK.WaitForChildOfClass(inst: Instance, classname: string, timeout: number?): Instance?
	local thing, time = inst:FindFirstChildOfClass(classname), timeout or 10
	if not thing then
		repeat
			time -= task.wait()
			thing = inst:FindFirstChildOfClass(classname)
		until (thing ~= nil) or (time < 0)
	end
	return thing
end

--- returns all children of instance whose names match vararg
function InstanceK.GetChildrenWithName(inst: Instance, ...: string): {Instance}
	local names = {...}
	local children = inst:GetChildren()
	local matches = table.create(#children)

	for _, thing in children do
		if not table.find(names, thing.Name) then continue end

		table.insert(matches, thing)
	end

	return matches
end

--- returns all children of instance whose classnames match vararg
function InstanceK.GetChildrenOfClass(inst: Instance, ...: string): {Instance}
	local names = {...}
	local children = inst:GetChildren()
	local matches = table.create(#children)

	for _, thing in children do
		if not table.find(names, thing.ClassName) then continue end

		table.insert(matches, thing)
	end

	return matches
end

--- returns first child of instance where `f(thing) -> true`
function InstanceK.FindFirstChildWithCase(inst: Instance, f: (thing: Instance) -> boolean): Instance?
	for _, thing: Instance in inst:GetChildren() do
		if string.sub(thing.Name, 1, 1) == "_" then continue end
		if f(thing) then return thing end
	end
	return
end

--- recursively searches for the highest ancestor `ancestor` of Instance `inst` whose ClassName property matches string `ClassName`
--- ```
--- --- Fish: Model
--- --- ┣━ Scales: Part
--- --- ┣━ Eyes: Part
--- --- ┗┳ Fins: Model
--- ---  ┣━ RightFin: Part
--- ---  ┗━ LeftFin: Part
--- --- ┗━ Animator: Animator
--- InstanceK.FindHighestAncestorOfClass(RightFin, "Model") --> Fish
--- ```
function InstanceK.FindHighestAncestorOfClass(inst: Instance, classname: string): Instance?
	local ancestor = inst:FindFirstAncestorOfClass(classname)
	if ancestor then
		local thisancestor = InstanceK.FindHighestAncestorOfClass(ancestor, classname)
		if not thisancestor then
			return ancestor
		else
			ancestor = thisancestor
		end
	end
	return ancestor
end

--- returns desired parents of things
function InstanceK.FindParentsOfClass(things: {Instance | RaycastResult}, classname: string, ignore: Instance?): {Instance}
	local matches = table.create(#things)

	for _, thing in things do
		local parent = nil
		if typeof(thing) == "RaycastResult" then
			parent = thing.Instance.Parent
		else
			parent = thing.Parent
		end

		if not parent then continue end
		if not parent:IsA(classname) then continue end
		if table.find(matches, parent) then continue end
		if parent == ignore then continue end

		table.insert(matches, parent)
	end

	return matches
end

--- Instance:IsDescendantOf() but it accepts varargs
function InstanceK.IsDescendantOf(inst: Instance, ...: Instance): boolean
	for _, thing in {...} do
		if inst:IsDescendantOf(thing) then
			return true
		end
	end
	return false
end

--- ClearAllChildrenWithNames()
function InstanceK.ClearChildrenWithName(inst: Instance, name: string)
	local thingwithclassname = inst:FindFirstChild(name)
	if thingwithclassname then
		thingwithclassname:Destroy()
		InstanceK.ClearChildrenWithName(inst, name)
	else
		return
	end
end

--- ClearAllChildrenWithoutNames()
function InstanceK.ClearWithoutName(inst: Instance, ...: string)
	local names = {...}
	for _, thing: Instance in inst:GetChildren() do
		if string.sub(thing.Name, 1, 1) == "_" then continue end
		if table.find(names, thing.Name) then continue end
		thing:Destroy()
	end
end

--- ClearChildrenWithClassName()
function InstanceK.ClearChildrenWithClassName(inst: Instance, classname: string)
	local thingwithclassname = inst:FindFirstChildOfClass(classname)
	if thingwithclassname then
		thingwithclassname:Destroy()
		InstanceK.ClearChildrenWithClassName(inst, classname)
	else
		return
	end
end

--- ClearChildrenWithoutClassName()
function InstanceK.ClearChildrenWithoutClassName(inst: Instance, classname: string)
	for _, thing: Instance in inst:GetChildren() do
		if string.sub(thing.Name, 1, 1) == "_" then continue end
		if thing.ClassName == classname then continue end
		thing:Destroy()
	end
end

--- ClearChildrenWithCase()
function InstanceK.ClearChildrenWithCase(inst: Instance, shoulddelete: (thing: Instance) -> boolean)
	for _, thing: Instance in inst:GetChildren() do
		if string.sub(thing.Name, 1, 1) == "_" then continue end
		if shoulddelete(thing) == false then continue end
		thing:Destroy()
	end
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
function InstanceK.emit<t>(template: t & Instance, at: Vector3|BasePart, transform: ((real: t) -> ())?, destruct: number?)
	local real = template:Clone()

	if typeof(at) == "Vector3" then
		real.Parent = InstanceK.emitContainer
		if real:IsA("BasePart") then
			real.Position = at
		end
	elseif at:IsA("BasePart") then
		real.Parent = at
		if real:IsA("BasePart") then
			real.Anchored = false
			real.Massless = true

			InstanceK.Weld(at, real)
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

	local newmover = InstanceK.Movers[class]:Clone()

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

if IsServer then
else
	MoverRemote.OnClientEvent:Connect(InstanceK.applybodymover)
end

return InstanceK