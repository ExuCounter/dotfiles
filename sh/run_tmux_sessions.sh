#!/bin/bash

function run_tmux_sessions {
  echo "Starting sessions. Enjoy!"

  tmux new-session -d -s expert-portal 'teamocil expert-portal'
  tmux new-session -d -s surveys 'teamocil surveys'
  tmux new-session -d -s platform 'teamocil platform'
  tmux new-session -d -s learning 'teamocil learning'
  tmux new-session -d -s dotfiles 'teamocil dotfiles'
  tmux new-session -s build 'teamocil build'
}

export -f run_tmux_sessions
