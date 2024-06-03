local file_manager = {}
local server_manager = {}


local lfs = require("lfs")
local ltn12 = require("ltn12")
local json = require("dkjson")
local http = require("socket.http")

local home_dir = os.getenv("HOME") or os.getenv("USERPROFILE")

local function create_server_home(server_name)
    local hanger_dir = home_dir .. "/.Hanger"
    local server_dir = hanger_dir .. "/" .. server_name

    if not lfs.attributes(hanger_dir) then
        print("Created a source folder in your home directory.")
        lfs.mkdir(hanger_dir)
    end

    if not lfs.attributes(server_dir) then
        print("Creating server directory for: " .. server_name)
        lfs.mkdir(server_dir)
    else
        print("Server directory already exists: " .. server_name )
    end

    return server_dir
end

local function fetch_jar_link(version)
    local paper_build_url = "https://papermc.io/api/v2/projects/paper"
    local response_body = {}

    local res, code, headers, status = http.request {
        url = paper_build_url,
        sink = ltn12.sink.table(response_body)
    }

    if code ~= 200 then
        error("Failed to fetch PaperMC builds: " .. (status or code) )
    end

    local builds_json = table.concat(response_body)
    local builds_table = json.decode(builds_json)
    local goooGoooGaaaGaaaVersion = version or builds_table.versions(#builds_table.versions)
    local url = paper_build_url .. "/versions/" .. goooGoooGaaaGaaaVersion

    response_body = {}
    res, code, headers, status = http.request {
        url = url,
        sink = ltn12.sink.table(response_body)
    }

    if code ~= 200 then
        error("Failed to fetch PaperMC builds: " .. (status or code) )
    end

    builds_json = table.concat(response_body)
    builds_table = json.decode(builds_json)
    local latest_build = builds_table.builds[#builds_table.builds]
    local jar_url = url .. "/builds/" .. latest_build .. "/downloads/paper-" .. version .. "-" .. latest_build .. ".jar"

    return jar_url

end

local function download_jar(url, dir)
    local file = dir .. "/paper.jar"
    file = io.open(file, "wb")

    if not file then
        error("Failed to create PaperMC far file.")
    end

    local res, code, headers, status = http.request {
        url = url,
        sink = ltn12.sink.file(file)
    }

    if code ~= 200 then
        error("Failed to download jar: " .. (status or code) )
    end


end

local function take_my_soul(dir)
    local eula = dir .. "/eula.txt"

    -- Check if the EULA file exists
    if lfs.attributes(eula) then
        print("EULA already accepted.")
        return true
    end


    print("Accept the EULA ?!? y/n (default: y)")

    local function create_and_accept()
        local file = io.open(eula, "w")
        if not file then
            error("Failed to create eula.txt file.")
        end
        file:write("eula=true\n")
        file:close()
    end

    local choosing = true
    while choosing do
        local answer = io.read()
        if answer == "y" or answer == "" then  -- Default to 'y' if the user just presses Enter
            print("EULA accepted.")
            create_and_accept()
            choosing = false
            return true
        elseif answer == "n" then
            print("EULA not accepted. Exiting.")
            choosing = false
            return false
        else
            print("Invalid input. Please enter 'y' or 'n'.")
        end
    end
end

local function create_server_properties(dir, server_ip, server_port, rcon_port, rcon_password, broadcast_rcon_to_ops)
    local properties_file_path = dir .. "/server.properties"
    local file, err = io.open(properties_file_path, "w")

    if not file then
        error("Failed to create server.properties file: " .. err)
    end

    -- Accumulate properties in a string
    local properties_content = string.format([[
        server-ip=%s
        server-port=%s
        rcon.port=%s
        rcon.password=%s
        broadcast-rcon-to-ops=%s
        allow-flight=false
        allow-nether=true
        broadcast-console-to-ops=false
        debug=false
        difficulty=normal
        enable-command-block=true
        enable-jmx-monitoring=false
        enable-query=false
        enable-rcon=true
        enable-status=true
        enforce-secure-profile=false
        enforce-whitelist=false
        entity-broadcast-range-percentage=100
        force-gamemode=false
        function-permission-level=2
        gamemode=survival
        generate-structures=true
        generator-settings={}
        hardcore=false
        hide-online-players=false
        initial-disabled-packs=
        initial-enabled-packs=vanilla
        level-name=world
        level-seed=
        level-type=minecraft:normal
        log-ips=true
        max-chained-neighbor-updates=1000000
        max-players=20
        max-tick-time=60000
        max-world-size=29999984
        motd=A Minecraft Server
        network-compression-threshold=256
        online-mode=false
        op-permission-level=4
        player-idle-timeout=0
        prevent-proxy-connections=false
        pvp=true
        query.port=25565
        rate-limit=0
        require-resource-pack=false
        resource-pack=
        resource-pack-id=
        resource-pack-prompt=
        resource-pack-sha1=
        simulation-distance=10
        spawn-animals=true
        spawn-monsters=true
        spawn-npcs=true
        spawn-protection=16
        sync-chunk-writes=true
        text-filtering-config=
        use-native-transport=true
        view-distance=10
        white-list=false
    ]], server_ip, server_port, rcon_port, rcon_password, tostring(broadcast_rcon_to_ops))

    -- Write the entire content in one go
    file:write(properties_content)
    file:close()

    print("Server properties file created at: " .. properties_file_path)
end

local function remove_directory(path)
    for entry in lfs.dir(path) do
        if entry ~= "." and entry ~= ".." then
            local entry_path = path .. '/' .. entry
            local mode = lfs.attributes(entry_path, "mode")
            if mode == "directory" then
                remove_directory(entry_path)  -- Recursive call to remove subdirectories
            end
            os.remove(entry_path)  -- Remove the file or directory
        end
    end
    lfs.rmdir(path)  -- Remove the now-empty directory
end


function file_manager.new_server(server_name, version, ip, port, rcon_port, rcon_password, rcon_broadcast)

    local server_dir = create_server_home(server_name)
    download_jar(fetch_jar_link(version), server_dir)
    take_my_soul(server_dir)
    create_server_properties(server_dir, ip, port, rcon_port, rcon_password, rcon_broadcast)

end


function file_manager.delete_server(server_name)
    local server_path = home_dir .. "/.Hanger/" .. server_name

    if not lfs.attributes(server_path) then
        error("Server directory does not exist: " .. server_name)
    end

    print("Deleting server: " .. server_name)
    remove_directory(server_path)
    print("Server " .. server_name .. " deleted successfully.")
end

function file_manager.delete_world(server_name, world)
    local server_path = home_dir .. "/.Hanger/" .. server_name
    local world_path = server_path .. "/" .. world

    if not lfs.attributes(server_path) then
        error("This server does not exists.")
    end

    if not lfs.attributes(world_path) then
        error("This world does not exists.")
    end

    remove_directory(world_path)
    print("Remove the world " .. world)
end

function file_manager.clear_caches(server_name)
    local server_path = home_dir .. "/.Hanger/" .. server_name

    if not lfs.attributes(server_path) then
        error("This server does not exists.")
    end

    local dirs = {
        "Cache",
        "Libraries",
        "config"
    }

    for _, dir in ipairs(dirs) do
        local path = server_path .. "/" .. dir
        if lfs.attributes(path, "mode") == "directory" then
            remove_directory(path)
        end
    end

    -- Clear all content within the plugins directory
    local plugins_dir = server_path .. "/plugins"
    if lfs.attributes(plugins_dir, "mode") == "directory" then
        for plugin in lfs.dir(plugins_dir) do
            if plugin ~= "." and plugin ~= ".." then
                local plugin_path = plugins_dir .. "/" .. plugin
                remove_directory(plugin_path)
            end
        end
    end

end





function server_manager.start_server(server_name, min_ram, max_ram)
    local server_dir = home_dir .. "/.Hanger/" .. server_name
    local jar_file = server_dir .. "/paper.jar"
    local command = "cd '" .. server_dir .. "' && java -Xms" .. min_ram .. " -Xmx" .. max_ram .. " -jar " .. jar_file .. " nogui"
    --command = command .. " > /dev/null 2>&1 &" -- run command in the background.

    os.execute(command)
end

function server_manager.stop_server(server_data, send_service_instructions)

    local close_tcp = {cmd = "close_connection", host = server_data.ip, port = server_data.rcon_port}
    local server_stop = {
        cmd = "rcon_command", 
        host = server_data.ip, 
        port = server_data.rcon_port, 
        password = server_data.rcon_password, 
        command = "stop"
    }

    local success = send_service_instructions(server_stop)

    if success then
        success = send_service_instructions(close_tcp)
        if not success then
            error("Failed to stop server.")
        else
            print("Server has been stopped.")
        end
    else
        error("Failed to stop server.")
    end

end

function server_manager.add_plugin(server_name, plugin)
    local server_dir = home_dir .. "/.Hanger/" .. server_name
    local plugin_dir = server_dir .. "/plugins"

    if not lfs.attributes(server_dir) then
        error("Server does not exist.")
    end

    if not lfs.attributes(plugin_dir) then
        error("Plugins folder does not exist.")
    end

    local plugin_name = plugin:match("([^/\\]+)$")
    local destination = plugin_dir .. "/" .. plugin_name

    local success, err = os.rename(plugin_dir, destination)

    if not success then
        error("Failed to move the plugin " .. err)
    end

    print("Plugin moved successfully")
end

function server_manager.remove_plugin(server_name, plugin)
    local server_dir = home_dir .. "/.Hanger/" .. server_name
    local plugins = server_dir .. "/plugins"
    local found = false


    for file in lfs.dir(plugins) do
        if file:match(plugin) then
            local plugin_path = plugins .. "/" .. file
            if lfs.attributes(plugin_path, "mode") == "file" then
                os.remove(plugin_path)
                print("Plugin removed!")
                found = true
            end
        end
    end

    if not found then
        print("Couldn't find the plugin.")
    end
end

local data = {
    file_manager = file_manager,
    minecraft = server_manager
}

return data
