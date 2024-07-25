--!strict

local EmitPart					= script:WaitForChild("EmitPart")

--- ### Sounds.luau
---
--- `Sound` player/loader
local Sounds = {}

--- plays sound at position
function Sounds.playatposition(sound: Sound, position: Vector3, properties: {[string]: any}?)
	local EP = EmitPart:Clone()
	EP.Position = position
	EP.Parent = workspace
	local NewSound = sound:Clone() :: Sound
	NewSound.Parent = EP
	NewSound.PlayOnRemove = true

	if properties then
		for k, v in properties do
			(NewSound :: any)[k] = v
		end
	end

	EP:Destroy()
end

--- plays sound once
function Sounds.play(sound: Sound, parent: Instance?, properties: {[string]: any}?): Sound
	local NewSound = sound:Clone() :: Sound
	NewSound.Parent = parent or sound.Parent

	if properties then
		for k, v in properties do
			(NewSound :: any)[k] = v
		end
	end

	NewSound:Play()
	NewSound.PlayOnRemove = false
	NewSound.Ended:Once(function()
		NewSound:Destroy()
	end)
	NewSound.Stopped:Once(function()
		NewSound:Destroy()
	end)

	return NewSound
end

return Sounds