package.path = package.path .. ';' .. debug.getinfo(1).source:match("@?(.*/)") .. '?.lua'

local argparse = require("argparse")
local socket = require("socket")
local serpent = require("serpent")
local lfs = require("lfs")
local json = require("dkjson")
local service = require("service")



local function host_ipv4()
    local udp = socket.udp()
    udp:setpeername("1.1.1.1", 80)
    local ip = udp:getsockname()
    udp:close()
    return ip
end

local function set_daemon_server(ip)
    local cwd = lfs.currentdir()
    local file_path = cwd .. "/storage.json"

    local file = io.open(file_path, "r")
    local prev_contents = file and file:read("*a") or ""
    
    if file then file:close() end

    local json_contents = (#prev_contents > 0) and json.decode(prev_contents) or {}
    if type(json_contents) ~= "table" then json_contents = {} end

    json_contents.daemon_ip = ip

    file = io.open(file_path, "w")
    if not file then
        print("Failed to open file for writing.")
        return
    end
    file:write(json.encode(json_contents, { indent = true }))
    file:close()
    print("Daemon IP has been set.")
end

local function get_daemon_server()
    local cwd = lfs.currentdir()
    local file_path = cwd .. "/storage.json"

    local file = io.open(file_path, "r")
    local prev_contents = file and file:read("*a") or ""
    if file then file:close() end

    local json_contents = (#prev_contents > 0) and json.decode(prev_contents) or {}
    if type(json_contents) ~= "table" then json_contents = {} end

    if not json_contents.daemon_ip then
        return host_ipv4()
    else
        return json_contents.daemon_ip
    end
end

local dameaon_client = get_daemon_server()


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

local function read_file(file_path)
    local file = io.open(file_path, "rb")
    if not file then
        return nil, "Failed to open file"
    end
    local conent = file:read("*all")
    file:close()
    return conent
end

local parser = argparse("hanger", "A CLI tool to manage all of your Minecraft Servers")

local dameaon_parser = parser:command("daemon", "Start the daemon.")
dameaon_parser:flag("--start", "Start the daemon.")
dameaon_parser:flag("--stop", "Stop the daemon.")
dameaon_parser:option("--connect", "Connect to the daemon."):default(host_ipv4())

local help_parser = parser:command("help", "Shows a list and individual help menus.")
help_parser:argument("CommandName", "Get a help menu from the provided command name.")

local create_parser = parser:command("create", "Create local or remote servers.")
create_parser:argument("ServerName", "The server name to create.")
create_parser:argument("Version", "The server version to create.")
create_parser:argument("ServerIP", "The server IP to create.")
create_parser:argument("ServerPort", "The server port to create.")
create_parser:argument("RconPort", "The server rcon port to create.")
create_parser:argument("RconPassword", "The server rcon password to create.")
create_parser:option("--rcon-broadcast", "Broadcast commands to oped players."):default(false)

local delete_parser = parser:command("delete", "Delete a server.")
delete_parser:argument("ServerName", "The server name to delete.")

local manager_parser = parser:command("manage", "Manage a server.")
manager_parser:argument("ServerName", "Name of the server to manage.")

manager_parser:flag("--start", "Start the server.")
manager_parser:flag("--stop", "Stop the server.")
manager_parser:flag("--status", "Get the status of the server.")
manager_parser:option("--add-plugin", "Add a plugin to the server.")
manager_parser:option("--remove-plugin", "Removes a plugin from the selected server.")

manager_parser:option("--custom", "send your own command to the server.")

manager_parser:option("--min-ram", "The minimum amount of RAM the server will use."):default("1G")
manager_parser:option("--max-ram", "The maximum amount of RAM the server will use."):default("2G")


local args = parser:parse()


if args.daemon then
    if args.start then
        service.Start_Service()
    end

    if args.stop then
        local response = send_service_instructions({Action = "shutdown"})
        if response then
            print("Server has been shut down.")
        else
            print("Failed to shutdown server.")
        end
    end

    if args.connect then
        set_daemon_server(args.connect)
    end
end



if args.create then

    local instructions = {
        Action = "new_mc_server",
        Payload = {
            ServerName = args.ServerName,
            Version = args.Version,
            ServerIP = args.ServerIP,
            ServerPort = args.ServerPort,
            RconPort = args.RconPort,
            RconPassword = args.RconPassword,
            RconBroadcast = args.rcon_broadcast
        }
        
    }

    send_service_instructions(instructions)

end

if args.delete then
    
    local instructions = {
        Action = "delete_mc_server",
        Payload = {
            name = args.ServerName
        }
    }

    send_service_instructions(instructions)
end

if args.manage then
    if args.start then
        local instructions =  {
            Action = "start_mc_server",
            Payload = {
                name = args.ServerName,
                min_ram = args.min_ram,
                max_ram = args.max_ram
            }
        }

        send_service_instructions(instructions)
    end

    if args.stop then
        local instructions = {
            Action = "stop_mc_server",
            Payload = {
                name = args.ServerName
            }
        }

        send_service_instructions(instructions)
    end

    if args.custom then
        local command = args.custom
        local instructions = {
            Action = "mc_command",
            Payload = {
                name = args.ServerName,
                command = command
            }
        }

        send_service_instructions(instructions)

    end

    if args.status then
        local instructions = {
            Action = "mc_status",
            Payload = {
                name = args.ServerName
            }
        }

        send_service_instructions(instructions)
    end

    if args.add_plugin then
        local file_path = args.add_plugin
        local instructions = {
            Action = "mc_add_plugin",
            Payload = {
                server = args.ServerName,
                file_name = file_path:match("([^/\\]+)$"),
                file_conent = read_file(file_path)
            }
        }

        send_service_instructions(instructions)
    end

    if args.remove_plugin then
        local instructions = {
            Action = "mc_remove_plugin",
            Payload = {
                name = args.ServerName,
                plugin = args.remove_plugin
            }
        }

        send_service_instructions(instructions)
    end



end