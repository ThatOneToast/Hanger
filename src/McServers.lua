local server = {}

local lfs = require("lfs")
local ltn12 = require("ltn12")
local json = require("dkjson")
local http = require("socket.http")
local rcon = require("Rcon")


local function server_storage(modify_type, server_name, new_data)

    if modify_type == "new" then
        local file = io.open("servers.json", "a")

        if not file then
            print("Failed to open file.")
            return
        end

        file:write(server_name .. " " .. new_data .. "\n")
        file:close()

    end

    if modify_type == "delete" then
        local file = io.open("servers.json", "r")

        if not file then
            print("Failed to open file.")
            return
        end

        local data = file:read("*a")
        file:close()

        local new_data1 = string.gsub(data, server_name, "")
        local file1 = io.open("servers.json", "w")

        if not file1 then
            print("Failed to open file.")
            return
        end

        file1:write(new_data1)
        file1:close()
    end
end


function server.open_connection(server_ip, rcon_port, rcon_password, save_server, server_name)

    local connection = rcon.establish_tcp_connection(server_ip, rcon_port)

    if connection then
        print("Connection has been a success!")
        if save_server then
            local data = server_ip .. "\n" .. rcon_port .. "\n" .. rcon_password
            local json_object = json.encode(data)
            server_storage("new", server_name, json_object)
        end
    end

end


return server
