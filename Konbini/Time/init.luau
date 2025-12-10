--!strict

local RunService = game:GetService("RunService")
local IsServer = RunService:IsServer()

local Remote = script:WaitForChild("Remote")

--- ### Time.luau
---
--- server-authoritative global time
local Time = {
	Framerate = 1/60;
	UnixBuffer = buffer.create(8);
}

--- returns server-authoritative unix time in seconds
function Time.now()
	return buffer.readf64(Time.UnixBuffer, 0) / 1000
end

--- returns server-authoritative unix time in milliseconds
function Time.nowms()
	return buffer.readf64(Time.UnixBuffer, 0)
end

--- runs function at second interval `x` \
--- `immediate(?=true)`: function is called on the next frame
function Time.framerule(x: number, f: (dt: number) -> (), immediate: boolean?)
	local recent = os.clock()
	if immediate ~= false then
		recent -= x
	end

	return RunService.Heartbeat:Connect(function()
		local now = os.clock()
		local dt = now - recent
		if dt > x then
			recent = now - (dt - x)

			f(dt)
		end
	end)
end

if IsServer then
	local recent = os.clock() - Time.Framerate
	buffer.writef64(Time.UnixBuffer, 0, DateTime.now().UnixTimestampMillis)

	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		local dt = now - recent
		if dt > Time.Framerate then
			recent = now - (dt - Time.Framerate)

			buffer.writef64(Time.UnixBuffer, 0, DateTime.now().UnixTimestampMillis)
			Remote:FireAllClients(Time.UnixBuffer)
		end
	end)
else
	Remote.OnClientEvent:Connect(function(b: buffer)
		buffer.copy(Time.UnixBuffer, 0, b)
	end)
end

return Time