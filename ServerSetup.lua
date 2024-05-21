-- Main module table to encapsulate all functions
local mc_server = {}

-- Required Lua libraries
local lfs = require("lfs")
local ltn12 = require("ltn12")
local json = require("dkjson")
local http = require("socket.http")
local rcon = require("Rcon")

--- Creates a directory for storing Minecraft server files.
-- @param server_name The name of the server directory to create.
-- @return String Path to the server directory.
function mc_server.create_dir(server_name)
    local home_dir = os.getenv("HOME") or os.getenv("USERPROFILE") -- Ensures compatibility with Windows and Unix
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

--- Recursively removes a directory and all its contents.
-- @param path The path to the directory to be removed.
function mc_server.remove_directory(path)
    for entry in lfs.dir(path) do
        if entry ~= "." and entry ~= ".." then
            local entry_path = path .. '/' .. entry
            local mode = lfs.attributes(entry_path, "mode")
            if mode == "directory" then
                mc_server.remove_directory(entry_path)  -- Recursive call to remove subdirectories
            end
            os.remove(entry_path)  -- Remove the file or directory
        end
    end
    lfs.rmdir(path)  -- Remove the now-empty directory
end

--- Fetches the download URL for a specific version of PaperMC.
-- @param version The Minecraft version for which to get the download URL. If nil, fetches the latest version.
-- @return String URL to the PaperMC .jar file for the specified version.
function mc_server.get_jar_url(version)
    local paper_builds_url = "https://papermc.io/api/v2/projects/paper"
    local response_body = {}

    -- Fetch project information
    local res, code, headers, status = http.request {
        url = paper_builds_url,
        sink = ltn12.sink.table(response_body)
    }

    if code ~= 200 then
        error("Failed to fetch PaperMC builds: " .. (status or code))
    end

    -- Parse the response to find the correct build
    local paper_builds_json = table.concat(response_body)
    local paper_builds_table = json.decode(paper_builds_json)
    local selected_version = version or paper_builds_table.versions[#paper_builds_table.versions]
    local builds_url = paper_builds_url .. "/versions/" .. selected_version

    -- Fetch builds for the specified version
    response_body = {}
    res, code, headers, status = http.request {
        url = builds_url,
        sink = ltn12.sink.table(response_body)
    }

    if code ~= 200 then
        error("Failed to fetch builds for version " .. selected_version .. ": " .. (status or code))
    end

    -- Find the latest build and construct the download URL
    local builds_json = table.concat(response_body)
    local builds_table = json.decode(builds_json)
    local latest_build = builds_table.builds[#builds_table.builds]
    local jar_url = builds_url .. "/builds/" .. latest_build .. "/downloads/paper-" .. selected_version .. "-" .. latest_build .. ".jar"

    return jar_url
end

--- Downloads the PaperMC jar file to a specified server directory.
-- @param jar_url URL from which to download the PaperMC jar.
-- @param server_dir Directory where the jar will be saved.
function mc_server.download_jar(jar_url, server_dir)
    local jar_file = server_dir .. "/paper.jar"
    local file = io.open(jar_file, "wb")

    if not file then
        error("Failed to create PaperMC jar file.")
    end

    -- Download the file using HTTP GET
    local res, code, headers, status = http.request {
        url = jar_url,
        sink = ltn12.sink.file(file)
    }

    if code ~= 200 then
        error("Failed to download PaperMC jar: " .. (status or code))
    end


    print("Downloaded PaperMC jar to:", jar_file)
end

--- Ensures the creation of the eula.txt file, setting the server's EULA status to true if it does not exist.
-- @param server_dir The directory where the eula.txt should be located.
function mc_server.create_eula_file(server_dir)
    local eula_file = server_dir .. "/eula.txt"
    -- Check if the EULA file already exists
    if not lfs.attributes(eula_file) then
        local file = io.open(eula_file, "w")
        -- Validate the file was opened successfully
        if not file then
            error("Failed to create eula.txt file.")
        end
        -- Set EULA to true
        file:write("eula=true\n")
        file:close()
        print("EULA file created and accepted.")
    else
        print("EULA file already exists.")
    end
end

--- Configures and writes server settings to the server.properties file based on specified parameters.
-- @param server_dir Directory where the server.properties file will be created.
-- @param server_ip IP address that the server should bind to.
-- @param server_port Port number on which the Minecraft server will run.
-- @param rcon_port Port number for RCON.
-- @param rcon_password Password for RCON.
-- @param broadcast Whether to broadcast console messages to ops.
function mc_server.create_properties(server_dir, server_ip, server_port, rcon_port, rcon_password, broadcast)
    local properties_file = server_dir .. "/server.properties"
    local file = io.open(properties_file, "w")
    -- Ensure the file was created successfully
    if not file then
        error("Failed to create server.properties file.")
    end

    file:write("allow-flight=false\n")
    file:write("allow-nether=true\n")
    file:write("broadcast-console-to-ops=false\n")
    file:write("broadcast-rcon-to-ops=" .. tostring(broadcast) .. "\n")
    file:write("debug=false\n")
    file:write("difficulty=normal\n")
    file:write("enable-command-block=true\n")
    file:write("enable-jmx-monitoring=false\n")
    file:write("enable-query=false\n")
    file:write("enable-rcon=true\n")  -- Enabling RCON
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
    file:write("rcon.password=" .. tostring(rcon_password) .. "\n")
    file:write("rcon.port=" .. tonumber(rcon_port) .. "\n")
    file:write("require-resource-pack=false\n")
    file:write("resource-pack=\n")
    file:write("resource-pack-id=\n")
    file:write("resource-pack-prompt=\n")
    file:write("resource-pack-sha1=\n")
    file:write("server-ip=" .. tostring(server_ip) .. "\n")
    file:write("server-port=" .. tonumber(server_port) .. "\n")
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

    -- Initialize the server properties settings
    print("Server properties file updated with specified settings.")
end

--- Clears specified cache and temporary directories to maintain a clean server environment.
-- @param server_dir The directory from which subdirectories will be cleared.
function mc_server.clear_server_cache(server_dir)
    local directories = {
        "Cache",
        "Libraries",
        "Logs",
        "config",
        "world",
        "world_nether",
        "world_the_end"
    }

    -- Remove each directory listed in the directories array
    for _, dir in ipairs(directories) do
        local dir_path = server_dir .. "/" .. dir
        if lfs.attributes(dir_path, "mode") == "directory" then
            mc_server.remove_directory(dir_path)
        end
    end

    -- Clear all content within the plugins directory
    local plugins_dir = server_dir .. "/plugins"
    if lfs.attributes(plugins_dir, "mode") == "directory" then
        for plugin in lfs.dir(plugins_dir) do
            if plugin ~= "." and plugin ~= ".." then
                local plugin_path = plugins_dir .. "/" .. plugin
                mc_server.remove_directory(plugin_path)
            end
        end
    end

    print("Server cache and temporary files cleared.")
end

--- Retrieves the full path to the server's base directory.
-- @param server_name The name of the server to locate.
-- @return The path to the server's base directory.
function mc_server.get_server_home(server_name)
    local home_dir = os.getenv("HOME") or os.getenv("USERPROFILE") -- for windows compatibility
    local hanger_dir = home_dir .. "/.Hanger"
    local server_dir = hanger_dir .. "/" .. server_name

    -- Ensure the server directory exists
    if not lfs.attributes(server_dir) then
        error("Server directory does not exist: " .. server_name)
    end

    return server_dir
end

--- Initiates the Minecraft server process, with options for foreground or background execution.
-- @param server_dir The directory where the server executable resides.
-- @param min_ram Minimum RAM allocation for the server.
-- @param max_ram Maximum RAM allocation for the server.
-- @param run_in_background Whether to run the server in the background.
function mc_server.start_server(server_dir, min_ram, max_ram, run_in_background)
    local jar_file = server_dir .. "/paper.jar"
    local command = "cd '" .. server_dir .. "' && java -Xms" .. min_ram .. " -Xmx" .. max_ram .. " -jar " .. jar_file .. " nogui"
    -- Determine if the server should run in the background
    if run_in_background then
        command = command .. " > /dev/null 2>&1 &"
    end
    os.execute(command)
    print("Server started with the specified memory limits.")
end

--- Stops a Minecraft server using RCON.
-- @param host The host IP address of the server.
-- @param port The port number on which the server's RCON is listening.
-- @param rcon_port The port number for RCON commands.
-- @param rcon_password The password for authenticating to the RCON service.
function mc_server.stop_server(host, port, rcon_port, rcon_password)
    local success = rcon.send_command_packet(host, rcon_port, rcon_password, "stop")
    -- Check the result of the stop command and print appropriate message
    if success then
        print("Server stopped successfully.")
    else
        print("Failed to stop server.")
    end
end

--- Adds a plugin to the server by moving it to the server's plugin directory.
-- @param server_dir The directory of the server where the plugin should be added.
-- @param plugin_path The full path of the plugin file to be moved.
function mc_server.add_plugin_to_server(server_dir, plugin_path)
    local plugins_dir = server_dir .. "/plugins"
    -- Ensure the plugin directory exists; create it if it doesn't
    if not lfs.attributes(plugins_dir, "mode") then
        lfs.mkdir(plugins_dir)  -- Create the plugins directory if it does not exist
    end

    local plugin_name = plugin_path:match("([^/\\]+)$")  -- Extract the file name from the path
    local destination_path = plugins_dir .. "/" .. plugin_name

    -- Attempt to move the file to the plugin directory
    local success, err = os.rename(plugin_path, destination_path)
    if not success then
        error("Failed to move plugin file: " .. err)
    end

    print("Plugin moved successfully to:", destination_path)
end

--- Removes a plugin from the server's plugin directory.
-- @param server_dir The directory of the server from which the plugin should be removed.
-- @param plugin_name The name of the plugin file to be removed. Can be a partial name.
function mc_server.remove_plugin_from_server(server_dir, plugin_name)
    local plugins_dir = server_dir .. "/plugins"
    local plugin_found = false

    -- Iterate through all files in the plugins directory to find and remove the specified plugin
    for file in lfs.dir(plugins_dir) do
        if file:match(plugin_name) then  -- Check if the file name matches the specified plugin name
            local plugin_path = plugins_dir .. "/" .. file
            if lfs.attributes(plugin_path, "mode") == "file" then  -- Ensure it is a file before attempting to remove
                os.remove(plugin_path)
                print("Plugin removed successfully:", file)
                plugin_found = true
            end
        end
    end

    -- Notify if the plugin was not found
    if not plugin_found then
        print("Plugin not found:", plugin_name)
    end
end

return mc_server
