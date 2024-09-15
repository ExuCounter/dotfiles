#!/usr/bin/env bash

# Git aliases
alias gco='git checkout'
alias gs='git status'
alias gst="git stash"
alias ga='git add'
alias gb='git branch'
alias gcm='git commit -m'
alias gd='git diff'
alias gpl='git pull origin $(git rev-parse --abbrev-ref HEAD)'
alias gp='git push origin'
alias gpf='git push origin -f'
alias grs='git reset --soft'
alias grh='git reset --hard'
alias gl='git log --graph --pretty=format:"%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset" --abbrev-commit'
alias chrome='open -a "Google Chrome"'
alias prettier='npx prettier'
alias gfa='git fetch --all --prune --jobs=10'

# Vim aliases
alias vi="nvim"
alias code="nvim"

ZSH_THEME="geoffgarside"
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=12'

plugins=(git web-search dirhistory asdf)

export ASDF_DIR=$HOME/.asdf/
# export CARGO_DIR=$HOME/.cargo/
export ZSH_DIR=$HOME/.oh-my-zsh/

# export DIRENV_LOG_FORMAT=
export EDITOR=nvim
export VISUAL="$EDITOR"

export LUA_PATH=~/nvim/lua/?.lua
export PATH=/opt/homebrew/opt/postgresql@15/bin:$HOME/.config/bin:/opt/homebrew/bin:$HOME/.iex-history:$HOME/elixir_ls:$HOME/bin:$PATH

eval "$(direnv hook zsh)"

source $ZSH_DIR/oh-my-zsh.sh
source $ASDF_DIR/asdf.sh
# source $CARGO_DIR/env

for file in $HOME/.config/zsh/*; do
  [ -f $file ] && source "$file"
done

setopt share_history

alias kitty=~/.local/kitty.app/bin/kitty
source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

export DD_REMOTE_CONFIGURATION_ENABLED=true
