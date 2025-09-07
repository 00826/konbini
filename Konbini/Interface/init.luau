--!strict

local GuiService = game:GetService("GuiService")
local StarterGui = game:GetService("StarterGui")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local function tween(object: Instance, properties: {[string]: any}, time: number, ...)
	TweenService:Create(object, TweenInfo.new(time, ...), properties):Play()
end

local function cartesian(p: number, w: number)
	p -= 1
	return p // w, p % w
end

--- ### Interface.luau
---
--- UDim, UDim2, Vector2 library extensions \
--- ui helper functions
local Interface = {
	UDim = {
		zero = UDim.new(0, 0);

		--- returns `UDim.new(w, w)`
		fromconstant = function(w: number)
			return UDim.new(w, w)
		end;
	};
	UDim2 = {
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

		--- returns UDim2.fromScale(v, v)
		fromScale = function(v: number)
			return UDim2.fromScale(v, v)
		end;
		--- returns UDim2.fromOffset(v, v)
		fromOffset = function(v: number)
			return UDim2.fromOffset(v, v)
		end;
		--- returns UDim2.fromOffset(v.X, v.Y)
		fromVector2 = function(v: Vector2|Vector3)
			return UDim2.fromOffset(v.X, v.Y)
		end;
		--- returns unit circle with initial rotation `initialradians (?=0)`
		unitcircle = function(vertices: number, radius: number, initialradians: number?)
			local results = table.create(vertices)

			local start = initialradians or 0
			local step = (2 * math.pi) / vertices

			for i = 1, vertices do
				i -= 1
				local a = (i * step) + start
				local udim = UDim2.fromScale(radius * math.cos(a), radius * math.sin(a)) + UDim2.fromScale(0.5, 0.5)
				table.insert(results, udim)
			end

			return results
		end;
	};
	Vector2 = {
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
		--- returns `UDim2.fromOffset(v.X, v.Y)`
		fromUDim2 = function(v: Vector2)
			return UDim2.fromOffset(v.X, v.Y)
		end;
		--- returns square at `vec` with `size` clamped within `bounds`
		clamp = function(vec: Vector2, size: Vector2, bounds: Vector2)
			local delta = (vec + size) - bounds

			if delta.X > 0 then
				vec -= Vector2.xAxis * delta.X
			end
			if delta.Y > 0 then
				vec -= Vector2.yAxis * delta.Y
			end

			return vec
		end;
	};
	AspectRatios = {
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
}

--- returns point along bezier `curve` at interpolant `a`
Interface.UDim2.bezier = function(curve: {UDim2}, a: number)
	local len = #curve
	if len > 1 then
		local newpoints = table.create(len)
		for i = 1, len - 1 do
			table.insert(newpoints, curve[i]:Lerp(curve[i + 1], a))
		end

		return Interface.UDim2.bezier(newpoints, a)
	end

	return curve[1]
end;

--- returns `GuiService.PreferredTextSize`
function Interface.preferredtextsize()
	return GuiService.PreferredTextSize
end

--- returns `GuiService:GetPropertyChangedSignal("PreferredTextSize")`
function Interface.preferredtextsizechanged()
	return GuiService:GetPropertyChangedSignal("PreferredTextSize")
end

--- returns `GuiService.PreferredTransparency`
function Interface.preferredtransparency()
	return GuiService.PreferredTransparency
end

--- returns `GuiService:GetPropertyChangedSignal("PreferredTransparency")`
function Interface.preferredtransparencychanged()
	return GuiService:GetPropertyChangedSignal("PreferredTransparency")
end

--- returns `GuiService.ReducedMotionEnabled`
function Interface.reducedmotionenabled()
	return GuiService.ReducedMotionEnabled
end

--- returns `GuiService:GetPropertyChangedSignal("ReducedMotionEnabled")`
function Interface.reducedmotionchanged()
	return GuiService:GetPropertyChangedSignal("ReducedMotionEnabled")
end

--- returns `GuiService:GetGuiInset()`
function Interface.guiinset()
	return GuiService:GetGuiInset()
end

--- locally emits a TextChatService message in `channel (?="RBXGeneral")`
function Interface.textchatmessage(message: string, channel: string?)
	local textchannel = TextChatService:WaitForChild("TextChannels"):WaitForChild(channel or "RBXGeneral")
	if textchannel and textchannel:IsA("TextChannel") then
		return textchannel:DisplaySystemMessage(message)
	end

	error(`"{channel}" is not a text channel of TextChatService.TextChannels`)
end

--- connects button events to `guibutton`
function Interface.connectbutton(button: GuiButton, functions: {
	--- `MouseButton1Down`
	ClickDown: (x: number, y: number) -> ()?;
	--- `MouseButton1Up`
	ClickUp: (x: number, y: number) -> ()?;
	--- `MouseButton2Down`
	RClickDown: (x: number, y: number) -> ()?;
	--- `MouseButton2Up`
	RClickUp: (x: number, y: number) -> ()?;
	--- `MouseEnter` \
	--- `SelectionGained`
	Enter: (x: number, y: number) -> ()?;
	--- `MouseLeave` \
	--- `SelectionLost`
	Leave: (x: number, y: number) -> ()?;
	--- `MouseMoved`
	Move: (x: number, y: number) -> ()?;
	--- `MouseWheelForward`
	ScrollUp: (x: number, y: number) -> ()?;
	--- `MouseWheelBackward`
	ScrollDown: (x: number, y: number) -> ()?;
})
	local connections = table.create(11)

	if functions.ClickDown then
		table.insert(connections, button.MouseButton1Down:Connect(functions.ClickDown))
	end
	if functions.ClickUp then
		table.insert(connections, button.MouseButton1Up:Connect(functions.ClickUp))
	end

	if functions.RClickDown then
		table.insert(connections, button.MouseButton2Down:Connect(functions.RClickDown))
	end
	if functions.RClickUp then
		table.insert(connections, button.MouseButton2Up:Connect(functions.RClickUp))
	end

	if functions.Enter then
		table.insert(connections, button.MouseEnter:Connect(functions.Enter))
		table.insert(connections, button.SelectionGained:Connect(function()
			local vec2 = UserInputService:GetMouseLocation()
			functions.Enter(vec2.X, vec2.Y)
		end))
	end
	if functions.Leave then
		table.insert(connections, button.MouseLeave:Connect(functions.Leave))
		table.insert(connections, button.SelectionLost:Connect(function()
			local vec2 = UserInputService:GetMouseLocation()
			functions.Leave(vec2.X, vec2.Y)
		end))
	end
	if functions.Move then
		table.insert(connections, button.MouseMoved:Connect(functions.Move))
	end
	if functions.ScrollUp then
		table.insert(connections, button.MouseWheelForward:Connect(functions.ScrollUp))
	end
	if functions.ScrollDown then
		table.insert(connections, button.MouseWheelBackward:Connect(functions.ScrollDown))
	end

	return connections
end

--- applies `sprite` to `imagelabel`
function Interface.sprite(imagelabel: ImageLabel, sprite: typeof(
	{
		Position = 0;
		Layout = {
			Id = "";
			Size = Vector2.zero;
			Width = 0;
		};
	})?)
	if not sprite then
		imagelabel.Image = ""
		imagelabel.ImageRectSize = Vector2.zero
		imagelabel.ImageRectOffset = Vector2.zero

		return
	end

	local layout = sprite.Layout

	if layout then
		imagelabel.Image = layout.Id
		local x, y = cartesian(sprite.Position, layout.Width)
		local size = layout.Size
		imagelabel.ImageRectSize = size
		imagelabel.ImageRectOffset = Vector2.new(y * size.X, x * size.Y)
	else
		imagelabel.Image = ""
		imagelabel.ImageRectSize = Vector2.zero
		imagelabel.ImageRectOffset = Vector2.zero
	end
end

--- scrolls textlabel text with `speed (?=100)` and initially-visible `graphemes (?=0)` \
--- returns scroll time
function Interface.scrolltext(textlabel: TextLabel, text: string?, speed: number?, graphemes: number?)
	if text == "" then
		--- nothing
		textlabel.MaxVisibleGraphemes = utf8.len(textlabel.ContentText) or 0
	elseif text then
		textlabel.Text = text
		textlabel.MaxVisibleGraphemes = graphemes or 0
	end

	local len = math.clamp((utf8.len(textlabel.ContentText) or 0) - (graphemes or 0), 0, math.huge)
	local time = len / (speed or 100)

	tween(textlabel, {MaxVisibleGraphemes = text == "" and 0 or len}, time, Enum.EasingStyle.Linear)

	return time
end

--- returns a clone of `template`
function Interface.clone<T>(template: T & GuiObject, name: string?, layoutorder: number?, parent: Instance?): T
	local clone = template:Clone()
	clone.Name = name or "_clone"
	clone.Parent = parent or template.Parent
	clone.LayoutOrder = layoutorder or 0
	clone.Visible = true

	return clone
end

--- returns array populated by clones of `template`
function Interface.dupes<T>(template: T & GuiObject, count: number, parent: Instance?): {T}
	local result = table.create(count)
	for i = 1, count do
		local clone = template:Clone()
		clone.Name = tostring(i)
		clone.Parent = parent or template.Parent
		clone.LayoutOrder = i
		clone.Visible = true

		table.insert(result, clone)
	end

	return result
end

--- applies column-row-padding layout to optional `uigridlayout(?=nil)` \
--- returns cellpadding, cellsize for convenience
function Interface.grid(columns: number, rows: number, padding: number, uigridlayout: UIGridLayout?)
	local cellpadding = UDim2.fromOffset(padding, padding)
	local cellsize = UDim2.new(1/columns, -padding, 1/rows, -padding)

	if uigridlayout then
		uigridlayout.CellPadding = cellpadding
		uigridlayout.CellSize = cellsize
	end

	return cellpadding, cellsize
end

--- applies `UIPadding` to guiobject, instantiating one if it doesn't already exist
function Interface.uipadding(guiobject: GuiObject, value: UDim?)
	--- type solver umad?
	local uipadding = guiobject:FindFirstChildOfClass("UIPadding")
	if not uipadding then
		uipadding = Instance.new("UIPadding")
		;(uipadding::any).Parent = guiobject
	end

	if value then
		(uipadding::any).PaddingTop = value
		;(uipadding::any).PaddingLeft = value
		;(uipadding::any).PaddingRight = value
		;(uipadding::any).PaddingBottom = value
	end

	return uipadding::UIPadding
end

--- applies `UIAspectRatioConstraint` to guiobject, instantiating one if it doesn't already exist
function Interface.aspectratio(guiobject: GuiObject, value: number?)
	--- type solver umad?
	local aspectratio = guiobject:FindFirstChildOfClass("UIAspectRatioConstraint")
	if not aspectratio then
		aspectratio = Instance.new("UIAspectRatioConstraint")
		;(aspectratio::any).Parent = guiobject
	end

	if value then
		(aspectratio::any).AspectRatio = value
	end

	return aspectratio::UIAspectRatioConstraint
end

--- pcall-wrapped `StarterGui:SetCoreGuiEnabled(...)`
function Interface.setcoreguienabled(coreguis: {[Enum.CoreGuiType]: boolean})
	return pcall(function()
		for coregui, enabled in coreguis do
			StarterGui:SetCoreGuiEnabled(coregui, enabled)
		end
		return true
	end)
end

--- creates a textqueuecontroller
function Interface.createtextqueuecontroller(textobject: TextLabel, separator: string, alloc: number?)
	return {
		Queue = table.create(alloc or 16) :: { {string|number} };
		Separator = separator;
		TextObject = textobject;
	}
end

--- inserts text into textqueuecontroller
function Interface.textqueuecontrollerinsert(tq: typeof(Interface.createtextqueuecontroller(...)), text: string, expiry: number, front: boolean)
	if front then
		table.insert(tq.Queue, 1, {text, expiry::any})
	else
		table.insert(tq.Queue, {text, expiry::any})
	end
end

--- advances textqueuecontroller, removing any expired text
function Interface.textqueuecontrollerstep(tq: typeof(Interface.createtextqueuecontroller(...)), now: number)
	local queue = tq.Queue
	for i = #queue, 1, -1 do
		local expiry = queue[i][2]::number
		if expiry < now then
			table.remove(queue, i)
		end
	end

	local len = #queue
	local textobject = tq.TextObject
	if len < 1 then
		textobject.Text = ""
	elseif len == 1 then
		textobject.Text = queue[1][1]::string
	else
		local concat = ""
		local sep = tq.Separator
		for i, entry in ipairs(queue) do
			local text = entry[1]::string
			if i < len then
				concat ..= text .. sep
			else
				concat ..= text
			end
		end

		textobject.Text = concat
	end
end

function Interface.nextguiobject(guiobjects: {GuiObject}, direction: Vector3, current: GuiObject?): GuiObject?
	current = current or guiobjects[1]
	if not current then
		return nil
	end

	if not (direction.Magnitude > 0) then
		return current
	end

	local point = current.AbsolutePosition + (current.AbsoluteSize * 0.5)

	local guiobjectswithinangle = table.create(#guiobjects)

	for _, guiobject in guiobjects do
		if guiobject == current then continue end

		local thispoint = guiobject.AbsolutePosition + (guiobject.AbsoluteSize * 0.5)
		thispoint -= point

		local dot = direction:Dot(-Vector3.new(thispoint.X, thispoint.Y, 0).Unit)
		if dot <= 0 then continue end

		table.insert(guiobjectswithinangle, guiobject)
	end

	table.sort(guiobjectswithinangle, function(a, b)
		local dista = (a.AbsolutePosition + (a.AbsoluteSize*0.5) - point).Magnitude
		local distb = (b.AbsolutePosition + (b.AbsoluteSize*0.5) - point).Magnitude

		return dista < distb
	end)

	return guiobjectswithinangle[1] or current
end

--- returns true if guiobject is actually visible on screen
function Interface.isvisibleonscreen(guiobject: GuiObject)
	if guiobject.Visible == false then
		return false
	else
		local screengui = guiobject:FindFirstAncestorOfClass("ScreenGui")
		if screengui then
			if screengui.Enabled == false then
				return false
			end
		end

		local ancestor = guiobject:FindFirstAncestorWhichIsA("GuiObject")
		if ancestor then
			return Interface.isvisibleonscreen(ancestor)
		else
			return guiobject.Visible
		end
	end
end

--- returns the equivalent of `BasePlayerGui:GetWhitelistedGuiObjectsAtPosition()`
function Interface.findhovertarget(list: {GuiObject}, insetmouselocation: Vector2): GuiObject?
	local mousex, mousey = insetmouselocation.X, insetmouselocation.Y

	local inbounds = table.create(#list)

	for _, guiobject in list do
		local topleft = guiobject.AbsolutePosition
		local bottomright = topleft + guiobject.AbsoluteSize

		if mousex >= topleft.X 
		and mousex <= bottomright.X
		and mousey >= topleft.Y
		and mousey <= bottomright.Y
		and Interface.isvisibleonscreen(guiobject)
		then
			table.insert(inbounds, guiobject)
		end
	end

	if #inbounds > 1 then
		--- sort by distance from center of guiobject
		table.sort(inbounds, function(a, b)
			--- local dista = vector.magnitude(a.AbsolutePosition::any + (a.AbsoluteSize*0.5) - insetmouselocation)
			--- local distb = vector.magnitude(b.AbsolutePosition::any + (b.AbsoluteSize*0.5) - insetmouselocation)
			local dista = (a.AbsolutePosition + (a.AbsoluteSize*0.5) - insetmouselocation).Magnitude
			local distb = (b.AbsolutePosition + (b.AbsoluteSize*0.5) - insetmouselocation).Magnitude

			return dista < distb
		end)
	end
	
	return inbounds[1]
end

return Interface