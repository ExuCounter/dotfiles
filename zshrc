#!/usr/bin/env bash

export ASDF_DIR=$HOME/.asdf/
export FZF_DEFAULT_COMMAND='ag --hidden --ignore node_modules -g ""'
export FZF_CTRL_T_COMMAND=$FZF_DEFAULT_COMMAND
export FZF_HIGHLIGHT_PREVIEW_OPTS="--height 100% --preview '(highlight -O ansi -l {} 2> /dev/null || cat {} || tree -C {}) 2> /dev/null' --preview-window=up:40%"
export FZF_DEFAULT_OPTS="--height 80% --color=bg+:#eee8d5,fg+:-1,gutter:-1"
export FZF_CTRL_T_OPTS="--delimiter '/' --nth=-1 $FZF_HIGHLIGHT_PREVIEW_OPTS"
export BAT_THEME="Solarized (light)"

export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="geoffgarside"
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=12'

plugins=(git zsh-autosuggestions web-search dirhistory)

source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

source $ZSH/oh-my-zsh.sh

export HISTFILE=$HOME/Desktop/projects/own/dotfiles/.zsh_history
export PATH=/opt/homebrew/bin:$PATH
export DIRENV_LOG_FORMAT=
export EDITOR=nvim
export VISUAL="$EDITOR"
export CPPFLAGS="-I/opt/homebrew/opt/openjdk/include -I/opt/homebrew/opt/unixodbc/include"
export LDFLAGS="-L/opt/homebrew/opt/unixodbc/lib"
export ASDF_HASHICORP_OVERWRITE_ARCH="amd64"
export KERL_CONFIGURE_OPTIONS="
      --enable-darwin-64bit \
      --with-odbc=/opt/homebrew/opt/unixodbc \
      --without-javac \
      "
export KERL_BUILD_DOCS=yes
export KERL_INSTALL_HTMLDOCS=no
export KERL_INSTALL_MANPAGES=no

export LUA_PATH=~/nvim/lua/?.lua


eval "$(direnv hook zsh)"
source $HOME/.zshenv

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

source $HOME/scripts/functions.sh

. $HOME/.asdf/asdf.sh
. "$HOME/.cargo/env"
