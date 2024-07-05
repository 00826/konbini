--!strict

--- ### Konbini.luau
---
--- a shelf of roblox-luau convenience modules \
--- [*view konbini on github*](https://github.com/00826/konbini)
return table.freeze{
	types						= script:WaitForChild("types");

	Animation					= require(script:WaitForChild("Animation"));
	async						= require(script:WaitForChild("async"));
	Bar							= require(script:WaitForChild("Bar"));
	Bind						= require(script:WaitForChild("Bind"));
	Cache						= require(script:WaitForChild("Cache"));
	CFrame						= require(script:WaitForChild("CFrame"));
	Collisions					= require(script:WaitForChild("Collisions"));
	Data						= require(script:WaitForChild("Data"));
	Debounce					= require(script:WaitForChild("Debounce"));
	Encoder						= require(script:WaitForChild("Encoder"));
	Group						= require(script:WaitForChild("Group"));
	Inputs						= require(script:WaitForChild("Inputs"));
	Instance					= require(script:WaitForChild("Instance"));
	Interface					= require(script:WaitForChild("Interface"));
	Math						= require(script:WaitForChild("Math"));
	Matrix						= require(script:WaitForChild("Matrix"));
	Misc						= require(script:WaitForChild("Misc"));
	Network						= require(script:WaitForChild("Network"));
	Rig							= require(script:WaitForChild("Rig"));
	Sounds						= require(script:WaitForChild("Sounds"));
	Status						= require(script:WaitForChild("Status"));
	Table						= require(script:WaitForChild("Table"));
	Time						= require(script:WaitForChild("Time"));
	Tween						= require(script:WaitForChild("Tween"));
	Vector3						= require(script:WaitForChild("Vector3"));
}