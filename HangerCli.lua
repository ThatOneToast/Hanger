
local argparse = require("argparse")
local lfs = require("lfs")
local http = require("socket.http")
local json = require("dkjson")
local ltn12 = require("ltn12")



local function create_server_folder(server_name)
    local home_dir = os.getenv("HOME") or os.getenv("USERPROFILE") -- for windows compatibility
    local hanger_dir = home_dir .. "/.Hanger"
    local server_dir = hanger_dir .. "/" .. server_name

    -- Create the base directory if it doesn't exist
    if not lfs.attributes(hanger_dir) then
        print("Created a source folder in your home directory.")
        lfs.mkdir(hanger_dir)
    end

    -- Create the server-specific directory
    if not lfs.attributes(server_dir) then
        print("Creating server directory for:", server_name)
        lfs.mkdir(server_dir)
    else
        print("Server directory already exists:", server_name)
    end

    return server_dir
end


local function get_paper_url(version)
    local paper_builds_url = "https://papermc.io/api/v2/projects/paper"
    local response_body = {}

    local res, code, headers, status = http.request {
        url = paper_builds_url,
        sink = ltn12.sink.table(response_body)
    }

    if code ~= 200 then
        error("Failed to fetch PaperMC builds: " .. (status or code))
    end

    local paper_builds_json = table.concat(response_body)
    local paper_builds_table = json.decode(paper_builds_json)

    -- Use the specified version or the latest if none is provided
    local selected_version = version or paper_builds_table.versions[#paper_builds_table.versions]
    local builds_url = paper_builds_url .. "/versions/" .. selected_version

    response_body = {}
    res, code, headers, status = http.request {
        url = builds_url,
        sink = ltn12.sink.table(response_body)
    }

    if code ~= 200 then
        error("Failed to fetch builds for version " .. selected_version .. ": " .. (status or code))
    end

    local builds_json = table.concat(response_body)
    local builds_table = json.decode(builds_json)
    local latest_build = builds_table.builds[#builds_table.builds]

    local jar_url = builds_url .. "/builds/" .. latest_build .. "/downloads/paper-" .. selected_version .. "-" .. latest_build .. ".jar"

    return jar_url
end

local function download_paper_jar(jar_url, server_dir)
    local jar_file = server_dir .. "/paper.jar"
    local file = io.open(jar_file, "wb")

    local res, code, headers, status = http.request {
        url = jar_url,
        sink = ltn12.sink.file(file)
    }

    if code ~= 200 then
        error("Failed to download PaperMC jar: " .. (status or code))
    end

    print("Downloaded PaperMC jar to:", jar_file)
end

local function get_server_home(server_name)
    local home_dir = os.getenv("HOME") or os.getenv("USERPROFILE") -- for windows compatibility
    local hanger_dir = home_dir .. "/.Hanger"
    local server_dir = hanger_dir .. "/" .. server_name

    if not lfs.attributes(server_dir) then
        error("Server directory does not exist:", server_name)
    end

    return server_dir
end

local function create_eula_file(server_dir)
    local eula_file = server_dir .. "/eula.txt"
    if not lfs.attributes(eula_file) then
        local file = io.open(eula_file, "w")
        if not file then
            error("Failed to create eula.txt file." )
        end
        file:write("eula=true\n")
        file:close()
        print("Created eula.txt file and accepted the EULA.")
    else
        print("eula.txt already exists.")
    end
end

local function create_server_properties(server_dir)
    local rcon_password = "!Umm$uper$ecurePa$$word%verHereLmfa%"
    local properties_file = server_dir .. "/server.properties"
    local file = io.open(properties_file, "w")
    if not file then
        error("Failed to create server.properties file.")
    end
    file:write("allow-flight=false\n")
    file:write("allow-nether=true\n")
    file:write("broadcast-console-to-ops=true\n")
    file:write("broadcast-rcon-to-ops=true\n")
    file:write("debug=false\n")
    file:write("difficulty=easy\n")
    file:write("enable-command-block=true\n")
    file:write("enable-jmx-monitoring=false\n")
    file:write("enable-query=false\n")
    file:write("enable-rcon=true\n") -- Enabling RCON
    file:write("enable-status=true\n")
    file:write("enforce-secure-profile=false\n")
    file:write("enforce-whitelist=false\n")
    file:write("entity-broadcast-range-percentage=100\n")
    file:write("force-gamemode=false\n")
    file:write("function-permission-level=2\n")
    file:write("gamemode=survival\n")
    file:write("generate-structures=true\n")
    file:write("generator-settings={}\n")
    file:write("hardcore=false\n")
    file:write("hide-online-players=false\n")
    file:write("initial-disabled-packs=\n")
    file:write("initial-enabled-packs=vanilla\n")
    file:write("level-name=world\n")
    file:write("level-seed=\n")
    file:write("level-type=minecraft:normal\n")
    file:write("log-ips=true\n")
    file:write("max-chained-neighbor-updates=1000000\n")
    file:write("max-players=20\n")
    file:write("max-tick-time=60000\n")
    file:write("max-world-size=29999984\n")
    file:write("motd=A Minecraft Server\n")
    file:write("network-compression-threshold=256\n")
    file:write("online-mode=false\n")
    file:write("op-permission-level=4\n")
    file:write("player-idle-timeout=0\n")
    file:write("prevent-proxy-connections=false\n")
    file:write("pvp=true\n")
    file:write("query.port=25565\n")
    file:write("rate-limit=0\n")
    file:write("rcon.password=" .. rcon_password .. "\n")
    file:write("rcon.port=25575\n")
    file:write("require-resource-pack=false\n")
    file:write("resource-pack=\n")
    file:write("resource-pack-id=\n")
    file:write("resource-pack-prompt=\n")
    file:write("resource-pack-sha1=\n")
    file:write("server-ip=\n")
    file:write("server-port=25565\n")
    file:write("simulation-distance=10\n")
    file:write("spawn-animals=true\n")
    file:write("spawn-monsters=true\n")
    file:write("spawn-npcs=true\n")
    file:write("spawn-protection=16\n")
    file:write("sync-chunk-writes=true\n")
    file:write("text-filtering-config=\n")
    file:write("use-native-transport=true\n")
    file:write("view-distance=10\n")
    file:write("white-list=false\n")
    file:close()
    print("Updated server.properties with server settings.")
end

local function start_server(server_dir, min_ram, max_ram, run_in_background)
    local jar_file = server_dir .. "/paper.jar"
    local pid_file = server_dir .. "/server.pid"
    -- The command starts the server in the background and stores the PID in pid_file.
    local command = "cd '" .. server_dir .. "' && java -Xms" .. min_ram .. " -Xmx" .. max_ram .. " -jar " .. jar_file .. " nogui > /dev/null 2>&1 & echo $! > " .. pid_file
    os.execute(command)

    -- Give the system a moment to write the PID to the file
    os.execute("sleep 1")  -- This is often necessary to wait for the file to be written in some environments

    -- Read the PID from the file
    local pid
    local file = io.open(pid_file, "r")
    if file then
        pid = file:read("*all")  -- Read the entire contents, which should be the PID
        file:close()
        print("Server started in background. With a PID of:", pid)
    else
        print("Failed to retrieve PID. Check if server started correctly.")
    end
end

local function stop_server(server_dir)
    local pid_file = server_dir .. "/server.pid"
    local file = io.open(pid_file, "r")
    if file then
        local pid = file:read("*a")
        file:close()
        local command = "kill " .. pid
        os.execute(command)
        print("Server stopped. PID:", pid)
    else
        print("PID file not found. Cannot stop server.")
    end
end

local function add_plugin_to_server(server_dir, plugin_path)
    local plugins_dir = server_dir .. "/plugins"
    if not lfs.attributes(plugins_dir, "mode") then
        lfs.mkdir(plugins_dir)  -- Create the plugins directory if it does not exist
    end

    local plugin_name = plugin_path:match("([^/\\]+)$")  -- Extract the file name from the path
    local destination_path = plugins_dir .. "/" .. plugin_name

    -- Move the file using os.rename
    local success, err = os.rename(plugin_path, destination_path)
    if not success then
        error("Failed to move plugin file: " .. err)
    end

    print("Plugin moved successfully to:", destination_path)
end

local function remove_plugin_from_server(server_dir, plugin_name)
    local plugins_dir = server_dir .. "/plugins"
    local plugin_found = false

    -- List all files in the plugins directory
    for file in lfs.dir(plugins_dir) do
        if file:match(plugin_name) then  -- Check if the plugin name is contained in the filename
            local plugin_path = plugins_dir .. "/" .. file
            if lfs.attributes(plugin_path, "mode") == "file" then  -- Ensure it is a file
                os.remove(plugin_path)
                print("Plugin removed successfully:", file)
                plugin_found = true
            end
        end
    end

    if not plugin_found then
        print("Plugin not found:", plugin_name)
    end
end


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

local action_parser = parser:command("execute", "Perform an action on a server.")
action_parser:argument("serverName", "The name of the server you wish to perform an action on.")
action_parser:flag("-s --start", "Start the server.")
action_parser:flag("-S --stop", "Stop the server.")

action_parser:option("-MR --max-ram", "Set the maximum amount of RAM the server can use."):default("1G")
action_parser:option("-mr --min-ram", "Set the minimum amount of RAM the server can use."):default("1G")

action_parser:flag("-nt --no-takeover", "The minecraft server won't take over your terminal, and will run in the background.")

action_parser:option("-ap --add-plugin", "Add a plugin to the servers plugin folder.")
action_parser:option("-rp --remove-plugin", "Remove a plugin from the servers plugin folder.")

local args = parser:parse()
local password = "!Umm$uper$ecurePa$$word%verHereLmfa%"

if args.execute then
    local server_name = args.serverName
    local server_dir = get_server_home(server_name)


    -- Check if there is a file called server.jar
    local jar_file = server_dir .. "/paper.jar"
    if not lfs.attributes(jar_file) then
        error("Server jar file does not exist:", server_name)
    end

    -- Check if there is a file called eula.txt
    local eula_file = server_dir .. "/eula.txt"
    if not lfs.attributes(eula_file) then
        create_eula_file(server_dir)
    end

    -- Check if there is a file called server.properties
    local properties_file = server_dir .. "/server.properties"
    if not lfs.attributes(properties_file) then
        create_server_properties(server_dir)
    end

    if args.start then
        if args.no_takeover then
            start_server(server_dir, args.max_ram, args.max_ram, true)
        else
            start_server(server_dir, args.max_ram, args.max_ram, false)
        end
    end

    if args.stop then
        stop_server(server_dir)
    end

    if args.add_plugin then
        add_plugin_to_server(server_dir, args.add_plugin)
    end

    if args.remove_plugin then
        remove_plugin_from_server(server_dir, args.remove_plugin)
    end

end


if args.create then
    local server_dir = create_server_folder(args.serverName)
    local jar_url = get_paper_url(args.version)
    download_paper_jar(jar_url, server_dir)
end
