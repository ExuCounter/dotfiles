#!/usr/bin/env bash

input=$(cat)

model=$(echo "$input" | jq -r '.model.display_name // "Claude"')
effort=$(echo "$input" | jq -r '.effort.level // .model.effort // .output_style.name // empty')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
used_tokens=$(echo "$input" | jq -r '.context_window.total_input_tokens // .context_window.used_tokens // empty')
total_tokens=$(echo "$input" | jq -r '.context_window.context_window_size // .context_window.total_tokens // empty')
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
cache_read=$(echo "$input" | jq -r '.context_window.current_usage.cache_read_input_tokens // empty')
cache_write=$(echo "$input" | jq -r '.context_window.current_usage.cache_creation_input_tokens // empty')
fresh_in=$(echo "$input" | jq -r '.context_window.current_usage.input_tokens // empty')

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
    # Uncommitted work (staged + unstaged, tracked files) — how much
    # AI-written code is sitting unreviewed.
    diff_label=""
    shortstat=$(git -C "$cwd" diff HEAD --shortstat 2>/dev/null)
    if [ -n "$shortstat" ]; then
      adds=$(echo "$shortstat" | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+')
      dels=$(echo "$shortstat" | grep -oE '[0-9]+ deletion' | grep -oE '[0-9]+')
      : "${adds:=0}" "${dels:=0}"
      diff_label=" \033[32m+${adds}${reset}\033[31m-${dels}${reset}"
    fi
    git_segment=" ${dim}|${reset} \033[36m${branch}${reset}${wt_label}${diff_label}"
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
  bar=$(awk -v f="$filled" -v e="$empty" 'BEGIN{ s=""; for(i=0;i<f;i++) s=s "█"; for(i=0;i<e;i++) s=s "░"; print s }')

  # Token count: prefer real fields, fall back to 200k window estimate
  [ -z "$total_tokens" ] || [ "$total_tokens" = "0" ] && total_tokens=200000
  if [ -z "$used_tokens" ]; then
    used_tokens=$(( total_tokens * used_int / 100 ))
  fi
  used_tokens=$(printf '%.0f' "$used_tokens")
  fmt_k() { awk -v n="$1" 'BEGIN{ if (n>=1000000) printf "%.1fM", n/1000000; else if (n>=10000) printf "%.0fk", n/1000; else printf "%.1fk", n/1000 }'; }
  tokens_label="$(fmt_k "$used_tokens")/$(fmt_k "$total_tokens")"

  # Cache hit ratio on the last API call: how much of the input was served
  # from the prompt cache rather than re-sent.
  : "${cache_read:=0}" "${cache_write:=0}" "${fresh_in:=0}"
  last_in=$(( cache_read + cache_write + fresh_in ))
  if [ "$last_in" -gt 0 ]; then
    hit=$(( cache_read * 100 / last_in ))
    tokens_label="${tokens_label} $(printf '\033[2m')⚡${hit}%"
  fi

  # Zone thresholds, in tokens. Big windows get absolute budgets (a 1M context
  # doesn't become unwieldy at 250k just because that's 25% of it); 200k-class
  # windows keep the original percentage points.
  if [ "$total_tokens" -ge 1000000 ]; then
    t_plan=125000; t_code=250000; t_dump=350000; t_dead=750000
  else
    t_plan=$(( total_tokens * 25 / 100 ))
    t_code=$(( total_tokens * 40 / 100 ))
    t_dump=$(( total_tokens * 70 / 100 ))
    t_dead=$(( total_tokens * 75 / 100 ))
  fi

  if [ "$used_tokens" -ge "$t_dead" ]; then
    color="\033[90m"; zone="Dead — start new session"
  elif [ "$used_tokens" -ge "$t_dump" ]; then
    color="\033[31m"; zone="ExDump — handoff now"
  elif [ "$used_tokens" -ge "$t_code" ]; then
    color="\033[38;5;208m"; zone="Dump — wrap up, prep handoff"
  elif [ "$used_tokens" -ge "$t_plan" ]; then
    color="\033[33m"; zone="Code-only — finish task, no new plans"
  else
    color="\033[32m"; zone="Planning — keep coding"
  fi

  printf "%b%b  ${color}[%s]${reset} %s%% \033[38;5;240m(%s)${reset}  ${dim}·${reset} ${color}%s${reset}" \
    "$model_label" "$git_segment" "$bar" "$used_int" "$tokens_label" "$zone"
else
  printf "%b%b" "$model_label" "$git_segment"
fi
