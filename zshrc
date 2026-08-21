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

# source ~/.zsh/catppuccin_mocha-zsh-syntax-highlighting.zsh

plugins=(git zsh-syntax-highlighting zsh-autosuggestions web-search dirhistory)

# export ASDF_DIR=$HOME/.asdf/
export CARGO_DIR=$HOME/.cargo/

# export DIRENV_LOG_FORMAT=
export EDITOR=zed
export VISUAL="$EDITOR"

export PKG_CONFIG_PATH="/opt/homebrew/opt/icu4c/lib/pkgconfig"
export LUA_PATH=~/nvim/lua/?.lua
export HOMEBREW_PREFIX=/opt/homebrew
export PATH=/opt/homebrew/opt/postgresql@15/bin:$HOME/.config/bin:/opt/homebrew/bin:$HOME/.iex-history:$HOME/elixir_ls:$HOME/bin:${ASDF_DATA_DIR:-$HOME/.asdf}:$HOME/.asdf/shims:$HOME/.rd/bin:$HOME/zig-macos-aarch64-0.14:$PATH

eval "$(direnv hook zsh)"

source ~/.oh-my-zsh/oh-my-zsh.sh
# source $ASDF_DIR/asdf.sh
# source $CARGO_DIR/env
source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

for file in $HOME/.config/zsh/*; do
  [ -f $file ] && source "$file"
done

setopt share_history

source <(fzf --zsh)

export PATH="/opt/homebrew/opt/postgresql@15/bin:$PATH"
alias pro_ops=/Users/volodymyr.potiichuk/Desktop/projects/prosapient/pro-ops/_build/prod/rel/bakeware/pro_ops

export AWS_PROFILE=platform-test
alias pro_ops=/Users/volodymyr.potiichuk/Desktop/projects/prosapient/pro-ops/burrito_out/pro_ops_macos
export PATH="/opt/homebrew/opt/postgresql@16/bin:$PATH"
alias pro_ops=/Users/volodymyr.potiichuk/Desktop/projects/prosapient/pro-ops/burrito_out/pro_ops_macos

function zed_tmux() {
  SESSION=$(basename "$PWD")
  tmux new-session -A -s $SESSION teamocil $SESSION
}

export HEX_CACERTS_PATH="$HOME/corp-ca.pem"
export SSL_CERT_FILE="$HOME/corp-ca.pem"
export NODE_EXTRA_CA_CERTS="$HOME/corp-ca.pem"
alias pro_ops=/Users/volodymyrpotiichuk/Desktop/projects/prosapient/pro-ops/_build/prod/rel/pro_ops/bin/pro_ops
