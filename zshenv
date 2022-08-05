# vim-git checkout
fco() {
  local tags branches target
  tags=$(
    git tag | awk '{print "\x1b[31;1mtag\x1b[m\t" $1}') || return
  branches=$(
    git branch --all | grep -v HEAD             |
    sed "s/.* //"    | sed "s#remotes/[^/]*/##" |
    sort -u          | awk '{print "\x1b[34;1mbranch\x1b[m\t" $1}') || return
  target=$(
    (echo "$tags"; echo "$branches") |
    fzf-tmux -l30 -- --no-hscroll --ansi +m -d "\t" -n 2) || return
  git checkout $(echo "$target" | awk '{print $2}')
}
  
fbr() {
  local branches branch
  branches=$(git for-each-ref --count=20 --sort=-committerdate refs/heads/ --format="%(refname:short)") &&
  branch=$(echo "$branches" |
           fzf-tmux -d $(( 2 + $(wc -l <<< "$branches") )) +m) &&
  git checkout $(echo "$branch" | sed "s/.* //" | sed "s#remotes/[^/]*/##")
}

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
alias kafka='~/Downloads/kafka/bin/kafka-server-start.sh config/server.properties'
alias zookeeper='~/Downloads/kafka/bin/zookeeper-server-start.sh config/zookeeper.properties'
alias prettier='npx prettier'

# Vim aliases
alias vi="nvim"
# alias vim="nvim"
alias code="nvim"
. "$HOME/.cargo/env"
