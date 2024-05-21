# Hanger CLI

Hanger CLI is a powerful Lua-based command-line interface for managing Minecraft servers efficiently and effectively. It simplifies server management by allowing you to create, start, stop, and manage multiple Minecraft servers with just a few commands.

## Features

- **Create and Delete Servers**: Easily set up new Minecraft servers and remove them when they're no longer needed.
- **Start and Stop Servers**: Control your Minecraft server's operational status with simple commands.
- **Manage Server Resources**: Specify the maximum and minimum RAM usage for your servers.
- **Background Operation**: Run servers in the background, ensuring they don't interfere with terminal usage.
- **Plugin Management**: Add or remove plugins from your server's plugins folder on the fly.
- **Server Communication**: Send broadcast messages directly to your server using RCON.
- **Cache Management**: Clear your server's cache to ensure smooth operations.

## Commands

- `create <serverName> -v <version>`: Creates a new server instance with the specified name and Minecraft version.
- `delete <serverName>`: Deletes the specified server instance.
- `execute <serverName>`: Executes specified actions such as starting, stopping, and managing server properties.

### Examples

- **Creating a Server**: `hanger_cli create MyServer -v 1.16.5`
- **Starting a Server**: `hanger_cli execute MyServer --start --max-ram 2G --min-ram 1G --no-takeover`
- **Stopping a Server**: `hanger_cli execute MyServer --stop`
- **Adding a Plugin**: `hanger_cli execute MyServer --add-plugin AwesomePlugin.jar`
- **Removing a Plugin**: `hanger_cli execute MyServer --remove-plugin AwesomePlugin.jar`
- **Broadcasting a Message**: `hanger_cli execute MyServer --say "Hello, World!"`

## Current Limitations

- **Single Connection**: Currently, the CLI supports managing only one connection to a server at a time. Efforts are underway to enable support for managing multiple servers concurrently.

## Getting Started

To get started with Hanger CLI, clone this repository to your local machine and ensure you have Lua and required modules installed. Follow the setup instructions to configure your environment.

## Contribution

Contributions are welcome! If you have suggestions or improvements, please fork the repository and submit a pull request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
