-- Define a table to encapsulate RCON functionality
local rcon = {}
local socket = require("socket")  -- Load the LuaSocket library for TCP socket operations

--- Creates an RCON packet for sending commands or authentication.
-- @param id The packet ID, used for matching requests with responses.
-- @param cmd_type The type of command (3 for auth, 2 for command).
-- @param body The actual command or password to send.
-- @return A binary string representing the RCON packet.
function rcon.create_packet(id, cmd_type, body)
    local body_with_null = body .. "\0\0"
    local total_length = 4 + 4 + #body_with_null
    local packet = string.pack("<i4i4i4c" .. #body_with_null, total_length, id, cmd_type, body_with_null)
    return packet
end

function rcon.establish_tcp_connection(server_addr, server_port)
    local tcp = assert(socket.tcp())

    local status, err = tcp:connect(server_addr, server_port)
    if not status then
        print("Failed to connect:", err)
        return false
    else
        print("Connection successful!")
        return tcp
    end
end

function rcon.shutdown_tcp_connection(tcp)
    if tcp then
        tcp:close()
        print("Connection closed successfully.")
    end
end


-- Save connection data to a file
local function save_connection_data(server_id, data)
    local file = io.open(server_id .. ".txt", "w")
    if file then
        file:write(data)
        file:close()
    end
end

-- Load connection data from a file
local function load_connection_data(server_id)
    local file = io.open(server_id .. ".txt", "r")
    if file then
        local data = file:read("*a")
        file:close()
        return data
    end
    return nil
end

--- Sends an RCON command to a server and handles the connection and authentication.
-- @param host The IP address or hostname of the RCON server.
-- @param port The port on which the RCON server is listening.
-- @param password The RCON password for authentication.
-- @param command The command to execute on the server.
-- @return true if the command was successfully sent and a response received, false otherwise.
function rcon.send_command_packet(host, port, password, command)
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
    local auth_packet = rcon.create_packet(1, 3, password)  -- Packet type 3 for authentication
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
    print("Authenticated successfully!")

    -- Send command packet
    local command_packet = rcon.create_packet(2, 2, command)  -- Packet type 2 for commands
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

return rcon
