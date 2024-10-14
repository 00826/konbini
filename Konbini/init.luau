--!strict

export type types = typeof(require(script.types))

--- ### Konbini.luau
---
--- a shelf of roblox-luau convenience modules \
--- [*view konbini on github*](https://github.com/00826/konbini)
return table.freeze{
	Animation					= require(script:WaitForChild("Animation"));
	async						= require(script:WaitForChild("async"));
	Bind						= require(script:WaitForChild("Bind"));
	CFrame						= require(script:WaitForChild("CFrame"));
	Collisions					= require(script:WaitForChild("Collisions"));
	Couture						= require(script:WaitForChild("Couture"));
	Data						= require(script:WaitForChild("Data"));
	Debounce					= require(script:WaitForChild("Debounce"));
	Encoder						= require(script:WaitForChild("Encoder"));
	Inputs						= require(script:WaitForChild("Inputs"));
	Instance					= require(script:WaitForChild("Instance"));
	Interface					= require(script:WaitForChild("Interface"));
	Math						= require(script:WaitForChild("Math"));
	Misc						= require(script:WaitForChild("Misc"));
	Network						= require(script:WaitForChild("Network"));
	Rig							= require(script:WaitForChild("Rig"));
	Table						= require(script:WaitForChild("Table"));
	Time						= require(script:WaitForChild("Time"));
	Tween						= require(script:WaitForChild("Tween"));
	Vector3						= require(script:WaitForChild("Vector3"));
	Zone						= require(script:WaitForChild("Zone"));
}