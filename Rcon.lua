local rcon = {}
local socket = require("socket")

function rcon.create_packet(id, cmd_type, body)
    -- First, create the body of the packet, which includes the body text followed by two null bytes
    local body_with_null = body .. "\0\0"

    -- Calculate the total length of the packet (not including the length field itself)
    local total_length = 4 + 4 + #body_with_null  -- Length of id, type, and body including the null terminator

    -- Pack the length, id, type, and the body into a binary string
    local packet = string.pack("<I4I4I4c" .. #body_with_null, total_length, id, cmd_type, body_with_null)

    return packet
end

function rcon.send_command_packet(host, port, password, command)
    local tcp = assert(socket.tcp())
    tcp:settimeout(5)

    local status, err = tcp:connect(host, port)
    if not status then
        print("Failed to connect:", err)
        return false
    end

    -- Authenticate
    local auth_packet = rcon.create_packet(1, 3, password)
    tcp:send(auth_packet)
    local auth_response, auth_err = tcp:receive("*a")

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
    print("Authenticated-Successfully!")

    local command_packet = rcon.create_packet(2, 2, command)
    tcp:send(command_packet)
    local response, command_err = tcp:recieve("*a")

    if not response then
        print("Failed to receive command return:", command_err)
        tcp:close()
        return false
    end

    tcp:close()
    return true

end
