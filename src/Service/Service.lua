package.path = package.path .. ";./?.lua"

local socket = require("socket")
local serpent = require("serpent")
local rcon = {}

local minecraft_utils = require("minecraft")
local file_manager = minecraft_utils.file_manager
local minecraft = minecraft_utils.minecraft

local lfs = require("lfs")
local json = require("dkjson")

local open_connections = {}
local running = true

local home_dir = os.getenv("HOME") or os.getenv("USERPROFILE")

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

local function remove_from_storage(server_name)
    local cwd = lfs.currentdir()
    local file_path = cwd .. "/storage.json"

    local file = io.open(file_path, "r")
    local prev_contents = file and file:read("*a") or ""
    if file then file:close() end

    local json_contents = (#prev_contents > 0) and json.decode(prev_contents) or {}
    if type(json_contents) ~= "table" then json_contents = {} end

    json_contents[server_name] = nil

    file = io.open(file_path, "w")
    if not file then
        print("Failed to open file for writing.")
        return
    end
    file:write(json.encode(json_contents, { indent = true }))
    file:close()
    print("Server has been removed from storage.")
end

local function add_to_server_storage(server)
    local cwd = lfs.currentdir()
    local file_path = cwd .. "/storage.json"

    local file = io.open(file_path, "r")
    local prev_contents = file and file:read("*a") or ""
    if file then file:close() end

    local json_contents = (#prev_contents > 0) and json.decode(prev_contents) or {}
    if type(json_contents) ~= "table" then json_contents = {} end

    json_contents[server.name] = {
        ip = server.ip,
        rcon_port = server.rcon_port,
        rcon_password = server.rcon_password
    }

    file = io.open(file_path, "w")
    if not file then
        print("Failed to open file for writing.")
        return
    end
    file:write(json.encode(json_contents, { indent = true }))
    file:close()
    print("Server has been added to storage.")
end

local function get_server_from_storage(server_name)
    local cwd = lfs.currentdir()
    local file_path = cwd .. "/storage.json"

    local file = io.open(file_path, "r")
    local prev_contents = file and file:read("*a") or ""
    if file then file:close() end

    local json_contents = (#prev_contents > 0) and json.decode(prev_contents) or {}
    if type(json_contents) ~= "table" then json_contents = {} end

    return json_contents[server_name]
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


    local action = data.Action
    local payload = data.Payload

    if action == "shutdown" then
        running = false
        return "Server has been shut down."

    elseif action == "new_mc_server" then

        file_manager.new_server(
            payload.ServerName,
            payload.Version,
            payload.ServerIP,
            payload.Port,
            payload.RconPort,
            payload.RconPassword,
            payload.RconBroadcast
        )

        local save_data = {
            name = payload.ServerName,
            ip = payload.ServerIP,
            rcon_port = payload.RconPort,
            rcon_password = payload.RconPassword,
        }

        add_to_server_storage(save_data)

        return "Server has been added to storage."

    elseif action == "delete_mc_server" then
        if not payload.name then
            return "No name provided in the payload."
        end

        local server_name = payload.name
        local server = get_server_from_storage(server_name)

        if not server then
            return "Server not found in storage."
        end

        file_manager.delete_server(server_name)
        remove_from_storage(server_name)
        

    elseif action == "start_mc_server" then
        if not payload.name then
            return "No name provided in the payload."
        end

        local server_name = payload.name
        local server = get_server_from_storage(server_name)

        if not server then
            return "Server not found in storage."
        end

        local min_ram = payload.min_ram or "1GB"
        local max_ram = payload.max_ram or "1GB"

        minecraft.start_server(server_name, min_ram, max_ram)

    elseif action == "stop_mc_server" then
        if not payload.name then
            return "No name provided in the payload."
        end

        local server_name = payload.name
        local server = get_server_from_storage(server_name)

        if not server then
            return "Server not found in storage."
        end

        local server_data = {
            ip = server.ip,
            rcon_port = server.rcon_port,
            rcon_password = server.rcon_password
        }

        minecraft.stop_server(server_data, rcon.send_command_packet)


    elseif action == "mc_command" then
        if not payload then
            return "No RCON information provided."
        end

        local server = get_server_from_storage(payload.name)

        if not server then
            return "Server not found in storage."
        end

        return rcon.send_command_packet(server.ip, server.rcon_port, server.rcon_password, payload.command)

    elseif action == "mc_status" then
        if not payload then
            return "No RCON information provided."
        end

        local server = get_server_from_storage(payload.name)

        if not server then
            return "Server not found in storage."
        end

        local success = rcon.send_command_packet(server.ip, server.rcon_port, server.rcon_password, "say ping")

        if success then
            return "Server is online."
        else
            return "Server is offline."
        end

        
    
    elseif action == "mc_add_plugin" then
        if not payload then 
            return "There is no information provided to adding a plugin."
        end

        local server = get_server_from_storage(payload.server)

        if not server then
            return "This server does not exist."
        end

        -- Get the servers plugins folder
        local plugins_dir = home_dir .. "/.Hanger/" .. payload.server .. "/plugins"
        if not lfs.attributes(plugins_dir) then
            return "This server does not have any plugins."
        end

        local plugin_dir = plugins_dir .. "/" .. payload.file_name
        if lfs.attributes(plugin_dir) then
            return "This plugin already exists."
        end

        local file = io.open(plugin_dir, "wb")
        if not file then
            return "Failed to create plugin file."
        end
        file:write(payload.file_conent)
        file:close()
        
        
    elseif action == "mc_remove_plugin" then
        if not payload then
            return "There is no information provided to removing a plugin."
        end    

        local server = get_server_from_storage(payload.name)

        if not server then
            return "This server does not exist."
        end

        minecraft.remove_plugin(payload.name, payload.plugin)

    else
        return "Unknown command: " .. action
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