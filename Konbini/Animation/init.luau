--!strict

local types						= require("./Konbini/types")

local AnimationInstance			= script:WaitForChild("Animation")

local AnimLibrary				= {} :: { [types.AnimLibraryKey]: {[string]: types.AnimLibraryEntry} }
local StepSounds				= {} :: { [types.StepSoundKey]: Sound }

local Vector3_xzAxis			= Vector3.one - Vector3.yAxis

--- ### Animation.luau
---
--- aio animation handler
local Animation = { __index = {} }

--- creates an animation controller object
function Animation.Controller(rig: Model)
	local Controller, Animator = Animation.components(rig)
	assert(Controller)
	assert(rig.PrimaryPart)
	return setmetatable({
		Rig					= rig;
		RootPart			= rig.PrimaryPart;
		Controller			= Controller;
		Animator			= Animator;
		AnimTable			= Controller:IsA("Humanoid") and AnimLibrary[Controller.RigType] or AnimLibrary["Custom"];

		CurrentLoopAnim		= nil :: AnimationTrack?;
		CurrentToolAnim		= nil :: AnimationTrack?;

		PlayStepSounds		= true;

		ScalarBuffer		= buffer.create(12);
		--[[
		[0] uint8 BaseRecp # when LateralVelocity <= BaseSpeed, AnimationSpeed = LateralVelocity * (1 / BaseRecp)
		[1] uint8 SprintRecp # when LateralVelocity > BaseSpeed, AnimationSpeed = LateralVelocity * (1 / SprintRecp)
		[2] uint16 BaseSpeed # BaseSpeed
		[4] f32 AnimSpeedUpperLimit # Animation::SolveAnimSpeed upper limit
		[8] f32 StepsMuted # step sounds muted until
		]]
	}, Animation)
end

--- returns motion state: \
--- `0`: idle \
--- `1`: walking \
--- `2`: runnning
function Animation.__index:FastSolveMotionState(): number
	local ScalarBuffer = self.ScalarBuffer
	local LateralVelocity = ((self :: {RootPart: BasePart}).RootPart.AssemblyLinearVelocity * Vector3_xzAxis).Magnitude
	if LateralVelocity < 1 then
		return 0
	elseif LateralVelocity <= buffer.readu16(ScalarBuffer, 2) + 1 then
		return 1
	else
		return 2
	end
end

--- returns animation speed scalar
function Animation.__index:SolveAnimSpeed(): number
	local ScalarBuffer = self.ScalarBuffer
	local LateralVelocity = ((self :: {RootPart: BasePart}).RootPart.AssemblyLinearVelocity * Vector3_xzAxis).Magnitude
	if LateralVelocity <= buffer.readu16(ScalarBuffer, 2) + 1 then
		return math.clamp(LateralVelocity * (1 / buffer.readu8(ScalarBuffer, 0)), 0, buffer.readf32(self.ScalarBuffer, 4))
	else
		return math.clamp(LateralVelocity * (1 / buffer.readu8(ScalarBuffer, 1)), 0, buffer.readf32(self.ScalarBuffer, 4))
	end
end

--- writes animation speed scalars: \
--- `basespeed`: base speed, to solve whether rig is walking or running \
--- `baserecp`: while walking: reciprocal `1 / baserecp`, used to adjust walking animation speed \
--- `sprintrecp`: while running: reiciprocal `1 / sprintrecp`, used to adjust running animation speed \
--- `animspeedupperlimit`: upper limit of how fast the loop animation speed can go
function Animation.__index:WriteScalars(basespeed: number?, baserecp: number?, sprintrecp: number?, animspeedupperlimit: number?): buffer
	local sBuffer = self.ScalarBuffer
	if baserecp then
		buffer.writeu8(sBuffer, 0, baserecp)
	end
	if sprintrecp then
		buffer.writeu8(sBuffer, 1, sprintrecp)
	end
	if basespeed then
		buffer.writeu16(sBuffer, 2, basespeed)
	end
	if animspeedupperlimit then
		buffer.writef32(sBuffer, 4, animspeedupperlimit)
	end
	return sBuffer
end

--- changes the loop speed of the current looping animation
function Animation.__index:UpdateLoopSpeed(speed: number?)
	if self.CurrentLoopAnim then
		self.CurrentLoopAnim:AdjustSpeed(speed or self:SolveAnimSpeed())
	end
end

--- sets the current looping animation
function Animation.__index:SetLoopAnim(ref: string?): AnimationTrack?
	if self:Evaluate(self.CurrentLoopAnim, ref) then
		self.CurrentLoopAnim = self:Replace(self.CurrentLoopAnim, ref)
		if (self.CurrentLoopAnim)
		and (self.PlayStepSounds)
		and (next(StepSounds) ~= nil)
		then
			self.CurrentLoopAnim.KeyframeReached:Connect(function()
				if buffer.readf32(self.ScalarBuffer, 8) > os.clock() then return end
				if not self.Controller then return end
				if not self.Controller:IsA("Humanoid") then return end

				local NewSound = (StepSounds[self.Controller.FloorMaterial] or StepSounds.Default):Clone()
				NewSound.Parent = self.RootPart
				NewSound.Ended:Once(function()
					NewSound:Destroy()
				end)
				NewSound:Play()
			end)
		end
	end
	return self.CurrentLoopAnim
end

--- sets the tool animation
function Animation.__index:SetToolAnim(ref: string?): AnimationTrack?
	if self:Evaluate(self.CurrentToolAnim, ref) then
		self.CurrentToolAnim = self:Replace(self.CurrentToolAnim, ref)
	end
	return self.CurrentToolAnim
end

--- replaces animtrack
function Animation.__index:Replace(animtrack: AnimationTrack?, ref: string?): AnimationTrack?
	if animtrack then
		animtrack:Stop(0.1)
		animtrack = nil
	end
	if ref then
		animtrack = self:LoadFromRef(ref)
		if animtrack then
			animtrack:Play()
			animtrack:AdjustSpeed(self:SolveAnimSpeed())
		else
			warn(`nil animation ref "{ref}"`)
		end
	end
	return animtrack
end

--- returns true if animtrack can be replaced by Ref
function Animation.__index:Evaluate(animtrack: AnimationTrack?, ref: string?): boolean
	if (animtrack == nil) and (ref == nil) then return false end
	if (animtrack == nil) then return true end
	return animtrack.Name ~= ref
end

--- loads & returns animationtrack from reference
function Animation.__index:LoadFromRef(ref: string): AnimationTrack
	local AnimData = self.AnimTable[ref]
	local Track = self.Animator:LoadAnimation(AnimData.AnimInstance)
	Track.Name = ref
	Track.Priority = AnimData.Priority
	return Track
end

--- mutes step sounds
function Animation.__index:MuteStepSounds(time: number): ()
	buffer.writef32(self.ScalarBuffer, 8, os.clock() + time)
end

--- destroys controller
function Animation.__index:Destroy(): ()
	if self.CurrentLoopAnim then
		self.CurrentLoopAnim:Stop()
	end
	if self.CurrentToolAnim then
		self.CurrentToolAnim:Stop()
	end
	table.clear(self)
	setmetatable(self, nil)
end

--- returns: \
--- `Humanoid|AnimationController`: belonging to rig \
--- `Animator`: belonging to ^
function Animation.components(rig: Model): ((Humanoid|AnimationController)?, Animator?)
	local Container = rig:FindFirstChildOfClass("Humanoid") or rig:FindFirstChildOfClass("AnimationController")
	local Animator = nil
	if Container then
		Animator = Container:FindFirstChildOfClass("Animator")
	end
	return Container, Animator
end

--- returns animator
function Animation.findanimator(rig: Model): Animator?
	local Container = rig:FindFirstChildOfClass("Humanoid") or rig:FindFirstChildOfClass("AnimationController")
	if Container then
		return Container:FindFirstChildOfClass("Animator")
	end
	return
end

--- inserts animator
function Animation.addanimator(rig: Model): Animator?
	local Container = rig:FindFirstChildOfClass("Humanoid") or rig:FindFirstChildOfClass("AnimationController")
	if Container then
		local PreExisting = nil
		repeat
			PreExisting = Container:FindFirstChildOfClass("Animator")
			if PreExisting then
				PreExisting:Destroy()
			end
		until PreExisting == nil

		PreExisting = Instance.new("Animator") -- using a prefab animator that was made post-runtime has weird behavior
		assert(PreExisting)
		PreExisting.Parent = Container
		return PreExisting
	end
	return
end

--- stops all playing animation tracks
function Animation.stopplaying(A: Animator): ()
	for _, AnimTrack in A:GetPlayingAnimationTracks() do
		AnimTrack:Stop()
	end
end

--- plays animation from `rbxassetid://`
function Animation.playfromassetid(rig: Model, id: string, priority: Enum.AnimationPriority?): AnimationTrack?
	local Controller, Animator = Animation.components(rig)
	if Controller and Animator then
		local AnimTable = nil
		if Controller:IsA("Humanoid") then
			AnimTable = AnimLibrary[Controller.RigType]
		elseif Controller:IsA("AnimationController") then
			AnimTable = AnimLibrary.Custom
		end
		if AnimTable then
			AnimationInstance.AnimationId = id
			local AnimationTrack = Animator:LoadAnimation(AnimationInstance)
			AnimationTrack.Name = id
			AnimationTrack.Priority = priority or Enum.AnimationPriority.Action
			AnimationTrack:Play()
			return AnimationTrack
		else
			warn(rig.Name, Controller)
		end
	end
	return
end

--- plays animation from library reference
function Animation.playfromref(rig: Model, ref: string): AnimationTrack?
	local Controller, Animator = Animation.components(rig)
	if Controller and Animator then
		local AnimTable = nil
		if Controller:IsA("Humanoid") then
			AnimTable = AnimLibrary[Controller.RigType]
		elseif Controller:IsA("AnimationController") then
			AnimTable = AnimLibrary.Custom
		end
		if AnimTable and AnimTable[ref] then
			local AnimData = AnimTable[ref]
			assert(AnimData.AnimInstance)
			local AnimationTrack = Animator:LoadAnimation(AnimData.AnimInstance)
			AnimationTrack.Name = ref
			AnimationTrack.Priority = AnimData.Priority
			AnimationTrack:Play()
			return AnimationTrack
		else
			warn(rig.Name, ref, Controller)
		end
	end
	return
end

--- defines animation library for functions/methods that use anim references
function Animation.defineanimlibrary(T: { [types.AnimLibraryKey]: { [string]: types.AnimLibraryEntry } }): ()
	for RigType, AnimTable in T do
		AnimLibrary[RigType] = AnimTable
		for k, v in AnimTable do
			local A = Instance.new("Animation")
			A.Name = k
			A.AnimationId = v.Id
			A.Parent = script

			v.AnimInstance = A
		end
	end
end

--- defines step sounds
function Animation.definestepsounds(T: { [types.StepSoundKey]: Sound }): ()
	for Material, Sound in T do
		StepSounds[Material] = Sound
	end
end

return Animation