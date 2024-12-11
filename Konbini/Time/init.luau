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
function Time.now(latency: number?)
	return buffer.readf32(Time.buffer, 0) + (latency or 0)
end

--- extends expiry `x` by `time` seconds, where `x`, if behind konbini time, is set to current konbini time
function Time.extend(x: number, time: number)
	return math.max(x or 0, buffer.readf32(Time.buffer, 0)) + time
end

--- runs function for `x` seconds
function Time.run(x: number, f: (elapsed: number, dt: number) -> ())
	local elapsed = 0
	local c; c = RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		f(elapsed, dt)

		if elapsed > x then
			c:Disconnect()
		end
	end)

	return c
end

--- runs function at every second interval `x`
function Time.framerule(x: number, f: (...any) -> ())
	local elapsed = x
	local function frame(dt: number)
		elapsed += dt
		if elapsed < x then return end
		elapsed -= x
		f()
	end

	return RunService.Heartbeat:Connect(frame)
end

--- runs function at exponential backoff interval `math.clamp(x + (base ^ failures) - 1, x, limit)` \
--- `f() -> true`: failures decremented by `1` (min: `0`) \
--- `f() -> false`: failures incremented by `1` (max: `math.huge`)
function Time.backoff(x: number, base: number, limit: number, f: (...any) -> boolean)
	local elapsed, failures = x, 0

	return RunService.Heartbeat:Connect(function(dt: number)
		local backoffrate = math.clamp(x + (base ^ failures) - 1, x, limit)
		elapsed += dt
		if elapsed < backoffrate then return end
		elapsed -= backoffrate

		local success = f()
		if success == true then
			failures = math.clamp(failures - 1, 0, math.huge)
		elseif success == false then
			failures += 1
		else
			warn(`{debug.traceback()}, function {f} did not return a boolean; interpreting as failure`)
			failures += 1
		end
	end)
end

--- returns latency, in seconds: \
--- `in-studio, regardless of calling environment`: `Time.incomingreplicationlag` \
--- `server`: `client:GetNetworkPing()` or `0` \
--- `client`: `localplayer:GetNetworkPing()` \
--- `roundtrip (?=false)`: apply cost of network roundtrip? `(latency * 2)`
function Time.latency(client: Player?, roundtrip: boolean?)
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