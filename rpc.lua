-- you need to define all rpcs in the same order on the other side for now, sorry
local to_peers = "peers"
local to_self_and_peers = "self_and_peers"
local to_peer = "peer"
local to_self_and_peer = "self_and_peer"

local disable_debug = true
local print = print
if disable_debug then
	print = function(...) end
end

local ffi = require("ffi")
local encoders = {}
encoders = {
	["byte"] = {
		["typecheck"] = function(object)
			if type(object) == "string" and object:len() == 1 then
				return true
			end
			return false
		end,
		["encode"] = function(byte)
			return byte, 1 -- characters used
		end,
		["decode"] = function(str)
			return str:sub(1, 1), 1 -- characters consumed
		end,
	},
	["int"] = {
		["typecheck"] = function(object)
			if type(object) == "number" and object == math.floor(object) then
				return true
			end
			return false
		end,
		["encode"] = function(int)
			local encoded = ffi.string(ffi.new("int[?]", 1, int), 4)
			return encoded, 4
		end,
		["decode"] = function(str)
			local ptr = ffi.cast("int*", ffi.new("char[?]", 4, str))
			local t = ptr[0]
			return t, 4
		end,
	},
	["float"] = {
		["typecheck"] = function(object)
			if type(object) == "number" then
				return true
			end
			return false
		end,
		["encode"] = function(float)
			local encoded = ffi.string(ffi.new("float[?]", 1, float), 4)
			return encoded, 4
		end,
		["decode"] = function(str)
			local ptr = ffi.cast("float*", ffi.new("char[?]", 4, str))
			local t = ptr[0]
			return t, 4
		end,
	},
	["double"] = {
		["typecheck"] = function(object)
			if type(object) == "number" then
				return true
			end
			return false
		end,
		["encode"] = function(double)
			local encoded = ffi.string(ffi.new("double[?]", 1, double), 8)
			return encoded, 8
		end,
		["decode"] = function(str)
			local ptr = ffi.cast("double*", ffi.new("char[?]", 8, str))
			local t = ptr[0]
			return t, 8
		end,
	},
	["string"] = {
		["typecheck"] = function(object)
			if type(object) == "string" then
				return true
			end
			return false
		end,
		["encode"] = function(str)
			local encoded_length = encoders.int.encode(str:len())
			return encoded_length .. str
		end,
		["decode"] = function(str)
			local length = str:sub(1, 4)
			length = encoders.int.decode(length)
			return str:sub(5, 4 + length), 4 + length
		end,
	},
}

local rpcs = {}

function rpc_peer(host, peer_index, this_id, param_types, flag, ...)
	local args = { ... }
	local peer = host:get_peer(peer_index)
	local msg = encoders["int"].encode(this_id)
	for i, param in pairs(param_types) do
		local encoder = encoders[param]
		if encoder then
			msg = msg .. encoder.encode(args[i])
		else
			error("no encoder for " .. param)
		end
	end
	print("msg:", msg)
	print("peer_index:", peer_index)
	print("peer:", peer)
	peer:send(msg, nil, flag)
end

function rpc_peers(host, this_id, param_types, flag, ...)
	local args = { ... }
	local msg = encoders["int"].encode(this_id)
	for i, param in pairs(param_types) do
		local encoder = encoders[param]
		if encoder then
			print("encoding:", args[i], "as", param)
			msg = msg .. encoder.encode(args[i])
		else
			error("no encoder for " .. param)
		end
	end
	print("end of encoding")
	host:broadcast(msg, nil, flag)
end
local module = {}

module.sender = nil

function add_rpc(rpc_func, func, types)
	table.insert(rpcs, {
		["rpc"] = rpc_func,
		["func"] = func,
		["types"] = types,
	})
end

local ids = {}

function module.new_rpc(receiver, param_types, flag, host, func)
	if receiver == to_self_and_peer then
		local this_id = #rpcs + 1
		local rpc_func = function(peer_index, ...)
			func(...)
			peer_index = peer_index or 1
			rpc_peer(host, peer_index, this_id, param_types, flag, ...)
		end
		add_rpc(rpc_func, func, param_types)
		return rpc_func
	elseif receiver == to_self_and_peers then
		local this_id = #rpcs + 1
		local rpc_func = function(...)
			func(...)
			rpc_peers(host, this_id, param_types, flag, ...)
		end
		add_rpc(rpc_func, func, param_types)
		return rpc_func
	elseif receiver == to_peer then
		print("to_peer")
		local this_id = #rpcs + 1
		local rpc_func = function(peer_index, ...)
			peer_index = peer_index or 1
			print("ble", peer_index, ...)
			rpc_peer(host, peer_index, this_id, param_types, flag, ...)
		end
		add_rpc(rpc_func, func, param_types)
		return rpc_func
	elseif receiver == to_peers then
		local this_id = #rpcs + 1
		local rpc_func = function(...)
			rpc_peers(host, this_id, param_types, flag, ...)
		end
		add_rpc(rpc_func, func, param_types)
		return rpc_func
	end
end

function module.listen_rpc(data, peer)
	local args_data = data:sub(5, -1)
	local id = encoders["int"].decode(data:sub(1, 4))
	local rpc = rpcs[id]
	local args = {}
	local buf = args_data
	print("id:", id)
	for _, arg_type in pairs(rpc.types) do
		print(arg_type)
		local encoder = encoders[arg_type]
		print(encoder)
		if not encoder then
			return
		end
		local success, decoded, consumed = pcall(encoder.decode, buf)
		if not success then
			return
		end
		table.insert(args, decoded)
		buf = buf:sub(1 + consumed, -1)
	end
	module.sender = peer
	local success, smth = pcall(rpc.func, unpack(args))
	module.sender = nil
	if not success then
		print("caught error msg from rpc:", smth)
	end
end
return module
