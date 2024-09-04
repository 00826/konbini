--!strict

local types						= require(script.Parent.types)

local TweenService				= game:GetService("TweenService")

local function Tween(Object: Instance, Properties: {[string]: any}, Time: number, ...)
	TweenService:Create(Object, TweenInfo.new(Time, ...), Properties):Play()
end

local function cartesian(p: number, w: number): (number, number)
	p -= 1
	return p % w, p // w
end

--- ### Interface.luau
---
--- contains quality-of-life functions for UI development
local Interface = {
	ButtonSounds				= {} :: {[string]: Sound};

	UDimOne						= UDim2.fromScale(1, 1);		-- `UDim2.fromScale(1, 1)`
	UDimZero					= UDim2.fromScale(0, 0);		-- `UDim2.fromScale(0, 0)`
	UDimX						= UDim2.fromScale(1, 0);		-- `UDim2.fromScale(1, 0)`
	UDimY						= UDim2.fromScale(0, 1);		-- `UDim2.fromScale(0, 1)`

	UDimHalf					= UDim2.fromScale(0.5, 0.5);	-- `UDim2.fromScale(0.5, 0.5)`
	UDimTop						= UDim2.fromScale(0.5, 0);		-- `🡱` -- `UDim2.fromScale(0.5, 0)`
	UDimBottom					= UDim2.fromScale(0.5, 1);		-- `🡳` -- `UDim2.fromScale(0.5, 1)`
	UDimLeft					= UDim2.fromScale(0, 0.5);		-- `🡰` -- `UDim2.fromScale(0, 0.5)`
	UDimRight					= UDim2.fromScale(1, 0.5);		-- `🡲` -- `UDim2.fromScale(1, 0.5)`
	UDimTopLeft					= UDim2.fromScale(0, 0);		-- `🡴` -- `UDim2.fromScale(0, 0)`
	UDimTopRight				= UDim2.fromScale(1, 0);		-- `🡵` -- `UDim2.fromScale(1, 0)`
	UDimBottomLeft				= UDim2.fromScale(0, 1);		-- `🡷` -- `UDim2.fromScale(0, 1)`
	UDimBottomRight				= UDim2.fromScale(1, 1);		-- `🡶` -- `UDim2.fromScale(1, 1)`

	UDimOffsetX					= UDim2.fromOffset(1, 0);		-- `UDim2.fromOffset(1, 0)`
	UDimOffsetY					= UDim2.fromOffset(0, 1); 		-- `UDim2.fromOffset(0, 1)`

	Vector2Half					= Vector2.new(0.5, 0.5);		-- `Vector2.new(0.5, 0.5)`
	Vector2Top					= Vector2.new(0.5, 0);			-- `🡱` -- `Vector2.new(0.5, 0)`
	Vector2Bottom				= Vector2.new(0.5, 1);			-- `🡳` -- `Vector2.new(0.5, 1)`
	Vector2Left					= Vector2.new(0, 0.5);			-- `🡰` -- `Vector2.new(0, 0.5)`
	Vector2Right				= Vector2.new(1, 0.5);			-- `🡲` -- `Vector2.new(1, 0.5)`
	Vector2TopLeft				= Vector2.new(0, 0);			-- `🡴` -- `Vector2.new(0, 0)`
	Vector2TopRight				= Vector2.new(1, 0);			-- `🡵` -- `Vector2.new(1, 0)`
	Vector2BottomLeft			= Vector2.new(0, 1);			-- `🡷` -- `Vector2.new(0, 1)`
	Vector2BottomRight			= Vector2.new(1, 1);			-- `🡶` -- `Vector2.new(1, 1)`

	Color3White					= Color3.fromRGB(255, 255, 255);
	Color3Gray					= Color3.fromRGB(128, 128, 128);
	Color3Black					= Color3.fromRGB();

	Suffixes					= table.freeze{""; "K"; "M"; "B"; "T"; "Qd", "Qt", "Sx", "Sp", "Oc", "No", "De"};
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
function Interface.playsound(ref: string): ()
	local Sound = Interface.ButtonSounds[ref]
	assert(Sound, `{ref} not an imported sound`)

	local S = Sound:Clone()
	S.PlayOnRemove = true
	S.Parent = script
	S:Destroy()
end

--- imports sounds
function Interface.importsounds(sounds: {Sound}): ()
	for _, Sound in sounds do
		Interface.ButtonSounds[Sound.Name] = Sound
	end
end

--- scrolls textlabel text
function Interface.scrolltext(TextLabel: TextLabel, Text: string?, Speed: number?): ()
	TextLabel.MaxVisibleGraphemes = 0
	if Text then TextLabel.Text = Text end
	local n = utf8.len(TextLabel.ContentText) or 0
	Tween(TextLabel, {MaxVisibleGraphemes = n}, n / (Speed or 40), Enum.EasingStyle.Sine)
	return
end

--- connects button events to guibutton
function Interface.connectbutton(button: GuiButton, connectfunctions: types.ButtonFunctions, muteclicksounds: boolean?): {RBXScriptConnection}
	local t = table.create(9)

	if connectfunctions.ClickDown then
		table.insert(t, button.MouseButton1Down:Connect(connectfunctions.ClickDown))
	end
	if connectfunctions.ClickUp then
		table.insert(t, button.MouseButton1Up:Connect(function(...)
			connectfunctions.ClickUp(...)
			if muteclicksounds == true then return end
			Interface.playsound("Click")
		end))
	end

	if connectfunctions.RClickDown then
		table.insert(t, button.MouseButton2Down:Connect(connectfunctions.RClickDown))
	end
	if connectfunctions.RClickUp then
		table.insert(t, button.MouseButton2Up:Connect(function(...)
			connectfunctions.RClickUp(...)
			if muteclicksounds == true then return end
			Interface.playsound("Click")
		end))
	end

	if connectfunctions.Enter then
		local function Enter(...)
			connectfunctions.Enter(...)
			if muteclicksounds == true then return end
			Interface.playsound("Hover")
		end
		table.insert(t, button.MouseEnter:Connect(Enter))
		table.insert(t, button.SelectionGained:Connect(Enter))
	end
	if connectfunctions.Leave then
		table.insert(t, button.MouseLeave:Connect(connectfunctions.Leave))
		table.insert(t, button.SelectionLost:Connect(connectfunctions.Leave))
	end
	if connectfunctions.Move then
		table.insert(t, button.MouseMoved:Connect(connectfunctions.Move))
	end

	return t
end

--- applies sprite to imagelabel
function Interface.applysprite(imagelabel: ImageLabel, sprite: types.Sprite): ()
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
			textlabel.Size += Interface.UDimOffsetY
		until textlabel.TextFits
	end

	textlabel.Size += UDim2.fromOffset((offsetX or 0), (offsetY or 0))
end

--- attaches target to textlabel
function Interface.appendtextlabel(textlabel: TextLabel, target: GuiObject, alignment: types.LeftOrRight, padding: number?)
	local TextX = textlabel.TextBounds.X

	if textlabel.TextXAlignment == Enum.TextXAlignment.Left then
		if alignment == "Left" then
			target.Position = Interface.UDimLeft
		elseif alignment == "Right" then
			target.Position = UDim2.new(0, TextX, 0.5, 0)
		end
	elseif textlabel.TextXAlignment == Enum.TextXAlignment.Right then
		if alignment == "Left" then
			target.Position = UDim2.new(1, -TextX, 0.5, 0)
		elseif alignment == "Right" then
			target.Position = Interface.UDimRight
		end
	elseif textlabel.TextXAlignment == Enum.TextXAlignment.Center then
		if alignment == "Left" then
			target.Position = UDim2.new(0.5, -TextX * 0.5, 0.5, 0)
		elseif alignment == "Right" then
			target.Position = UDim2.new(0.5, TextX * 0.5, 0.5, 0)
		end
	end
	
	if alignment == "Left" then
		target.AnchorPoint = Interface.Vector2Right
		target.Position += UDim2.fromOffset(-(padding or 0), 0)
	elseif alignment == "Right" then
		target.AnchorPoint = Interface.Vector2Left
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
function Interface.togglecontents(target: GuiObject, state: boolean, ...: string): ()
	local Names = {...}

	for _, Thing in target:GetChildren() do
		if not Thing:IsA("GuiObject") then continue end
		if not table.find(Names, Thing.Name) then continue end
		
		Thing.Visible = state
	end
end

--- automatically adjusts gridlayout to fit specified columns
function Interface.adjustgridlayout(gridlayout: UIGridLayout, columns: number)
	local Container = gridlayout.Parent :: GuiObject
	if not gridlayout:GetAttribute("IsAutoAdjusting") then
		gridlayout:SetAttribute("IsAutoAdjusting", true)

		local Placeholders = table.create(10) :: {Frame}

		local function Adjust()
			local ThisSize = Container.AbsoluteSize
			local Width = 1 + math.ceil(ThisSize.X / columns)
			gridlayout.CellSize = UDim2.fromOffset(Width, Width)

			for _, P in Placeholders do
				P.Visible = true
			end

			repeat
				gridlayout.CellSize -= Interface.UDimOffsetX
				task.wait()
				if gridlayout.CellSize.X.Offset < 0 then
					gridlayout.CellSize = Interface.UDimOne
				end
			until (ThisSize ~= Container.AbsoluteSize) or (gridlayout.AbsoluteCellCount.X == gridlayout:GetAttribute("Columns"))

			for _, P in Placeholders do
				P.Visible = false
			end
		end

		gridlayout:GetAttributeChangedSignal("Columns"):Connect(function()
			for i = 1, (gridlayout:GetAttribute("Columns") :: number?) or columns do
				local placeholder = Container:FindFirstChild("_placeholder" .. i) :: any
				if not placeholder then
					placeholder = Instance.new("Frame")
					placeholder.Name = "_placeholder" .. i
					placeholder.LayoutOrder = -99999 + i
					placeholder.Parent = Container

					Placeholders[i] = placeholder
				end
			end

			Adjust()
		end)

		Container:GetPropertyChangedSignal("AbsoluteSize"):Connect(Adjust)
	end
	gridlayout:SetAttribute("Columns", columns)
end

--- automatically adjusts scrollingframe canvas to fit its layoutobject
function Interface.adjustscrollcanvas(ScrollingFrame: ScrollingFrame): RBXScriptConnection?
	local LayoutObject = ScrollingFrame:FindFirstChildOfClass("UIGridLayout") or ScrollingFrame:FindFirstChildOfClass("UIListLayout")
	if not LayoutObject then return end
	local PaddingObject = ScrollingFrame:FindFirstChildOfClass("UIPadding")

	local Compound = 0
	if PaddingObject then
		Compound += PaddingObject.PaddingTop.Offset + PaddingObject.PaddingBottom.Offset
	end

	ScrollingFrame.CanvasSize = UDim2.fromOffset(0, math.ceil(LayoutObject.AbsoluteContentSize.Y + Compound))

	return LayoutObject:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		ScrollingFrame.CanvasSize = UDim2.fromOffset(0, math.ceil(LayoutObject.AbsoluteContentSize.Y + Compound))
	end)
end

--- automatically scales size of target along axis with respect to uigridlayout or uilistlayout
function Interface.scaleto(target: Frame, gridorlist: UIGridLayout | UIListLayout, Axis: "X" | "Y"): RBXScriptConnection
	assert(gridorlist.Parent)

	local PaddingObject = gridorlist.Parent:FindFirstChildOfClass("UIPadding")
	local Compound = 0
	if PaddingObject then
		if Axis == "X" then
			Compound += PaddingObject.PaddingLeft.Offset
			Compound += PaddingObject.PaddingRight.Offset
		elseif Axis == "Y" then
			Compound += PaddingObject.PaddingTop.Offset
			Compound += PaddingObject.PaddingBottom.Offset
		end
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

--- sets padding values of uipadding instance
function Interface.padding(uipadding: UIPadding, padding: UDim): ()
	uipadding.PaddingTop = padding
	uipadding.PaddingLeft = padding
	uipadding.PaddingRight = padding
	uipadding.PaddingBottom = padding
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
		local U = UDim2.fromScale(radius * math.cos(a), radius * math.sin(a)) + Interface.UDimHalf
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
	local suffix = Interface.Suffixes[1 + exp] or ("e+" .. exp)
	local norm = math.floor(n * ((10 ^ (decimalplaces or 1)) / (1000 ^ exp))) / (10 ^ (decimalplaces or 1))

	return string.format("%." .. (decimalplaces or 1) .. "f%s", norm, suffix)
end

return Interface