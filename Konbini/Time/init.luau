--!strict

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

--- returns furthest-ahead time between `x` and konbini time
function Time.furthest(x: number?): number
	return math.max(x or 0, buffer.readf32(Time.buffer, 0))
end

--- applies debounce against instance `i` \
--- returns true if debounce passed, returns false if not passed
function Time.debounce(i: Instance, name: string, time: number): boolean
	local now, later = Time.now(), i:GetAttribute("K_Time_debounce_" .. name) or 0
	if later > now then return false end

	i:SetAttribute("K_Time_debounce_" .. name, now + time)
	return true
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

--- returns latency, in milliseconds: \
--- `in-studio, regardless of calling environment`: `Time.incomingreplicationlag` \
--- `server`: `client:GetNetworkPing()` or `0` \
--- `client`: `localplayer:GetNetworkPing()`
function Time.latency(client: Player?): number
	if RunService:IsStudio() then
		return Time.incomingreplicationlag / 1000
	else
		if IsServer then
			return client and client:GetNetworkPing() * 1000 or 0
		end
		return LocalPlayer:GetNetworkPing() * 1000
	end
end

if IsServer then
	local elapsed = 0
	local function UpdateTime(t, dt)
		buffer.writef32(Time.buffer, 0, t)

		elapsed += dt
		if elapsed < Time.rate then return end
		elapsed -= Time.rate

		TimeRemote:FireAllClients(Time.buffer)
	end
	UpdateTime(0, Time.rate)
	RunService.Stepped:Connect(UpdateTime)
else
	TimeRemote.OnClientEvent:Connect(function(tBuffer: buffer)
		buffer.writef32(Time.buffer, 0, buffer.readf32(tBuffer, 0))
	end)
end

return Time