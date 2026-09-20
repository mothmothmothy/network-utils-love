local rpc = require("rpc")

local net_id_counter = 1
local net_id_to_object = {}

local blueprint = {}
blueprint.__index = blueprint

function blueprint:add_field(typ, name, default_value)
	table.insert(self.types, typ)
	table.insert(self.name, name)
	table.insert(self.default_fields, default_value)
	return self
end

function blueprint:complete(receiver, is_host, host)
	local class = {}
	class.__index = class
	class._name_to_index = {}
	class._index_to_name = self.name
	for index, name in pairs(self.name) do
		class._name_to_index[name] = index
	end
	local class_rpc
	local rpc_types = { "int", "int" }
	for _, typ in pairs(self.types) do
		table.insert(rpc_types, typ)
	end
	print("rpc type structure:")
	for _, typ in pairs(rpc_types) do
		print(typ)
	end
	print("end")
	if not is_host then
		class_rpc = rpc.new_rpc(receiver, rpc_types, nil, host, function(net_id, net_id_counter, ...)
			local arguments = { ... }
			local new_arguments = { net_id, -1 }
			if net_id_counter ~= -1 then
				new_arguments[2] = net_id_counter
			end
			for index, name in pairs(class._index_to_name) do
				table.insert(new_arguments, arguments[index])
			end
			local object = net_id_to_object[net_id]
			if object then
				for index, name in pairs(class._index_to_name) do
					object[name] = arguments[index]
				end
				print("synced existing object:", net_id)
			else
				object = class.new(unpack(new_arguments))
				print("synced a new object:", net_id)
				class.on_new_object(object)
			end
		end)
	else
		class_rpc = rpc.new_rpc(receiver, rpc_types, nil, host, function(...) end)
	end
	class.sync = function(self, peer)
		assert(is_host, "cant do sync on client")
		local params
		if peer then
			params = { peer, self.net_id, net_id_counter }
		else
			params = { self.net_id, net_id_counter }
		end
		for index, name in pairs(class._index_to_name) do
			table.insert(params, self[name])
		end
		print("bullshit start")
		for _, p in pairs(params) do
			print(p)
		end
		print("bullshit end")
		class_rpc(unpack(params))
	end
	-- to be called on the server, or by the sync rpc for the client
	class.new = function(new_net_id, new_net_id_counter, ...)
		local new_object = {}
		setmetatable(new_object, class)
		for index, field in pairs({ ... }) do
			print(index, field)
			new_object[class._index_to_name[index]] = field
		end
		if new_net_id_counter ~= -1 and new_net_id_counter ~= nil then
			new_object.net_id = new_net_id
			net_id_counter = new_net_id_counter
		else
			new_object.net_id = net_id_counter
			net_id_counter = net_id_counter + 1
		end
		net_id_to_object[new_object.net_id] = new_object
		return new_object
	end
	-- override this
	class.on_new_object = function(self) end
	return class
end

local module = {}
-- this function must be called in the same order on every side, since recognising an rpc is based on the order in which they are created
function module.new_net_blueprint()
	-- new rpc is made for synchronising changes
	-- new blueprint is made, this acts like a macro
	local object = {}
	object.types = {}
	object.default_fields = {}
	object.name = {}
	setmetatable(object, blueprint)
	return object
end
function module.get_net_id_table()
	return net_id_to_object
end
return module
