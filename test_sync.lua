local host
local server
local hosting
local send_stuff
local rpc
local sync_net
function love.load()
	local enet = require("enet")
	rpc = require("rpc")
	hosting = false
	for i, arg in pairs(arg) do
		if arg == "--host" then
			hosting = true
		end
	end
	print("hosting:", hosting)
	if hosting then
		host = enet.host_create("localhost:6789")
	else
		host = enet.host_create()
	end

	if not hosting then
		server = host:connect("localhost:6789")
	end
	sync_net = require("sync_net")
	local crate_class = sync_net
		.new_net_blueprint()
		:add_field("string", "crate_name", "apples")
		:add_field("int", "quantity", 5)
		:complete("peers", hosting, host)
	if hosting then
		crate = crate_class.new(-1, -1, "bananas", 7)
		print(crate.fruits)
	end
end

function love.draw()
	if crate then
		crate:sync()
	else
		for a, b in pairs(sync_net.get_net_id_table()) do
			print("object:", a, b)
			print(b.crate_name)
			print(b.quantity)
		end
	end
	local event = host:service(100)
	while event do
		if event.type == "receive" then
			print("Got message: ", event.data, event.peer)
			--event.peer:send( "pong" )
			rpc.listen_rpc(event.data)
		elseif event.type == "connect" then
			print(event.peer, "connected.")
		elseif event.type == "disconnect" then
			print(event.peer, "disconnected.")
		end
		event = host:service()
	end
end
