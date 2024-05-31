
local socket = require("socket")
local serpent = require("serpent")
local rcon = require("Rcon")

local open_connections = {}
local running = true

local function new_connection(host, port)
    local tcp = assert(socket.tcp())
    local status, err = tcp:connect(host, port)

    if not status then
        return "Failed to connect: " .. err
    end

    local key = host .. ":" .. port
    open_connections[key] = tcp
    return "Connection opened: " .. key
end

local function shutdown_connection(host, port)
    local key = host .. ":" .. port
    local tcp = open_connections[key]

    if tcp then
        tcp:close()
        open_connections[key] = nil
        print("Connection closed successfully.")
    else
        return "No active connection to close for: " .. key
    end
end

local function send_packet(host, port, data)
    local key = host .. ":" .. port
    local tcp = open_connections[key]

    if not tcp then
        local response = new_connection(host, port)
        if response:match("Failed to connect") then
            return response
        end
        tcp = open_connections[key]
    end

    if tcp then
        tcp:send(data)
        local response, err = tcp:receive("*l")

        if response then
            return "Received response: " .. response
        else
            return "Failed to receive response: " .. err
        end
    end

    return "Unable to send packet."
end

local function handle_incomming_packet(packet)
    local success, data = serpent.load(packet)

    if not success then
        return "Failed to deserialize packet."
    end


    local cmd = data.command
    local host = data.host
    local port = data.port
    local payload = data.payload

    -- Rcon Properties
    local password = data.password
    local command = data.mc_command

    if cmd == "new_connection" then
        return new_connection(host, port)
    elseif cmd == "send" then
        return send_packet(host, port, payload)
    elseif cmd == "ping" then
        return "Pong!"
    elseif cmd == "close_connection" then
        return shutdown_connection(host, port)
    elseif cmd == "shutdown" then
        for key, tcp in pairs(open_connections) do
            tcp:close()
            open_connections[key] = nil
        end
        running = false
        return "Server shutting down. All connections closed."
    elseif cmd == "rcon_command" then

        return rcon.send_command_packet(host, port, password, command)
    else
        return "Unknown command: " .. cmd
    end

end

function Start_Service()
    local server = assert(socket.bind("127.0.0.1", 5000))
    local ip, port = server:getsockname()
    print("Server listening on " .. ip .. ":" .. port)

    while running do
        local client = server:accept()
        client:settimeout(2)
        local packet, err = client:receive()

        if not err then
            local response = handle_incomming_packet(packet)
            client:send(response .. "\n")
        else
            client:send("Error receiving packet: " .. err .. "\n")
        end

        client:close()
    end

    server:close()
    print("Server has been shut down.")
end

Start_Service()
