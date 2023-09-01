#!/usr/bin/env sh

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
