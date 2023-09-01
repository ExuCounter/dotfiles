#!/bin/sh

run_tmux_sessions() {
  if [$TMUX = ""]; then
    echo "Starting tmux"
    tmux
  fi

  echo "Sessions starting"
  echo "Press prefix C-f to switch sessions"
  echo "Have a nice session :D You are the best. Engineering is true magic"

  tmux new-session -d -s prosapient 'teamocil prosapient'
  tmux new-session -d -s learning 'teamocil learning'
  tmux new-session -d -s dotfiles 'teamocil dotfiles'
  tmux new-session -s build 'teamocil build'

  }

alias run_tmux_sessions=run_tmux_sessions
