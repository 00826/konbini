--!strict

local RunService = game:GetService("RunService")
local IsServer = RunService:IsServer()

local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local GamepadService = game:GetService("GamepadService")

local Keycodes = Enum.KeyCode:GetEnumItems()

local BlacklistParams = RaycastParams.new()
BlacklistParams.FilterType = Enum.RaycastFilterType.Exclude
BlacklistParams.IgnoreWater = true
BlacklistParams.FilterDescendantsInstances = {}

local CursorBlacklist = {}

--- ### Inputs.luau
---
--- all-in-one input wrapper
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

		MouseBehavior = Enum.MouseBehavior.Default;
		TargetMouseBehavior = Enum.MouseBehavior.Default;
	};

	--- used by `Inputs.keybindof()` \
	--- to convert mouse clicks (`Enum.UserInputType`) to their `Enum.KeyCode` equivalent
	InputTypesToKeyCodes = {
		[Enum.UserInputType.MouseButton1] = Enum.KeyCode.MouseLeftButton;
		[Enum.UserInputType.MouseButton2] = Enum.KeyCode.MouseRightButton;
		[Enum.UserInputType.MouseButton3] = Enum.KeyCode.MouseMiddleButton;
	};

	CurrentInputDevice = "Unknown" :: "Unknown"|"Keyboard"|"Mobile"|"Gamepad";
	DeviceMap = {
		[Enum.UserInputType.None] = "Unknown";

		[Enum.UserInputType.Keyboard] = "Keyboard";
		[Enum.UserInputType.MouseButton1] = "Keyboard";
		[Enum.UserInputType.MouseButton2] = "Keyboard";
		[Enum.UserInputType.MouseButton3] = "Keyboard";
		[Enum.UserInputType.MouseMovement] = "Keyboard";
		[Enum.UserInputType.MouseWheel] = "Keyboard";
	
		[Enum.UserInputType.Touch] = "Mobile";
	
		[Enum.UserInputType.Gamepad1] = "Gamepad";
		[Enum.UserInputType.Gamepad2] = "Gamepad";
		[Enum.UserInputType.Gamepad3] = "Gamepad";
		[Enum.UserInputType.Gamepad4] = "Gamepad";
		[Enum.UserInputType.Gamepad5] = "Gamepad";
		[Enum.UserInputType.Gamepad6] = "Gamepad";
		[Enum.UserInputType.Gamepad7] = "Gamepad";
		[Enum.UserInputType.Gamepad8] = "Gamepad";
	} :: {[Enum.UserInputType]: "Unknown"|"Keyboard"|"Mobile"|"Gamepad"};
}

--- returns key bound to `Inputs.InputTypesToKeyCodes[inputobject.UserInputType]` or `inputObject.KeyCode`
function Inputs.keybindof(inputobject: InputObject, keybinds: {value: Enum.KeyCode} & {[string]: any}): (number?, ({value: Enum.KeyCode} & {[string]: any})?)
	local keycode = Inputs.InputTypesToKeyCodes[inputobject.UserInputType] or inputobject.KeyCode

	for i, bind in ipairs(keybinds) do
		if bind.Value == keycode then
			return i, bind
		end
	end

	return nil, nil
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

--- defers `callback` when the local device input changes
function Inputs.inputdevicechanged(callback: (inputdevice: "Unknown"|"Keyboard"|"Mobile"|"Gamepad") -> ())
	return UserInputService.LastInputTypeChanged:Connect(function(userinputtype: Enum.UserInputType)
		local newinputdevice = Inputs.DeviceMap[userinputtype] or "Unknown"
		if newinputdevice ~= Inputs.CurrentInputDevice then
			Inputs.CurrentInputDevice = newinputdevice::any

			task.defer(callback, Inputs.CurrentInputDevice)
		end
	end)
end

--- calls `GamepadService:EnableGamepadCursor(target)` or `GamepadService:DisableGamepadCursor()` depending on state
function Inputs.setgamepadcursorstate(state: boolean, target: GuiObject?)
	if state == true then
		GamepadService:EnableGamepadCursor(target)
	else
		GamepadService:DisableGamepadCursor()
	end
end

--- defers `callback` when the gamepad cursor state changes
function Inputs.gamepadcursorenabled(callback: (state: boolean) -> ())
	return GamepadService:GetPropertyChangedSignal("GamepadCursorEnabled"):Connect(function()
		task.defer(callback, GamepadService.GamepadCursorEnabled)
	end)
end

--- returns `GuiService.MenuOpened`
function Inputs.menuopened()
	return GuiService.MenuOpened
end

--- returns `GuiService.MenuClosed`
function Inputs.menuclosed()
	return GuiService.MenuClosed
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

--- returns `Enum.Keycode` associated with enum value `ev` from optional range `keycodes (?=Enum.KeyCode:GetEnumItems())`
function Inputs.keycodefromenumvalue(ev: number, keycodes: {Enum.KeyCode}?): Enum.KeyCode?
	keycodes = keycodes or Keycodes
	assert(keycodes)

	local L = 1
	local R = #keycodes

	if L > R then
		return nil
	else
		local idx = (L + R) // 2
		local value = keycodes[idx]

		local result = value.Value == ev and 0 or value.Value < ev and 1 or 2

		if result == 0 then
			return value
		else
			if result == 1 then
				L = idx + 1
			elseif result == 2 then
				R = idx - 1
			end
			return Inputs.keycodefromenumvalue(ev, table.move(keycodes, L, R, 1, table.create(L + R)))
		end
	end
end

if IsServer then
else
	Inputs.CurrentInputDevice = (Inputs.DeviceMap[UserInputService:GetLastInputType()] or "Unknown")::any

	local cursor = Inputs.Cursor

	cursor.GuiInset = GuiService:GetGuiInset()
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(function()
		cursor.GuiInset = GuiService:GetGuiInset()
	end)

	local function updatemouse(inputobject: InputObject?)
		if cursor.TargetMouseBehavior ~= UserInputService.MouseBehavior then
			UserInputService.MouseBehavior = cursor.TargetMouseBehavior
			cursor.MouseBehavior = UserInputService.MouseBehavior
		end

		local currentcamera = workspace.CurrentCamera
		local screenposition = Vector2.zero

		if cursor.ForceScreenPosition then
			screenposition = cursor.ForceScreenPosition
		else
			if Inputs.CurrentInputDevice == "Mobile" then
				if inputobject then
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
	
	RunService.Heartbeat:Connect(updatemouse)
end

return Inputs