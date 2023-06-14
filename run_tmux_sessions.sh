tmux new-session -d -s prosapient 'teamocil prosapient'
tmux new-session -d -s learning 'teamocil learning'
tmux new-session -d -s dotfiles 'teamocil dotfiles'

if [$TMUX = ""]; then
  echo "Starting tmux"
  tmux
fi

echo "Sessions started"
echo "Press prefix C-F to switch sessions"
