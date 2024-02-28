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
  panes=$(tmux list-panes -a -F "id: #{pane_id} process: #{pane_current_command} window_id: #{window_id} session: #{session_name}" | grep $1)
  panes_array=($panes)

  for (( i=0; i<${#panes_array[@]}; i++ )); do
    echo ${panes_array[$i]} | awk '{print $1, $2, $3, $4, $5, $6}'
  done

}

export -f list_tmux_session_processes

function list_available_teamocil_sessions {
  files=$(ls $HOME/.config/teamocil/)
  tmux_sessions_array=$(list_tmux_sessions)

  for file in $files; do
    session_name=$(echo $file | awk -F'.' '{print $1}')
  
    if [[ ! $(echo "${tmux_sessions_array[@]}" | fgrep -w "$session_name") ]]; then
       echo "$session_name"
    fi
  done
}

export -f list_available_teamocil_sessions 

function kill_tmux_pane {
    pane_id=$(echo $1 | awk '{print $2}')
    pane_process=$(echo $1 | awk '{print $4}')
    kill_cmd="C-c"

    if [[ "$pane_process" =~ psql ]]; then
      kill_cmd='\q Enter'
    fi

    if [ "$pane_process" != "nvim" ] && [ "$pane_process" != "zsh" ]; then
      tmux send-keys -t $pane_id $kill_cmd
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

export ENV_FILE=$HOME/log.sh
export TEAMOCIL_FOLDER=$HOME/.config/teamocil/

export SESSIONS_HEADER="Press Ctrl-T for switch to processes / Ctrl-D for kill session"
export SESSIONS_PROMPT="sessions> "

export TEAMOCIL_HEADER="Press Ctrl-E to edit / Enter to start teamocil session"
export TEAMOCIL_PROMPT="teamocil>"

export PROCESSES_HEADER="Press Enter to move to process; Ctrl-D for kill"
export PROCESSES_PROMPT="processes>"

function change_env_variable {
  echo "export $1=$2" >> $ENV_FILE
}

function clear_env_file {
  : > $ENV_FILE
}

function source_env_file {
  source $ENV_FILE
}

export -f change_env_variable
export -f clear_env_file 
export -f source_env_file 

function __preview {
  source_env_file

  if [[ $SELECTED_FZF_SESSION ]]; then 
      echo $1 | awk '{print $2}' | xargs -I pane_id tmux capture-pane -eJ -t pane_id && tmux show-buffer
  else
    if [[ $IS_TEAMOCIL_SESSION ]]; then 
      cat "$TEAMOCIL_FOLDER/$1.yml"
    else
      list_tmux_windows $1
    fi
  fi
}

function __bind_ctrl_s {
  source_env_file

  if [[ $IS_TEAMOCIL_SESSION ]]; then 
    input="echo $SESSIONS_HEADER; list_tmux_sessions"

    echo "change-prompt($SESSIONS_PROMPT)+reload($input)+execute(clear_env_file)"
  else
    input="echo $TEAMOCIL_HEADER; list_available_teamocil_sessions"

    echo "change-prompt($TEAMOCIL_PROMPT)+reload($input)+execute(change_env_variable IS_TEAMOCIL_SESSION true)"
  fi
}

function __bind_ctrl_t {
  source_env_file

  if [[ $SELECTED_FZF_SESSION ]]; then 
    input="echo $SESSIONS_HEADER; list_tmux_sessions"

    echo "execute(clear_env_file)+change-prompt($SESSIONS_PROMPT)+reload($input)"
  else
    input="echo $PROCESSES_HEADER; list_tmux_session_processes $1"

echo "execute(change_env_variable SELECTED_FZF_SESSION {})+change-prompt($PROCESSES_PROMPT)+reload($input)"

  fi
}

function __bind_ctrl_d {
  source_env_file

  if [[ $SELECTED_FZF_SESSION ]]; then 
    input="sleep 1 && echo $PROCESSES_HEADER; list_tmux_session_processes $SELECTED_FZF_SESSION"

    echo "execute(kill_tmux_pane {})+reload($input)"
  else
    input="echo $SESSIONS_HEADER; list_tmux_sessions"

    echo "execute(kill_tmux_panes {} && tmux kill-session -t {})+reload($input)"
  fi
}

function __bind_ctrl_e {
  source_env_file

  if [[ $IS_TEAMOCIL_SESSION ]]; then 
    echo "execute(change_env_variable TEAMOCIL_SESSION $1)+abort+abort"
  fi
}

export -f __preview
export -f __bind_ctrl_s 
export -f __bind_ctrl_t
export -f __bind_ctrl_d
export -f __bind_ctrl_e

function fzf_tmux_sessions {
  FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS \
  --prompt='sessions> '
  --height='100%'
  --header-lines=1"
  
  session_or_process=$(( echo $SESSIONS_HEADER; list_tmux_sessions ) | fzf \
    --preview '__preview {}' \
    --bind 'ctrl-s:transform:__bind_ctrl_s {}' \
    --bind 'ctrl-t:transform:__bind_ctrl_t {}' \
    --bind 'ctrl-d:transform:__bind_ctrl_d {}' \
    --bind 'ctrl-e:transform:__bind_ctrl_e {}' \
  )

  source_env_file

  if [[ ! $session_or_process ]]; then
    if [[ $IS_TEAMOCIL_SESSION ]]; then
      tmux new-window nvim $TEAMOCIL_FOLDER/$TEAMOCIL_SESSION.yml
    fi

    clear_env_file
    return
  fi

  if [[ $session_or_process =~ 'process' ]]; then
    process=$session_or_process
    pane_id=$(echo $process | awk '{print $2}')
    window_id=$(echo $process | awk '{print $6}')

    tmux switch -t $SELECTED_FZF_SESSION
    tmux select-window -t $window_id
    tmux select-pane -t $pane_id
  else
    session=$session_or_process

    if [[ $IS_TEAMOCIL_SESSION ]]; then
      tmux new-session -d -s $session "teamocil $session"
      tmux switch -t $session
    else
      tmux switch -t $session
    fi
  fi

  clear_env_file
}

export -f fzf_tmux_sessions
