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

alias gco='git checkout'
alias gstatus='git status'
alias gstash="git stash"
alias gadd='git add'
alias gbranch='git branch'
alias gcommit='git commit -m'
alias gdiff='git diff'
alias gpull='git pull origin $(git rev-parse --abbrev-ref HEAD)'
alias gpush='git push origin'
alias gpushf='git push origin -f'
alias gresets='git reset --soft'
alias greseth='git reset --hard'

alias vi="nvim"
alias vim="nvim"
alias code="nvim"
