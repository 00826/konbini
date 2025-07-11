--!strict
--!native

local RunService = game:GetService("RunService")
local IsServer = RunService:IsServer()

local TimeRemote = script:WaitForChild("Remote")

--- ### Time.luau
---
--- server-authoritative global time
local Time = {
	Framerate = 1/60;
	UnixBuffer = buffer.create(8);
}

--- returns server-authoritative unix time in seconds
function Time.now()
	return buffer.readf64(Time.UnixBuffer, 0)
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

if IsServer then
	local elapsed = 0
	local function frame(dt: number)
		buffer.writef64(Time.UnixBuffer, 0, DateTime.now().UnixTimestampMillis/1000) --- accurate down to the millisecond

		elapsed += dt
		if elapsed < Time.Framerate then return end
		elapsed -= Time.Framerate

		TimeRemote:FireAllClients(Time.UnixBuffer)
	end
	frame(Time.Framerate)
	RunService.Heartbeat:Connect(frame)
else
	TimeRemote.OnClientEvent:Connect(function(b: buffer)
		buffer.writef64(Time.UnixBuffer, 0, buffer.readf64(b, 0))
	end)
end

return Time