#!/bin/bash

function kill_tmux_pane {
    pane_id=$(echo $1 | awk '{print $1}')
    pane_process=$(echo $1 | awk '{print $2}')
    kill_cmd="C-c"

    if [ "$pane_process" != "nvim" ] && [ "$pane_process" != "zsh" ]; then
      tmux send-keys -t $pane_id $kill_cmd
    fi
}

function kill_tmux_panes {
  if [ ! $1 ]; then
    echo 'Please provide tmux session name'
    return 
  fi

  local IFS=$'\n'
  panes=$(tmux list-panes -a -F "#{pane_id} #{pane_current_command} #{session_name}\n" | grep $1)
  panes_array=($panes)

  for (( i=0; i<${#panes_array[@]}; i++ )); do
    kill_tmux_pane ${panes_array[$i]}
  done
}

export -f kill_tmux_panes
