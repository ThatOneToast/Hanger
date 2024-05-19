local mc_server = {}

local lfs = require("lfs")
local ltn12 = require("ltn12")
local json = require("dkjson")
local http = require("socket.http")
local rcon = require("Rcon")


function mc_server.create_dir(server_name)
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
    lfs.rmdir(path)  -- Finally, remove the now-empty directory
end

function mc_server.get_jar_url(version)
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

function mc_server.download_jar(jar_url, server_dir)
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


function mc_server.create_eula_file(server_dir)
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

function mc_server.create_properties(server_dir, server_ip, server_port, rcon_port, rcon_password, broadcast)
    local properties_file = server_dir .. "/server.properties"
    local file = io.open(properties_file, "w")
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

    print("Updated server.properties with server settings.")
end

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

    -- Remove specified directories
    for _, dir in ipairs(directories) do
        local dir_path = server_dir .. "/" .. dir
        if lfs.attributes(dir_path, "mode") == "directory" then
            mc_server.remove_directory(dir_path)
        end
    end

    -- Removes all folders within the plugins directory.
    local plugins_dir = server_dir .. "/plugins"
    if lfs.attributes(plugins_dir, "mode") == "directory" then
        for plugin in lfs.dir(plugins_dir) do
            if plugin ~= "." and plugin ~= ".." then
                local plugin_path = plugins_dir .. "/" .. plugin
                mc_server.remove_directory(plugin_path)
            end
        end
    end

    print("Server cache cleared.")
end

function mc_server.get_server_home(server_name)
    local home_dir = os.getenv("HOME") or os.getenv("USERPROFILE") -- for windows compatibility
    local hanger_dir = home_dir .. "/.Hanger"
    local server_dir = hanger_dir .. "/" .. server_name

    if not lfs.attributes(server_dir) then
        error("Server directory does not exist:", server_name)
    end

    return server_dir
end

function mc_server.start_server(server_dir, min_ram, max_ram, run_in_background)
    local jar_file = server_dir .. "/paper.jar"
    local command = "cd '" .. server_dir .. "' && java -Xms" .. min_ram .. " -Xmx" .. max_ram .. " -jar " .. jar_file .. " nogui"

    if run_in_background then
        command = command .. " > /dev/null 2>&1 &"
    end
    os.execute(command)
end

function mc_server.stop_server(host, port, rcon_port, rcon_password)
    local success = rcon.send_command_packet(host, port, rcon_password, "stop")
    if success then
        print("Server stopped successfully.")
    else
        print("Failed to stop server.")
    end
end


function mc_server.add_plugin_to_server(server_dir, plugin_path)
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

function mc_server.remove_plugin_from_server(server_dir, plugin_name)
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
