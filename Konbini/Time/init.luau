--!strict
--!native

local RunService = game:GetService("RunService")
local IsServer = RunService:IsServer()

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local TimeRemote = script:WaitForChild("TimeRemote")

--- ### Time.luau
---
--- server-authoritative global time
local Time = {
	rate = 1/60;
	buffer = buffer.create(4);

	incomingreplicationlag = 80;
}

--- returns konbini time
function Time.now(latency: number?): number
	return buffer.readf32(Time.buffer, 0) + (latency or 0)
end

--- extends expiry `x` by `time` seconds, where `x`, if behind konbini time, is set to current konbini time
function Time.extend(x: number, time: number)
	return math.max(x or 0, buffer.readf32(Time.buffer, 0)) + time
end

--- runs function for `x` seconds, or until function returns `true`
function Time.run(x: number, f: (elapsed: number, dt: number) -> boolean?): RBXScriptConnection
	local elapsed = 0
	local C; C = RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		local result = f(elapsed, dt)
		if (elapsed > x) or (result == true) then
			C:Disconnect()
		end
	end)
	return C
end

--- runs function at every second interval `x`
function Time.framerule(x: number, f: (...any) -> ()): RBXScriptConnection
	local elapsed = 0
	local function frame(dt)
		elapsed += dt
		if elapsed < x then return end
		elapsed -= x
		f()
	end
	f()
	return RunService.Heartbeat:Connect(frame)
end

--- returns latency, in seconds: \
--- `in-studio, regardless of calling environment`: `Time.incomingreplicationlag` \
--- `server`: `client:GetNetworkPing()` or `0` \
--- `client`: `localplayer:GetNetworkPing()` \
--- `roundtrip (?=false)`: apply cost of network roundtrip? `(latency * 2)`
function Time.latency(client: Player?, roundtrip: boolean?): number
	if RunService:IsStudio() then
		return (Time.incomingreplicationlag / 1000) * (roundtrip and 2 or 1)
	else
		if IsServer then
			return (client and client:GetNetworkPing() or 0) * (roundtrip and 2 or 1)
		end
		return (LocalPlayer:GetNetworkPing()) * (roundtrip and 2 or 1)
	end
end

--- calls function `n` times, with `x` seconds between each call
function Time.stagger<A...>(n: number, x: number, f: (A...) -> (), ...: A...)
	for i = 0, n - 1, 1 do
		task.delay(x * i, f, ...)
	end
end

if IsServer then
	local elapsed = 0
	local function updatetime(t, dt)
		buffer.writef32(Time.buffer, 0, t)

		elapsed += dt
		if elapsed < Time.rate then return end
		elapsed -= Time.rate

		TimeRemote:FireAllClients(Time.buffer)
	end
	updatetime(0, Time.rate)
	RunService.Stepped:Connect(updatetime)
else
	TimeRemote.OnClientEvent:Connect(function(tBuffer: buffer)
		buffer.writef32(Time.buffer, 0, buffer.readf32(tBuffer, 0))
	end)
end

return Time