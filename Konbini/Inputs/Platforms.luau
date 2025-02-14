--- ### Platforms.luau
---
--- contains UserInputType-to-Platform conversions

return {
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
}