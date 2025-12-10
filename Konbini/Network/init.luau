--!strict
--!native

local RunService = game:GetService("RunService")
local IsServer = RunService:IsServer()

local Players = game:GetService("Players")

local RemoteEvent = script:WaitForChild("RemoteEvent")
local UnreliableRemoteEvent = script:WaitForChild("UnreliableRemoteEvent")

local Hooks = {}

--- writes signed 24-bit integer to buffer
local function writei24(b: buffer, offset: number, value: number)
	local bitoffset = offset * 8
	local sign = math.sign(value) < 0 and 1 or 0
	if sign == 1 then
		value += 1
	end

	buffer.writebits(b, bitoffset, 23, math.abs(value))
	buffer.writebits(b, bitoffset + 23, 1, sign)
end

--- reads signed 24-bit integer from buffer
local function readi24(b: buffer, offset: number)
	local bitoffset = offset * 8
	local value = buffer.readbits(b, bitoffset, 23)
	local sign = buffer.readbits(b, bitoffset + 23, 1)
	
	if sign == 1 then
		value *= -1
		value -= 1
	end
	
	return value
end

--- writes unsigned 24-bit integer to buffer
local function writeu24(b: buffer, offset: number, value: number)
	buffer.writebits(b, offset * 8, 24, value)
end

--- reads unsigned 24-bit integer from buffer
local function readu24(b: buffer, offset: number)
	return buffer.readbits(b, offset * 8, 24)
end

--- returns a data-typed buffer of variable width
local function createtypedbuffer(i: number, size: number)
	local b = buffer.create(1 + size)
	buffer.writeu8(b, 0, i)

	return b
end

--- resolves optimal remote wrt packet size of network send args
local function resolveremote(b: buffer, i: {Instance})
	local len = 1 + buffer.len(b) + (#i * 5)
	
	if IsServer then
		if len > 127 then
			len += 13
		else
			len += 12
		end
	else
		if len > 127 then
			len += 18
		else
			len += 17
		end
	end

	if len >= 1000 then
		return RemoteEvent
	else
		return UnreliableRemoteEvent
	end
end

--- hard-checks network recv args
local function assertrecvtypes(b: buffer, i: {Instance})
	assert(type(b) == "buffer", string.format("expected buffer, got %s", type(b)))
	assert(type(i) == "table", string.format("expected table, got %s", type(i)))
	for _, instance in i do
		assert(typeof(instance) == "Instance", string.format("expected Instance, got %s", typeof(i)))
	end
end

--- appends u8 network scope to end of buffer
local function writescope(b: buffer, u8: number)
	local size = buffer.len(b) + 1
	local s = buffer.create(size)
	buffer.copy(s, 0, b)
	buffer.writeu8(s, size - 1, u8)

	return s
end

--- reads u8 network scope from end of buffer
local function readscope(s: buffer)
	return buffer.readu8(s, buffer.len(s) - 1)
end

--- removes u8 network scope from end of buffer
local function removescope(s: buffer)
	local size = buffer.len(s) - 1
	local b = buffer.create(size)
	buffer.copy(b, 0, s, 0, size)

	return b
end

--- ### Network.luau
---
--- buffer-based remote interface
local Network = {
	Framerate = 1/60;
	Scopes = table.create(255);
	Queue = table.create(64);
}

--- returns network scope, creating one if it does not already exist
function Network.scope(scope: string)
	local i
	for thisi, thisscope in Network.Scopes do
		if thisscope == scope then
			i = thisi
			break
		end
	end

	if not i then
		assert(IsServer, string.format("unknown scope %s", scope))
		assert(#Network.Scopes <= 2^8-1, "network at max scopes (uint8 limit)")
		table.insert(Network.Scopes, scope)
		
		i = table.find(Network.Scopes, scope)::any
		script:SetAttribute(scope, i)
	end

	return i
end

--- sends value to network scope \
--- `force(="Reliable"|"Unreliable")`: forces remoteevent when this value is sent \
--- `force(=nil)`: automatically resolves remoteevent wrt value size \
--- `front(=true)`: value is inserted to front of queue \
--- `front(=false|nil)`: value is inserted to back of queue
function Network.send(scope: string, value: any, client:
	| nil
	| number
	| Player
	| { number|Player }
	| (Player) -> boolean,
	force: "Reliable"|"Unreliable"?,
	front: boolean?
)
	local u8scope = Network.scope(scope)

	local unscoped, instances = Network.pack(value)
	local scoped = writescope(unscoped, u8scope)

	if front == true then
		table.insert(Network.Queue, 1, {scoped::any, instances::any, client::any, force::any})
	else
		table.insert(Network.Queue, {scoped::any, instances::any, client::any, force::any})
	end
end

--- receives value from network scope
function Network.recv(scope: string, recv: ((value: any) -> ()) & (player: Player, value: any) -> ())
	if IsServer then
		--- add scope if doesnt already exist
		local u8scope = Network.scope(scope)

		local function serverrecv(player: Player, s: buffer, i: {Instance})
			assertrecvtypes(s, i)

			if u8scope == readscope(s) then
				local value = Network.unpack(removescope(s), 0, i)
				recv(player, value)
			end
		end

		return 
			RemoteEvent.OnServerEvent:Connect(serverrecv),
			UnreliableRemoteEvent.OnServerEvent:Connect(serverrecv)
	else
		local function clientrecv(s: buffer, i: {Instance})
			assertrecvtypes(s, i)

			local u8scope = Network.scope(scope)
			if u8scope == readscope(s) then
				local value = Network.unpack(removescope(s), 0, i)
				recv(value)
			end
		end

		return 
			RemoteEvent.OnClientEvent:Connect(clientrecv),
			UnreliableRemoteEvent.OnClientEvent:Connect(clientrecv)
	end
end

--- unsigned integer lookup
local uintlookup = {
	{ key = "u8", value = {0, 255}; size = 1; write = buffer.writeu8; read = buffer.readu8; };
	{ key = "u16", value = {0, 65535}; size = 2; write = buffer.writeu16; read = buffer.readu16; };
	{ key = "u24", value = {0, 16777215}; size = 3; write = writeu24; read = readu24; };
	{ key = "u32", value = {0, 4294967295}; size = 4; write = buffer.writeu32; read = buffer.readu32; };
}

--- signed integer lookup
local intlookup = {
	{ key = "i8", value = {-128, 127}; size = 1; write = buffer.writei8; read = buffer.readi8; };
	{ key = "i16", value = {-32768, 32767}; size = 2; write = buffer.writei16; read = buffer.readi16; };
	{ key = "i24", value = {-8388608, 8388607}; size = 3; write = writei24; read = readi24; };
	{ key = "i32", value = {-2147483648, 2147483647}; size = 4; write = buffer.writei32; read = buffer.readi32; };
}

--- type lookup
local typelookup = {
	"nil";
	"Instance";

	"table";
	"buffer";
	"string";

	"boolean";
	"number";

	"u8";
	"u16";
	"u24";
	"u32";

	"i8";
	"i16";
	"i24";
	"i32";

	"f32";
	"f64";

	"Vector2";
	"Vector3";
	"CFrame";
	"Color3";
}

--- returns: \
--- `value` packed into a buffer \
--- `instances` supplementary instance table \
--- \
--- instances are returned as a supplementary table to pass into `unwrap()` when decoding \
--- as there is no way to represent an instance into buffer-only terms \
--- \
--- `strings` must be no longer than 255 characters, as their length is encoded as an unsigned 8-bit integer \
--- `tables & arrays` must contain no more than 65535 key-value/index-value pairs, as their length is encoded as an unsigned 16-bit integer \
function Network.pack(value: any, instances: {Instance}?)
	local i = table.find(typelookup, typeof(value))
	assert(i, string.format("unsupported type %s", typeof(value)))

	instances = instances or {}
	assert(instances)

	local b = buffer.create(0)

	if typeof(value) == "nil" then
		b = createtypedbuffer(i, 0)

	elseif typeof(value) == "Instance" then
		local offset = table.find(instances, value)
		if not offset then
			table.insert(instances, value)
			offset = #instances
		end
		assert(offset)

		b = createtypedbuffer(i, 1)
		buffer.writeu8(b, 1, offset)

	elseif typeof(value) == "table" then
		local result = {}
		if #value > 0 then
			for idx, val in ipairs(value) do
				local idxb = Network.pack(idx, instances)
				local valb = Network.pack(val, instances)

				local idxlen, vallen = buffer.len(idxb), buffer.len(valb)
				local pair = buffer.create(idxlen + vallen)
				buffer.copy(pair, 0, idxb)
				buffer.copy(pair, idxlen, valb)

				table.insert(result, pair)
			end
		else
			for key, val in value do
				local keyb = Network.pack(key, instances)
				local valb = Network.pack(val, instances)

				local idxlen, vallen = buffer.len(keyb), buffer.len(valb)
				local pair = buffer.create(idxlen + vallen)
				buffer.copy(pair, 0, keyb)
				buffer.copy(pair, idxlen, valb)

				table.insert(result, pair)
			end
		end

		local size = 0
		local len = 0
		for _, thisb in result do
			size += buffer.len(thisb)
			len += 1
		end

		local prebuffer = buffer.create(size)
		local offset = 0
		for _, thisb in ipairs(result) do
			local thislen = buffer.len(thisb)
			buffer.copy(prebuffer, offset, thisb, 0, thislen)
			offset += thislen
		end

		b = createtypedbuffer(i, buffer.len(prebuffer) + 2)
		buffer.writeu16(b, 1, len)
		buffer.copy(b, 3, prebuffer)

	elseif typeof(value) == "buffer" then
		local len = buffer.len(value)

		b = createtypedbuffer(i, len + 2)
		buffer.writeu16(b, 1, len)
		buffer.copy(b, 3, value)

	elseif typeof(value) == "string" then
		local len = string.len(value)

		b = createtypedbuffer(i, len + 1)
		buffer.writeu8(b, 1, len)
		buffer.writestring(b, 2, value, len)

	elseif typeof(value) == "boolean" then
		b = createtypedbuffer(i, 1)
		buffer.writeu8(b, 1, value and 1 or 0)

	elseif typeof(value) == "number" then
		if value == value and value ~= 1/0 and value ~= -1/0 then
			local integer, fraction = math.modf(value)
			if fraction == 0 then
				--- integer
				for _, a in ipairs(integer < 0 and intlookup or uintlookup) do
					if integer >= a.value[1] and integer <= a.value[2] then
						local itype = a.key
						b = createtypedbuffer(table.find(typelookup, itype)::number, a.size)
						a.write(b, 1, integer)

						break
					end
				end
				
				--- fallback to f64 if integer exceeds i/u32 limit
				b = createtypedbuffer(table.find(typelookup, "f64")::number, 8)
				buffer.writef64(b, 1, value)

			else
				--- float
				if integer < 2^24-1 then --- f32 integer limit
					b = createtypedbuffer(table.find(typelookup, "f32")::number, 4)
					buffer.writef32(b, 1, value)

				else
					b = createtypedbuffer(table.find(typelookup, "f64")::number, 8)
					buffer.writef64(b, 1, value)

				end
			end
		else
			b = createtypedbuffer(table.find(typelookup, "f64")::number, 8)
			buffer.writef64(b, 1, value)

		end

	elseif typeof(value) == "Vector2" then
		local vec = {}
		for _, value in ipairs{value.X, value.Y} do
			local thisb = Network.pack(value, instances)
			table.insert(vec, thisb)
		end

		local size = 0
		for _, thisb in vec do
			size += buffer.len(thisb)
		end

		local vecbuffer = buffer.create(size)
		local offset = 0
		for _, thisb in ipairs(vec) do
			buffer.copy(vecbuffer, offset, thisb, 0, buffer.len(thisb))
			offset += buffer.len(thisb)
		end

		b = createtypedbuffer(i, buffer.len(vecbuffer))
		buffer.copy(b, 1, vecbuffer)

	elseif typeof(value) == "Vector3" then
		local vec = {}
		for _, value in ipairs{value.X, value.Y, value.Z} do
			local thisb = Network.pack(value, instances)
			table.insert(vec, thisb)
		end

		local size = 0
		for _, thisb in vec do
			size += buffer.len(thisb)
		end

		local vecbuffer = buffer.create(size)
		local offset = 0
		for _, thisb in ipairs(vec) do
			buffer.copy(vecbuffer, offset, thisb, 0)
			offset += buffer.len(thisb)
		end

		b = createtypedbuffer(i, buffer.len(vecbuffer))
		buffer.copy(b, 1, vecbuffer)

	elseif typeof(value) == "CFrame" then
		local vec = {}
		for _, value in ipairs{value.X, value.Y, value.Z} do
			local thisb = Network.pack(value, instances)
			table.insert(vec, thisb)
		end

		local size = 0
		for _, thisb in vec do
			size += buffer.len(thisb)
		end

		local vecbuffer = buffer.create(size)
		local offset = 0
		for _, thisb in ipairs(vec) do
			buffer.copy(vecbuffer, offset, thisb)
			offset += buffer.len(thisb)
		end

		local rx, ry, rz = value:ToOrientation()
		local r = buffer.create(3)
		local rlen = buffer.len(r)
		buffer.writeu8(r, 0, math.map(rx, -math.pi, math.pi, 0, 255))
		buffer.writeu8(r, 1, math.map(ry, -math.pi, math.pi, 0, 255))
		buffer.writeu8(r, 2, math.map(rz, -math.pi, math.pi, 0, 255))

		local prebuffer = buffer.create(size + rlen)
		buffer.copy(prebuffer, 0, vecbuffer)
		buffer.copy(prebuffer, size, r)

		b = createtypedbuffer(i, buffer.len(prebuffer))
		buffer.copy(b, 1, prebuffer)

	elseif typeof(value) == "Color3" then
		local red = Network.pack(value.R * 255, instances)
		local rlen = buffer.len(red)
		local green = Network.pack(value.G * 255, instances)
		local glen = buffer.len(green)
		local blue = Network.pack(value.B * 255, instances)
		local blen = buffer.len(blue)

		local prebuffer = buffer.create(rlen + glen + blen)
		buffer.copy(prebuffer, 0, red)
		buffer.copy(prebuffer, rlen, green)
		buffer.copy(prebuffer, rlen + glen, blue)

		b = createtypedbuffer(i, buffer.len(prebuffer))
		buffer.copy(b, 1, prebuffer)

	end

	return b, instances
end

--- returns:
--- `value`: unpacked value, packed by `decode`, beginning at `offset`, using supplementary instance table `instances`
--- `offset`: final offset after unpacking the buffer, should equate to `buffer.len(b)`
function Network.unpack(pack: buffer, offset: number, instances: {Instance}): (any, number)
	local type = typelookup[buffer.readu8(pack, offset)]

	if type == "nil" then
		return nil, offset

	elseif type == "Instance" then
		offset += 1
		return instances[buffer.readu8(pack, offset)], offset + 1

	elseif type == "table" then
		offset += 1
		local len = buffer.readu16(pack, offset)

		offset += 2
		local result = {}
		for i = 1, len do
			local key, aoffset = Network.unpack(pack, offset, instances)
			offset = aoffset
			local value, boffset = Network.unpack(pack, offset, instances)
			offset = boffset 

			result[key] = value
		end

		return result, offset

	elseif type == "buffer" then
		offset += 1
		local len = buffer.readu16(pack, offset)
		local thisbuffer = buffer.create(len)

		offset += 2
		buffer.copy(thisbuffer, 0, pack, offset, len)

		return thisbuffer, offset + len

	elseif type == "string" then
		offset += 1
		local len = buffer.readu8(pack, offset)

		offset += 1
		return buffer.readstring(pack, offset, len), offset + len

	elseif type == "boolean" then
		offset += 1
		return buffer.readu8(pack, offset) == 1, offset + 1

	elseif type == "number" then
		--- last case

	elseif type == "Vector2" then
		local position = table.create(2)
		for i = 1, 2 do
			offset += 1
			local value, nextoffset = Network.unpack(pack, offset, instances)
			offset = nextoffset - 1
			table.insert(position, value)
		end

		return Vector2.new(position[1], position[2]), offset + 1

	elseif type == "Vector3" then
		local position = table.create(3)
		for i = 1, 3 do
			offset += 1
			local value, nextoffset = Network.unpack(pack, offset, instances)
			offset = nextoffset - 1
			table.insert(position, value)
		end

		return Vector3.new(position[1], position[2], position[3]), offset + 1

	elseif type == "CFrame" then
		local position = table.create(3)
		for i = 1, 3 do
			offset += 1
			local value, nextoffset = Network.unpack(pack, offset, instances)
			offset = nextoffset - 1
			table.insert(position, value)
		end

		local rotation = table.create(3)
		for i = 1, 3 do
			offset += 1
			table.insert(rotation, math.map(buffer.readu8(pack, offset), 0, 255, -math.pi, math.pi))
		end

		return CFrame.new(position[1], position[2], position[3]) * CFrame.fromOrientation(rotation[1], rotation[2], rotation[3]), offset + 1

	elseif type == "Color3" then
		local color = table.create(3)
		for i = 1, 3 do
			offset += 1
			local value, nextoffset = Network.unpack(pack, offset, instances)
			offset = nextoffset - 1
			table.insert(color, value)
		end

		return Color3.fromRGB(color[1], color[2], color[3]), offset + 1

	elseif type == "f32" then
		offset += 1
		return buffer.readf32(pack, offset), offset + 4

	elseif type == "f64" then
		offset += 1
		return buffer.readf64(pack, offset), offset + 8

	else
		--- true number case
		for _, uintentry in uintlookup do
			if uintentry.key == type then

				offset += 1
				return uintentry.read(pack, offset), offset + uintentry.size
			end
		end
		for _, intentry in intlookup do
			if intentry.key == type then

				offset += 1
				return intentry.read(pack, offset), offset + intentry.size
			end
		end
	end

	return nil, offset
end

--- returns hooked-function table `<H>` \
--- functions are deferred
function Network.hook(name: string)
	if not Hooks[name] then
		Hooks[name] = {
			functions = {};
			onces = {};
			yields = {};
		}
		local hook = Hooks[name]

		--- recursively resumes yielded threads
		local function resume(...: any)
			local co = table.remove(hook.yields)
			if co then
				task.defer(co, ...)
				resume(...)
			else
				return
			end
		end

		--- recursively removes-then-defers functions bound by signal.once()
		local function onces(...: any)
			local f = table.remove(hook.onces)
			if f then
				task.defer(f, ...)
				onces(...)
			else
				return
			end
		end

		--- connects function to this signal
		hook.connect = function(f: (...any) -> ())
			table.insert(hook.functions, f)

			return function()
				table.remove(hook.functions, table.find(hook.functions, f) or 0)
			end
		end
		--- connects function to this signal to be fired once
		hook.once = function(f: (...any) -> ())
			table.insert(hook.onces, f)

			return function()
				table.remove(hook.onces, table.find(hook.onces, f) or 0)
			end
		end
		--- yields thread until this signal is fired
		hook.wait = function()
			table.insert(hook.yields, coroutine.running())

			return coroutine.yield()
		end
		--- calls functions bound to this signal along with any arguments passed
		hook.fire = function(...: any)
			for _, f in hook.functions do
				task.defer(f, ...)
			end
			
			onces(...)
			resume(...)
		end
		--- disconnects all functions bound to this signal
		hook.disconnectall = function()
			table.clear(hook.functions)
			table.clear(hook.onces)
		end
		--- destroys this signal, resuming any yielded threads prior to destruction
		hook.destroy = function(...: any)
			resume(...)

			table.clear(hook.functions)
			table.clear(hook.onces)
			
			table.clear(hook)
			Hooks[name] = nil
		end
	end

	return Hooks[name]
end

if IsServer then
	local function flush(queue: {any})
		local entry = table.remove(queue, 1)
		if entry then
			local scoped = entry[1]
			local instances = entry[2]
			local client = entry[3]
			local force = entry[4]

			local remote
			if force == "Reliable" then
				remote = RemoteEvent
			elseif force == "Unreliable" then
				remote = UnreliableRemoteEvent
			else
				remote = resolveremote(scoped, instances)	
			end
			
			if type(client) == "nil" then --- fire all
				remote:FireAllClients(scoped, instances)
			elseif type(client) == "number" then --- fire by userid
				local player = Players:GetPlayerByUserId(client)
				if player then
					remote:FireClient(player, scoped, instances)
				end
			elseif typeof(client) == "Instance" then --- fire by player
				assert(client:IsA("Player"), string.format("expected instance player, got %s %s", client.ClassName, client.Name))
				remote:FireClient(client, scoped, instances)
			elseif type(client) == "table" then --- fire by list of userids or players
				for _, a in client do
					if typeof(a) == "Instance" then
						remote:FireClient(a, scoped, instances)
					elseif typeof(a) == "number" then
						local player = Players:GetPlayerByUserId(a)
						if player then
							remote:FireClient(player, scoped, instances)
						end
					else
						warn("value dropped for client", typeof(a), a, "expected instance player or number userid")
					end
				end
			elseif type(client) == "function" then --- fire by case
				for _, a in Players:GetPlayers() do
					if client(a) == true then
						remote:FireClient(a, scoped, instances)
					end
				end
			else
				warn(string.format("(value dropped) error solving client: type(%s) typeof(%s)", type(client), typeof(client)), client, client)
			end

			flush(queue)
		else
			return
		end
	end

	local recent = os.clock() - Network.Framerate
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		local dt = now - recent
		if dt > Network.Framerate then
			recent = now - (dt - Network.Framerate)

			flush(Network.Queue)
		end
	end)
else
	local function flush(queue: {any})
		local entry = table.remove(Network.Queue, 1)
		if entry then
			local scoped = entry[1]
			local instances = entry[2]
			local force = entry[4]

			local remote
			if force == "Reliable" then
				remote = RemoteEvent
			elseif force == "Unreliable" then
				remote = UnreliableRemoteEvent
			else
				remote = resolveremote(scoped, instances)	
			end

			remote:FireServer(scoped, instances)

			flush(queue)
		else
			return
		end
	end

	local recent = os.clock() - Network.Framerate
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		local dt = now - recent
		if dt > Network.Framerate then
			recent = now - (dt - Network.Framerate)

			flush(Network.Queue)
		end
	end)

	script.AttributeChanged:Connect(function(scope: string)
		local i = script:GetAttribute(scope)
		assert(type(i) == "number")
		Network.Scopes[i] = scope
	end)
	for scope, i in script:GetAttributes() do
		assert(type(i) == "number")
		Network.Scopes[i] = scope
	end
end

return Network