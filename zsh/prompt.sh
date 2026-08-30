elixir_prompt_info() {
  local dir=$PWD
  while [[ -n $dir && $dir != / ]]; do
    if [[ -f $dir/mix.exs ]]; then
      local tv=$dir/.tool-versions
      [[ -f $tv ]] || return
      local ex er out=""
      ex=$(awk '$1=="elixir"{print $2; exit}' "$tv")
      er=$(awk '$1=="erlang"{print $2; exit}' "$tv")
      [[ -n $ex ]] && out+=" %F{#4B275F}"$''" $ex%f"
      [[ -n $er ]] && out+=" %F{#A90533}"$''" $er%f"
      print -n -- "$out"
      return
    fi
    dir=${dir:h}
  done
}

PROMPT='[%*] %{$fg[green]%}%c%{$reset_color%}$(git_prompt_info)$(elixir_prompt_info) %(!.#.$) '
