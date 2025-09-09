--!strict

local GuiService = game:GetService("GuiService")
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

--- returns point along bezier curve `u` at interpolant `a`
local function bezier(u: {UDim2}, a: number)
	local len = #u
	if len > 1 then
		local newpoints = table.create(len)
		for i, v in ipairs(u) do
			local w = u[i + 1]
			if not w then break end

			table.insert(newpoints, v:Lerp(w, a))
		end

		return bezier(newpoints, a)
	else
		return u[1]
	end
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
		half = UDim2.fromScale(0.5, 0.5);

		onescale = UDim2.fromScale(1, 1);
		xscale = UDim2.fromScale(1, 0);
		yscale = UDim2.fromScale(0, 1);

		oneoffset = UDim2.fromOffset(1, 1);
		xoffset = UDim2.fromOffset(1, 0);
		yoffset = UDim2.fromOffset(0, 1);

		--- returns `UDim2.fromScale(v, v)`
		fromscale = function(v: number)
			return UDim2.fromScale(v, v)
		end;
		--- returns `UDim2.fromOffset(v, v)`
		fromoffset = function(v: number)
			return UDim2.fromOffset(v, v)
		end;
		--- returns `UDim2.fromOffset(v.X, v.Y)`
		fromvector = function(v: Vector2|Vector3)
			return UDim2.fromOffset(v.X, v.Y)
		end;
		
		bezier = bezier;
	};
	Vector2 = {
		half = Vector2.new(0.5, 0.5);

		--- returns `Vector2.new(w, w)`
		fromconstant = function(w: number)
			return Vector2.new(w, w)
		end;
		--- returns `UDim2.fromOffset(u.X.Offset, u.Y.Offset)`
		fromudim2 = function(u: UDim2)
			return UDim2.fromOffset(u.X.Offset, u.Y.Offset)
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
}

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

--- creates a textqueue, used for displaying text messages
function Interface.createtextqueue(textobject: TextLabel, separator: string, alloc: number?)
	return {
		Queue = table.create(alloc or 16) :: { {string|number} };
		Separator = separator;
		TextObject = textobject;
	}
end

--- inserts text into textqueue
function Interface.textqueueinsert(tq: typeof(Interface.createtextqueue(...)), text: string, expiry: number, front: boolean?)
	if front == true then
		table.insert(tq.Queue, 1, {text, expiry::any})
	else
		table.insert(tq.Queue, {text, expiry::any})
	end
end

--- advances textqueue, removing any expired text
function Interface.textqueuestep(tq: typeof(Interface.createtextqueue(...)), now: number)
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

--- returns best-fit-for-selection guiobject wrt `thumbstickvector` and currently-selected guiobject
function Interface.nextguiobject(guiobjects: {GuiObject}, thumbstickvector: Vector3, current: GuiObject?): GuiObject?
	current = current or guiobjects[1]
	if not current then
		return nil
	end

	if not (vector.magnitude(thumbstickvector::any) > 0) then
		return current
	end

	local point = current.AbsolutePosition + (current.AbsoluteSize * 0.5)

	local guiobjectswithinangle = table.create(#guiobjects)

	for _, guiobject in guiobjects do
		if guiobject == current then continue end

		local thispoint = guiobject.AbsolutePosition + (guiobject.AbsoluteSize * 0.5)
		thispoint -= point

		local dot = vector.dot(thumbstickvector::any, vector.normalize(-Vector3.new(thispoint.X, thispoint.Y, 0)::any))
		if dot <= 0 then continue end

		table.insert(guiobjectswithinangle, guiobject)
	end

	table.sort(guiobjectswithinangle, function(a, b)
		--- vector lib incompatible w vector2
		--- local dista = vector.magnitude(a.AbsolutePosition::any + (a.AbsoluteSize*0.5) - point)
		--- local distb = vector.magnitude(b.AbsolutePosition::any + (b.AbsoluteSize*0.5) - point)
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
			--- vector lib incompatible w vector2
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