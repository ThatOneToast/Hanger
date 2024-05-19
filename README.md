#Hanger - V1.0.0

This CLI tool helps manage your minecraft servers. Put's them all in 1 spot, and you  can manage them all right from the command line. 

Let's create a server.

Create a server: `lua HangerCLI.lua create <serverName> <version>`
Start a server: `lua HangerCLI.lua execute <serverName> --start` -- Will start a server with a max of 1g of ram and a min of 1g.
Stop a server: `lua HangerCLI.lua execute <serverName> --stop`
Clear server cache: `lua HangerCLI.lua execute <serverName> --clear-cache` -- Will delete all of server cache folders, and all plugin data in the plugins folder.
Add a plugin to server: `lua HangerCLI.lua execute <serverName> --add-plugin <plugin>` -- Will move the plugin file to the plugins folder. 
Remove a plugin from server: `lua HangerCLI.lua execute <serverName> --remove-plugin <plugin>` -- Will delete the plugin from the folder.


As of right now executing this CLI requires the installation of Lua and Luarocks + packages. 
In the future when this comes to a more complete tool, I will compile it.

