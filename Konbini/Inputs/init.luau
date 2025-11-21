--!strict

local RunService = game:GetService("RunService")

local GuiService = game:GetService("GuiService")
local GamepadService = game:GetService("GamepadService")
local UserInputService = game:GetService("UserInputService")

--- ### Inputs.luau
---
--- input service wrapper
local Inputs = {
	--- interally-resolved preferred input based on recency
	PreferredInput = Enum.PreferredInput.KeyboardAndMouse;

	--- used by `Inputs.keybindof()` \
	--- to convert mouse clicks (`Enum.UserInputType`) to their `Enum.KeyCode` equivalent
	InputTypesToKeyCodes = {
		[Enum.UserInputType.MouseButton1] = Enum.KeyCode.MouseLeftButton;
		[Enum.UserInputType.MouseButton2] = Enum.KeyCode.MouseRightButton;
		[Enum.UserInputType.MouseButton3] = Enum.KeyCode.MouseMiddleButton;
	};

	--- `Enum.UserInputType -> Enum.PreferredInput` conversion table \
	--- `Enum.UserInputType.TextInput` is omitted and should be accounted for externally
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

	GamepadService = GamepadService;
	GuiService = GuiService;
	UserInputService = UserInputService;
}

--- returns index-value pair of key bound to `Inputs.InputTypesToKeyCodes[inputobject.UserInputType]` or `inputObject.KeyCode` \
--- `Enum.KeyCode.Unknown` returns `nil, nil`
function Inputs.keybindof<T>(inputobject: InputObject, keybinds: {{key: Enum.KeyCode}} & T): (number?, any?)
	local keycode = Inputs.InputTypesToKeyCodes[inputobject.UserInputType] or inputobject.KeyCode

	if keycode == Enum.KeyCode.Unknown then
		return nil, nil
	else
		for i, bind in ipairs(keybinds) do
			if bind.key == keycode then
				return i, bind
			end
		end
	end

	return nil, nil
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

--- returns `UserInputService.LasInputTypeChanged`
function Inputs.lastinputtypechanged()
	return UserInputService.LastInputTypeChanged
end

--- returns internally-resolved `UserInputService.PreferredInput` signal based on recency
function Inputs.preferredinputchanged()
	return script:GetAttributeChangedSignal("PreferredInput")
end

--- returns `UserInputService:GetMouseLocation()`
function Inputs.mouselocation()
	return UserInputService:GetMouseLocation()
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

--- returns `UserInputService.TouchTapInWorld`
function Inputs.touchtapinworld()
	return UserInputService.TouchTapInWorld
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

--- returns position, direction, and raycastresult of `camera:ScreenPointToRay`
function Inputs.screenpointraycast(camera: Camera, screenposition: Vector2, raycastparams: RaycastParams, length: number)
	local unitray = camera:ScreenPointToRay(screenposition.X, screenposition.Y)
	local origin, direction = unitray.Origin, unitray.Direction

	return origin, direction, workspace:Raycast(origin, direction * length, raycastparams)
end

if RunService:IsClient() then
	local function updatepreferredinput(userinputtype: Enum.UserInputType)
		local thispreferredinput = Inputs.InputTypesToPreferredInputs[userinputtype]
		if thispreferredinput == nil then return end
		if Inputs.PreferredInput ~= thispreferredinput then
			Inputs.PreferredInput = thispreferredinput

			script:SetAttribute("PreferredInput", Inputs.PreferredInput.Value)
		end
	end

	UserInputService.LastInputTypeChanged:Connect(updatepreferredinput)
	updatepreferredinput(UserInputService:GetLastInputType())
end

return Inputs