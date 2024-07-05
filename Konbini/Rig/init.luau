--!strict

local types						= require(script.Parent.types)

local RunService				= game:GetService("RunService")
local Players					= game:GetService("Players")

local IsServer					= RunService:IsServer()

local MoverCache				= {} :: {[string]: BodyMover}
local MoverRemote				= script:WaitForChild("MoverRemote") :: UnreliableRemoteEvent

local AccessoryPart				= script:WaitForChild("AccessoryPart")
local Ball						= script:WaitForChild("BallSocketConstraint")
local Motor						= script:WaitForChild("Motor6D")
local Weld						= script:WaitForChild("Weld")

local RagdollLimbs				= {
	[Enum.HumanoidRigType.R6]		= {
		--[["Head";
		"Left Arm";
		"Left Leg";
		"Right Arm";
		"Right Leg";
		"Torso";]]
	};
	[Enum.HumanoidRigType.R15]		= {
		"Head";
		"LeftHand";
		"RightHand";
		"LeftFoot";
		"RightFoot";
	};
}

local RagdollMotors			= {
	[Enum.HumanoidRigType.R6]		= {
		"Neck";
		"Right Shoulder";
		"Left Shoulder";
		"Right Hip";
		"Left Hip";
	};
	[Enum.HumanoidRigType.R15]		= {
		"Neck";
		"RightShoulder";
		"LeftShoulder";
		"RightHip";
		"LeftHip";
	};
}



--- ### Rig.luau
---
--- handler for motor6d-based rigs
local Rig = {}

for _, BodyMover: BodyMover in script:WaitForChild("Movers"):GetChildren() do
	MoverCache[BodyMover.ClassName] = BodyMover
end

--- memory-safe `Player:LoadCharacter()`
function Rig.loadcharacter(player: Player, description: HumanoidDescription?)
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

--- updates player humanoiddescription
function Rig.updatedescription(player: Player): HumanoidDescription?
	local UserId = player.UserId
	if UserId < 1 then return nil end -- Players in test mode throw errors as their UserId's are negative

	local Description = player:FindFirstChildOfClass("HumanoidDescription") :: HumanoidDescription
	if Description then
		Description:Destroy()
	end
	Description = Players:GetHumanoidDescriptionFromUserId(UserId)
	Description.Parent = player

	return Description
end

--- creates accessorypart
function Rig.createaccessorypart(name: string, offset: CFrame, properties: {}): BasePart
	local NewPart = AccessoryPart:Clone()
	NewPart.Name = name

	local Attachment = AccessoryPart:FindFirstChildOfClass("Attachment")
	if Attachment then
		Attachment.CFrame = offset
	end

	local SpecialMesh = AccessoryPart:FindFirstChildOfClass("SpecialMesh")
	if SpecialMesh then
		for Property, Value in properties do
			SpecialMesh[Property] = Value
		end
	end

	return NewPart
end

--- attaches accessorypart to target
function Rig.attachaccessorypart(target: Model, accessorypart: BasePart, attachmentref: string, parent: Instance?): boolean
	local A0 = target:FindFirstChild(attachmentref, true) :: Attachment
	if not A0 then return false end
	if not A0:IsA("Attachment") then return false end

	local A1 = accessorypart:FindFirstChildOfClass("Attachment") :: Attachment?
	if not A1 then return false end

	accessorypart.Parent = parent or target
	accessorypart.CFrame = A0.WorldCFrame * A1.CFrame:Inverse()

	local W = Weld:Clone()
	W.Part0 = accessorypart
	W.Part1 = A0.Parent
	W.Parent = accessorypart

	return true
end

--- disables humanoidstates
function Rig.disablestates(humanoid: Humanoid, states: {Enum.HumanoidStateType})
	for _, State: Enum.HumanoidStateType in states do
		humanoid:SetStateEnabled(State, false)
	end
end

--- connects ragdoll event to target, defined as `boolean Attribute: "Ragdoll"`
function Rig.ConnectRagdollEvent(target: Model)
	local Humanoid = target:WaitForChild("Humanoid") :: Humanoid
	if not Humanoid then warn(`Humanoid not found in {target}`); return end
	target:GetAttributeChangedSignal("Ragdoll"):Connect(function()
		if target:GetAttribute("Ragdoll") == true then
			Humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
			Humanoid:ChangeState(Enum.HumanoidStateType.Ragdoll)
			Rig.ToggleRagdollCollisions(target, Humanoid.RigType, true)
			if not IsServer then return end
			Rig.Ragdoll(target, true)
		else
			Humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
			Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
			Rig.ToggleRagdollCollisions(target, Humanoid.RigType, false)
			if not IsServer then return end
			Rig.Ragdoll(target, false)
		end
	end)
end

--- ragdolls target
function Rig.Ragdoll(target: Model, state: boolean?)
	if not IsServer then
		warn("call .Ragdoll on server")
		return
	end

	local Humanoid = target:FindFirstChildOfClass("Humanoid")
	if not Humanoid then return end

	local TargetMotors = RagdollMotors[Humanoid.RigType]

	if state == true then
		Humanoid.Sit = true
		Humanoid.RequiresNeck = false
		for _, Motor6D: Motor6D|any in target:GetDescendants() do
			if not Motor6D:IsA("Motor6D") then continue end
			if not table.find(TargetMotors, Motor6D.Name) then continue end
			Motor6D.Part1:SetAttribute("MotorRef", Motor6D.Name)
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
	else
		for _, BallSocket: any in target:GetDescendants() do
			if not BallSocket:IsA("BallSocketConstraint") then continue end
			BallSocket.UpperAngle = 0
			BallSocket.TwistUpperAngle = 0
			BallSocket.TwistLowerAngle = 0
			local Motor6D = Motor:Clone()
			Motor6D.Part0 = BallSocket.Attachment0.Parent
			Motor6D.Part1 = BallSocket.Attachment1.Parent
			Motor6D.C0 = BallSocket.Attachment0.CFrame
			Motor6D.C1 = BallSocket.Attachment1.CFrame
			Motor6D.Name = Motor6D.Part1:GetAttribute("MotorRef")
			Motor6D.Parent = BallSocket.Parent
			BallSocket.Attachment0:Destroy()
			BallSocket.Attachment1:Destroy()
			BallSocket:Destroy()
		end
		Humanoid.Sit = false
		Humanoid.RequiresNeck = true
	end
	Rig.ToggleRagdollCollisions(target, Humanoid.RigType, state or false)
end

--- toggles collisions on certain limbs depending on ragdoll state
function Rig.ToggleRagdollCollisions(target: Model, rigtype: Enum.HumanoidRigType, state: boolean)
	for _, Limb in RagdollLimbs[rigtype] do
		local P = target:FindFirstChild(Limb :: string)
		if not P then continue end
		if not P:IsA("BasePart") then continue end

		P.CanCollide = state or false
	end
end

--- applies bodymover to primarypart of target \
--- *in contexts where `time` is omitted, the bodymover will remain indefinitely*
function Rig.applybodymover(target: Model, class: types.MoverClass, time: number?, properties: {[string]: any}?): BodyMover?
	local RootPart = target.PrimaryPart
	assert(RootPart, `{target} has no PrimaryPart`)

	if IsServer then
		local Player = Players:GetPlayerFromCharacter(target) or RootPart:GetNetworkOwner()

		if Player then
			MoverRemote:FireClient(Player, target, class, time, properties)
			return
		end
	end

	local NewMover: any = MoverCache[class]:Clone()

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
	MoverRemote.OnClientEvent:Connect(Rig.applybodymover)
end

return Rig