--- ### DPad2DMap.luau
---
--- contains DPad2D-to-KeyCode conversions

return {
	["Up"] = Enum.KeyCode.DPadUp;
	["Left"] = Enum.KeyCode.DPadLeft;
	["Right"] = Enum.KeyCode.DPadRight;
	["Down"] = Enum.KeyCode.DPadDown;

	["R3"] = Enum.KeyCode.ButtonR3;
} :: {[string]: Enum.KeyCode}