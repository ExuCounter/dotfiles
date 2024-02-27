function list_tmux_sessions {
  tmux list-sessions | sed -E 's/:.*$//' | awk \"/^[a-zA-Z]/\" | grep -v '^$(tmux display-message -p "#S")\$'
}

export -f list_tmux_sessions

function list_tmux_session_processes {
  if [ ! $1 ]; then
    echo 'Please provide tmux session name'
    return 
  fi

  local IFS=$'\n'
  panes=$(tmux list-panes -a -F "id: #{pane_id} process: #{pane_current_command} session: #{session_name}" | grep $1)
  panes_array=($panes)

  for (( i=0; i<${#panes_array[@]}; i++ )); do
    echo ${panes_array[$i]} | awk '{print $1, $2, $3, $4}'
  done

}

export -f list_tmux_session_processes

function list_available_teamocil_sessions {
  files=$(ls $(dirname $0)/../../teamocil/)
  tmux_sessions_array=$(list_tmux_sessions)
  
  for file in $files; do
    session_name=$(echo $file | awk -F'.' '{print $1}')
  
    if [[ $(echo "${tmux_sessions_array[@]}" | fgrep -w "$session_name") ]];
     then
       echo "$session_name (Running)"
     else
       echo "$session_name (Stopped)"
    fi
  done
}


export -f list_available_teamocil_sessions 

function kill_tmux_pane {
    pane_id=$(echo $1 | awk '{print $2}')
    pane_process=$(echo $1 | awk '{print $4}')
    kill_cmd="C-c"

    if [[ "$pane_process" =~ python ]]; then
      kill_cmd='C-c "exit" Enter'
    fi

    if [[ "$pane_process" =~ psql ]]; then
      kill_cmd='\q Enter'
    fi

    if [ "$pane_process" != "nvim" ] && [ "$pane_process" != "zsh" ]; then
      tmux send-keys -t $pane_id $kill_cmd
      return 0
    else
      return 2
    fi

}


export -f kill_tmux_pane 

function kill_tmux_panes {
  if [ ! $1 ]; then
    echo 'Please provide tmux session name'
    return 
  fi

  local IFS=$'\n'
  panes_array=($(list_tmux_session_processes $1))

  for (( i=0; i<${#panes_array[@]}; i++ )); do
   kill_tmux_pane ${panes_array[$i]}
  done
}

export -f kill_tmux_panes

# function fzf_tmux_sessions {
#   list_available_teamocil_sessions $1 | fzf --reverse \
#   --prompt 'Sessions> ' \
#   --header 'CTRL-D to stop session / Enter to start or open session' \
#   --bind 'ctrl-d:transform:[[ $FZF_PROMPT =~ Sessions ]] &&
#   echo "execute(echo {} | awk '\''{print \$1}'\'' | xargs -I session_name bash -c \"source ~/.config/fzf_tmux_sessions/sh/functions.sh && kill_tmux_panes session_name\" 2>> ~/log.txt)+reload(echo {})" || echo "execute(echo lol)"' \
#   --bind 'ctrl-p:transform:[[ $FZF_PROMPT =~ Sessions ]] && 
#   echo "change-prompt(Processes> )+reload(echo {} | awk '\''{print \$1}'\'' | xargs -I session_name bash -c \"source ~/.config/fzf_tmux_sessions/sh/functions.sh; list_tmux_session_processes session_name\" 2>> ~/log.txt)" ||
#   echo "change-prompt(Sessions> )+reload(echo {} | awk "{print \$1}" | list_available_teamocil_sessions)"'
# }

# function fzf_tmux_sessions {
#   list_tmux_sessions | fzf --reverse \
#   --prompt 'Sessions> ' \
#   --header 'CTRL-D to stop session / Enter to start or open session' \
#   --bind 'ctrl-d:transform:[[ $FZF_PROMPT =~ Sessions ]] &&
#   echo "execute(source ~/.config/fzf_tmux_sessions/sh/functions.sh && kill_tmux_panes {}\" 2>> ~/log.txt)+reload(echo {})" || echo "execute(echo lol)+reload(bash -c \"source ~/.config/fzf_tmux_sessions/sh/functions.sh; list_tmux_session_processes {}\")""' \
#   --bind 'ctrl-p:transform:[[ $FZF_PROMPT =~ Sessions ]] && 
#   echo "change-prompt(Processes> )+reload(bash -c \"source ~/.config/fzf_tmux_sessions/sh/functions.sh; list_tmux_session_processes {}\")" ||
#   echo "change-prompt(Sessions> )+reload(bash -c \"source ~/.config/fzf_tmux_sessions/sh/functions.sh; list_tmux_sessions {}\")"'
# }

#!/usr/bin/env bash

function list_tmux_windows {
  tmux ls -F'#{session_id}' | while read -r s; do
    S=$(tmux ls -F'#{session_id}#{session_name}: #{T:tree_mode_format}' | grep ^"$s")
    session_info=${S##$s}
    session_name=$(echo "$session_info" | cut -d ':' -f 1)
    if [[ -n "$1" ]] && [[ "$1" == "$session_name" ]]; then
        echo -e "\033[1;34m$session_info\033[0m"
    else
        echo -e "\033[1m$session_info\033[0m"
    fi
    tmux lsw -t"$s" -F'#{window_id}' | while read -r w; do
        W=$(tmux lsw -t"$s" -F'#{window_id}#{T:tree_mode_format}' | grep ^"$w")
        echo "  ﬌ ${W##$w}"
    done
  done
}

export -f list_tmux_windows

function fzf_tmux_sessions {
  FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS \
  --prompt='sessions> '
  --header='Ctrl-T for switch / Ctrl-D for kill'
  --height='100%'"
  
  session_or_process=$(list_tmux_sessions | fzf \
    --preview 'source $HOME/log.sh && [[ ! $SELECTED_FZF_SESSION ]] && list_tmux_windows {} && sleep 0.1 && source "$HOME/log.sh" && echo $SELECTED_FZF_SESSION >> ~/log.txt || echo {} | awk "{print \$2}" | xargs -I pane_id bash -c "tmux capture-pane -eJ -t pane_id && tmux show-buffer"' \
    --bind 'ctrl-t:transform:[[ $FZF_PROMPT =~ sessions ]] &&
    echo "execute(echo "export SELECTED_FZF_SESSION={}" > ~/log.sh)+change-prompt({} session processes> )+reload(list_tmux_session_processes {})" ||
    echo "execute(: > ~/log.sh)+change-prompt(sessions> )+reload(list_tmux_sessions {})"' \
    --bind 'ctrl-d:transform:[[ $FZF_PROMPT =~ sessions ]] &&
    echo "execute(kill_tmux_panes {})+reload(list_tmux_sessions)" ||
    echo "execute(kill_tmux_pane {})+reload(sleep 0.15 && echo \"$FZF_PROMPT\" | awk '\''{print \$1}'\'' | xargs -I session_name bash -c \"list_tmux_session_processes session_name\" 2> ~/log.txt)"'
  )

  if [[ ! $session_or_process ]]; then
    echo "Exited"
    return
  fi

  if [[ $session_or_process =~ 'process' ]]; then
    pane_id=$(echo $session_or_process | awk '{print $2}')

    echo $session >> ~/log.txt
    echo $pane_id >> ~/log.txt

    tmux switch -t $SELECTED_FZF_SESSION
    tmux select-pane -t $pane_id
  else
    tmux switch -t $session_or_process
  fi
}

export -f fzf_tmux_sessions
