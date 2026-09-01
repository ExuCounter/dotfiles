#!/usr/bin/env bash

input=$(cat)

model=$(echo "$input" | jq -r '.model.display_name // "Claude"')
effort=$(echo "$input" | jq -r '.model.effort // .model.reasoning_effort // .reasoning_effort // .output_style.name // empty')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
used_tokens=$(echo "$input" | jq -r '.context_window.used_tokens // .context_window.tokens_used // empty')
total_tokens=$(echo "$input" | jq -r '.context_window.total_tokens // .context_window.max_tokens // empty')
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')

reset="\033[0m"
dim="\033[2m"

model_label="$model"
if [ -n "$effort" ]; then
  model_label="${model}${dim}·${reset}\033[35m${effort}${reset}"
fi

# Git branch + worktree folder
git_segment=""
if [ -n "$cwd" ] && command -v git >/dev/null 2>&1; then
  branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
  if [ -n "$branch" ]; then
    git_dir=$(git -C "$cwd" rev-parse --git-dir 2>/dev/null)
    wt_label=""
    case "$git_dir" in
      *"/worktrees/"*)
        wt_name=$(basename "$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)")
        wt_label=" ${dim}⑂${reset}\033[35m${wt_name}${reset}"
        ;;
    esac
    git_segment=" ${dim}|${reset} \033[36m${branch}${reset}${wt_label}"
  fi
fi

if [ -n "$used" ]; then
  used_int=$(printf '%.0f' "$used")

  # 15-char bar (~25% smaller than before). Each block ≈ 6.67%.
  bar_width=15
  filled=$(( (used_int * bar_width + 50) / 100 ))
  [ "$filled" -gt "$bar_width" ] && filled=$bar_width
  [ "$filled" -lt 0 ] && filled=0
  empty=$(( bar_width - filled ))
  bar=""
  for i in $(seq 1 $filled); do bar="${bar}█"; done
  for i in $(seq 1 $empty); do bar="${bar}░"; done

  # Token count: prefer real fields, fall back to 200k window estimate
  [ -z "$total_tokens" ] && total_tokens=200000
  if [ -z "$used_tokens" ]; then
    used_tokens=$(( total_tokens * used_int / 100 ))
  fi
  fmt_k() { awk -v n="$1" 'BEGIN{ printf (n>=10000)? "%.0fk" : "%.1fk", n/1000 }'; }
  tokens_label="$(fmt_k "$used_tokens")/$(fmt_k "$total_tokens")"

  # Zones from luongnv89/context-stats (standard-context defaults)
  if [ "$used_int" -ge 75 ]; then
    color="\033[90m"; zone="Dead — start new session"
  elif [ "$used_int" -ge 70 ]; then
    color="\033[31m"; zone="ExDump — handoff now"
  elif [ "$used_int" -ge 40 ]; then
    color="\033[38;5;208m"; zone="Dump — wrap up, prep handoff"
  elif [ "$used_int" -ge 25 ]; then
    color="\033[33m"; zone="Code-only — finish task, no new plans"
  else
    color="\033[32m"; zone="Planning — keep coding"
  fi

  printf "%b%b  ${color}[%s]${reset} %s%% \033[38;5;240m(%s)${reset}  ${dim}·${reset} ${color}%s${reset}" \
    "$model_label" "$git_segment" "$bar" "$used_int" "$tokens_label" "$zone"
else
  printf "%b%b" "$model_label" "$git_segment"
fi
