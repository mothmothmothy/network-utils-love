local host
local server
local hosting
local send_stuff
local rpc
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
	send_stuff = rpc.new_rpc("peer", { "string", "int", "double" }, nil, host, function(phrase, number, double)
		print("phrase ->", phrase, "number ->", number, "double ->", double)
	end)
	if not hosting then
		server = host:connect("localhost:6789")
		print("sending")
		send_stuff(server:index(), "hello", 5, 5.32)
	end
end

function love.draw()
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
	if not hosting then
		print("sending")
		send_stuff(server:index(), "hello", 5, 5.32)
	end
end
