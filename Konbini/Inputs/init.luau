--!strict

local types = require(script.Parent.types)

local RunService = game:GetService("RunService")
local IsServer = RunService:IsServer()

local Players = game:GetService("Players")

local UIS = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local GamepadService = game:GetService("GamepadService")

local Bind = require(script.Parent.Bind)

local LocalPlayer = Players.LocalPlayer
local PlayerGui = nil :: PlayerGui?

local Camera = workspace.CurrentCamera

local Keycodes = Enum.KeyCode:GetEnumItems()

local function searchkeycodes(A: {Enum.KeyCode}, enumvalue: number): Enum.KeyCode?
	local L = 1
	local R = #A

	if L > R then
		return nil
	else
		local idx = (L + R) // 2
		local value = A[idx]

		local result = value.Value == enumvalue and 0 or value.Value < enumvalue and 1 or 2

		if result == 0 then
			return value
		else
			if result == 1 then
				L = idx + 1
			elseif result == 2 then
				R = idx - 1
			end
			return searchkeycodes(table.move(A, L, R, 1, table.create(L + R)), enumvalue)
		end
	end
end

--- ### Inputs.luau
---
--- `UserInputService` wrapper \
--- compatible with pc, mobile, gamepad \
--- \
--- PlatformId `0`: unknown \
--- PlatformId `1`: pc \
--- PlatformId `2`: mobile \
--- PlatformId `3`: gamepad
local Inputs = {
	TouchEnabled = UIS.TouchEnabled;
	PlatformId = 0;
	InputTimes = {};
	DoubleTapTime = 0.2;
	
	MobileScreenCenter = nil :: (() -> Vector2)?;
	AssistMousePosition = nil :: (() -> Vector2)?;

	CursorBlacklist = table.create(8);
	GuiInset = Vector2.zero;

	Aliases = require(script.Aliases);
	Platforms = require(script.Platforms);

	Gamepad2D = script:WaitForChild("Gamepad2D");
	Gamepad2DMap = require(script.Gamepad2DMap);

	DPad2D = script:WaitForChild("DPad2D");
	DPad2DMap = require(script.DPad2DMap);

	Select2DColor = Color3.fromRGB(255, 255, 255);
	Deselect2DColor = Color3.fromRGB(0, 0, 0);
}

local BlacklistParams = RaycastParams.new()
BlacklistParams.FilterType = Enum.RaycastFilterType.Exclude
BlacklistParams.IgnoreWater = true
BlacklistParams.FilterDescendantsInstances = Inputs.CursorBlacklist

local Cursor: types.Cursor = {
	Position = Vector3.zero;
	Normal = Vector3.yAxis;
	Camera = -Vector3.zAxis;
	Instance = nil;
}

local function rayblacklist(origin: Vector3, direction: Vector3): RaycastResult
	return workspace:Raycast(origin, direction, BlacklistParams)
end

--- returns mutable input-cursor, describing client input
function Inputs.cursor(): types.Cursor
	return Cursor
end

--- adds instance to cursor blacklist
function Inputs.cursorblacklistadd(thing: Instance)
	if not table.find(Inputs.CursorBlacklist, thing) then
		table.insert(Inputs.CursorBlacklist, thing)
	end
end

--- removes instance from cursor blacklist
function Inputs.cursorblacklistremove(thing: Instance)
	table.remove(Inputs.CursorBlacklist, table.find(Inputs.CursorBlacklist, thing) or 0)
end

--- returns key-value pair bound to keycode with respect to internal platform id \
--- `Enum.KeyCode.Unknown (value 0)` immediately returns nil
function Inputs.keybind(keycode: Enum.KeyCode, k: {[string]: types.Keybind}): (string?, types.Keybind?)
	local PlatformId = Inputs.PlatformId
	if PlatformId == 0 then
		return
	elseif keycode == Enum.KeyCode.Unknown then
		return nil, nil
	else
		for keyid, keybind in k do
			local reals = k[keyid].Reals
			local defaults = k[keyid].Defaults

			assert(type(reals) == "table")
			assert(type(defaults) == "table")

			local boundkey = reals[PlatformId] or defaults[PlatformId]
			if boundkey == keycode.Value then
				return keyid, keybind
			end
		end
	end
	return
end

--- folds saved keybinds `j` into read-write keybind table `k`
function Inputs.keybindfold(j: {[string]: {number}}, k: {[string]: types.Keybind})
	for keyid, keybinds in j do
		local reals = k[keyid].Reals
		assert(type(reals) == "table")
		local defaults = k[keyid].Defaults
		assert(type(defaults) == "table")

		table.move(defaults, 1, #defaults, 1, reals)
		table.move(keybinds, 1, #keybinds, 1, reals)
	end
end

--- resets keybind of `k`
function Inputs.keybindreset(keyid: string, k: {[string]: types.Keybind})
	local reals = k[keyid].Reals
	assert(type(reals) == "table")
	local defaults = k[keyid].Defaults
	assert(type(defaults) == "table")

	table.move(defaults, 1, #defaults, 1, reals)
end

--- compiles read-write keybind table `k` into a savable format
function Inputs.keybindcompile(k: {[string]: types.Keybind}): {[string]: {number}}
	local j = {}
	for keyid, keybind in k do
		local reals = k[keyid].Reals
		assert(type(reals) == "table")

		j[keyid] = table.clone(reals)
	end
	return j
end

--- asserts keybinds `j` are of read-write keybind table `k`
function Inputs.keybindassert(j: {[string]: {number}}, k: {[string]: types.Keybind})
	assert(type(j) == "table")
	for keyid, keybinds in j do
		assert(k[keyid] ~= nil)
		assert(type(keyid) == "string")
		assert(type(keybinds) == "table")
		assert(#keybinds <= #k[keyid].Defaults)
	end
end

--- returns associated mouse button `Enum.KeyCode` with respect to inputobject
function Inputs.inputobjecttomousekeycode(inputobject: InputObject): Enum.KeyCode?
	local inputtype = inputobject.UserInputType
	if inputtype == Enum.UserInputType.MouseButton1 then
		return Enum.KeyCode.MouseLeftButton
	elseif inputtype == Enum.UserInputType.MouseButton3 then
		return Enum.KeyCode.MouseMiddleButton
	elseif inputtype == Enum.UserInputType.MouseButton2 then
		return Enum.KeyCode.MouseRightButton
	end

	return
end

--- returns a platform id corresponding to `inputobject.UserInputType` \
--- `0`: unknown \
--- `1`: pc \
--- `2`: mobile \
--- `3`: gamepad
function Inputs.platform(inputobject: InputObject): number
	return Inputs.Platforms[inputobject.UserInputType] or 0
end

--- binds function to `UserInputService.InputBegan`
function Inputs.began(f: (inputobject: InputObject, SunkInput: boolean) -> ()): types.Disconnect
	return Bind("k_Input_began"):Connect(f)
end

--- binds function to `UserInputService.InputEnded`
function Inputs.ended(f: (inputobject: InputObject, SunkInput: boolean) -> ()): types.Disconnect
	return Bind("k_Input_ended"):Connect(f)
end

--- binds function to `UserInputService.InputChanged`
function Inputs.changed(f: (inputobject: InputObject, SunkInput: boolean) -> ()): types.Disconnect
	return Bind("k_Input_changed"):Connect(f)
end

--- fires function when a key is double-tapped
function Inputs.doubletap(f: (KeyCode: Enum.KeyCode) -> ()): types.Disconnect
	return Bind("k_Input_doubletap"):Connect(f)
end

--- fires function when the input platform is changed \
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
function Inputs.setmouseiconenabled(state: boolean)
	UIS.MouseIconEnabled = state
end

--- returns true if mousebehavior == lockcenter
function Inputs.ismouselockcenter(): boolean
	return UIS.MouseBehavior == Enum.MouseBehavior.LockCenter
end

--- returns keycode enum from its integral value
function Inputs.findkeycodefromvalue(keycodevalue: number): Enum.KeyCode?
	return searchkeycodes(Keycodes, keycodevalue)
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

--- connects on-screen gamepad \
--- emits keycodes `ButtonY`, `ButtonX`, `ButtonB`, `ButtonA`, `ButtonR3`, `ButtonL1`, `ButtonR1`, `ButtonL2`, `ButtonR2`
--- ```
--- --- Gamepad2D: GuiObject
--- --- ┗┳ [KeyId]: GuiObject
--- ---  ┣━ ...: any
--- ---  ┗━ Button: TextButton
--- ```
function Inputs.connectGamepad2D(gamepad2d: typeof(Inputs.Gamepad2D), f: (KeyCode: Enum.KeyCode, UserInputState: Enum.UserInputState, InputFrame: Frame) -> ())
	for KeyId, KeyEnum in Inputs.Gamepad2DMap do
		local ButtonFrame = gamepad2d:FindFirstChild(KeyId)
		if not ButtonFrame then warn(gamepad2d, KeyId); continue end

		local UIStroke = ButtonFrame:FindFirstChildOfClass("UIStroke")
		local TextButton = ButtonFrame:FindFirstChildOfClass("TextButton")
		if not TextButton then continue end

		TextButton:GetPropertyChangedSignal("GuiState"):Connect(function()
			if TextButton.GuiState == Enum.GuiState.Press then
				f(KeyEnum, Enum.UserInputState.Begin, ButtonFrame)
				if UIStroke then
					UIStroke.Color = Inputs.Select2DColor
				end
			elseif TextButton.GuiState == Enum.GuiState.Idle then
				f(KeyEnum, Enum.UserInputState.End, ButtonFrame)
				if UIStroke then
					UIStroke.Color = Inputs.Deselect2DColor
				end
			end
		end)
	end
end

--- connects on-screen dpad \
--- emits keycodes `DPadUp`, `DPadLeft`, `DPadRight`, `DPadDown`, `ButtonL3`
--- ```
--- --- DPad2D: GuiObject
--- --- ┗┳ [KeyId]: GuiObject
--- ---  ┣━ ...: any
--- ---  ┗━ Button: TextButton
--- ```
function Inputs.connectDPad2D(dpad2d: typeof(Inputs.DPad2D), f: (KeyCode: Enum.KeyCode, UserInputState: Enum.UserInputState, InputFrame: Frame) -> ())
	for KeyId, KeyEnum in Inputs.DPad2DMap do
		local ButtonFrame = dpad2d:FindFirstChild(KeyId)
		if not ButtonFrame then warn(dpad2d, KeyId); continue end

		local UIStroke = ButtonFrame:FindFirstChildOfClass("UIStroke")
		local TextButton = ButtonFrame:FindFirstChildOfClass("TextButton")
		if not TextButton then continue end

		TextButton:GetPropertyChangedSignal("GuiState"):Connect(function()
			if TextButton.GuiState == Enum.GuiState.Press then
				f(KeyEnum, Enum.UserInputState.Begin, ButtonFrame)
				if UIStroke then
					UIStroke.Color = Inputs.Select2DColor
				end
			elseif TextButton.GuiState == Enum.GuiState.Idle then
				f(KeyEnum, Enum.UserInputState.End, ButtonFrame)
				if UIStroke then
					UIStroke.Color = Inputs.Deselect2DColor
				end
			end
		end)
	end
end

if IsServer then
	
else
	Inputs.PlatformId = Inputs.Platforms[UIS:GetLastInputType()]

	LocalPlayer.CharacterAdded:Connect(function(C: Model)
		Inputs.cursorblacklistadd(C)
	end)
	LocalPlayer.CharacterRemoving:Connect(Inputs.cursorblacklistremove)

	Inputs.GuiInset = GuiService:GetGuiInset()
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(function()
		Inputs.GuiInset = GuiService:GetGuiInset()
	end)

	local function UpdateMouse(inputobject: InputObject)
		local ScreenPosition = Vector2.zero
		if Inputs.PlatformId == 2 then
			local InputPosition: Vector2|Vector3 = inputobject.Position
			if Inputs.MobileScreenCenter then
				InputPosition = Inputs.MobileScreenCenter() or InputPosition
			end
			ScreenPosition = Vector2.new(InputPosition.X, InputPosition.Y)
		else
			ScreenPosition = UIS:GetMouseLocation() - Inputs.GuiInset
		end

		if Inputs.AssistMousePosition then
			ScreenPosition = Inputs.AssistMousePosition() or ScreenPosition
		end
	
		local UnitRay = Camera:ScreenPointToRay(ScreenPosition.X, ScreenPosition.Y)
		local Result = rayblacklist(UnitRay.Origin, UnitRay.Direction * 10000)

		if Result then
			Cursor.Position = Result.Position
			Cursor.Normal = Result.Normal
			Cursor.Instance = Result.Instance
		else
			Cursor.Position = UnitRay.Origin + (UnitRay.Direction * 10000)
			Cursor.Normal = Vector3.yAxis
			Cursor.Instance = nil
		end
		Cursor.Camera = Camera.CFrame.LookVector
	end

	--- input changes

	UIS.InputBegan:Connect(function(inputobject: InputObject, ...)
		if Inputs.sinkthumbstickcheck(inputobject) then return end
		Bind("k_Input_began"):Fire(inputobject, ...)

		local Now, KeyCode = os.clock(), inputobject.KeyCode
		local KeyCodeTimeTable = Inputs.InputTimes

		do --- doubletap inputs
			local Then = KeyCodeTimeTable[KeyCode] or 0
			KeyCodeTimeTable[KeyCode] = Now
			if Now - Then < Inputs.DoubleTapTime then
				Bind("k_Input_doubletap"):Fire(KeyCode)
			end
		end

		UpdateMouse(inputobject)
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

		local ThisPlatform = Inputs.Platforms[InputType] or Inputs.PlatformId
		if Inputs.PlatformId ~= ThisPlatform then
			Inputs.PlatformId = ThisPlatform
			Bind("k_Input_platformchanged"):Fire(Inputs.PlatformId)
		end
	end)
	GamepadService:GetPropertyChangedSignal("GamepadCursorEnabled"):Connect(function()
		Inputs.GamepadCursorEnabled = GamepadService.GamepadCursorEnabled
		Bind("k_Input_gamepadcursorstatechanged"):Fire(GamepadService.GamepadCursorEnabled)
	end)
end

return Inputs