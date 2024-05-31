local argparse = require("argparse")
local socket = require("socket")
local serpent = require("serpent")
local patterns = require("Patterns")
local lfs = require("lfs")
local json = require("dkjson")

local function send_service_instructions(instructions)
    local daemon_client = assert(socket.connect("127.0.0.1", 5000))
    local packet = serpent.dump(instructions)
    daemon_client:send(packet .. "\n")
    local response, err = daemon_client:receive()
    if not err then
        return response
    end
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

local parser = argparse("hanger", "A CLI tool to manage all of your Minecraft Servers")

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


local args = parser:parse()

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
    local server_data = get_server_from_storage(args.ServerName)
    local new_connect_pattern = patterns["new_connection"]
    new_connect_pattern.host = server_data.ip
    new_connect_pattern.port = server_data.port
    new_connect_pattern.rcon_port = server_data.rcon_port
    new_connect_pattern.rcon_password = server_data.rcon_password
    local response, err = send_service_instructions(new_connect_pattern)

    if not response then
        print("Error Occured: " .. err)
    else
        print(response)
    end
end

if args.disconnect then
    local server_data = get_server_from_storage(args.ServerName)
    local new_close_connection_pattern = patterns["disconnect"]
    new_close_connection_pattern.host = server_data.ip
    new_close_connection_pattern.rcon_port = server_data.rcon_port
    send_service_instructions(new_close_connection_pattern)
end
