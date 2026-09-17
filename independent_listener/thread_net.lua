print("net thread says hi")
local host_address = ...
local enet = require"enet"
print(host_address, "< host addr")
if host_address == "" then host_address = nil end
local host = enet.host_create(host_address)
local ids = {}
local net_in = love.thread.getChannel"net_in"
local net_out = love.thread.getChannel"net_out"
while true do
    local t = net_in:pop()
    while t do
        local typ = t[1]
        if typ == "send" then
            print("sending:",t[2],t[3])
            host:get_peer(t[2]):send(t[3])
        elseif typ == "broadcast" then
            print("broadcasting:",t[2])
            host:broadcast(t[2])
        elseif typ == "connect" then
            print("connecting:",t[2])
            host:connect(t[2])
        elseif typ == "state" then
            net_out:push({"state",host:get_peer(t[2])})
        end
        t = net_in:pop()
    end
    local event = host:service()
    if event then
        print("RECEIVED:",event.type,event.peer,event.data)
        net_out:push({event.type,event.peer:index(),event.data})
    end
end
