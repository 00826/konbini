--!strict

local types = require(script.Parent.types)

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local IsServer = RunService:IsServer()

local MoverCache = {} :: {[string]: BodyMover}
local MoverRemote = script:WaitForChild("MoverRemote") :: UnreliableRemoteEvent

local Ball = script:WaitForChild("BallSocketConstraint")
local Motor = script:WaitForChild("Motor6D")

--- ### Rig.luau
---
--- handler for motor6d-based rigs
local Rig = {
	RagdollMotors = {
		[Enum.HumanoidRigType.R6] = {
			"Neck";
			"Right Shoulder";
			"Left Shoulder";
			"Right Hip";
			"Left Hip";
		};
		[Enum.HumanoidRigType.R15] = {
			"Neck";
			"RightShoulder";
			"LeftShoulder";
			"RightHip";
			"LeftHip";
		};
	};
}

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

--- disables humanoidstates
function Rig.disablestates(humanoid: Humanoid, states: {Enum.HumanoidStateType})
	for _, State: Enum.HumanoidStateType in states do
		humanoid:SetStateEnabled(State, false)
	end
end

--- ragdolls motors contained in target \
--- motors must be owned by the current calling environment
function Rig.ragdoll(target: Model, state: boolean, motors: {string}?)
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
function Rig.setlimbcancollide(target: Model, cancollide: boolean, limbs: {string})
	for _, name in limbs do
		local basepart = target:FindFirstChild(name)
		if basepart and basepart:IsA("BasePart") then
			basepart.CanCollide = cancollide
		end
	end
end

--- applies bodymover to primarypart of target \
--- *in contexts where `time` is omitted, the bodymover will remain indefinitely*
function Rig.applybodymover(target: Model|BasePart, class: types.MoverClass, time: number?, properties: {[string]: any}?): BodyMover?
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