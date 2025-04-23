--!strict

local types = require(script.Parent.types)

local Encoder = require(script.Parent.Encoder)
local Hook = require(script.Parent.Hook)

local RunService = game:GetService("RunService")
local IsServer = RunService:IsServer()

local Players = game:GetService("Players")

local UIS = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local GamepadService = game:GetService("GamepadService")

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
--- compatible with pc, mobile, gamepad
local Inputs = {
	TouchEnabled = UIS.TouchEnabled;
	Platform = "Unknown" :: types.Platform;
	PlatformOrder = {"Unknown", "Keyboard", "Mobile", "Gamepad"};

	ThumbstickDeadzone = 0.7;
	ThumbstickDirection = "None" :: types.ThumbstickDirection;

	InputTimes = {};
	DoubleTapTime = 0.2;
	
	CursorPosition = nil :: Vector2?;

	--- write externally
	MoveVector = Vector3.zero;
	Vertical = 0;

	CursorBlacklist = table.create(16);
	GuiInset = Vector2.zero;

	Aliases = require(script.Aliases);
	Binds = require(script.Binds);
	Conversions = require(script.Conversions);
	Platforms = require(script.Platforms) :: {[Enum.UserInputType]: types.Platform};
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
	ScreenPosition = Vector2.zero;
}

local function rayblacklist(origin: Vector3, direction: Vector3)
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

	BlacklistParams.FilterDescendantsInstances = Inputs.CursorBlacklist
end

--- removes instance from cursor blacklist
function Inputs.cursorblacklistremove(thing: Instance)
	table.remove(Inputs.CursorBlacklist, table.find(Inputs.CursorBlacklist, thing) or 0)

	BlacklistParams.FilterDescendantsInstances = Inputs.CursorBlacklist
end

--- packs cursor vectors into a buffer
function Inputs.cursorpack()
	local c = buffer.create(12+3+3) --- totally folded to 18
	Encoder.writevector3(c, 0, Cursor.Position)
	Encoder.writeunitvector(c, 12, Cursor.Normal)
	Encoder.writeunitvector(c, 15, Cursor.Camera)

	return c
end

--- unpacks cursor-buffer:
--- `Position`: cursor world position
--- `Normal`: cursor surface normal
--- `Camera`: camera normal
function Inputs.cursorunpack(c: buffer)
	return
		Encoder.readvector3(c, 0),
		Encoder.readunitvector(c, 12),
		Encoder.readunitvector(c, 15)
end

--- returns key and bind bound to `inputobject`
function Inputs.keybindof(inputobject: InputObject, set: {string}?): (string?, any)
	local keycode = Inputs.Conversions[inputobject.UserInputType] or inputobject.KeyCode
	local platform = Inputs.Platform

	if set then
		for _, key in set do
			local bind = Inputs.Binds[key]::any
			if not bind then continue end

			local ovalue = bind.Overwrites[platform]
			if (ovalue == keycode) and (ovalue ~= Enum.KeyCode.Unknown) then
				return key, bind.Value
			else
				continue
			end
		end
	else
		local t = table.create(32)
		for key in Inputs.Binds do
			table.insert(t, key)
		end

		return Inputs.keybindof(inputobject, t::{string})
	end

	return
end

--- overwrites keybinds
function Inputs.keybindoverwrite(ow: {[string]: {[types.Platform]: Enum.KeyCode}})
	for key, bind in Inputs.Binds do
		local otable = ow[key::any]

		for platform, enum in (bind::any).Defaults do
			local ovalue = otable and otable[platform] or enum;
			(bind::any).Overwrites[platform] = ovalue;
		end
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

--- returns a platform id and its associated value corresponding to `inputobject.UserInputType`
function Inputs.platform(inputobject: InputObject)
	local platform = Inputs.Platforms[inputobject.UserInputType]

	local platformvalue = table.find(Inputs.PlatformOrder, platform)
	assert(platformvalue)

	return platform::types.Platform, platformvalue
end

function Inputs.platformvalue(platform: types.Platform)
	local platformvalue = table.find(Inputs.PlatformOrder, platform)
	assert(platformvalue)

	return platformvalue
end

--- binds function to `UserInputService.InputBegan`
function Inputs.began(f: (inputobject: InputObject, sunkinput: boolean) -> ())
	return Hook("k_InputBegan").Connect(f)
end

--- binds function to `UserInputService.InputEnded`
function Inputs.ended(f: (inputobject: InputObject, sunkinput: boolean) -> ())
	return Hook("k_InputEnded").Connect(f)
end

--- binds function to `UserInputService.InputChanged`
function Inputs.changed(f: (inputobject: InputObject, sunkinput: boolean) -> ())
	return Hook("k_InputChanged").Connect(f)
end

--- fires function when a key is double-tapped
function Inputs.doubletap(f: (keycode: Enum.KeyCode) -> ())
	return Hook("k_DoubleTap").Connect(f)
end

--- fires function when the input platform is changed
function Inputs.platformchanged(f: (platform: types.Platform) -> ())
	return Hook("k_PlatformChanged").Connect(f)
end

--- fires function when the gamepad cursor is toggled on/off
function Inputs.gamepadcursorstatechanged(f: (gamepadcursorenabled: boolean) -> ())
	return Hook("k_GamepadCursorStateChanged").Connect(f)
end

--- returns Inputs.ThumbstickDirection
function Inputs.thumbstickdirection(): types.ThumbstickDirection
	return Inputs.ThumbstickDirection
end

--- sets visibility of mouse icon
function Inputs.setmouseiconenabled(state: boolean)
	UIS.MouseIconEnabled = state
end

function Inputs.setmousebehavior(mousebehavior: Enum.MouseBehavior)
	UIS.MouseBehavior = mousebehavior
end

--- returns `UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter`
function Inputs.ismouselockcenter()
	return UIS.MouseBehavior == Enum.MouseBehavior.LockCenter
end

--- returns keycode enum from its integral value
function Inputs.findkeycodefromvalue(keycodevalue: number): Enum.KeyCode?
	return searchkeycodes(Keycodes, keycodevalue)
end

--- returns true if the inputobject was *not* obscured by the on-screen thumbstick
function Inputs.sinkthumbstickcheck(inputobject: InputObject)
	if not PlayerGui then return false end
	if Inputs.Platform == "Gamepad" then
		local screenposition = inputobject.Position
		local array = PlayerGui:GetGuiObjectsAtPosition(screenposition.X, screenposition.Y)
		if #array == 0 then
			return true
		else
			for _, GuiObject in array do
				if GuiObject.Name ~= "DynamicThumbstickFrame" then continue end
				return false
			end
		end
	end
	return true
end

--- toggles (displaces) mobile gui elements off-screen \
--- setting `.Enabled` does not work as that property is constantly set by the control scripts
function Inputs.togglemobileinterface(thumbstickenabled: boolean?, jumpbuttonenabled: boolean?)
	assert(PlayerGui)
	local function t(TouchGui: Instance)
		if TouchGui.Name ~= "TouchGui" then return end
		local touchcontrolframe = TouchGui:WaitForChild("TouchControlFrame")

		local jumpbutton = touchcontrolframe:WaitForChild("JumpButton") :: ImageButton
		if not jumpbuttonenabled then
			jumpbutton.Position = UDim2.fromScale(2, 2)
		end

		local thumbstick = touchcontrolframe:WaitForChild("DynamicThumbstickFrame") :: Frame
		if not thumbstickenabled then
			thumbstick.Position = UDim2.fromScale(2, 2)
		end
	end

	for _, thing in PlayerGui:GetChildren() do
		t(thing)
	end
	return PlayerGui.ChildAdded:Connect(function(thing)
		t(thing)
	end)
end

--- fires function when the esc menu is opened
function Inputs.menuopened(f: () -> ())
	return GuiService.MenuOpened:Connect(f)
end

--- fires function when the esc menu is closed
function Inputs.menuclosed(f: () -> ())
	return GuiService.MenuClosed:Connect(f)
end

if IsServer then
	
else
	Inputs.Platform = Inputs.Platforms[UIS:GetLastInputType()]

	LocalPlayer.CharacterAdded:Connect(function(C: Model)
		Inputs.cursorblacklistadd(C)
	end)
	LocalPlayer.CharacterRemoving:Connect(Inputs.cursorblacklistremove)

	Inputs.GuiInset = GuiService:GetGuiInset()
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(function()
		Inputs.GuiInset = GuiService:GetGuiInset()
	end)

	local function updatemouse(inputobject: InputObject?)
		local screenposition = Vector2.zero

		if Inputs.CursorPosition then
			screenposition = Inputs.CursorPosition
		else
			if Inputs.Platform == "Mobile" then
				if inputobject then
					local p = inputobject.Position
					screenposition = Vector2.new(p.X, p.Y)
				end
			else
				screenposition = UIS:GetMouseLocation() - Inputs.GuiInset
			end
		end
	
		local unitray = Camera:ScreenPointToRay(screenposition.X, screenposition.Y)
		local result = rayblacklist(unitray.Origin, unitray.Direction * 0x800) --- ray length 2048 units

		if result then
			Cursor.Position = result.Position
			Cursor.Normal = result.Normal
			Cursor.Instance = result.Instance
		else
			Cursor.Position = unitray.Origin + (unitray.Direction * 0x800)
			Cursor.Normal = Vector3.yAxis
			Cursor.Instance = nil
		end
		Cursor.Camera = Camera.CFrame.LookVector
		Cursor.ScreenPosition = screenposition
	end

	local thumbstickposition = Vector3.zero
	local function updatethumbstickdirection(inputobject: InputObject)
		if inputobject.KeyCode ~= Enum.KeyCode.Thumbstick1 then return end
		thumbstickposition = inputobject.Position
		if thumbstickposition.Magnitude < Inputs.ThumbstickDeadzone then
			Inputs.ThumbstickDirection = "None"
		else
			local pX, pY = thumbstickposition.X, thumbstickposition.Y
			local real: types.ThumbstickDirection = "None"
			
			if math.abs(pX) > math.abs(pY) then
				if pX < 0 then
					real = "Left"
				else
					real = "Right"
				end
			else
				if pY < 0 then
					real = "Down"
				else
					real = "Up"
				end
			end
			
			if Inputs.ThumbstickDirection ~= real then
				Inputs.ThumbstickDirection = real
			end
		end
	end

	--- input changes

	UIS.InputBegan:Connect(function(inputobject: InputObject, ...)
		if Inputs.sinkthumbstickcheck(inputobject) then return end
		Hook("k_InputBegan").Fire(inputobject, ...)

		local now, keycode = os.clock(), inputobject.KeyCode
		local keycodetimetable = Inputs.InputTimes

		do --- doubletap inputs
			local later = keycodetimetable[keycode] or 0
			keycodetimetable[keycode] = now
			if now - later < Inputs.DoubleTapTime then
				Hook("k_DoubleTap").Fire(keycode)
			end
		end

		updatemouse(inputobject)
	end)
	UIS.InputEnded:Connect(function(...)
		Hook("k_InputEnded").Fire(...)
		updatemouse(...)
	end)
	UIS.InputChanged:Connect(function(...)
		Hook("k_InputChanged").Fire(...)
		updatemouse(...)
		updatethumbstickdirection(...)
	end)
	UIS.TouchStarted:Connect(function(...)
		if not Inputs.sinkthumbstickcheck(...) then return end
		Hook("k_InputBegan").Fire(...)
	end)
	UIS.TouchEnded:Connect(function(...)
		Hook("k_InputEnded").Fire(...)
	end)
	UIS.TouchMoved:Connect(function(...)
		Hook("k_InputChanged").Fire(...)
	end)
	UIS.LastInputTypeChanged:Connect(function(userinputtype: Enum.UserInputType)
		Inputs.TouchEnabled = UIS.TouchEnabled

		local platform = Inputs.Platforms[userinputtype] or Inputs.Platform
		if Inputs.Platform ~= platform then
			Inputs.Platform = platform::any
			Hook("k_PlatformChanged").Fire(Inputs.Platform)
		end
	end)
	GamepadService:GetPropertyChangedSignal("GamepadCursorEnabled"):Connect(function()
		Inputs.GamepadCursorEnabled = GamepadService.GamepadCursorEnabled
		Hook("k_GamepadCursorStateChanged").Fire(GamepadService.GamepadCursorEnabled)
	end)

	RunService.Heartbeat:Connect(updatemouse)
end

return Inputs