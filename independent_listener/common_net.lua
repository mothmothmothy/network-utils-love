local module = {}
module.host = nil
module.peers = {}
module.process_funcs = {}
module.connected = false
local net_in = love.thread.getChannel"net_in"
local net_out = love.thread.getChannel"net_out"
local encoder = require("encoder")
-- used as a placeholder till encryption is done
function module.send(peer_id,msg_cat,data)
    local thingy = encoder.builder.new():encode_string(msg_cat):encode_string(data)
    net_in:push({"send",peer_id,thingy:as_str()})
end
function module.broadcast(msg_cat,data)
    local thingy = encoder.builder.new():encode_string(msg_cat):encode_string(data)
    net_in:push({"broadcast",thingy:as_str()})
end
local thread = nil
function module.start(address)
    if thread then error("net already started") end
    local contents = love.filesystem.read("thread_net.lua")
    print(contents)
    thread = love.thread.newThread(contents)
    thread:start(address)
end
function module.stop()
    if not thread then error("no net") end
    thread:stop()
    thread = nil
end
function module.restart(address)
    if thread then module.stop() end
    module.start(address)
end
function module.connect(address)
    net_in:push({"connect",address})
end
function module.state(peer_id)
    net_in:push({"state",peer_id})
end
local reader = encoder.reader
function module.clear_receiver_funcs()
    module.process_funcs = {}
end
function module.receive()
    local popped = net_out:pop()
    local new_reader = reader.new("")
    while popped do
        if popped[1] == "receive" then
            new_reader:reuse(popped[3])
            assert(new_reader.str,"fuuck")
            local category = new_reader:read_string()
            if module.process_funcs[category] then
                module.process_funcs[category](new_reader,popped[2])
            end
        elseif popped[1] == "connect" then
            print("peer:",popped[2])
            module.on_connect(popped)
            module.connected = true
        elseif popped[1] == "disconnect" then
            module.connected = false
        end

        popped = net_out:pop()
    end
end

function module.on_connect()

end
return module