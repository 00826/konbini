--!strict

local types						= require(script.Parent.types)

local ObjectValue				= script:WaitForChild("ObjectValue")
local Weld						= script:WaitForChild("Weld")

--- ### Instance.luau
---
--- extension of Instance library
local K_Instance = {}

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

--- creates objectvalue proxy tree of instance with recursion levels
function K_Instance.Proxy(inst: Instance, levels: number?): ObjectValue
	local OV = ObjectValue:Clone()
	OV.Name = inst.Name
	OV.Value = inst

	if levels and levels > 0 then
		for _, Thing in inst:GetChildren() do
			K_Instance.Proxy(Thing, levels - 1).Parent = OV
		end
	end
	return OV
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

return K_Instance