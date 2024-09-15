# Setup fzf
# ---------
if [[ ! "$PATH" == */opt/homebrew/opt/fzf/bin* ]]; then
  export PATH="${PATH:+${PATH}:}/opt/homebrew/opt/fzf/bin"
fi

# Settings
export FZF_DEFAULT_COMMAND='ag --hidden --ignore node_modules -g ""'
export FZF_CTRL_T_COMMAND=$FZF_DEFAULT_COMMAND
export FZF_HIGHLIGHT_PREVIEW_OPTS="--height 100% --preview '(highlight -O ansi -l {} 2> /dev/null || cat {} || tree -C {}) 2> /dev/null' --preview-window=up:40%"
export FZF_DEFAULT_OPTS="--height 80% --color=bg+:#eee8d5,fg+:-1,gutter:-1"
export FZF_CTRL_T_OPTS="--delimiter '/' --nth=-1 $FZF_HIGHLIGHT_PREVIEW_OPTS"
export BAT_THEME="Solarized (light)"

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
