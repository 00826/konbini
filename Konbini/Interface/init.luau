--!strict

local types = require(script.Parent.types)

local TweenService = game:GetService("TweenService")

local function tween(object: Instance, properties: {[string]: any}, time: number, ...)
	TweenService:Create(object, TweenInfo.new(time, ...), properties):Play()
end

local function cartesian(p: number, w: number): (number, number)
	p -= 1
	return p // w, p % w
end

--- ### Interface.luau
---
--- contains quality-of-life functions for UI development
local Interface = {
	ButtonSounds = {} :: {[string]: Sound};

	UDim = table.freeze{
		zero = UDim.new(0, 0);

		--- returns `UDim.new(w, w)`
		fromConstant = function(w: number)
			return UDim.new(w, w)
		end;
	};
	UDim2 = table.freeze{
		zero = UDim2.fromScale(0, 0);

		oneOffset = UDim2.fromOffset(1, 1);
		xOffset = UDim2.fromOffset(1, 0);
		yOffset = UDim2.fromOffset(0, 1);
		oneScale = UDim2.fromScale(1, 1);
		xScale = UDim2.fromScale(1, 0);
		yScale = UDim2.fromScale(0, 1);

		half = UDim2.fromScale(0.5, 0.5);
		top = UDim2.fromScale(0.5, 0);
		bottom = UDim2.fromScale(0.5, 1);
		left = UDim2.fromScale(0, 0.5);
		right = UDim2.fromScale(1, 0.5);
		topLeft = UDim2.fromScale(0, 0);
		topRight = UDim2.fromScale(1, 0);
		bottomLeft = UDim2.fromScale(0, 1);
		bottomRight = UDim2.fromScale(1, 1);

		--- returns `UDim2.new(w, w)`
		fromConstant = function(w: number)
			return UDim2.new(w, w)
		end;
	};
	Vector2 = table.freeze{
		half = Vector2.new(0.5, 0.5);
		top = Vector2.new(0.5, 0);
		bottom = Vector2.new(0.5, 1);
		left = Vector2.new(0, 0.5);
		right = Vector2.new(1, 0.5);
		topLeft = Vector2.new(0, 0);
		topRight = Vector2.new(1, 0);
		bottomLeft = Vector2.new(0, 1);
		bottomRight = Vector2.new(1, 1);

		--- returns `Vector2.new(w, w)`
		fromConstant = function(w: number)
			return Vector2.new(w, w)
		end;
	};
	Color3 = table.freeze{
		white = Color3.fromRGB(255, 255, 255);
		gray = Color3.fromRGB(128, 128, 128);
		black = Color3.fromRGB(0, 0, 0);

		--- returns `Color3.fromRGB(w, w, w)`
		fromConstant = function(w: number)
			return Color3.fromRGB(w, w, w)
		end;
		--- adjusts color3 saturation
		adjustSaturation = function(c: Color3, value: number)
			local H, S, V = c:ToHSV()
			return Color3.fromHSV(H, math.clamp(S + (value / 100), 0, 1), V)
		end;
		--- returns approximate sort value of color3
		sortValue = function(c: Color3)
			return (c:ToHSV()) * 100
		end;
		--- inverts color3
		invert = function(c: Color3)
			return Color3.new(1 - c.R, 1 - c.G, 1 - c.B)
		end;
		--- returns a vertexcolor from color3
		toVertexColor = function(c: Color3)
			return Vector3.new(c.R, c.G, c.B) / 255
		end;
		--- returns a color3 from vertexcolor
		fromVertexColor = function(v: Vector3)
			v *= 255
			return Color3.new(v.X, v.Y, v.Z)
		end;
	};
	ColorSequence = table.freeze{
		white = ColorSequence.new(Color3.fromRGB(255, 255, 255));
		gray = ColorSequence.new(Color3.fromRGB(128, 128, 128));
		black = ColorSequence.new(Color3.fromRGB(0, 0, 0));

		--- returns `ColorSequence.new(Color3.fromRGB(w, w, w))`
		fromConstant = function(w: number)
			return ColorSequence.new(Color3.fromRGB(w, w, w))
		end;
		--- returns color3 in colorsequence at interpolant `a`
		colorAt = function(sequence: ColorSequence, a: number): Color3
			local LastKeypoint = nil
			for _, Keypoint in ipairs(sequence.Keypoints) do
				if a < Keypoint.Time then
					local T0 = LastKeypoint.Time
		
					return LastKeypoint.Value:Lerp(Keypoint.Value, (a - T0) / (Keypoint.Time - T0))
				end
				LastKeypoint = Keypoint
			end
			return LastKeypoint and LastKeypoint.Value or Color3.fromRGB(255, 255, 255)
		end;
	};
	AspectRatios = table.freeze{
		--- `1:1`
		Square = 1/1;
		--- `4:3`
		Classy = 4/3;
		--- `1.618:1`
		GoldenRatio = (1 + 5^0.5) * 0.5;
		--- `16:9`
		Standard = 16/9;
		--- `21:9`
		Ultrawide = 21/9;
		--- `1.85:1`
		Cinema = 37/20;
		--- `6:13`
		Portrait = 6/13;
	};

	suffixes = table.freeze{""; "K"; "M"; "B"; "T"; "Qd", "Qt", "Sx", "Sp", "Oc", "No", "De"};
}

--- returns point on bezier curve at interpolant `A`
function Interface.bezier(A: number, points: {UDim2}): UDim2
	if #points > 1 then
		local NewPoints = {}
		for i = 1, #points - 1 do
			table.insert(NewPoints, points[i]:Lerp(points[i + 1], A))
		end
		return Interface.bezier(A, NewPoints)
	end
	return points[1]
end

--- plays imported sound
function Interface.playsound(ref: string)
	local Sound = Interface.ButtonSounds[ref]
	assert(Sound, `{ref} not an imported sound`)

	local S = Sound:Clone()
	S.PlayOnRemove = true
	S.Parent = script
	S:Destroy()
end

--- imports sounds
function Interface.importsounds(sounds: {Sound})
	for _, Sound in sounds do
		Interface.ButtonSounds[Sound.Name] = Sound
	end
end

--- scrolls textlabel text \
--- `speed (?=40)` scrolling speed
function Interface.scrolltext(textlabel: TextLabel, text: string?, speed: number?)
	textlabel.MaxVisibleGraphemes = 0
	if text then textlabel.Text = text end
	local n = utf8.len(textlabel.ContentText) or 0
	tween(textlabel, {MaxVisibleGraphemes = n}, n / (speed or 40), Enum.EasingStyle.Sine)
end

--- connects button events to guibutton
function Interface.connectbutton(button: GuiButton, functions: types.ButtonFunctions, sounds: types.ButtonSounds): {RBXScriptConnection}
	local connections = table.create(9)

	if functions.ClickDown then
		table.insert(connections, button.MouseButton1Down:Connect(functions.ClickDown))
	end
	if functions.ClickUp then
		table.insert(connections, button.MouseButton1Up:Connect(function(...)
			functions.ClickUp(...)

			if sounds.Click then
				Interface.playsound(sounds.Click)
			end
		end))
	end

	if functions.RClickDown then
		table.insert(connections, button.MouseButton2Down:Connect(functions.RClickDown))
	end
	if functions.RClickUp then
		table.insert(connections, button.MouseButton2Up:Connect(function(...)
			functions.RClickUp(...)

			if sounds.RClick then
				Interface.playsound(sounds.RClick)
			end
		end))
	end

	if functions.Enter then
		local function e(...)
			functions.Enter(...)

			if sounds.Enter then
				Interface.playsound(sounds.Enter)
			end
		end

		table.insert(connections, button.MouseEnter:Connect(e))
		table.insert(connections, button.SelectionGained:Connect(e))
	end
	if functions.Leave then
		table.insert(connections, button.MouseLeave:Connect(functions.Leave))
		table.insert(connections, button.SelectionLost:Connect(functions.Leave))
	end
	if functions.Move then
		table.insert(connections, button.MouseMoved:Connect(functions.Move))
	end

	return connections
end

--- applies sprite to imagelabel
function Interface.applysprite(imagelabel: ImageLabel, sprite: types.Sprite)
	local Layout = sprite.Layout

	if Layout then
		imagelabel.Image = Layout.Id
		local X, Y = cartesian(sprite.Position, Layout.Width)
		local Padding = Layout.Padding or 0
		local Size = Layout.Size
		imagelabel.ImageRectSize = Size
		imagelabel.ImageRectOffset = Vector2.new((Y * Size.X) + (Y * Padding), (X * Size.Y) + (X * Padding))
	else
		imagelabel.Image = ""
		imagelabel.ImageRectSize = Vector2.zero
		imagelabel.ImageRectOffset = Vector2.zero
	end
end

--- expands expands textlabel until
function Interface.scaletextlabel(textlabel: TextLabel, settextbounds: boolean?, offsetX: number?, offsetY: number?)
	if settextbounds then
		local aY = textlabel.AbsoluteSize.Y
		textlabel.Size = UDim2.new(1, 0, 0, aY)
		textlabel.TextSize = aY
	end

	textlabel.TextWrapped = true
	if not textlabel.TextFits then
		repeat
			textlabel.Size += Interface.UDim2.yOffset
		until textlabel.TextFits
	end

	textlabel.Size += UDim2.fromOffset((offsetX or 0), (offsetY or 0))
end

--- attaches target to textlabel
function Interface.appendtextlabel(textlabel: TextLabel, target: GuiObject, alignment: types.LeftOrRight, padding: number?)
	local TextX = textlabel.TextBounds.X

	if textlabel.TextXAlignment == Enum.TextXAlignment.Left then
		if alignment == "Left" then
			target.Position = Interface.UDim2.left
		elseif alignment == "Right" then
			target.Position = UDim2.new(0, TextX, 0.5, 0)
		end
	elseif textlabel.TextXAlignment == Enum.TextXAlignment.Right then
		if alignment == "Left" then
			target.Position = UDim2.new(1, -TextX, 0.5, 0)
		elseif alignment == "Right" then
			target.Position = Interface.UDim2.right
		end
	elseif textlabel.TextXAlignment == Enum.TextXAlignment.Center then
		if alignment == "Left" then
			target.Position = UDim2.new(0.5, -TextX * 0.5, 0.5, 0)
		elseif alignment == "Right" then
			target.Position = UDim2.new(0.5, TextX * 0.5, 0.5, 0)
		end
	end
	
	if alignment == "Left" then
		target.AnchorPoint = Interface.Vector2.right
		target.Position += UDim2.fromOffset(-(padding or 0), 0)
	elseif alignment == "Right" then
		target.AnchorPoint = Interface.Vector2.left
		target.Position += UDim2.fromOffset((padding or 0), 0)
	end
end

--- returns position of target @ x,y constrained within bounds of container
function Interface.clampposition(x: number, y: number, target: GuiObject, container: GuiObject): UDim2
	local pX, pY = (x - container.AbsolutePosition.X), (y - container.AbsolutePosition.Y - 36)

	local dY = math.abs(math.clamp(container.AbsoluteSize.Y - (pY + target.AbsoluteSize.Y), -math.huge, 0))
	return UDim2.fromOffset(pX, pY - dY)
end

--- creates a quick clone of template
function Interface.quickclone<T>(template: T & GuiObject, name: string?, layoutorder: number?): T
	local Clone = template:Clone()
	Clone.Name = name or "quickclone"
	Clone.Parent = template.Parent
	Clone.LayoutOrder = layoutorder or 0
	Clone.Visible = true
	return Clone
end

--- sets visibility of all guiobject descendants of target
function Interface.toggledescendants(target: GuiObject, state: boolean, ...: string)
	local Names = {...}

	for _, Thing in target:GetDescendants() do
		if not Thing:IsA("GuiObject") then continue end
		if not table.find(Names, Thing.Name) then continue end
		
		Thing.Visible = state
	end
end

--- sets visibility of all guiobject children of target
function Interface.togglecontents(target: GuiObject, state: boolean, ...: string)
	local Names = {...}

	for _, Thing in target:GetChildren() do
		if not Thing:IsA("GuiObject") then continue end
		if not table.find(Names, Thing.Name) then continue end
		
		Thing.Visible = state
	end
end

--- populates container with a grid of entries drawn from `template (?=Frame)`
--- ```lua
--- Interface.gridfill(container, 5, 3, template)
--- 
--- container:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
--- 	Interface.gridfill(container, 5, 3, template)
--- end)
--- ```
function Interface.gridfill(container: Frame, width: number, height: number, template: GuiObject?)
	local gridlayout = container:FindFirstChildOfClass("UIGridLayout")
	assert(gridlayout)
	gridlayout.FillDirectionMaxCells = width

	local units = width * height
	for i = 1, units do
		local name = "griditem_" .. i
		local entry = container:FindFirstChild(name) :: any
		if not entry then
			entry = template and template:Clone() or Instance.new("Frame")
			entry.Name = name
			entry.LayoutOrder = -99999 + i
			entry.Parent = container
		end
		entry:SetAttribute("gridentry", i)
	end

	for i = units + 1, #container:GetChildren(), 1 do
		local name = "griditem_" .. i
		local entry = container:FindFirstChild(name) :: any
		if entry then
			entry:Destroy()
		end
	end

	local containersize = container.AbsoluteSize
	local target = math.round(containersize.Y - Interface.padheight(container:FindFirstChildOfClass("UIPadding")).Offset)
	
	local cell = target / width
	gridlayout.CellSize = UDim2.fromOffset(cell, cell)

	if target <= 0 then
		return
	else
		Interface.resizegrid(gridlayout, target, Enum.Axis.Y)
	end
end

--- returns entries created by `Interface.gridfill`
function Interface.gridentries(container: Frame): {GuiObject}
	local c = container:GetChildren()
	local entries = table.create(#c)

	for _, thing in c do
		if not thing:IsA("GuiObject") then continue end

		local value = thing:GetAttribute("gridentry") :: number?
		if value then
			entries[value] = thing
		end
	end

	return entries
end

--- populates container with a list of entries drawn from `template (?=Frame)`
--- ```lua
--- Interface.listfill(container, 10, template)
--- 
--- container:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
--- 	Interface.listfill(container, 10, template)
--- end)
--- ```
function Interface.listfill(container: Frame, rows: number, template: GuiObject?)
	local gridlayout = container:FindFirstChildOfClass("UIGridLayout")
	assert(gridlayout)
	gridlayout.FillDirectionMaxCells = 1

	for i = 1, rows do
		local name = "listitem_" .. i
		local entry = container:FindFirstChild(name) :: any
		if not entry then
			entry = template and template:Clone() or Instance.new("Frame")
			entry.Name = name
			entry.LayoutOrder = -99999 + i
			entry.Parent = container
		end
		entry:SetAttribute("listentry", i)
	end

	for i = rows + 1, #container:GetChildren(), 1 do
		local name = "listitem_" .. i
		local entry = container:FindFirstChild(name) :: any
		if entry then
			entry:Destroy()
		end
	end

	local padheight = Interface.padheight(container:FindFirstChildOfClass("UIPadding")).Offset
	local height = container.AbsoluteSize.Y
	gridlayout.CellSize = UDim2.new(1, 0, 0, height / rows)

	local target = math.round(height - padheight)

	if target <= 0 then
		return
	else
		Interface.resizegrid(gridlayout, target, Enum.Axis.Y)
	end
end

--- returns entries created by `Interface.listfill`
function Interface.listentries(container: Frame): {GuiObject}
	local c = container:GetChildren()
	local entries = table.create(#c)

	for _, thing in c do
		if not thing:IsA("GuiObject") then continue end

		local value = thing:GetAttribute("listentry") :: number?
		if value then
			entries[value] = thing
		end
	end

	return entries
end

function Interface.resizegrid(gridlayout: UIGridLayout, target: number, axis: Enum.Axis)
	if axis == Enum.Axis.X then
		repeat
			if gridlayout.AbsoluteContentSize.X < target then
				gridlayout.CellSize -= Interface.UDim2.xOffset
				if gridlayout.AbsoluteContentSize.X >= target then
					break
				end
			elseif gridlayout.AbsoluteContentSize.X > target then
				gridlayout.CellSize += Interface.UDim2.xOffset
				if gridlayout.AbsoluteContentSize.X <= target then
					break
				end
			end
		until gridlayout.AbsoluteContentSize.X == target or gridlayout.AbsoluteContentSize.X == 0
	elseif axis == Enum.Axis.Y then
		repeat
			if gridlayout.AbsoluteContentSize.Y < target then
				gridlayout.CellSize += Interface.UDim2.yOffset
				if gridlayout.AbsoluteContentSize.Y >= target then
					break
				end
			elseif gridlayout.AbsoluteContentSize.Y > target then
				gridlayout.CellSize -= Interface.UDim2.yOffset
				if gridlayout.AbsoluteContentSize.Y <= target then
					break
				end
			end
		until gridlayout.AbsoluteContentSize.Y == target or gridlayout.AbsoluteContentSize.Y == 0
	else
		error(axis)
	end
end

--- automatically scales size of target along axis with respect to uigridlayout or uilistlayout
function Interface.scaleto(target: Frame, gridorlist: UIGridLayout | UIListLayout, Axis: "X" | "Y"): RBXScriptConnection
	assert(gridorlist.Parent)

	local Compound = 0
	if Axis == "X" then
		Compound += Interface.padwidth(target:FindFirstChildOfClass("UIPadding")).Offset
	elseif Axis == "Y" then
		Compound += Interface.padheight(target:FindFirstChildOfClass("UIPadding")).Offset
	end

	local function UpdateSize()
		local Stretch = (gridorlist :: any).AbsoluteContentSize[Axis] :: number
		local Real = Stretch > 1 and math.ceil(Stretch + Compound) or 0
		if Axis == "X" then
			target.Size = UDim2.new(0, Real, 1, 0)
		elseif Axis == "Y" then
			target.Size = UDim2.new(1, 0, 0, Real)
		end
	end

	UpdateSize()
	return gridorlist:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(UpdateSize)
end

--- applies `UIPadding` instance with padding values to guiobject, instantiating one if it has not been created already
function Interface.pad(guiobject: GuiObject, value: UDim)
	local uipadding = guiobject:FindFirstChildOfClass("UIPadding")
	if not uipadding then
		uipadding = Instance.new("UIPadding") ; -- this semicolon is INSANE
		(uipadding::any).Parent = Interface.pad
	end
	assert(uipadding)

	uipadding.PaddingTop = value
	uipadding.PaddingLeft = value
	uipadding.PaddingRight = value
	uipadding.PaddingBottom = value
end

--- returns padding width (`left + right`)
function Interface.padwidth(uipadding: UIPadding?): UDim
	return uipadding and uipadding.PaddingLeft + uipadding.PaddingRight or UDim.new(0, 0)
end

--- returns padding height (`left + right`)
function Interface.padheight(uipadding: UIPadding?): UDim
	return uipadding and uipadding.PaddingTop + uipadding.PaddingBottom or UDim.new(0, 0)
end

--- creates a unit circle \
--- optional initial offset theta
function Interface.unitcircle(vertices: number, radius: number, theta: number?): {UDim2}
	local Results = table.create(vertices)

	local Start = math.rad(theta or 0)
	local Step = (2 * math.pi) / vertices

	for i = 1, vertices do
		i -= 1
		local a = (i * Step) + Start
		local U = UDim2.fromScale(radius * math.cos(a), radius * math.sin(a)) + Interface.UDim2.half
		table.insert(Results, U)
	end

	return Results
end

--- formats number with: \
--- `abbreviate (?=10000)`: if `x >= abbreviate`, `x` will be abbreviated \
--- `comma (?=1000)`: if `x >= comma`, `x` will be separated by commas \
--- `decimalplaces (?=1)`: *in contexts where `x` is abbreviated, # of decimal places*
function Interface.formatnumber(x: number, abbreviate: number?, comma: number?, decimalplaces: number?): string
	if x >= (abbreviate or 10000) then
		return Interface.abbreviatenumber(x, decimalplaces or 1)
	elseif x >= (comma or 1000) then
		return Interface.commanumber(x)
	end
	return tostring(x)
end

--- formats number separated by commas
function Interface.commanumber(x: number): string
	if math.abs(x) < 1000 then return tostring(x) end
	local a = string.gsub(string.gsub(string.reverse(tostring(math.floor(x))), "(%d%d%d)","%1,"), ",(%-?)$","%1")
	return string.reverse(a)
end

--- abbreviates number following a `"K", "M", "B", "T", "Qd"...`-esque notation
function Interface.abbreviatenumber(n: number, decimalplaces: number?): string
	local exp = math.floor(math.log(math.max(1, math.abs(n)), 1000))
	local suffix = Interface.suffixes[1 + exp] or ("e+" .. exp)
	local norm = math.floor(n * ((10 ^ (decimalplaces or 1)) / (1000 ^ exp))) / (10 ^ (decimalplaces or 1))

	return string.format("%." .. (decimalplaces or 1) .. "f%s", norm, suffix)
end

return Interface