--!strict

local RunService = game:GetService("RunService")
local IsServer = RunService:IsServer()

local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local GamepadService = game:GetService("GamepadService")

local BlacklistParams = RaycastParams.new()
BlacklistParams.FilterType = Enum.RaycastFilterType.Exclude
BlacklistParams.IgnoreWater = true
BlacklistParams.FilterDescendantsInstances = {}

local CursorBlacklist = {}

local InternalPreferredInput = Enum.PreferredInput.KeyboardAndMouse

--- ### Inputs.luau
---
--- input service wrapper
local Inputs = {
	--- written externally. just exists as a universal reference to device input vector
	InputVector = Vector3.zero;

	Cursor = {
		GuiInset = Vector2.zero;
		ScreenPosition = Vector2.zero;
		ForceScreenPosition = nil;
		CameraDirection = -Vector3.zAxis;

		RaycastDistance = 2048;

		Distance = 0;
		Position = Vector3.zero;
		Normal = Vector3.yAxis;
		Instance = nil;
		Material = nil;
	};

	--- used by `Inputs.keybindof()` \
	--- to convert mouse clicks (`Enum.UserInputType`) to their `Enum.KeyCode` equivalent
	InputTypesToKeyCodes = {
		[Enum.UserInputType.MouseButton1] = Enum.KeyCode.MouseLeftButton;
		[Enum.UserInputType.MouseButton2] = Enum.KeyCode.MouseRightButton;
		[Enum.UserInputType.MouseButton3] = Enum.KeyCode.MouseMiddleButton;
	};

	InputTypesToPreferredInputs = {
		[Enum.UserInputType.None] = Enum.PreferredInput.KeyboardAndMouse;
		[Enum.UserInputType.Focus] = Enum.PreferredInput.KeyboardAndMouse;

		[Enum.UserInputType.MouseButton1] = Enum.PreferredInput.KeyboardAndMouse;
		[Enum.UserInputType.MouseButton2] = Enum.PreferredInput.KeyboardAndMouse;
		[Enum.UserInputType.MouseButton3] = Enum.PreferredInput.KeyboardAndMouse;
		[Enum.UserInputType.MouseWheel] = Enum.PreferredInput.KeyboardAndMouse;
		[Enum.UserInputType.MouseMovement] = Enum.PreferredInput.KeyboardAndMouse;
		[Enum.UserInputType.Keyboard] = Enum.PreferredInput.KeyboardAndMouse;
		
		[Enum.UserInputType.Touch] = Enum.PreferredInput.Touch;
		[Enum.UserInputType.Accelerometer] = Enum.PreferredInput.Touch;
		[Enum.UserInputType.Gyro] = Enum.PreferredInput.Touch;

		[Enum.UserInputType.Gamepad1] = Enum.PreferredInput.Gamepad;
		[Enum.UserInputType.Gamepad2] = Enum.PreferredInput.Gamepad;
		[Enum.UserInputType.Gamepad3] = Enum.PreferredInput.Gamepad;
		[Enum.UserInputType.Gamepad4] = Enum.PreferredInput.Gamepad;
		[Enum.UserInputType.Gamepad5] = Enum.PreferredInput.Gamepad;
		[Enum.UserInputType.Gamepad6] = Enum.PreferredInput.Gamepad;
		[Enum.UserInputType.Gamepad7] = Enum.PreferredInput.Gamepad;
		[Enum.UserInputType.Gamepad8] = Enum.PreferredInput.Gamepad;
	};

	ThumbstickL = Vector3.zero;
	ThumbstickR = Vector3.zero;
	SignedThumbstickL = Vector3.zero;
	SignedThumbstickR = Vector3.zero;
	SignedThumbstickDeadzone = 1/3;
}

--- returns key bound to `Inputs.InputTypesToKeyCodes[inputobject.UserInputType]` or `inputObject.KeyCode` \
--- `Enum.KeyCode.Unknown` returns `nil, nil`
function Inputs.keybindof(inputobject: InputObject, keybinds: {{value: Enum.KeyCode} & {[string]: any}}): (number?, ({value: Enum.KeyCode} & {[string]: any})?)
	local keycode = Inputs.InputTypesToKeyCodes[inputobject.UserInputType] or inputobject.KeyCode

	if keycode == Enum.KeyCode.Unknown then
		return nil, nil
	else
		for i, bind in ipairs(keybinds) do
			if bind.value == keycode then
				return i, bind
			end
		end
	end

	return
end

--- adds thing to cursor raycast blacklist, if it does not exist already
function Inputs.cursorblacklistinsert(thing: Instance)
	if not table.find(CursorBlacklist, thing) then
		table.insert(CursorBlacklist, thing)
	end

	BlacklistParams.FilterDescendantsInstances = CursorBlacklist
end

--- removes thing from cursor raycast blacklist
function Inputs.cursorblacklistremove(thing: Instance)
	table.remove(CursorBlacklist, table.find(CursorBlacklist, thing) or 0)

	BlacklistParams.FilterDescendantsInstances = CursorBlacklist
end

--- clears cursor raycast blacklist
function Inputs.cursorblacklistclear()
	table.clear(CursorBlacklist)

	BlacklistParams.FilterDescendantsInstances = CursorBlacklist
end

--- returns `UserInputService.InputBegan`
function Inputs.began()
	return UserInputService.InputBegan
end

--- returns `UserInputService.InputChanged`
function Inputs.changed()
	return UserInputService.InputChanged
end

--- returns `UserInputService.InputEnded`
function Inputs.ended()
	return UserInputService.InputEnded
end

--- returns internally-resolved `UserInputService.PreferredInput` based on recency
function Inputs.preferredinput()
	return InternalPreferredInput
end

--- returns `Enum.UserInputType` converted to its associated `Enum.PreferredInput`
function Inputs.userinputtypetopreferredinput(userinputtype: Enum.UserInputType)
	return Inputs.InputTypesToPreferredInputs[userinputtype]
end

--- returns `UserInputService.LasInputTypeChanged`
function Inputs.lastinputtypechanged()
	return UserInputService.LastInputTypeChanged
end

--- returns `UserInputService:GetMouseLocation()`
function Inputs.mouselocation()
	return UserInputService:GetMouseLocation()
end

--- calls `GamepadService:EnableGamepadCursor(target)` or `GamepadService:DisableGamepadCursor()` depending on state
function Inputs.setgamepadcursorstate(state: boolean, target: GuiObject?)
	if state == true then
		GamepadService:EnableGamepadCursor(target)
	else
		GamepadService:DisableGamepadCursor()
	end
end

--- returns `GamepadService.GamepadCursorEnabled`
function Inputs.gamepadcursorenabled()
	return GamepadService.GamepadCursorEnabled
end

--- returns `GamepadService:GetPropertyChangedSignal("GamepadCursorEnabled")`
function Inputs.gamepadcursorstatechanged()
	return GamepadService:GetPropertyChangedSignal("GamepadCursorEnabled")
end

--- returns `GuiService.MenuOpened`
function Inputs.menuopened()
	return GuiService.MenuOpened
end

--- returns `GuiService.MenuClosed`
function Inputs.menuclosed()
	return GuiService.MenuClosed
end

--- returns `UserInputService.MouseBehavior`
function Inputs.mousebehavior()
	return UserInputService.MouseBehavior
end

--- equivalent to `UserInputService.MouseBehavior = mousebehavior`
function Inputs.setmousebehavior(mousebehavior: Enum.MouseBehavior)
	UserInputService.MouseBehavior = mousebehavior
end

--- returns `UserInputService.MouseIcon`
function Inputs.mouseicon()
	return UserInputService.MouseIcon
end

--- equivalent to `UserInputService.MouseIcon = icon or ""`
function Inputs.setmouseicon(icon: string?)
	UserInputService.MouseIcon = icon or ""
end

--- returns `UserInputService.TouchEnabled`
function Inputs.touchenabled()
	return UserInputService.TouchEnabled
end

--- defers `callback` when a guiobject matching name "TouchGui" is added or already exists in `playergui` \
--- \
--- *recommended to displace `TouchGui/TouchControlFrame/JumpButton` and `TouchGui/TouchControlFrame/DynamicThumbstickFrame`* \
--- *to `UDim2.fromScale(2, 2)` (or somewhere offscreen) as their `Visible` properties are always being changed by the player controlmodule*
function Inputs.touchguiadded(playergui: PlayerGui, callback: (touchgui: GuiObject) -> ())
	for _, thing in playergui:GetChildren() do
		if not thing:IsA("GuiObject") then continue end
		if thing.Name ~= "TouchGui" then continue end
		task.defer(callback, thing)
	end

	return playergui.ChildAdded:Connect(function(thing)
		if not thing:IsA("GuiObject") then return end
		if thing.Name ~= "TouchGui" then return end
		task.defer(callback, thing)
	end)
end

if IsServer then
else
	local cursor = Inputs.Cursor

	cursor.GuiInset = GuiService:GetGuiInset()
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(function()
		cursor.GuiInset = GuiService:GetGuiInset()
	end)

	local function updatemouse(inputobject: InputObject?)
		local currentcamera = workspace.CurrentCamera
		local screenposition = Vector2.zero

		if cursor.ForceScreenPosition then
			screenposition = cursor.ForceScreenPosition
		else
			if UserInputService.PreferredInput == Enum.PreferredInput.Touch then
				if inputobject and typeof(inputobject) == "InputObject" then
					local p = inputobject.Position
					screenposition = Vector2.new(p.X, p.Y)
				end
			else
				screenposition = UserInputService:GetMouseLocation() - cursor.GuiInset
			end
		end
	
		local unitray = currentcamera:ScreenPointToRay(screenposition.X, screenposition.Y)
		local result = workspace:Raycast(unitray.Origin, unitray.Direction * cursor.RaycastDistance, BlacklistParams)

		if result then
			cursor.Position = result.Position
			cursor.Normal = result.Normal
			cursor.Distance = result.Distance
			cursor.Instance = result.Instance
			cursor.Material = result.Material
		else
			cursor.Position = unitray.Origin + (unitray.Direction * cursor.RaycastDistance)
			cursor.Normal = Vector3.yAxis
			cursor.Distance = cursor.RaycastDistance
			cursor.Instance = nil
			cursor.Material = nil
		end

		cursor.CameraDirection = currentcamera.CFrame.LookVector
		cursor.ScreenPosition = screenposition
	end

	UserInputService.InputBegan:Connect(updatemouse)
	UserInputService.InputChanged:Connect(updatemouse)
	UserInputService.InputEnded:Connect(updatemouse)
	
	UserInputService.LastInputTypeChanged:Connect(function(userinputtype: Enum.UserInputType)
		local thispreferredinput = Inputs.userinputtypetopreferredinput(userinputtype)
		if InternalPreferredInput ~= thispreferredinput then
			InternalPreferredInput = thispreferredinput or InternalPreferredInput
		end
	end)
	
	RunService.Heartbeat:Connect(updatemouse)

	local function updatethumbstickdirection(inputobject: InputObject)
		if inputobject.KeyCode == Enum.KeyCode.Thumbstick1 then
			Inputs.ThumbstickL = inputobject.Position

			local x, y = Inputs.ThumbstickL.X, Inputs.ThumbstickL.Y
			Inputs.SignedThumbstickL = Vector3.new(
				math.abs(x) > Inputs.SignedThumbstickDeadzone and math.sign(x) or 0,
				math.abs(y) > Inputs.SignedThumbstickDeadzone and math.sign(y) or 0,
				0
			)
		elseif inputobject.KeyCode == Enum.KeyCode.Thumbstick2 then
			Inputs.ThumbstickR = inputobject.Position

			local x, y = Inputs.ThumbstickR.X, Inputs.ThumbstickR.Y
			Inputs.SignedThumbstickR = Vector3.new(
				math.abs(x) > Inputs.SignedThumbstickDeadzone and math.sign(x) or 0,
				math.abs(y) > Inputs.SignedThumbstickDeadzone and math.sign(y) or 0,
				0
			)
		end
	end

	UserInputService.InputChanged:Connect(updatethumbstickdirection)
end

return Inputs