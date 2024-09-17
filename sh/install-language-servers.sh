#!/bin/bash

global_node_modules=(dockerfile-language-server-nodejs @tailwindcss/language-server vscode-langservers-extracted @microsoft/compose-language-service sql-language-server typescript typescript-language-server)

brew_packages=(lua-language-server elixir-ls)

for node_module in ${global_node_modules[*]}
do
  npm install -g $node_module
done

for package in ${brew_packages[*]}
do
  brew install $package
done
