#!/bin/bash

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if Lua is installed
if ! command_exists lua; then
    echo "Lua is not installed. Attempting to install Lua..."
    if command_exists apt-get; then
        sudo apt-get update
        sudo apt-get install -y lua5.3
    elif command_exists brew; then
        brew install lua
    else
        echo "Please install Lua manually."
        exit 1
    fi
fi

# Install necessary dependencies
# Add any other dependencies that Hanger.lua might need here
if ! command_exists git; then
    echo "Git is not installed. Attempting to install Git..."
    if command_exists apt-get; then
        sudo apt-get update
        sudo apt-get install -y git
    elif command_exists brew; then
        brew install git
    else
        echo "Please install Git manually."
        exit 1
    fi
fi

# Clone the repository to the user's home directory
cd ~
if [ -d "Hanger" ]; then
  echo "The directory ~/Hanger already exists. Please remove it or choose another directory."
  exit 1
fi

git clone https://github.com/ToastArgumentative/Hanger.git

# Create the global bash script
cat << 'EOF' > /usr/local/bin/hanger
#!/bin/bash
lua ~/Hanger/src/Hanger.lua "$@"
EOF

# Make the script executable
chmod +x /usr/local/bin/hanger

echo "Hanger has been installed successfully. You can now use the 'hanger' command from anywhere."
