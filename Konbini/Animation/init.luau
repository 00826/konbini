--!strict

--- ### Animation.luau
---
--- animation player/controller
local Animation = {
	Library = {};

	FadeTime = 1/24;
}

--- returns animation controller table
function Animation.createcontroller(rig: Model)
	local animplayer = rig:FindFirstChildOfClass("AnimationController") or rig:FindFirstChildOfClass("Humanoid")
	assert(animplayer, "no AnimationController or Humanoid found in rig")
	local animator = animplayer:FindFirstChildOfClass("Animator")
	if not animator then
		local a = Instance.new("Animator")
		a.Parent = animplayer
		animator = a
	end

	return {
		Rig = rig;
		AnimPlayer = animplayer;
		Animator = animator::Animator;

		ActionTrack = nil :: AnimationTrack?;
		LoopTrack = nil :: AnimationTrack?;
	}
end

--- plays animation \
--- `priority (?=Library[name].Priority|Enum.AnimationPriority.Action)`: animation priority
function Animation.play(animator: Animator, name: string, priority: Enum.AnimationPriority?, speed: number?, fadetime: number?, weight: number?)
	local entry = Animation.Library[name]
	assert(entry, string.format("animation '%s' not defined", name))
	local animobject = entry.Animation
	assert(animobject)
	local animtrack = animator:LoadAnimation(animobject)
	animtrack:Play(fadetime or Animation.FadeTime, weight, speed)
	animtrack.Priority = priority or entry.Priority or Enum.AnimationPriority.Action

	return animtrack
end

--- sets and plays action track of animation controller \
--- `priority (?=Library[name].Priority|Enum.AnimationPriority.Action)`: animation priority \
--- returns `controller.ActionTrack` for convenience
function Animation.playactiontrack(controller: typeof(Animation.createcontroller(...)), name: string?, priority: Enum.AnimationPriority?, speed: number?, fadetime: number?, weight: number?)
	if controller.ActionTrack then
		controller.ActionTrack:Stop(fadetime or Animation.FadeTime)
		controller.ActionTrack = nil
	end

	if name == nil then
		if controller.ActionTrack then
			controller.ActionTrack:Stop(fadetime or Animation.FadeTime)
			controller.ActionTrack = nil
		end
		return controller.ActionTrack
	end

	local entry = Animation.Library[name]
	assert(entry, string.format("animation '%s' not defined", name))
	local animobject = entry.Animation
	assert(animobject)
	controller.ActionTrack = controller.Animator:LoadAnimation(animobject)
	assert(controller.ActionTrack, "lf solver")
	controller.ActionTrack:Play(fadetime or Animation.FadeTime, weight, speed)
	controller.ActionTrack.Priority = priority or entry.Priority or Enum.AnimationPriority.Action

	return controller.ActionTrack
end

--- sets and plays loop track of animation controller \
--- `priority (?=Library[name].Priority|Enum.AnimationPriority.Idle)`: animation priority \
--- returns `controller.LoopTrack` for convenience
function Animation.playlooptrack(controller: typeof(Animation.createcontroller(...)), name: string?, priority: Enum.AnimationPriority?, speed: number?, fadetime: number?, weight: number?)
	if controller.LoopTrack then
		controller.LoopTrack:Stop(fadetime or Animation.FadeTime)
		controller.LoopTrack = nil
	end

	if name == nil then
		if controller.LoopTrack then
			controller.LoopTrack:Stop(fadetime or Animation.FadeTime)
			controller.LoopTrack = nil
		end
		return controller.LoopTrack
	end

	local entry = Animation.Library[name]
	assert(entry, string.format("animation '%s' not defined", name))
	local animobject = entry.Animation
	assert(animobject)
	controller.LoopTrack = controller.Animator:LoadAnimation(animobject)
	assert(controller.LoopTrack, "lf solver")
	controller.LoopTrack:Play(fadetime or Animation.FadeTime, weight, speed)
	controller.LoopTrack.Priority = priority or entry.Priority or Enum.AnimationPriority.Idle

	return controller.LoopTrack
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

--- returns true if passed animtationtrack can be overwritten by a mismatching animation \
--- (exists to avoid cases where the same animation can be played over itself)
function Animation.evaluate(animtrack: AnimationTrack?, name: string?)
	if (animtrack == nil) and (name == nil) then return false end
	if (animtrack == nil) then return true end

	return animtrack.Name ~= name
end

--- returns animation library entry
function Animation.createentry(name: string, id: string, priority: Enum.AnimationPriority?)
	local animobject = Instance.new("Animation")
	animobject.Name = name
	animobject.AnimationId = id
	animobject.Parent = script
	
	return {
		Id = id;
		Priority = priority or Enum.AnimationPriority.Action;
		Animation = animobject;
	}
end

--- loads entries into library
function Animation.load(name: string, entry: typeof(Animation.createentry(...)))
	local preexisting = Animation.Library[name]
	if preexisting then
		preexisting.Animation:Destroy()
		table.clear(preexisting)
	end

	Animation.Library[name] = entry
end

--- returns array of animation instances for preloading
function Animation.compile()
	local a = table.create(64)

	for _, entry in Animation.Library do
		local anim = entry.Animation
		if not anim then continue end

		table.insert(a, anim)
	end

	return a
end

return Animation