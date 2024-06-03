local argparse = require("argparse")
local socket = require("socket")
local serpent = require("serpent")
local data = require("Service/MinecraftFiles")
local lfs = require("lfs")
local json = require("dkjson")
local service = require("Service/Service")

local file_manager = data.file_manager
local minecraft = data.minecraft

local function host_ipv4()
    local udp = socket.udp()
    udp:setpeername("1.1.1.1", 80)
    local ip = udp:getsockname()
    udp:close()
    return ip
end

local dameaon_client = host_ipv4()



local function send_service_instructions(instructions)
    local daemon_client, err = socket.connect(dameaon_client, 5000)
    if not daemon_client then
        error("Failed to connect to daemon: " .. err)
    end

    local packet = serpent.dump(instructions)
    local send_success, send_err = daemon_client:send(packet .. "\n")
    if not send_success then
        daemon_client:close()
        error("Failed to send packet: " .. send_err)
    end

    local response, receive_err = daemon_client:receive()

    if receive_err then
        error("Failed to receive response: " .. receive_err)
    end

    daemon_client:close()  -- Ensure the connection is closed

    return response
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
        port = server.port,
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

local function new_connection(server_name)
    local server_data = get_server_from_storage(server_name)

    local pattern = {cmd = "new_connection", host = server_data.ip, port = server_data.rcon_port}

    local response, err = send_service_instructions(pattern)

    if not response then
        print("Error Occured: " .. err)
    else
        print(response)
    end
end

local function close_connection(server_name)
    local server_data = get_server_from_storage(server_name)
    local pattern = {cmd = "close_connection", host = server_data.ip, port = server_data.rcon_port}
    send_service_instructions(pattern)
end




local parser = argparse("hanger", "A CLI tool to manage all of your Minecraft Servers")

local dameaon_parser = parser:command("daemon", "Start the daemon.")
dameaon_parser:flag("--start", "Start the daemon.")
dameaon_parser:flag("--stop", "Stop the daemon.")
dameaon_parser:option("--connect", "Connect to the daemon."):default(host_ipv4())

local help_parser = parser:command("help", "Shows a list and individual help menus.")
help_parser:argument("CommandName", "Get a help menu from the provided command name.")

local register_parser = parser:command("register", "Register a new Minecraft server.")
register_parser:argument("ServerName", "Name of the server to register")
register_parser:argument("ServerIP", "IP of the server to register")
register_parser:argument("ServerPort", "Port of the server to register")
register_parser:argument("RconPort", "Rcon port of the server to register")
register_parser:argument("RconPassword", "Rcon password of the server to register")

local connect_parser = parser:command("connect", "Open a connection to the server.")
connect_parser:argument("ServerName", "Name of the server to connect to")

local disconnect_parser = parser:command("disconnect", "Shuts down the servers RCON connection.")
disconnect_parser:argument("ServerName", "Name of the server to disconnect from")

local create_parser = parser:command("create", "Create local or remote servers.")
create_parser:argument("ServerName", "The server name to create.")
create_parser:argument("Version", "The server version to create.")
create_parser:argument("ServerIP", "The server IP to create.")
create_parser:argument("ServerPort", "The server port to create.")
create_parser:argument("RconPort", "The server rcon port to create.")
create_parser:argument("RconPassword", "The server rcon password to create.")
create_parser:option("--rcon-broadcast", "Broadcast commands to oped players."):default(true)

local delete_parser = parser:command("delete", "Delete a server.")
delete_parser:argument("ServerName", "The server name to delete.")

local manager_parser = parser:command("manage", "Manage a server.")
manager_parser:argument("ServerName", "Name of the server to manage.")

manager_parser:flag("--start", "Start the server.")
manager_parser:flag("--stop", "Stop the server.")
manager_parser:flag("--status", "Get the status of the server.")

manager_parser:option("--custom", "send your own command to the server.")

manager_parser:option("--min-ram", "The minimum amount of RAM the server will use."):default("1G")
manager_parser:option("--max-ram", "The maximum amount of RAM the server will use."):default("2G")


local args = parser:parse()


if args.daemon then
    if args.start then
        service.Start_Service()
    end

    if args.stop then
        local response = send_service_instructions({cmd = "shutdown"})
        if response then
            print("Server has been shut down.")
        else
            print("Failed to shutdown server.")
        end
    end

    if args.connect then
        dameaon_client = args.connect
        -- Try a ping to see if the daemon is running
        local ping_command = {cmd = "ping"}
        local response = send_service_instructions(ping_command)
        if response then
            print("Daemon is running and connected.")
        else
            print("Daemon is not running.")
        end
    end
end

if args.register then
    local server = {
        name = args.ServerName,
        ip = args.ServerIP,
        port = tonumber(args.ServerPort),
        rcon_port = tonumber(args.RconPort),
        rcon_password = args.RconPassword
    }
    add_to_server_storage(server)
end


if args.connect then
    new_connection(args.ServerName)
end

if args.disconnect then
    close_connection(args.ServerName)
end

if args.create then
    local server = {
        name = args.ServerName,
        ip = args.ServerIP,
        port = tonumber(args.ServerPort),
        rcon_port = tonumber(args.RconPort),
        rcon_password = args.RconPassword
    }
    add_to_server_storage(server)

    file_manager.new_server(args.ServerName, args.Version, args.ServerIP, args.ServerPort, args.RconPort, args.RconPassword, args.rcon_broadcast)
end

if args.delete then
    file_manager.delete_server(args.ServerName)
end

if args.manage then
    local server_data = get_server_from_storage(args.ServerName)

    if args.start then
        minecraft.start_server(args.ServerName, args.min_ram, args.max_ram)
    end

    if args.stop then
        minecraft.stop_server(server_data, send_service_instructions)
    end

    if args.custom then
        local command = args.custom
        local pattern = {
            cmd = "rcon_command", 
            host = server_data.ip, 
            port = server_data.rcon_port, 
            password = server_data.rcon_password, 
            command = command
        }
        local response = send_service_instructions(pattern)
        if response then
            print("Command sent to server. Response: " .. response)
        else
            print("Command failed to send. Response: " .. response)
        end

    end

    if args.status then
        local ping_command = {
            cmd = "rcon_command",
            host = server_data.ip,
            port = server_data.rcon_port,
            password = server_data.rcon_password,
            command = "say ping"
        }

        local response = send_service_instructions(ping_command)
        if response then
            print("Server is online.")
        else
            print("Server is offline.")
        end
    end



end