local argparse = require("argparse")
local rcon = require("Rcon")
local minecraft_server = require("ServerSetup")
local lfs = require("lfs")


local parser = argparse("hanger_cli", "A CLI tool to manage all of your Minecraft Servers")

local helpMessage = [[
        Hanger CLI is a tool to manage all of your Minecraft servers.
        It allows you to create, start, stop, and manage your servers with ease.

        Commands:
        - create <serverName> -v <version>
        Creates a new server with the specified name and version.
        Example: create TestServer -v 1.16.5

        - execute <serverName> [options]
        Perform actions on a specified server.

        Options for execute command:
        -s --start
        Starts the specified server.
        Example: execute TestServer -s -MR 2G -mr 1G --no-takeover

        -S --stop
        Stops the specified server.
        Example: execute TestServer -S

        -MR --max-ram <amount>
        Sets the maximum amount of RAM that the server can use.
        Default: 1G
        Example: execute TestServer -s -MR 2G

        -mr --min-ram <amount>
        Sets the minimum amount of RAM that the server can use.
        Default: 1G
        Example: execute TestServer -s -mr 1G

        -nt --no-takeover
        Ensures the Minecraft server runs in the background and does not take over the terminal.
        Example: execute TestServer -s -nt

        -ap --add-plugin <pluginPath>
        Adds a plugin to the server's plugin folder.
        Example: execute TestServer --add-plugin TeleportPads.jar

        -rp --remove-plugin <pluginName>
        Removes a plugin from the server's plugin folder based on its filename.
        Example: execute TestServer --remove-plugin TeleportPads.jar

        -h --help
        Displays this help message.
]]

parser:flag("-h --help", "Prints the help message."):action(function() print(helpMessage) end)

local create_parser = parser:command("create", "Start the server creation wizzard.")
create_parser:argument("serverName", "The name of the server you wish to create.")
create_parser:option("-v --version", "The version of the server you wish to create.")

local delete_parser = parser:command("delete", "Delete a server.")
delete_parser:argument("serverName", "The name of the server you wish to delete.")


-- Starting execution pipeline on serverName
local execute_parser = parser:command("execute", "Perform an action on a server.")
execute_parser:argument("serverName", "The name of the server you wish to perform an action on.")

-- Server starting arguments
execute_parser:flag("-s --start", "Start the server.")
execute_parser:flag("-S --stop", "Stop the server.")
execute_parser:option("--max-ram", "Set the maximum amount of RAM the server can use."):default("1G")
execute_parser:option("--min-ram", "Set the minimum amount of RAM the server can use."):default("1G")
execute_parser:flag("--no-takeover", "The minecraft server won't take over your terminal, and will run in the background.")

-- Modify the server
execute_parser:option("--add-plugin", "Add a plugin to the servers plugin folder.")
execute_parser:option("--remove-plugin", "Remove a plugin from the servers plugin folder.")
execute_parser:flag("--clear-cache", "Clears the entire servers cache.")

-- Run server Commands
execute_parser:option("--say", "Broadcast a message to the server.")
    :args("1")
    :description("Send a message within quotes to the server.")

local args = parser:parse()

local password = "!Umm$uper$ecurePa$$word%verHereLmfa%"

if args.execute then
    local server_name = args.serverName
    local server_dir = minecraft_server.get_server_home(server_name)


    -- Check if there is a file called server.jar
    local jar_file = server_dir .. "/paper.jar"
    if not lfs.attributes(jar_file) then
        error("Server jar file does not exist:", server_name)
    end

    -- Check if there is a file called eula.txt
    local eula_file = server_dir .. "/eula.txt"
    if not lfs.attributes(eula_file) then
        minecraft_server.create_eula_file(server_dir)
    end

    -- Check if there is a file called server.properties
    local properties_file = server_dir .. "/server.properties"
    if not lfs.attributes(properties_file) then
        minecraft_server.create_server_properties(server_dir, "0.0.0.0", 25565, 25575, password, true)
    end

    if args.start then
        if args.no_takeover then
            minecraft_server.start_server(server_dir, args.max_ram, args.max_ram, true)
        else
            minecraft_server.start_server(server_dir, args.max_ram, args.max_ram, false)
        end
    end

    if args.stop then
        minecraft_server.stop_server(password)
    end

    if args.add_plugin then
        minecraft_server.add_plugin_to_server(server_dir, args.add_plugin)
    end

    if args.remove_plugin then
        minecraft_server.remove_plugin_from_server(server_dir, args.remove_plugin)
    end

    if args.clear_cache then
        minecraft_server.clear_server_cache(server_dir)
    end

    if args.say then
        local message = args.say
        rcon.send_command_packet("locahost", 25575, password, "say " .. message)
    end
end


if args.create then
    local server_dir = minecraft_server.create_server_folder(args.serverName)
    local jar_url = minecraft_server.get_paper_url(args.version)
    minecraft_server.download_paper_jar(jar_url, server_dir)
end

if args.delete then
    local server_dir = minecraft_server.get_server_home(args.serverName)
    minecraft_server.remove_directory(server_dir)
    print("Deleted server " .. args.serverName)
end
