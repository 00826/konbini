--!strict

--- ### Color3.luau
---
--- extension of Color3 library
local Color3K = {
	white = Color3.fromRGB(255, 255, 255);
	gray = Color3.fromRGB(148, 148, 148);
	black = Color3.fromRGB(0, 0, 0);

	v000 = Color3.fromRGB(0, 0, 0);
	v015 = Color3.fromRGB(15, 15, 15);
	v030 = Color3.fromRGB(30, 30, 30);
	v045 = Color3.fromRGB(45, 45, 45);
	v060 = Color3.fromRGB(60, 60, 60);
	v075 = Color3.fromRGB(75, 75, 75);
	v090 = Color3.fromRGB(90, 90, 90);
	v105 = Color3.fromRGB(105, 105, 105);
	v120 = Color3.fromRGB(120, 120, 120);
	v135 = Color3.fromRGB(135, 135, 135);
	v150 = Color3.fromRGB(150, 150, 150);
	v165 = Color3.fromRGB(165, 165, 165);
	v180 = Color3.fromRGB(180, 180, 180);
	v195 = Color3.fromRGB(195, 195, 195);
	v210 = Color3.fromRGB(210, 210, 210);
	v225 = Color3.fromRGB(225, 225, 225);
	v240 = Color3.fromRGB(240, 240, 240);
	v255 = Color3.fromRGB(255, 255, 255);

	h000 = Color3.fromRGB(255, 85, 85);
	h015 = Color3.fromRGB(255, 128, 85);
	h030 = Color3.fromRGB(255, 170, 85);
	h045 = Color3.fromRGB(255, 213, 85);
	h060 = Color3.fromRGB(255, 255, 85);
	h075 = Color3.fromRGB(213, 255, 85);
	h090 = Color3.fromRGB(170, 255, 85);
	h105 = Color3.fromRGB(128, 255, 85);
	h120 = Color3.fromRGB(85, 255, 85);
	h135 = Color3.fromRGB(85, 255, 128);
	h150 = Color3.fromRGB(85, 255, 170);
	h165 = Color3.fromRGB(85, 255, 213);
	h180 = Color3.fromRGB(85, 255, 255);
	h195 = Color3.fromRGB(85, 213, 255);
	h210 = Color3.fromRGB(85, 170, 255);
	h225 = Color3.fromRGB(85, 128, 255);
	h240 = Color3.fromRGB(85, 85, 255);
	h255 = Color3.fromRGB(128, 85, 255);
	h270 = Color3.fromRGB(170, 85, 255);
	h285 = Color3.fromRGB(213, 85, 255);
	h300 = Color3.fromRGB(255, 85, 255);
	h315 = Color3.fromRGB(255, 85, 213);
	h330 = Color3.fromRGB(255, 85, 170);
	h345 = Color3.fromRGB(255, 85, 128);

	glow300 = Color3.fromRGB(300, 300, 300);
	glow350 = Color3.fromRGB(350, 350, 350);
	glow400 = Color3.fromRGB(400, 400, 400);
	glow450 = Color3.fromRGB(450, 450, 450);
	glow500 = Color3.fromRGB(500, 500, 500);
	glow750 = Color3.fromRGB(750, 750, 750);
	glow1000 = Color3.fromRGB(1000, 1000, 1000);

	PlayerColors = {
		[1] = Color3.fromRGB(253, 41, 67); --- Color3.new(253/255, 41/255, 67/255);
		[2] = Color3.fromRGB(1, 162, 255); --- Color3.new(1/255, 162/255, 255/255);
		[3] = Color3.fromRGB(2, 184, 87); --- Color3.new(2/255, 184/255, 87/255);
		[4] = Color3.fromRGB(180, 128, 255); --- BrickColor.new("Alder").Color; Color3.fromRGB(107, 50, 124); BrickColor.new("Bright violet").Color;
		[5] = Color3.fromRGB(218, 133, 65); --- BrickColor.new("Bright orange").Color;
		[6] = Color3.fromRGB(245, 205, 48); --- BrickColor.new("Bright yellow").Color;
		[7] = Color3.fromRGB(232, 186, 200); --- BrickColor.new("Light reddish violet").Color;
		[8] = Color3.fromRGB(215, 197, 154); --- BrickColor.new("Brick yellow").Color;
	};

	BrickColors = {
		["Alder"] = Color3.new(0.705882, 0.501961, 1);
		["Artichoke"] = Color3.new(0.541176, 0.670588, 0.521569);
		["Baby blue"] = Color3.new(0.596078, 0.760784, 0.858824);
		["Beige"] = Color3.new(0.792157, 0.74902, 0.639216);
		["Black metallic"] = Color3.new(0.0862745, 0.113725, 0.196078);
		["Black"] = Color3.new(0.105882, 0.164706, 0.207843);
		["Br. reddish orange"] = Color3.new(0.827451, 0.435294, 0.298039);
		["Br. yellowish green"] = Color3.new(0.643137, 0.741176, 0.278431);
		["Br. yellowish orange"] = Color3.new(0.886275, 0.607843, 0.25098);
		["Brick yellow"] = Color3.new(0.843137, 0.772549, 0.603922);
		["Bright blue"] = Color3.new(0.0509804, 0.411765, 0.67451);
		["Bright bluish green"] = Color3.new(0, 0.560784, 0.611765);
		["Bright bluish violet"] = Color3.new(0.262745, 0.329412, 0.576471);
		["Bright green"] = Color3.new(0.294118, 0.592157, 0.294118);
		["Bright orange"] = Color3.new(0.854902, 0.521569, 0.254902);
		["Bright purple"] = Color3.new(0.803922, 0.384314, 0.596078);
		["Bright red"] = Color3.new(0.768628, 0.156863, 0.109804);
		["Bright reddish lilac"] = Color3.new(0.556863, 0.258824, 0.521569);
		["Bright reddish violet"] = Color3.new(0.572549, 0.223529, 0.470588);
		["Bright violet"] = Color3.new(0.419608, 0.196078, 0.486275);
		["Bright yellow"] = Color3.new(0.960784, 0.803922, 0.188235);
		["Bronze"] = Color3.new(0.494118, 0.407843, 0.247059);
		["Brown"] = Color3.new(0.486275, 0.360784, 0.27451);
		["Burgundy"] = Color3.new(0.533333, 0.243137, 0.243137);
		["Burlap"] = Color3.new(0.780392, 0.67451, 0.470588);
		["Burnt Sienna"] = Color3.new(0.415686, 0.223529, 0.0352941);
		["Buttermilk"] = Color3.new(0.996078, 0.952941, 0.733333);
		["CGA brown"] = Color3.new(0.666667, 0.333333, 0);
		["Cadet blue"] = Color3.new(0.623529, 0.678431, 0.752941);
		["Camo"] = Color3.new(0.227451, 0.490196, 0.0823529);
		["Carnation pink"] = Color3.new(1, 0.596078, 0.862745);
		["Cashmere"] = Color3.new(0.827451, 0.745098, 0.588235);
		["Cloudy grey"] = Color3.new(0.670588, 0.658824, 0.619608);
		["Cocoa"] = Color3.new(0.337255, 0.141176, 0.141176);
		["Cool yellow"] = Color3.new(0.992157, 0.917647, 0.552941);
		["Copper"] = Color3.new(0.588235, 0.403922, 0.4);
		["Cork"] = Color3.new(0.737255, 0.607843, 0.364706);
		["Crimson"] = Color3.new(0.592157, 0, 0);
		["Curry"] = Color3.new(0.843137, 0.662745, 0.294118);
		["Cyan"] = Color3.new(0.0156863, 0.686275, 0.92549);
		["Daisy orange"] = Color3.new(0.972549, 0.85098, 0.427451);
		["Dark Curry"] = Color3.new(0.690196, 0.556863, 0.266667);
		["Dark Royal blue"] = Color3.new(0.137255, 0.278431, 0.545098);
		["Dark blue"] = Color3.new(0, 0.0627451, 0.690196);
		["Dark green"] = Color3.new(0.156863, 0.498039, 0.278431);
		["Dark grey metallic"] = Color3.new(0.341176, 0.345098, 0.341176);
		["Dark grey"] = Color3.new(0.427451, 0.431373, 0.423529);
		["Dark indigo"] = Color3.new(0.239216, 0.0823529, 0.521569);
		["Dark nougat"] = Color3.new(0.682353, 0.478431, 0.34902);
		["Dark orange"] = Color3.new(0.627451, 0.372549, 0.207843);
		["Dark red"] = Color3.new(0.482353, 0.180392, 0.184314);
		["Dark stone grey"] = Color3.new(0.388235, 0.372549, 0.384314);
		["Dark taupe"] = Color3.new(0.352941, 0.298039, 0.258824);
		["Deep blue"] = Color3.new(0.129412, 0.329412, 0.72549);
		["Deep orange"] = Color3.new(1, 0.686275, 0);
		["Dove blue"] = Color3.new(0.490196, 0.733333, 0.866667);
		["Dusty Rose"] = Color3.new(0.639216, 0.294118, 0.294118);
		["Earth blue"] = Color3.new(0.12549, 0.227451, 0.337255);
		["Earth green"] = Color3.new(0.152941, 0.27451, 0.176471);
		["Earth orange"] = Color3.new(0.384314, 0.278431, 0.196078);
		["Earth yellow"] = Color3.new(0.407843, 0.360784, 0.262745);
		["Eggplant"] = Color3.new(0.482353, 0, 0.482353);
		["Electric blue"] = Color3.new(0.0352941, 0.537255, 0.811765);
		["Faded green"] = Color3.new(0.439216, 0.584314, 0.470588);
		["Fawn brown"] = Color3.new(0.627451, 0.517647, 0.309804);
		["Fire Yellow"] = Color3.new(0.976471, 0.839216, 0.180392);
		["Flame reddish orange"] = Color3.new(0.811765, 0.376471, 0.141176);
		["Flame yellowish orange"] = Color3.new(0.909804, 0.670588, 0.176471);
		["Flint"] = Color3.new(0.411765, 0.4, 0.360784);
		["Fog"] = Color3.new(0.780392, 0.831373, 0.894118);
		["Forest green"] = Color3.new(0.121569, 0.501961, 0.113725);
		["Fossil"] = Color3.new(0.623529, 0.631373, 0.67451);
		["Ghost grey"] = Color3.new(0.792157, 0.796079, 0.819608);
		["Gold"] = Color3.new(0.937255, 0.721569, 0.219608);
		["Grey"] = Color3.new(0.631373, 0.647059, 0.635294);
		["Grime"] = Color3.new(0.498039, 0.556863, 0.392157);
		["Gun metallic"] = Color3.new(0.458824, 0.423529, 0.384314);
		["Hot pink"] = Color3.new(1, 0, 0.74902);
		["Hurricane grey"] = Color3.new(0.584314, 0.537255, 0.533333);
		["Institutional white"] = Color3.new(0.972549, 0.972549, 0.972549);
		["Khaki"] = Color3.new(0.886275, 0.862745, 0.737255);
		["Lapis"] = Color3.new(0.0627451, 0.164706, 0.862745);
		["Laurel green"] = Color3.new(0.658824, 0.741176, 0.6);
		["Lavender"] = Color3.new(0.54902, 0.356863, 0.623529);
		["Lemon metalic"] = Color3.new(0.509804, 0.541176, 0.364706);
		["Lig. Yellowich orange"] = Color3.new(0.952941, 0.811765, 0.607843);
		["Lig. yellowish green"] = Color3.new(0.85098, 0.894118, 0.654902);
		["Light Royal blue"] = Color3.new(0.623529, 0.764706, 0.913726);
		["Light blue"] = Color3.new(0.705882, 0.823529, 0.894118);
		["Light bluish green"] = Color3.new(0.717647, 0.843137, 0.835294);
		["Light bluish violet"] = Color3.new(0.756863, 0.792157, 0.870588);
		["Light brick yellow"] = Color3.new(0.941177, 0.835294, 0.627451);
		["Light green (Mint)"] = Color3.new(0.760784, 0.854902, 0.721569);
		["Light grey metallic"] = Color3.new(0.670588, 0.678431, 0.67451);
		["Light grey"] = Color3.new(0.780392, 0.756863, 0.717647);
		["Light lilac"] = Color3.new(0.654902, 0.662745, 0.807843);
		["Light orange brown"] = Color3.new(0.796079, 0.517647, 0.258824);
		["Light orange"] = Color3.new(0.917647, 0.721569, 0.572549);
		["Light pink"] = Color3.new(0.862745, 0.564706, 0.584314);
		["Light purple"] = Color3.new(0.894118, 0.678431, 0.784314);
		["Light red"] = Color3.new(0.933333, 0.768628, 0.713726);
		["Light reddish violet"] = Color3.new(0.909804, 0.729412, 0.784314);
		["Light stone grey"] = Color3.new(0.898039, 0.894118, 0.87451);
		["Light yellow"] = Color3.new(0.976471, 0.913726, 0.6);
		["Lilac"] = Color3.new(0.654902, 0.368627, 0.607843);
		["Lily white"] = Color3.new(0.929412, 0.917647, 0.917647);
		["Lime green"] = Color3.new(0, 1, 0);
		["Linen"] = Color3.new(0.686275, 0.580392, 0.513726);
		["Magenta"] = Color3.new(0.666667, 0, 0.666667);
		["Maroon"] = Color3.new(0.458824, 0, 0);
		["Mauve"] = Color3.new(0.878431, 0.698039, 0.815686);
		["Med. bluish green"] = Color3.new(0.333333, 0.647059, 0.686275);
		["Med. reddish violet"] = Color3.new(0.768628, 0.439216, 0.627451);
		["Med. yellowish green"] = Color3.new(0.780392, 0.823529, 0.235294);
		["Med. yellowish orange"] = Color3.new(0.905882, 0.67451, 0.345098);
		["Medium Royal blue"] = Color3.new(0.423529, 0.505882, 0.717647);
		["Medium blue"] = Color3.new(0.431373, 0.6, 0.792157);
		["Medium bluish violet"] = Color3.new(0.407843, 0.454902, 0.67451);
		["Medium brown"] = Color3.new(0.337255, 0.258824, 0.211765);
		["Medium green"] = Color3.new(0.631373, 0.768628, 0.54902);
		["Medium lilac"] = Color3.new(0.203922, 0.168627, 0.458824);
		["Medium orange"] = Color3.new(0.878431, 0.596078, 0.392157);
		["Medium red"] = Color3.new(0.854902, 0.52549, 0.478431);
		["Medium stone grey"] = Color3.new(0.639216, 0.635294, 0.647059);
		["Mid gray"] = Color3.new(0.803922, 0.803922, 0.803922);
		["Mint"] = Color3.new(0.694118, 0.898039, 0.65098);
		["Moss"] = Color3.new(0.486275, 0.611765, 0.419608);
		["Mulberry"] = Color3.new(0.34902, 0.133333, 0.34902);
		["Navy blue"] = Color3.new(0, 0.12549, 0.376471);
		["Neon green"] = Color3.new(0.847059, 0.866667, 0.337255);
		["Neon orange"] = Color3.new(0.835294, 0.45098, 0.239216);
		["New Yeller"] = Color3.new(1, 1, 0);
		["Nougat"] = Color3.new(0.8, 0.556863, 0.411765);
		["Olive"] = Color3.new(0.756863, 0.745098, 0.258824);
		["Olivine"] = Color3.new(0.580392, 0.745098, 0.505882);
		["Oyster"] = Color3.new(0.733333, 0.701961, 0.698039);
		["Parsley green"] = Color3.new(0.172549, 0.396078, 0.113725);
		["Pastel Blue"] = Color3.new(0.501961, 0.733333, 0.858824);
		["Pastel blue-green"] = Color3.new(0.623529, 0.952941, 0.913726);
		["Pastel brown"] = Color3.new(1, 0.8, 0.6);
		["Pastel green"] = Color3.new(0.8, 1, 0.8);
		["Pastel light blue"] = Color3.new(0.686275, 0.866667, 1);
		["Pastel orange"] = Color3.new(1, 0.788235, 0.788235);
		["Pastel violet"] = Color3.new(0.694118, 0.654902, 1);
		["Pastel yellow"] = Color3.new(1, 1, 0.8);
		["Pearl"] = Color3.new(0.905882, 0.905882, 0.92549);
		["Persimmon"] = Color3.new(1, 0.34902, 0.34902);
		["Phosph. White"] = Color3.new(0.92549, 0.909804, 0.870588);
		["Pine Cone"] = Color3.new(0.423529, 0.345098, 0.294118);
		["Pink"] = Color3.new(1, 0.4, 0.8);
		["Plum"] = Color3.new(0.482353, 0.184314, 0.482353);
		["Quill grey"] = Color3.new(0.87451, 0.87451, 0.870588);
		["Really black"] = Color3.new(0.0666667, 0.0666667, 0.0666667);
		["Really blue"] = Color3.new(0, 0, 1);
		["Really red"] = Color3.new(1, 0, 0);
		["Red flip/flop"] = Color3.new(0.592157, 0.411765, 0.356863);
		["Reddish brown"] = Color3.new(0.411765, 0.25098, 0.156863);
		["Reddish lilac"] = Color3.new(0.588235, 0.439216, 0.623529);
		["Royal blue"] = Color3.new(0.27451, 0.403922, 0.643137);
		["Royal purple"] = Color3.new(0.384314, 0.145098, 0.819608);
		["Rust"] = Color3.new(0.560784, 0.298039, 0.164706);
		["Sage green"] = Color3.new(0.72549, 0.768628, 0.694118);
		["Salmon"] = Color3.new(1, 0.580392, 0.580392);
		["Sand blue metallic"] = Color3.new(0.47451, 0.533333, 0.631373);
		["Sand blue"] = Color3.new(0.454902, 0.52549, 0.615686);
		["Sand green"] = Color3.new(0.470588, 0.564706, 0.509804);
		["Sand red"] = Color3.new(0.584314, 0.47451, 0.466667);
		["Sand violet metallic"] = Color3.new(0.584314, 0.556863, 0.639216);
		["Sand violet"] = Color3.new(0.529412, 0.486275, 0.564706);
		["Sand yellow metallic"] = Color3.new(0.576471, 0.529412, 0.403922);
		["Sand yellow"] = Color3.new(0.584314, 0.541176, 0.45098);
		["Sea green"] = Color3.new(0.203922, 0.556863, 0.25098);
		["Seashell"] = Color3.new(0.913726, 0.854902, 0.854902);
		["Shamrock"] = Color3.new(0.356863, 0.603922, 0.298039);
		["Silver flip/flop"] = Color3.new(0.537255, 0.529412, 0.533333);
		["Silver"] = Color3.new(0.611765, 0.639216, 0.658824);
		["Slime green"] = Color3.new(0.313726, 0.427451, 0.329412);
		["Smoky grey"] = Color3.new(0.356863, 0.364706, 0.411765);
		["Steel blue"] = Color3.new(0.321569, 0.486275, 0.682353);
		["Storm blue"] = Color3.new(0.2, 0.345098, 0.509804);
		["Sunrise"] = Color3.new(0.831373, 0.564706, 0.741176);
		["Tawny"] = Color3.new(0.588235, 0.333333, 0.333333);
		["Teal"] = Color3.new(0.0705882, 0.933333, 0.831373);
		["Terra Cotta"] = Color3.new(0.745098, 0.407843, 0.384314);
		["Toothpaste"] = Color3.new(0, 1, 1);
		["Tr. Blue"] = Color3.new(0.482353, 0.713726, 0.909804);
		["Tr. Bright bluish violet"] = Color3.new(0.647059, 0.647059, 0.796079);
		["Tr. Brown"] = Color3.new(0.74902, 0.717647, 0.694118);
		["Tr. Flu. Blue"] = Color3.new(0.811765, 0.886275, 0.968628);
		["Tr. Flu. Green"] = Color3.new(0.972549, 0.945098, 0.517647);
		["Tr. Flu. Red"] = Color3.new(0.882353, 0.643137, 0.760784);
		["Tr. Flu. Reddish orange"] = Color3.new(0.85098, 0.521569, 0.423529);
		["Tr. Flu. Yellow"] = Color3.new(1, 0.964706, 0.482353);
		["Tr. Green"] = Color3.new(0.517647, 0.713726, 0.552941);
		["Tr. Lg blue"] = Color3.new(0.756863, 0.87451, 0.941177);
		["Tr. Medi. reddish violet"] = Color3.new(0.898039, 0.678431, 0.784314);
		["Tr. Red"] = Color3.new(0.803922, 0.329412, 0.294118);
		["Tr. Yellow"] = Color3.new(0.968628, 0.945098, 0.552941);
		["Transparent"] = Color3.new(0.92549, 0.92549, 0.92549);
		["Turquoise"] = Color3.new(0.47451, 0.709804, 0.709804);
		["Warm yellowish orange"] = Color3.new(0.921569, 0.721569, 0.498039);
		["Wheat"] = Color3.new(0.945098, 0.905882, 0.780392);
		["White"] = Color3.new(0.94902, 0.952941, 0.952941);
		["Yellow flip/flop"] = Color3.new(0.705882, 0.517647, 0.333333);
	};

	--- ### Color3K.ColorSequence
	---
	--- extension of ColorSequence library
	ColorSequence = {
		white = ColorSequence.new(Color3.fromRGB(255, 255, 255));
		gray = ColorSequence.new(Color3.fromRGB(148, 148, 148));
		black = ColorSequence.new(Color3.fromRGB(0, 0, 0));

		--- returns `ColorSequence.new(Color3.fromRGB(w, w, w))`
		fromconstant = function(w: number)
			return ColorSequence.new(Color3.fromRGB(w, w, w))
		end;
		--- returns color3 in colorsequence at interpolant `a`
		colorat = function(sequence: ColorSequence, a: number)
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