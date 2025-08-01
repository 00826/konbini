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
		--- returns `vec` clamped within bounds defined by `absoluteposition` and `absolutesize`
		clamp = function(vec: Vector2, absoluteposition: Vector2, absolutesize: Vector2, guiinset: Vector2?)
			local relativeposition = vec - absoluteposition - (guiinset or Vector2.zero)

			return relativeposition - Vector2.new(0, math.abs(math.clamp(absolutesize.Y - (relativeposition.Y + absolutesize.Y), -math.huge, 0)))
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
	local textchannel = TextChatService:FindFirstChild("TextChannels"):FindFirstChild(channel or "RBXGeneral")
	if textchannel and textchannel:IsA("TextChannel") then
		return textchannel:DisplaySystemMessage(message)
	end

	error(`"{channel}" is not a text channel of TextChatService.TextChannels`)
end

--- connects button events to `guibutton`
function Interface.connectbutton(button: GuiButton, functions: {
	--- `MouseButton1Down`
	ClickDown: (x: number?, y: number?) -> ()?;
	--- `MouseButton1Up`
	ClickUp: (x: number?, y: number?) -> ()?;
	--- `MouseButton2Down`
	RClickDown: (x: number?, y: number?) -> ()?;
	--- `MouseButton2Up`
	RClickUp: (x: number?, y: number?) -> ()?;
	--- `MouseEnter` \
	--- `SelectionGained`
	Enter: (x: number?, y: number?) -> ()?;
	--- `MouseLeave` \
	--- `SelectionLost`
	Leave: (x: number?, y: number?) -> ()?;
	--- `MouseMoved`
	Move: (x: number?, y: number?) -> ()?;
	--- `ScrollUp`
	ScrollUp: () -> ()?;
	--- `ScrollDown`
	ScrollDown: () -> ()?;
})
	local connections = table.create(12)

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
		table.insert(connections, button.TouchTap:Connect(function(array: {Vector2})
			if #array ~= 2 then return end
			local vec2 = array[1] + array[2]
			vec2 *= 0.5
			functions.RClickUp(vec2.X, vec2.Y)
		end))
	end

	if functions.Enter then
		table.insert(connections, button.MouseEnter:Connect(functions.Enter))
		table.insert(connections, button.SelectionGained:Connect(function()
			--- local vec2 = button.AbsolutePosition
			local vec2 = UserInputService:GetMouseLocation()
			functions.Enter(vec2.X, vec2.Y)
		end))
	end
	if functions.Leave then
		table.insert(connections, button.MouseLeave:Connect(functions.Leave))
		table.insert(connections, button.SelectionLost:Connect(function()
			--- local vec2 = button.AbsolutePosition
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

--- returns empty sprite
function Interface.createsprite()
	return {
		Position = 0;
		Layout = {
			Id = "";
			Size = Vector2.zero;
			Width = 0;
		};
	}
end

--- applies `sprite` to `imagelabel`
function Interface.sprite(imagelabel: ImageLabel, sprite: typeof(Interface.createsprite())?)
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

--- scales `textlabel` along `TextBounds.Y`
function Interface.scaletext(textlabel: TextLabel)
	local sizeX = textlabel.AbsoluteSize.X

	if textlabel.TextBounds.Y == 0 then
		textlabel.Size = UDim2.fromOffset(sizeX, 0)
		return
	end

	textlabel.Size = UDim2.fromOffset(sizeX, textlabel.TextBounds.Y)
	if not textlabel.TextFits then
		repeat
			textlabel.Size += UDim2.fromOffset(0, 1)
		until textlabel.TextFits
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

--- attaches target to textlabel
function Interface.appendtextlabel(textlabel: TextLabel, target: GuiObject, alignment: "Left" | "Right", padding: number?)
	local textboundsx = textlabel.TextBounds.X

	if textlabel.TextXAlignment == Enum.TextXAlignment.Left then
		if alignment == "Left" then
			target.Position = Interface.UDim2.left
		elseif alignment == "Right" then
			target.Position = UDim2.new(0, textboundsx, 0.5, 0)
		end
	elseif textlabel.TextXAlignment == Enum.TextXAlignment.Right then
		if alignment == "Left" then
			target.Position = UDim2.new(1, -textboundsx, 0.5, 0)
		elseif alignment == "Right" then
			target.Position = Interface.UDim2.right
		end
	elseif textlabel.TextXAlignment == Enum.TextXAlignment.Center then
		if alignment == "Left" then
			target.Position = UDim2.new(0.5, -textboundsx * 0.5, 0.5, 0)
		elseif alignment == "Right" then
			target.Position = UDim2.new(0.5, textboundsx * 0.5, 0.5, 0)
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

--- returns a clone of `template`
function Interface.clone<T>(template: T & GuiObject, name: string?, layoutorder: number?): T
	local clone = template:Clone()
	clone.Name = name or "_clone"
	clone.Parent = template.Parent
	clone.LayoutOrder = layoutorder or 0
	clone.Visible = true

	return clone
end

--- returns `UIGridLayout` `CellPadding` and `CellSize` properties with respect to `columns`, `rows`, and `padding`
function Interface.grid(columns: number, rows: number, padding: number)
	local cellpadding = UDim2.fromOffset(padding, padding)
	local cellsize = UDim2.new(1/columns, -padding, 1/rows, -padding)

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

--- applies `UITextSizeConstraint` to guiobject, instantiating one if it doesn't already exist
function Interface.textsizeconstraint(guiobject: GuiObject, max: number?, min: number?)
	local textsizeconstraint = guiobject:FindFirstChildOfClass("UITextSizeConstraint")
	if not textsizeconstraint then
		textsizeconstraint = Instance.new("UITextSizeConstraint")
		;(textsizeconstraint::any).Parent = guiobject
	end

	if max then
		(textsizeconstraint::any).MaxTextSize = max
		;(textsizeconstraint::any).MinTextSize = min or 1
	end

	return textsizeconstraint::UITextSizeConstraint
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

	table.sort(guiobjectswithinangle, function(a: GuiObject, b: GuiObject): boolean
		local apos = a.AbsolutePosition + (a.AbsoluteSize * 0.5)
		local bpos = b.AbsolutePosition + (b.AbsoluteSize * 0.5)

		--[[local avec = Vector3.new(apos.X, apos.Y, 0)
		local bvec = Vector3.new(bpos.X, bpos.Y, 0)]]
		local adis = (apos - point).Magnitude
		local bdis = (bpos - point).Magnitude

		return adis < bdis
	end)

	return guiobjectswithinangle[1] or current
end

return Interface