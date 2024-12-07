--!strict

--- ### Color3.luau
---
--- extension of Color3 library
local Color3K = {
	white = Color3.fromRGB(255, 255, 255);
	lightgray = Color3.fromRGB(222, 222, 222);
	gray = Color3.fromRGB(148, 148, 148);
	darkgray = Color3.fromRGB(74, 74, 74);
	black = Color3.fromRGB(0, 0, 0);

	red = Color3.fromRGB(255, 85, 85);
	orange = Color3.fromRGB(255, 170, 85);
	yellow = Color3.fromRGB(255, 255, 85);
	lime = Color3.fromRGB(170, 255, 85);
	green = Color3.fromRGB(85, 255, 85);
	turquoise = Color3.fromRGB(85, 255, 170);
	cyan = Color3.fromRGB(85, 255, 255);
	blue = Color3.fromRGB(85, 170, 255);
	royal = Color3.fromRGB(85, 85, 255);
	violet = Color3.fromRGB(170, 85, 255);
	pink = Color3.fromRGB(255, 85, 255);
	hotpink = Color3.fromRGB(255, 85, 170);

	glow300 = Color3.fromRGB(300, 300, 300);
	glow400 = Color3.fromRGB(400, 400, 400);
	glow500 = Color3.fromRGB(500, 500, 500);
	glow750 = Color3.fromRGB(750, 750, 750);
	glow1000 = Color3.fromRGB(1000, 1000, 1000);

	PlayerColors = table.freeze{
		[1] = Color3.fromRGB(253, 41, 67); --- Color3.new(253/255, 41/255, 67/255);
		[2] = Color3.fromRGB(1, 162, 255); --- Color3.new(1/255, 162/255, 255/255);
		[3] = Color3.fromRGB(2, 184, 87); --- Color3.new(2/255, 184/255, 87/255);
		[4] = Color3.fromRGB(180, 128, 255); --- BrickColor.new("Alder").Color; Color3.fromRGB(107, 50, 124); BrickColor.new("Bright violet").Color;
		[5] = Color3.fromRGB(218, 133, 65); --- BrickColor.new("Bright orange").Color;
		[6] = Color3.fromRGB(245, 205, 48); --- BrickColor.new("Bright yellow").Color;
		[7] = Color3.fromRGB(232, 186, 200); --- BrickColor.new("Light reddish violet").Color;
		[8] = Color3.fromRGB(215, 197, 154); --- BrickColor.new("Brick yellow").Color;
	};

	--- ### Color3K.ColorSequence
	---
	--- extension of ColorSequence library
	ColorSequence = table.freeze{
		white = ColorSequence.new(Color3.fromRGB(255, 255, 255));
		gray = ColorSequence.new(Color3.fromRGB(148, 148, 148));
		black = ColorSequence.new(Color3.fromRGB(0, 0, 0));

		red = ColorSequence.new(Color3.fromRGB(255, 85, 85));
		orange = ColorSequence.new(Color3.fromRGB(255, 170, 85));
		yellow = ColorSequence.new(Color3.fromRGB(255, 255, 85));
		lime = ColorSequence.new(Color3.fromRGB(170, 255, 85));
		green = ColorSequence.new(Color3.fromRGB(85, 255, 85));
		turquoise = ColorSequence.new(Color3.fromRGB(85, 255, 170));
		cyan = ColorSequence.new(Color3.fromRGB(85, 255, 255));
		blue = ColorSequence.new(Color3.fromRGB(85, 170, 255));
		royal = ColorSequence.new(Color3.fromRGB(85, 85, 255));
		violet = ColorSequence.new(Color3.fromRGB(170, 85, 255));
		pink = ColorSequence.new(Color3.fromRGB(255, 85, 255));
		hotpink = ColorSequence.new(Color3.fromRGB(255, 85, 170));

		--- returns `ColorSequence.new(Color3.fromRGB(w, w, w))`
		fromconstant = function(w: number)
			return ColorSequence.new(Color3.fromRGB(w, w, w))
		end;
		--- returns color3 in colorsequence at interpolant `a`
		colorat = function(sequence: ColorSequence, a: number): Color3
			local lastkeypoint = nil
			for _, Keypoint in ipairs(sequence.Keypoints) do
				if a < Keypoint.Time then
					local time = lastkeypoint.Time
		
					return lastkeypoint.Value:Lerp(Keypoint.Value, (a - time) / (Keypoint.Time - time))
				end
				lastkeypoint = Keypoint
			end
			return lastkeypoint and lastkeypoint.Value or Color3.fromRGB(255, 255, 255)
		end;
	};
}

--- returns `Color3.fromRGB(w, w, w)`
function Color3K.fromconstant(w: number)
	return Color3.fromRGB(w, w, w)
end

--- adjusts color3 saturation
function Color3K.saturation(c: Color3, value: number)
	local H, S, V = c:ToHSV()

	return Color3.fromHSV(H, math.clamp(S + (value / 100), 0, 1), V)
end

--- returns approximate sort value of color3 \
--- equivalent to `(c:ToHSV()) * 100`
function Color3K.sortvalue(c: Color3)
	return (c:ToHSV()) * 100
end

--- returns an inversion of color3
function Color3K.invert(c: Color3)
	return Color3.new(1 - c.R, 1 - c.G, 1 - c.B)
end

--- returns vertexcolor from color3
function Color3K.tovertexcolor(c: Color3)
	return Vector3.new(c.R, c.G, c.B)
end

--- returns color3 from vertexcolor
function Color3K.fromvertexcolor(v: Vector3)
	return Color3.new(v.X, v.Y, v.Z)
end

--- returns `color3 * x`
function Color3K.scale(c: Color3, x: number)
	return Color3.new(c.R * x, c.G * x, c.B * x)
end

--- returns color3 with respect to player name
function Color3K.fromplayername(name: string)
	local value, len = 0, #name
	for i = 1, len do
		local byte = string.byte(string.sub(name, i, i))
		local reverseidx = len - i + 1
		if len % 2 == 1 then
			reverseidx -= 1
		end
		if reverseidx % 4 >= 2 then
			byte = -byte
		end
		value += byte
	end
	value %= #Color3K.PlayerColors

	return Color3K.PlayerColors[1 + value]
end

return Color3K