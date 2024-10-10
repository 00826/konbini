--- ### Platforms.luau
---
--- contains UserInputType-to-PlatformId conversions

return {
	[Enum.UserInputType.None]			= 0;

	[Enum.UserInputType.Keyboard]		= 1;
	[Enum.UserInputType.MouseButton1]	= 1;
	[Enum.UserInputType.MouseButton2]	= 1;
	[Enum.UserInputType.MouseButton3]	= 1;
	[Enum.UserInputType.MouseMovement]	= 1;
	[Enum.UserInputType.MouseWheel]		= 1;

	[Enum.UserInputType.Touch]			= 2;

	[Enum.UserInputType.Gamepad1]		= 3;
	[Enum.UserInputType.Gamepad2]		= 3;
	[Enum.UserInputType.Gamepad3]		= 3;
	[Enum.UserInputType.Gamepad4]		= 3;
	[Enum.UserInputType.Gamepad5]		= 3;
	[Enum.UserInputType.Gamepad6]		= 3;
	[Enum.UserInputType.Gamepad7]		= 3;
	[Enum.UserInputType.Gamepad8]		= 3;
}