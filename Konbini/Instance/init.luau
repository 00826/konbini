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
local K_Instance = {
	Movers = {};
	emitContainer = workspace;
}

for _, BodyMover in script:WaitForChild("Movers"):GetChildren() do
	K_Instance.Movers[BodyMover.ClassName] = BodyMover
end

--- recursive `Instance.new()` using instance tree
function K_Instance.new(tree: types.Tree): Instance
	local NewInstance: any = Instance.new(tree.ClassName)

	for Property, Value in pairs(tree) do
		if Property == "ClassName" then continue end
		if Property == "Parent" then continue end
		if Property == "Children" then continue end

		--- yes, these checks make the function very slow
		--- but property write errors on yet-to-be-parented instances are silent and yield indefinitely
		--- so its preferred to have something that works versus something thats fast
		if not K_Instance.IsPropertyOf(NewInstance, Property) then
			warn(`{debug.traceback()}{Property} is not a property of {tree.ClassName} "{tree.Name or tree.ClassName}"`)
			continue
		end
		if (NewInstance[Property] ~= nil) and (typeof(Value) ~= typeof(NewInstance[Property])) then
			warn(`{debug.traceback()}Attempt to write {typeof(Value)} to {tree.ClassName} "{tree.Name or tree.ClassName}" property {Property} ({typeof(NewInstance[Property])})`)
			continue
		end

		NewInstance[Property] = Value
	end

	if tree.Children then
		for _, v in pairs(tree.Children) do
			v.Parent = NewInstance
			K_Instance.new(v)
		end
	end

	NewInstance.Parent = tree.Parent

	return NewInstance
end

--- returns instance at the end of path `"path/to/instance"`, beginning at root `inst`
function K_Instance.Path(inst: Instance, Path: string, Yield: boolean?): Instance?
	for _, Ref in ipairs(string.split(Path, "/")) do
		local New = Yield and inst:WaitForChild(Ref) or inst:FindFirstChild(Ref)

		if not New then
			warn(`Ref "{Ref}" is not a member of {inst.ClassName} "{inst}"`)
			return nil
		end
		inst = New
	end
	return inst
end

--- returns true if property is a property of instance
function K_Instance.IsPropertyOf(inst: Instance, property: string): boolean
	return pcall(function() return (inst :: any)[property] end)
end

--- welds b to a at offset \
--- `a`: "root" part \
--- `b`: "loose" part
function K_Instance.Weld(a: BasePart, b: BasePart, offset: CFrame?): WeldConstraint
	local NewWeld = Weld:Clone()
	b.CFrame = a.CFrame * (offset or CFrame.identity)
	NewWeld.Part0 = b
	NewWeld.Part1 = a
	NewWeld.Parent = b
	return NewWeld
end

--- iterative `Property` setter
function K_Instance.Properties(inst: Instance, properties: {[string]: any})
	for k, v in properties do
		if k == "Parent" then continue end
		(inst :: any)[k] = v
	end
	if properties.Parent then
		inst.Parent = properties.Parent
	end
end

--- iterative `Attribute` setter
function K_Instance.Attributes(inst: Instance, attributes: {[string]: any})
	for k, v in attributes do
		inst:SetAttribute(k, v)
	end
end

--- yields until child of class is parented under instance
function K_Instance.WaitForChildOfClass(inst: Instance, classname: string, timeout: number?): Instance?
	local Thing, T = inst:FindFirstChildOfClass(classname), timeout or 10
	if not Thing then
		repeat
			T -= task.wait()
			Thing = inst:FindFirstChildOfClass(classname)
		until (Thing ~= nil) or (T < 0)
	end
	return Thing
end

--- returns all children of instance whose names match vararg
function K_Instance.GetChildrenWithName(inst: Instance, ...: string): {Instance}
	local Names = {...}
	local Children = inst:GetChildren()
	local Matches = table.create(#Children)

	for _, Thing in Children do
		if not table.find(Names, Thing.Name) then continue end

		table.insert(Matches, Thing)
	end

	return Matches
end

--- returns all children of instance whose classnames match vararg
function K_Instance.GetChildrenOfClass(inst: Instance, ...: string): {Instance}
	local Names = {...}
	local Children = inst:GetChildren()
	local Matches = table.create(#Children)

	for _, Thing in Children do
		if not table.find(Names, Thing.ClassName) then continue end

		table.insert(Matches, Thing)
	end

	return Matches
end

--- returns first child of instance where `f(Thing) -> true`
function K_Instance.FindFirstChildWithCase(inst: Instance, f: (Thing: Instance) -> boolean): Instance?
	for _, Thing: Instance in inst:GetChildren() do
		if string.sub(Thing.Name, 1, 1) == "_" then continue end
		if f(Thing) then return Thing end
	end
	return
end

--- recursively searches for the highest ancestor `Ancestor` of Instance `inst` whose ClassName property matches string `ClassName`
--- ```
--- --- Fish: Model
--- --- ┣━ Scales: Part
--- --- ┣━ Eyes: Part
--- --- ┗┳ Fins: Model
--- ---  ┣━ RightFin: Part
--- ---  ┗━ LeftFin: Part
--- --- ┗━ Animator: Animator
--- K_Instance.FindHighestAncestorOfClass(RightFin, "Model") --> Fish
--- ```
function K_Instance.FindHighestAncestorOfClass(inst: Instance, classname: string): Instance?
	local Ancestor = inst:FindFirstAncestorOfClass(classname)
	if Ancestor then
		local ThisAncestor = K_Instance.FindHighestAncestorOfClass(Ancestor, classname)
		if not ThisAncestor then
			return Ancestor
		else
			Ancestor = ThisAncestor
		end
	end
	return Ancestor
end

--- returns desired parents of things
function K_Instance.FindParentsOfClass(things: {Instance | RaycastResult}, classname: string, ignore: Instance?): {Instance}
	local Matches = table.create(#things)

	for _, Thing in things do
		local Parent = nil
		if typeof(Thing) == "RaycastResult" then
			Parent = Thing.Instance.Parent
		else
			Parent = Thing.Parent
		end

		if not Parent then continue end
		if not Parent:IsA(classname) then continue end
		if table.find(Matches, Parent) then continue end
		if Parent == ignore then continue end

		table.insert(Matches, Parent)
	end

	return Matches
end

--- Instance:IsDescendantOf() but it accepts varargs
function K_Instance.IsDescendantOf(inst: Instance, ...: Instance): boolean
	for _, Thing in {...} do
		if inst:IsDescendantOf(Thing) then
			return true
		end
	end
	return false
end

--- ClearAllChildrenWithNames()
function K_Instance.ClearChildrenWithName(inst: Instance, name: string)
	local ThingWithClassName = inst:FindFirstChild(name)
	if ThingWithClassName then
		ThingWithClassName:Destroy()
		K_Instance.ClearChildrenWithName(inst, name)
	else
		return
	end
end

--- ClearAllChildrenWithoutNames()
function K_Instance.ClearWithoutName(inst: Instance, ...: string)
	local Names = {...}
	for _, Thing: Instance in inst:GetChildren() do
		if string.sub(Thing.Name, 1, 1) == "_" then continue end
		if table.find(Names, Thing.Name) then continue end
		Thing:Destroy()
	end
end

--- ClearChildrenWithClassName()
function K_Instance.ClearChildrenWithClassName(inst: Instance, classname: string)
	local ThingWithClassName = inst:FindFirstChildOfClass(classname)
	if ThingWithClassName then
		ThingWithClassName:Destroy()
		K_Instance.ClearChildrenWithClassName(inst, classname)
	else
		return
	end
end

--- ClearChildrenWithoutClassName()
function K_Instance.ClearChildrenWithoutClassName(inst: Instance, classname: string)
	for _, Thing: Instance in inst:GetChildren() do
		if string.sub(Thing.Name, 1, 1) == "_" then continue end
		if Thing.ClassName == classname then continue end
		Thing:Destroy()
	end
end

--- ClearChildrenWithCase()
function K_Instance.ClearChildrenWithCase(inst: Instance, shoulddelete: (Thing: Instance) -> boolean)
	for _, Thing: Instance in inst:GetChildren() do
		if string.sub(Thing.Name, 1, 1) == "_" then continue end
		if shoulddelete(Thing) == false then continue end
		Thing:Destroy()
	end
end

--- emits sound at optional position or instance
function K_Instance.emitSound(sound: Sound, at: (Vector3|Instance)?)
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
function K_Instance.emit<t>(template: t & Instance, at: Vector3|BasePart, transform: ((real: t) -> ())?, destruct: number?)
	local real = template:Clone()

	if typeof(at) == "Vector3" then
		real.Parent = K_Instance.emitContainer
	elseif at:IsA("BasePart") then
		real.Parent = at
		if real:IsA("BasePart") then
			real.Anchored = false
			real.Massless = true

			K_Instance.Weld(at, real)
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
function K_Instance.loadcharacter(player: Player, description: HumanoidDescription?)
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
function K_Instance.disablestates(humanoid: Humanoid, states: {Enum.HumanoidStateType})
	for _, State: Enum.HumanoidStateType in states do
		humanoid:SetStateEnabled(State, false)
	end
end

--- returns `target.PrimaryPart:GetNetworkOwner() == (owner or Players.LocalPlayer)`
function K_Instance.isnetworkowner(target: Model, owner: Player?): boolean
	assert(target.PrimaryPart, `{target} has no primarypart`)
	return target.PrimaryPart:GetNetworkOwner() == (owner or Players.LocalPlayer)
end

--- sets network owner of target primarypart to owner
function K_Instance.setnetworkowner(target: Model, owner: Player?)
	assert(target.PrimaryPart, `{target} has no primarypart`)
	target.PrimaryPart:SetNetworkOwner(owner)
end

--- ragdolls motors contained in target \
--- motors must be owned by the current calling environment
function K_Instance.ragdoll(target: Model, state: boolean, motors: {string}?)
	if state == true then
		assert(motors, "expected motor target list")
		for _, Motor6D in target:GetDescendants() do
			if Motor6D:IsA("Motor6D") and table.find(motors, Motor6D.Name) then
				if not Motor6D.Part1 then warn(`motor6d {Motor6D} no part0`); continue end

				Motor6D.Part1:SetAttribute("MotorName", Motor6D.Name)
				Motor6D.Part1:SetAttribute("MotorVelocity", Motor6D.MaxVelocity)
				local Socket: BallSocketConstraint = Ball:Clone()
				local A0, A1 = Instance.new("Attachment"), Instance.new("Attachment")
				A0.Parent = Motor6D.Part0
				A1.Parent = Motor6D.Part1

				Socket.Attachment0 = A0
				Socket.Attachment1 = A1

				A0.CFrame = Motor6D.C0
				A1.CFrame = Motor6D.C1

				Socket.Parent = Motor6D.Parent

				Motor6D:Destroy()
			end
		end
	elseif state == false then
		for _, BallSocket in target:GetDescendants() do
			if BallSocket:IsA("BallSocketConstraint") then
				if not BallSocket.Attachment0 then warn(`ballsocket {BallSocket} no attachment0`); continue end
				if not BallSocket.Attachment1 then warn(`ballsocket {BallSocket} no attachment1`); continue end

				BallSocket.UpperAngle = 0
				BallSocket.TwistUpperAngle = 0
				BallSocket.TwistLowerAngle = 0

				local Motor6D = Motor:Clone()
				Motor6D.Part0 = BallSocket.Attachment0.Parent
				Motor6D.Part1 = BallSocket.Attachment1.Parent
				Motor6D.C0 = BallSocket.Attachment0.CFrame
				Motor6D.C1 = BallSocket.Attachment1.CFrame
				Motor6D.Name = Motor6D.Part1:GetAttribute("MotorName")
				Motor6D.MaxVelocity = Motor6D.Part1:GetAttribute("MotorVelocity")
				Motor6D.Parent = BallSocket.Parent

				BallSocket.Attachment0:Destroy()
				BallSocket.Attachment1:Destroy()
				BallSocket:Destroy()
			end
		end
	end
end

--- toggles cancollide on targeted limbs
function K_Instance.setlimbcancollide(target: Model, cancollide: boolean, limbs: {string})
	for _, name in limbs do
		local basepart = target:FindFirstChild(name)
		if basepart and basepart:IsA("BasePart") then
			basepart.CanCollide = cancollide
		end
	end
end

--- applies bodymover to primarypart of target \
--- *in contexts where `time` is omitted, the bodymover will remain indefinitely*
function K_Instance.applybodymover(target: Model|BasePart, class: types.MoverClass, time: number?, properties: {[string]: any}?): BodyMover?
	local RootPart
	if target:IsA("Model") then
		RootPart = target.PrimaryPart
	else
		RootPart = target
	end
	assert(RootPart, `{target} has no PrimaryPart`)

	if IsServer then
		local Player = Players:GetPlayerFromCharacter(target) or RootPart:GetNetworkOwner()

		if Player then
			MoverRemote:FireClient(Player, target, class, time, properties)
			return
		end
	end

	local NewMover = K_Instance.Movers[class]:Clone()

	if properties then
		for k, v in properties do
			NewMover[k] = v
		end
	end

	if time then
		task.delay(time, function()
			NewMover:Destroy()
		end)
	end

	NewMover.Parent = RootPart
	return NewMover
end

if IsServer then
else
	MoverRemote.OnClientEvent:Connect(K_Instance.applybodymover)
end

return K_Instance