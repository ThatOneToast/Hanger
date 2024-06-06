#!/bin/bash

# Clone the repository and navigate to the source directory
cd ~ 
git clone https://github.com/ToastArgumentative/Hanger.git
cd Hanger 
cd src 

# If on macOS
if [ "$(uname)" == "Darwin" ]; then
  brew install lua
  brew install luarocks

  echo 'export PATH=$PATH:~/Hanger/src' >> ~/.bashrc
  source ~/.bashrc

  echo 'export PATH=$PATH:~/Hanger/src' >> ~/.zshrc
  source ~/.zshrc
fi    

# If on Linux
if [ "$(uname)" == "Linux" ]; then
  sudo apt-get install lua5.3
  sudo apt-get install luarocks

  echo 'export PATH=$PATH:~/Hanger/src' >> ~/.bashrc
  source ~/.bashrc
fi

# Install dependencies
lua InstallDepends.lua



# Ensure ~/bin directory exists
mkdir -p "$HOME/bin" || exit 1