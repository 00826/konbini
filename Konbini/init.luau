--!strict

export type types = typeof(require(script.types))

--- ### Konbini.luau
---
--- a shelf of roblox-luau convenience modules \
--- [*view konbini on github*](https://github.com/00826/konbini)
return table.freeze{
	Animation = require(script:WaitForChild("Animation"));
	await = require(script:WaitForChild("await"));
	Bullet = require(script:WaitForChild("Bullet"));
	CFrame = require(script:WaitForChild("CFrame"));
	Collisions = require(script:WaitForChild("Collisions"));
	Color3 = require(script:WaitForChild("Color3"));
	Couture = require(script:WaitForChild("Couture"));
	Data = require(script:WaitForChild("Data"));
	Encoder = require(script:WaitForChild("Encoder"));
	Entity = require(script:WaitForChild("Entity"));
	Hook = require(script:WaitForChild("Hook"));
	Inputs = require(script:WaitForChild("Inputs"));
	Instance = require(script:WaitForChild("Instance"));
	Interface = require(script:WaitForChild("Interface"));
	Math = require(script:WaitForChild("Math"));
	Misc = require(script:WaitForChild("Misc"));
	Network = require(script:WaitForChild("Network"));
	Table = require(script:WaitForChild("Table"));
	Time = require(script:WaitForChild("Time"));
	Vector3 = require(script:WaitForChild("Vector3"));
	Zone = require(script:WaitForChild("Zone"));
}