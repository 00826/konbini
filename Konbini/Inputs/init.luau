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
--- compatible with pc, mobile, gamepad \
--- \
--- PlatformId `0`: unknown \
--- PlatformId `1`: pc \
--- PlatformId `2`: mobile \
--- PlatformId `3`: gamepad
local Inputs = {
	TouchEnabled = UIS.TouchEnabled;
	PlatformId = 0;

	ThumbstickDeadzone = 0.7;
	ThumbstickDirection = "None" :: types.ThumbstickDirection;

	InputTimes = {};
	DoubleTapTime = 0.2;
	
	MobileScreenCenter = nil :: (() -> Vector2)?;

	--- write externally
	MoveVector = Vector3.zero;

	CursorBlacklist = table.create(16);
	GuiInset = Vector2.zero;

	Aliases = require(script.Aliases);
	Platforms = require(script.Platforms);
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

--- returns key-value pair bound to keycode with respect to internal platform id \
--- `Enum.KeyCode.Unknown (value 0)` immediately returns nil
function Inputs.keybind(keycode: Enum.KeyCode, k: {[string]: types.Keybind}): (string?, types.Keybind?)
	local platformid = Inputs.PlatformId
	if platformid == 0 then
		return
	elseif keycode == Enum.KeyCode.Unknown then
		return nil, nil
	else
		for keyid, keybind in k do
			local reals = k[keyid].Reals
			local defaults = k[keyid].Defaults

			assert(type(reals) == "table")
			assert(type(defaults) == "table")

			local boundkey = reals[platformid] or defaults[platformid]
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

--- returns an enumeration of keybind aliases with respect to keybind table `k`
function Inputs.keybindenumerate(keyids: {string}, k: {[string]: types.Keybind})
	local platformid = Inputs.PlatformId
	if platformid ~= 0 then
		local enumeration = table.create(#keyids)

		for i, keyid in ipairs(keyids) do
			local defaults = k[keyid].Defaults :: {number}
			local reals = k[keyid].Reals :: {number}
			local keycode = searchkeycodes(Keycodes, reals[platformid] or defaults[platformid])
			table.insert(enumeration, i, Inputs.Aliases[keycode::any] or keycode and keycode.Name or keyid) --- remove ::any when solver grows a brain
		end

		return enumeration
	end

	return keyids
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
function Inputs.platform(inputobject: InputObject)
	return Inputs.Platforms[inputobject.UserInputType] or 0
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

--- fires function when the input platform is changed \
--- `0`: unknown \
--- `1`: pc \
--- `2`: mobile \
--- `3`: gamepad
function Inputs.platformchanged(f: (platformid: number) -> ())
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
	if Inputs.PlatformId == 2 then
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

	local function updatemouse(inputobject: InputObject)
		local screenposition = Vector2.zero
		if Inputs.PlatformId == 2 then
			local inputposition: Vector2|Vector3 = inputobject.Position
			if Inputs.MobileScreenCenter then
				inputposition = Inputs.MobileScreenCenter() or inputposition
			end
			screenposition = Vector2.new(inputposition.X, inputposition.Y)
		else
			screenposition = UIS:GetMouseLocation() - Inputs.GuiInset
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
	end

	local function updatethumbstickdirection(inputobject: InputObject)
		if inputobject.KeyCode ~= Enum.KeyCode.Thumbstick1 then return end
		local inputposition = inputobject.Position
		if inputposition.Magnitude < Inputs.ThumbstickDeadzone then
			Inputs.ThumbstickDirection = "None"
		else
			local pX, pY = inputposition.X, inputposition.Y
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

		local platformid = Inputs.Platforms[userinputtype] or Inputs.PlatformId
		if Inputs.PlatformId ~= platformid then
			Inputs.PlatformId = platformid
			Hook("k_PlatformChanged").Fire(Inputs.PlatformId)
		end
	end)
	GamepadService:GetPropertyChangedSignal("GamepadCursorEnabled"):Connect(function()
		Inputs.GamepadCursorEnabled = GamepadService.GamepadCursorEnabled
		Hook("k_GamepadCursorStateChanged").Fire(GamepadService.GamepadCursorEnabled)
	end)
end

return Inputs