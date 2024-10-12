--!strict

local types						= require(script.Parent.types)

local RunService				= game:GetService("RunService")
local IsServer					= RunService:IsServer()

local TimeRemote				= script:WaitForChild("TimeRemote")

local TimeBuffer				= buffer.create(4)

local function subf(x: string): string
	return #x == 1 and "0" .. x or x
end

--- ### Time.luau
---
--- server-authoritative global time
local Time = {}

--- returns konbini time
function Time.now(latency: number?): number
	return buffer.readf32(TimeBuffer, 0) + (latency or 0)
end

--- returns furthest-ahead time between `x` and konbini time
function Time.furthest(x: number?): number
	return math.max(x or 0, buffer.readf32(TimeBuffer, 0))
end

--- runs function for `x` seconds, or until function returns `true`
function Time.run(x: number, f: (elapsed: number, dt: number) -> boolean?): RBXScriptConnection
	local elapsed = 0
	local C; C = RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		local Result = f(elapsed, dt)
		if (elapsed > x) or (Result == true) then
			C:Disconnect()
		end
	end)
	return C
end

--- runs function in second intervals `x`
function Time.framerule(x: number, f: (...any) -> ()): RBXScriptConnection
	local T = 0
	local function Frame(dt)
		T += dt
		if T < x then return end
		T -= x
		f()
	end
	f()
	return RunService.Heartbeat:Connect(Frame)
end

--- formats `x` into a hour-minute-second-esque notation
function Time.hourminutesecond(x: number, Notation: types.Notation?): string
	--[[
		os.date("!%X", x) is the fastest for all inputs below 86400, because any input at or above 86400 breaks the formatting
		string.gsub(string.format(), x, subf) is the second fastest for all inputs, never has a formatting break, but is ~10% slower than os.date("!%X", x)
		combining both through comparing x >= 86400 gives a faster average across all possible inputs
	]]
	if Notation == "DD:HH:MM:SS" then
		if x >= 86400 then
			local D = x // 86400
			x -= D * 86400
			local H = x // 3600
			x -= H * 3600
			local M = x // 60
			x -= M * 60
			return string.gsub(string.format(("%d:%d:%d:%d"), D, H, M, x), "%d+", subf)
		else
			return "00:" .. os.date("!%X", x)
		end
	elseif Notation == "HH:MM:SS" then
		if x >= 86400 then
			local H = x // 3600
			x -= H * 3600
			local M = x // 60
			x -= M * 60
			return string.gsub(string.format(("%d:%d:%d"), H, M, x), "%d+", subf)
		else
			return os.date("!%X", x)
		end
	elseif Notation == "MM:SS" then
		if x >= 3600 then
			local M = x // 60
			x -= M * 60
			return string.gsub(string.format(("%d:%d"), M, x), "%d+", subf)
		else
			return string.sub(os.date("!%X", x), 4, 8)
		end
	elseif Notation == "M:SS" then
		return string.gsub(string.sub(os.date("!%X", x), 4, 8), "^0", "")
	end
	return os.date("!%X", x)
end

--- formats current utc time as a format result \
--- `Timestamp`: unique, non-recurring timestamp \
--- `Seed`: unique, non-recurring numeric seed \
--- `Until`: seconds until `Timestamp`, `Seed` will change
function Time.format(format: types.Format): types.FormatResult
	local T0 = os.date("!*t")
	local T1 = table.clone(T0)

	local Result = {
		Timestamp = "";
		Seed = 0;
		Until = 0;
	}
	if type(format) == "number" then
		--- `Format: 5`
		--- `February 14, 2024, 06:44` --> `"2024_45_6_8"`
		--- `Format: 10`
		--- `February 14, 2024, 06:44` --> `"2024_45_6_4"`
		--- `Format: 15`
		--- `February 14, 2024, 06:44` --> `"2024_45_6_2"`
		T1.min = format * math.ceil((T1.min + 1) / format)
		T1.sec = 0

		local Year, YDay, Hour, QtrHour = T0.year, T0.yday, T0.hour, math.ceil((T0.min + 1) / format) - 1
		Result.Timestamp = ("%d_%d_%d_%d"):format(Year, YDay, Hour, QtrHour)
		Result.Seed = tonumber(Year .. YDay .. Hour .. QtrHour) :: number
	else
		if format == "Hour" then
			--- `February 14, 2024, 06:44` --> `"2024_45_6"`
			T1.hour = math.floor(T1.hour + 1)
			T1.min = 0
			T1.sec = 0

			local Year, YDay, Hour = T0.year, T0.yday, T0.hour
			Result.Timestamp = ("%d_%d_%d"):format(Year, YDay, Hour)
			Result.Seed = tonumber(Year .. YDay .. Hour) :: number
		elseif format == "Biphase" then
			--- `February 14, 2024, 06:44` --> `"2024_45_AM"`
			--- `February 14, 2024, 16:44` --> `"2024_45_PM"`
			T1.hour = 12 * math.ceil((T1.hour + 1) / 12)
			T1.min = 0
			T1.sec = 0

			local Year, YDay, Phase = T0.year, T0.yday, os.date("!%p")
			Result.Timestamp = ("%d_%d_%s"):format(Year, YDay, Phase)
			Result.Seed = tonumber(Year .. YDay .. Phase:byte()) :: number
		elseif format == "Day" then
			--- `February 14, 2024` --> `"2024_45"`
			T1.day += 1
			T1.hour = 0
			T1.min = 0
			T1.sec = 0

			local Year, YDay = T0.year, T0.yday
			Result.Timestamp = ("%d_%d"):format(Year, YDay)
			Result.Seed = tonumber(Year .. YDay) :: number
		elseif format == "Week" then
			--- `February 14, 2024` --> `"2024_7_06"` (06th week of 2024)
			T1.day += 8 - T0.wday
			T1.hour = 0
			T1.min = 0
			T1.sec = 0

			local Year, Week, YWeek = T0.year, T0.wday, os.date("!%U")
			Result.Timestamp = ("%d_%d_%s"):format(Year, Week, YWeek)
			Result.Seed = tonumber(Year .. Week .. YWeek) :: number
		elseif format == "Season" then
			--- `February 14, 2024` --> `"2024_1"`
			--- Mar-May: `1` (spring)
			--- Jun-Aug: `2` (summer)
			--- Sep-Nov: `3` (fall)
			--- Dec-Feb: `4` (winter)
			T1.month += 1 + ((11 - math.ceil((T1.month - 3) % 12)) % 3)
			T1.day = 1
			T1.hour = 0
			T1.min = 0
			T1.sec = 0

			local Year, Month = T0.year, math.ceil((1 + ((T0.month - 3) % 12)) / 3)
			Result.Timestamp = ("%d_%d"):format(Year, Month)
			Result.Seed = tonumber(Year .. Month) :: number
		elseif format == "Biseason" then
			--- `February 14, 2024` --> `"2024_1"`
			--- Jan-Jun: `1` (SS)
			--- Jul-Dec: `2` (FW)
			T1.month = math.ceil(T1.month / 6)
			T1.day = 1
			T1.hour = 0
			T1.min = 0
			T1.sec = 0

			local Year, Month = T0.year, math.ceil(T0.month / 6)
			Result.Timestamp = ("%d_%d"):format(Year, Month)
			Result.Seed = tonumber(Year .. Month) :: number
		elseif format == "Year" then
			--- `February 14, 2024` --> `"2024"`
			T1.year += 1
			T1.month = 1
			T1.day = 1
			T1.hour = 0
			T1.min = 0
			T1.sec = 0

			Result.Timestamp = tostring(T0.year)
			Result.Seed = tonumber(T0.year) :: number
		end
	end

	Result.Until = os.time(T1) - os.time(T0)

	return Result
end

if IsServer then
	local Elapsed, Rate = 0, 1/60
	local function UpdateTime(t, dt)
		buffer.writef32(TimeBuffer, 0, t)

		Elapsed += dt
		if Elapsed < Rate then return end
		Elapsed -= Rate

		TimeRemote:FireAllClients(TimeBuffer)
	end
	UpdateTime(0, Rate)
	RunService.Stepped:Connect(UpdateTime)
else
	TimeRemote.OnClientEvent:Connect(function(tBuffer: buffer)
		buffer.writef32(TimeBuffer, 0, buffer.readf32(tBuffer, 0))
	end)
end

return Time