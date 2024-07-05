--!strict

local types						= require(script.Parent.types)

local RunService				= game:GetService("RunService")
local IsServer					= RunService:IsServer()

local Players					= game:GetService("Players")

local UIS						= game:GetService("UserInputService")
local GuiService				= game:GetService("GuiService")
local GamepadService			= game:GetService("GamepadService")

local Bind						= require(script.Parent.Bind)

local LocalPlayer				= Players.LocalPlayer
local PlayerGui					= nil :: PlayerGui?

local Camera					= workspace.CurrentCamera

local InputTable				= {
	Vector3.zero;				-- mouse position
	Vector3.zAxis;				-- camera direction
	Vector3.yAxis;				-- mouse surface normal
	Vector3.yAxis;				-- character floor normal
	Vector3.zero;				-- client move vector
}
local InputBufferLen			= #InputTable * 12
local InputBuffer				= buffer.create(InputBufferLen)

local InputCache				= {} :: {[Player]: buffer}
local InputRemote				= script:WaitForChild("InputRemote") :: UnreliableRemoteEvent

local Inset						= GuiService:GetGuiInset()
GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(function()
	Inset = GuiService:GetGuiInset()
end)

local ConversionTable			= {
	[Enum.UserInputType.None]			= 0;

	[Enum.UserInputType.Keyboard]		= 1;
	[Enum.UserInputType.MouseButton1]	= 1;
	[Enum.UserInputType.MouseButton2]	= 1;
	[Enum.UserInputType.MouseButton3]	= 1;
	[Enum.UserInputType.MouseMovement]	= 1;
	[Enum.UserInputType.MouseWheel]		= 1;

	[Enum.UserInputType.Touch]			= 2;

	[Enum.UserInputType.Gamepad1]		= 3;
	[Enum.UserInputType.Gamepad2]		= 3;
	[Enum.UserInputType.Gamepad3]		= 3;
	[Enum.UserInputType.Gamepad4]		= 3;
	[Enum.UserInputType.Gamepad5]		= 3;
	[Enum.UserInputType.Gamepad6]		= 3;
	[Enum.UserInputType.Gamepad7]		= 3;
	[Enum.UserInputType.Gamepad8]		= 3;
}



--- ### Inputs.luau
---
--- `UserInputService` wrapper \
--- compatible with pc, mobile, gamepad \
--- uses buffers to nicely replicate client inputs
local Inputs = {
	TouchEnabled				= UIS.TouchEnabled;
	PlatformId					= ConversionTable[UIS:GetLastInputType()] or 0;
	InputTimes					= {};
	DoubleTapTime				= 0.2;
	
	MobileScreenCenter			= nil :: (() -> (Vector2))?;
	AssistMousePosition			= nil :: (() -> (Vector2))?;
	MouseBlacklist				= table.create(8);

	SyncRate					= 1 / 60
}

local BlacklistParams = RaycastParams.new()
BlacklistParams.FilterType = Enum.RaycastFilterType.Exclude
BlacklistParams.IgnoreWater = true
BlacklistParams.FilterDescendantsInstances = Inputs.MouseBlacklist

local function rayblacklist(origin: Vector3, direction: Vector3): RaycastResult
	return workspace:Raycast(origin, direction, BlacklistParams)
end

--- reads vector from input buffer offset \
--- when called on client, values will be read from locally-stored input buffer \
--- `1`: mouse position \
--- `2`: camera direction \
--- `3`: mouse surface normal \
--- `4`: character floor normal \
--- `5`: client move vector
function Inputs.read(offset: number, Client: (Player|Model)?): Vector3
	local i = (offset - 1) * 12

	if IsServer then
		local P = Players:GetPlayerFromCharacter(Client) or Client
		assert(P)

		local CachedBuffer = InputCache[P]
		assert(CachedBuffer)

		return Vector3.new(
			buffer.readf32(CachedBuffer, i + 0),
			buffer.readf32(CachedBuffer, i + 4),
			buffer.readf32(CachedBuffer, i + 8)
		)
	else
		return Vector3.new(
			buffer.readf32(InputBuffer, i + 0),
			buffer.readf32(InputBuffer, i + 4),
			buffer.readf32(InputBuffer, i + 8)
		)
	end
end

--- writes vector to input buffer offset \
--- when called on client, values will be written to locally-stored input buffer \
--- `1`: mouse position \
--- `2`: camera direction \
--- `3`: mouse surface normal \
--- `4`: character floor normal \
--- `5`: client move vector
function Inputs.write(offset: number, value: Vector3, Client: (Player|Model)?): ()
	local i = (offset - 1) * 12

	if IsServer then
		local P = Players:GetPlayerFromCharacter(Client) or Client
		assert(P)

		local CachedBuffer = InputCache[P]
		assert(CachedBuffer)

		buffer.writef32(CachedBuffer, i + 0, value.X)
		buffer.writef32(CachedBuffer, i + 4, value.Y)
		buffer.writef32(CachedBuffer, i + 8, value.Z)
	else
		buffer.writef32(InputBuffer, i + 0, value.X)
		buffer.writef32(InputBuffer, i + 4, value.Y)
		buffer.writef32(InputBuffer, i + 8, value.Z)
	end
end

--- adds instance to mouse blacklist
function Inputs.mouseblacklistadd(thing: Instance): ()
	if not table.find(Inputs.MouseBlacklist, thing) then
		table.insert(Inputs.MouseBlacklist, thing)
	end
end

--- removes instance from mouse blacklist
function Inputs.mouseblacklistremove(thing: Instance): ()
	table.remove(Inputs.MouseBlacklist, table.find(Inputs.MouseBlacklist, thing) or 0)
end

--- returns a platform id corresponding to `InputObject.UserInputType` \
--- `0`: unknown \
--- `1`: pc \
--- `2`: mobile \
--- `3`: gamepad
function Inputs.platform(inputobject: InputObject): number
	return ConversionTable[inputobject.UserInputType] or 0
end

--- binds function to `UserInputService.InputBegan`
function Inputs.began(f: (InputObject: InputObject, SunkInput: boolean) -> ()): types.Disconnect
	return Bind("k_Input_began"):Connect(f)
end

--- binds function to `UserInputService.InputEnded`
function Inputs.ended(f: (InputObject: InputObject, SunkInput: boolean) -> ()): types.Disconnect
	return Bind("k_Input_ended"):Connect(f)
end

--- binds function to `UserInputService.InputChanged`
function Inputs.changed(f: (InputObject: InputObject, SunkInput: boolean) -> ()): types.Disconnect
	return Bind("k_Input_changed"):Connect(f)
end

--- fires function when a key is double-tapped
function Inputs.doubletap(f: (KeyCode: Enum.KeyCode) -> ()): types.Disconnect
	return Bind("k_Input_doubletap"):Connect(f)
end

--- fires function when the input platform is changed
--- `0`: unknown \
--- `1`: pc \
--- `2`: mobile \
--- `3`: gamepad
function Inputs.platformchanged(f: (PlatformId: number) -> ()): types.Disconnect
	return Bind("k_Input_platformchanged"):Connect(f)
end

--- fires function when the gamepad cursor is toggled on/off
function Inputs.gamepadcursorstatechanged(f: (GamepadCursorEnabled: boolean) -> ()): types.Disconnect
	return Bind("k_Input_gamepadcursorstatechanged"):Connect(f)
end

--- sets visibility of mouse icon
function Inputs.setmouseiconenabled(state: boolean): ()
	UIS.MouseIconEnabled = state
end

--- returns true if the inputobject was *not* obscured by the on-screen thumbstick
function Inputs.sinkthumbstickcheck(inputobject: InputObject): boolean
	if not PlayerGui then return false end
	if Inputs.PlatformId == 2 then
		local P = inputobject.Position
		local A: {GuiObject} = PlayerGui:GetGuiObjectsAtPosition(P.X, P.Y)
		if #A == 0 then
			return true
		else
			for _, GuiObject in A do
				if GuiObject.Name ~= "DynamicThumbstickFrame" then continue end
				return false
			end
		end
	end
	return true
end

--- toggles (displaces) mobile gui elements off-screen \
--- setting `.Enabled` does not work as that property is constantly set by the control scripts
function Inputs.togglemobileinterface(thumbstickenabled: boolean?, jumpbuttonenabled: boolean?): RBXScriptConnection
	assert(PlayerGui)
	local function t(TouchGui: Instance)
		if TouchGui.Name ~= "TouchGui" then return end
		local TouchControlFrame = TouchGui:WaitForChild("TouchControlFrame")

		local JumpButton = TouchControlFrame:WaitForChild("JumpButton") :: ImageButton
		if not jumpbuttonenabled then
			JumpButton.Position = UDim2.fromScale(2, 2)
		end

		local Thumbstick = TouchControlFrame:WaitForChild("DynamicThumbstickFrame") :: Frame
		if not thumbstickenabled then
			Thumbstick.Position = UDim2.fromScale(2, 2)
		end
	end

	for _, Thing in PlayerGui:GetChildren() do
		t(Thing)
	end
	return PlayerGui.ChildAdded:Connect(function(Thing)
		t(Thing)
	end)
end

--- connects mobile gamepad for nicer inputs \
--- managing CAS buttons and their auto-positioning is painful and not worth the mental taxation
--- ```
--- --gamepadobject: GuiObject
--- --┗┳ [KeyId]: GuiObject
--- -- ┣━ UIStroke: UIStroke?
--- -- ┗━ Button: TextButton
--- ```
function Inputs.connectmobilegamepad(gamepadobject: GuiObject, f: (KeyId: types.DynamicGamepadKey, UserInputState: Enum.UserInputState) -> ()): ()
	local White = Color3.fromRGB(255, 255, 255)
	local Black = Color3.fromRGB(0, 0, 0)
	for _, KeyId: types.DynamicGamepadKey in {"Y", "X", "B", "A", "L1", "R1", "L2", "R2"} :: {types.DynamicGamepadKey} do
		local ButtonFrame = gamepadobject:FindFirstChild(KeyId)
		if not ButtonFrame then warn(gamepadobject, KeyId); continue end

		local UIStroke = ButtonFrame:FindFirstChildOfClass("UIStroke")
		local TB = ButtonFrame:FindFirstChildOfClass("TextButton")
		if not TB then continue end

		TB:GetPropertyChangedSignal("GuiState"):Connect(function()
			if TB.GuiState== Enum.GuiState.Press then
				f(KeyId, Enum.UserInputState.Begin)
				if UIStroke then
					UIStroke.Color = White
				end
			elseif TB.GuiState == Enum.GuiState.Idle then
				f(KeyId, Enum.UserInputState.End)
				if UIStroke then
					UIStroke.Color = Black
				end
			end
		end)
	end
end

if IsServer then
	Players.PlayerAdded:Connect(function(P: Player)
		InputCache[P] = buffer.create(InputBufferLen)
	end)
	Players.PlayerRemoving:Connect(function(P: Player)
		InputCache[P] = nil
	end)

	InputRemote.OnServerEvent:Connect(function(P: Player, b: buffer)
		assert(buffer.len(b) == InputBufferLen)
		if not InputCache[P] then
			InputCache[P] = buffer.create(InputBufferLen)
		end
		buffer.copy(InputCache[P], 0, b, 0)
	end)
else
	LocalPlayer.CharacterAdded:Connect(function(C: Model)
		Inputs.mouseblacklistadd(C)

		local Humanoid = C:FindFirstChildOfClass("Humanoid") or C:WaitForChild("Humanoid") :: Humanoid
		Humanoid:GetPropertyChangedSignal("FloorMaterial"):Connect(function()
			Inputs.write(4, Humanoid.FloorMaterial ~= Enum.Material.Air and Vector3.yAxis or Vector3.zero, LocalPlayer)
		end)
	end)
	LocalPlayer.CharacterRemoving:Connect(Inputs.mouseblacklistremove)

	local function UpdateMouse(InputObject: InputObject)
		local ScreenPosition = Vector2.zero
		if Inputs.PlatformId == 2 then
			local InputPosition: Vector2|Vector3 = InputObject.Position
			if Inputs.MobileScreenCenter then
				InputPosition = Inputs.MobileScreenCenter() or InputPosition
			end
			ScreenPosition = Vector2.new(InputPosition.X, InputPosition.Y)
		else
			ScreenPosition = UIS:GetMouseLocation() - Inset
		end

		if Inputs.AssistMousePosition then
			ScreenPosition = Inputs.AssistMousePosition() or ScreenPosition
		end
	
		local UnitRay = Camera:ScreenPointToRay(ScreenPosition.X, ScreenPosition.Y)
		local Result = rayblacklist(UnitRay.Origin, UnitRay.Direction * 10000)
	
		Inputs.write(1, Result and Result.Position or (UnitRay.Origin + (UnitRay.Direction * 10000)), LocalPlayer)
		Inputs.write(2, Camera.CFrame.LookVector, LocalPlayer)
		Inputs.write(3, Result and Result.Normal or Vector3.yAxis, LocalPlayer)
	end

	--- input changes

	UIS.InputBegan:Connect(function(InputObject: InputObject, ...)
		if Inputs.sinkthumbstickcheck(InputObject) then return end
		Bind("k_Input_began"):Fire(InputObject, ...)

		local Now, KeyCode = os.clock(), InputObject.KeyCode
		local KeyCodeTimeTable = Inputs.InputTimes

		do -- doubletap inputs
			local Then = KeyCodeTimeTable[KeyCode] or 0
			KeyCodeTimeTable[KeyCode] = Now
			if Now - Then < Inputs.DoubleTapTime then
				Bind("k_Input_doubletap"):Fire(KeyCode)
			end
		end

		UpdateMouse(InputObject)
	end)
	UIS.InputEnded:Connect(function(...)
		Bind("k_Input_ended"):Fire(...)
		UpdateMouse(...)
	end)
	UIS.InputChanged:Connect(function(...)
		Bind("k_Input_changed"):Fire(...)
		UpdateMouse(...)
	end)
	UIS.TouchStarted:Connect(function(...)
		if not Inputs.sinkthumbstickcheck(...) then return end
		Bind("k_Input_began"):Fire(...)
	end)
	UIS.TouchEnded:Connect(function(...)
		Bind("k_Input_ended"):Fire(...)
	end)
	UIS.TouchMoved:Connect(function(...)
		Bind("k_Input_changed"):Fire(...)
	end)
	UIS.LastInputTypeChanged:Connect(function(InputType: Enum.UserInputType)
		Inputs.TouchEnabled = UIS.TouchEnabled

		local ThisPlatform = ConversionTable[InputType] or Inputs.PlatformId
		if Inputs.PlatformId ~= ThisPlatform then
			Inputs.PlatformId = ThisPlatform
			Bind("k_Input_platformchanged"):Fire(Inputs.PlatformId)
		end
	end)
	GamepadService:GetPropertyChangedSignal("GamepadCursorEnabled"):Connect(function()
		Inputs.GamepadCursorEnabled = GamepadService.GamepadCursorEnabled
		Bind("k_Input_gamepadcursorstatechanged"):Fire(GamepadService.GamepadCursorEnabled)
	end)

	--- input buffer sync

	local Elapsed = 0
	RunService.Heartbeat:Connect(function(dt: number)
		Elapsed += dt
		if Elapsed < Inputs.SyncRate then return end
		Elapsed -= Inputs.SyncRate
		InputRemote:FireServer(InputBuffer)
	end)
end

return Inputs