
local socket = require("socket")
local serpent = require("serpent")
local rcon = {}

local open_connections = {}
local running = true


--- Sends an RCON command to a server and handles the connection and authentication.
-- @param host The IP address or hostname of the RCON server.
-- @param port The port on which the RCON server is listening.
-- @param password The RCON password for authentication.
-- @param command The command to execute on the server.
-- @return true if the command was successfully sent and a response received, false otherwise.
function rcon.send_command_packet(host, port, password, command)

    local function create_packet(id, cmd_type, body)
        local body_with_null = body .. "\0\0"
        local total_length = 4 + 4 + #body_with_null
        local packet = string.pack("<i4i4i4c" .. #body_with_null, total_length, id, cmd_type, body_with_null)
        return packet
    end


    -- Create a new TCP socket and set a timeout of 5 seconds
    local tcp = assert(socket.tcp())
    tcp:settimeout(5)

    -- Attempt to connect to the server
    local status, err = tcp:connect(host, port)
    if not status then
        print("Failed to connect:", err)
        return false
    end

    -- Send authentication packet
    local auth_packet = create_packet(1, 3, password)  -- Packet type 3 for authentication
    local sent, authPacketSendError = tcp:send(auth_packet)
    if not sent then
        print("Fail;ed to send authentication packet: ", authPacketSendError)
        tcp:close()
        return false
    end

    -- Check authentication response
    local auth_response, auth_err = tcp:receive(4)  -- Receive the full response
    if auth_response == -1 then
        print("Failed to authenticate:", auth_err)
        tcp:close()
        return false
    end

    if not auth_response then
        print("Failed to authenticate:", auth_err)
        tcp:close()
        return false
    end
    print("Authenticated " .. host .. ":" .. port .. " successfully")

    -- Send command packet
    local command_packet = create_packet(2, 2, command)  -- Packet type 2 for commands
    local command_sent, command_send_err = tcp:send(command_packet)
    if not command_sent then
        print("Failed to send command packet:", command_send_err)
        tcp:close()
        return false
    end

    -- Check command response
    local response, command_recieve_err = tcp:receive(4)  -- Receive the full response
    if not response then
        print("Failed to receive command return:", command_recieve_err)
        tcp:close()
        return false
    end

    tcp:close()
    return true
end

local function new_connection(host, port)
    local tcp = assert(socket.tcp())
    local status, err = tcp:connect(host, port)

    if not status then
        return "Failed to connect: " .. err
    end

    local key = host .. ":" .. port
    open_connections[key] = tcp

    print(" New connection opened: " .. key)

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


    local cmd = data.cmd
    local host = data.host
    local port = data.port
    local payload = data.payload

    -- Rcon Properties
    local password = data.password
    local command = data.command

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

local function host_ipv4()
    local udp = socket.udp()
    udp:setpeername("1.1.1.1", 80)
    local ip = udp:getsockname()
    udp:close()
    return ip
end

local service = {}

function service.Start_Service()
    local server = assert(socket.bind(host_ipv4(), 5000))
    local ip, port = server:getsockname()
    print("Server listening on " .. ip .. ":" .. port)

    while running do
        local client = server:accept()

        if client then
            local client_ip, port = client:getsockname()
            print("Client connected from " .. client_ip .. ":" .. port)
            client:settimeout(2)
        end

        local packet, err = client:receive()

        if not err then
            local response = handle_incomming_packet(packet)
            client:send(tostring(response) .. "\n")
        else
            client:send("Error receiving packet: " .. err .. "\n")
        end

        client:close()
    end

    server:close()
    print("Server has been shut down.")
end

return service