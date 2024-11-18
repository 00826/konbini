--!strict

local types = require(script.Parent.types)

local Empty = script:WaitForChild("Animation")

--- ### Animation.luau
---
--- aio animation handler
local Animation = {
	libraries = {} :: {[string]: {[string]: types.AnimLibraryEntry}}
}

--- defines animation library
function Animation.define(name: string, library: {[string]: types.AnimLibraryEntry})
	if not Animation.libraries[name] then
		Animation.libraries[name] = {}
	end

	local real = Animation.libraries[name]
	for k, v in library do
		local entry = real[k]
		if not entry then
			real[k] = {
				Priority = v.Priority;
				Animation = Animation.create(v.Id);
			}
		else
			entry.Priority = v.Priority
			entry.Animation.AnimationId = v.Id
		end
	end
end

--- plays animation from defined library
--- `priority (?=library[name].Priority|Enum.AnimationPriority.Movement)` animationtrack priority \
--- `speed (?=1)` animationtrack speed \
--- `fadetime (?=0.1)` animationtrack fadetime \
--- `weight (?=1)` animationtrack weight
function Animation.play(a: Animator|Model, library: string, name: string, priority: Enum.AnimationPriority?, speed: number?, fadetime: number?, weight: number?)
	local lib = Animation.libraries[library]
	assert(lib, `library "{library}" not defined`)

	local entry = lib[name]
	assert(entry, `library "{library}" missing entry "{name}"`)

	if a:IsA("Model") then
		a = select(2, Animation.components(a))
	end
	assert(a:IsA("Animator"), "this should not happen")

	local track = a:LoadAnimation(entry.Animation)
	track.Name = library .. "/" .. name
	track.Priority = entry.Priority or Enum.AnimationPriority.Movement
	track:Play(fadetime or 0.1, weight or 1, speed or 1)

	return track
end

--- returns `AnimationController|Humanoid` and environment-owned Animator of rig, instantiating the Animator if it doesn't already exist
function Animation.components(rig: Model): (AnimationController|Humanoid, Animator)
	local controller = rig:FindFirstChildOfClass("AnimationController") or rig:FindFirstChildOfClass("Humanoid")
	assert(controller, `rig "{rig.Name}" no AnimationController or Humanoid`)
	
	local animator = controller:FindFirstChildOfClass("Animator")
	if animator then
		if animator:GetAttribute("k_OwnsFlag") then
			return controller, animator
		else
			animator:Destroy()
			animator = Instance.new("Animator")

			animator.Parent = controller
			animator:SetAttribute("k_OwnsFlag", true)

			return controller, animator
		end
	else
		animator = Instance.new("Animator")
		assert(animator)

		animator.Parent = controller
		animator:SetAttribute("k_OwnsFlag", true)
	end

	return controller, animator::Animator
end

--- adjusts animationtrack speed to fit *played* time \
--- `speed = tracklength / time`
function Animation.fitplayed(animtrack: AnimationTrack, time: number)
	animtrack:AdjustSpeed(animtrack.Length / time)
end

--- adjusts animationtrack speed to fit *remaining* time \
--- `speed = (tracklength - tracktime) / time`
function Animation.fitremaining(animtrack: AnimationTrack, time: number)
	animtrack:AdjustSpeed((animtrack.Length - animtrack.TimePosition) / time)
end

--- returns an empty animation instance, parented to this script
function Animation.create(id: string?)
	local a = Instance.fromExisting(Empty)
	a.Name = id or ""
	a.AnimationId = id or ""
	a.Parent = script

	return a
end

--- returns: \
--- `"Idle"|"Run"|"Walk"`: string describing the rig's locomotion state \
--- `scalar`: `= rig lateral speed / walk speed`
function Animation.locomotionstate(rig: Model, walkspeed: number): (types.LocomotionState, number)
	local root = rig.PrimaryPart
	assert(root, `{rig.Name} no primarypart`)

	local lateralspeed = math.floor((root.AssemblyLinearVelocity * (Vector3.one - Vector3.yAxis)).Magnitude)

	if lateralspeed < 1 then
		return "Idle", 1
	elseif lateralspeed > walkspeed then
		return "Run", lateralspeed / walkspeed
	else
		return "Walk", lateralspeed / walkspeed
	end
end

--- returns true if animtrack can be overwritten/played-over by a mismatching animation reference
function Animation.evaluate(animtrack: AnimationTrack?, library: string, name: string?)
	if (animtrack == nil) and (name == nil) then return false end
	if (animtrack == nil) then return true end
	return animtrack.Name ~= library .. "/" .. name
end

--- converts animation poses with respect to swap table
function Animation.convert(container: Instance, swaptable: {[string]: string})
	for _, thing in container:GetDescendants() do
		if not thing:IsA("Pose") then continue end

		local swap = swaptable[thing.Name]
		if not swap then continue end

		thing.Name = swap
	end
end

--- returns animation instances for preloading
function Animation.compile()
	local anims = {}
	for _, animation in script:GetChildren() do
		if not animation:IsA("Animation") then continue end
		if animation.AnimationId == "" then continue end

		table.insert(anims, animation)
	end

	return anims
end

return Animation