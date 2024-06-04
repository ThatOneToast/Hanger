# Hanger

Hanger is a powerful Lua-based command-line interface for managing Minecraft servers efficiently and effectively.
It simplifies server management allowing for quick access to commands and easy management of multiple servers under a node.

## Features

 -**Standard Server Management**: Create, start, stop, and manage multiple servers with just a few commands.
 -**Plugin Management**: Add and remove plugins from your server's plugins folder on the fly.
 -**Status Checking**: Get the status of your server and check if it's online or offline.
 **MC Commands**: Send any minecraft command to your server.

## Commands

- `daemon`:
  - `--start`: Starts the daemon service.
  - `--stop`: Stops the daemon service.
  - `--connect <ip>`: Connects to the daemon service at the specified IP.

- `create <ServerName> <Version> <ServerIP> <ServerPort> <RconPort> <RconPassword> [--rcon-broadcast]`: Creates a new server instance with the specified name and Minecraft version.
- `delete <ServerName>`: Deletes the specified server instance.

- `manage <ServerName>`:
  - `--start ( --min-ram 1G --max-ram 1G )`: Starts the specified server instance.
  - `--stop`: Stops the specified server instance.
  - `--status`: Gets the status of the specified server instance.
  - `--add-plugin <file_path>`: Adds a plugin to the specified server instance.
  - `--remove-plugin <plugin_name>`: Removes a plugin from the specified server instance.
  - `--custom <command>`: Sends a custom command to the specified server instance.

## Current Limitations

- **Single Connection**: Currently, the CLI supports managing only one connection to a server at a time. Efforts are underway to enable support for managing multiple servers concurrently.



## License

This project is licensed under the MIT License - see the LICENSE file for details.
